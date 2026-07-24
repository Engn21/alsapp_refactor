import type {
  ChatCompletionMessageParam,
  ChatCompletionCreateParamsNonStreaming,
} from "groq-sdk/resources/chat/completions";
import { getGroqClient } from "../groq";
import { ASSISTANT_TOOLS } from "./tools";
import { buildSystemPrompt } from "./systemPrompt";
import { toolExecutors, ToolCtx } from "./toolExecutors";

const MODEL = "llama-3.3-70b-versatile";
const MAX_COMPLETION_TOKENS = 1024;
// Prevents a pathological repeated-tool-call loop from running unbounded
// cost on a single user message.
const MAX_TOOL_ITERATIONS = 6;

export interface ToolCallAudit {
  toolName: string;
  input: unknown;
  outputSummary: string;
  isError: boolean;
}

export interface AssistantTurnResult {
  replyText: string;
  toolCallAudit: ToolCallAudit[];
}

// Llama models on Groq occasionally leak their internal tool-call
// pseudo-XML into the visible reply text (e.g. malformed
// "<function=get_crops-null</function>" fragments) instead of using the
// proper tool_calls mechanism, especially in non-English replies. Strip
// any such fragments as a safety net regardless of root cause.
function sanitizeReply(text: string): string {
  return text.replace(/<function[\s\S]*?<\/function>/g, "").replace(/\s{2,}/g, " ").trim();
}

const MAX_GENERATION_RETRIES = 2;

// Same malformed-generation issue as above, but sometimes severe enough
// that Groq's own API rejects the request outright (400, code
// "tool_use_failed") before any content is returned at all - retried a
// couple of times since it's a stochastic generation glitch, not a
// deterministic failure (the same prompt shape works most of the time).
async function createCompletionWithRetry(
  client: ReturnType<typeof getGroqClient>,
  params: ChatCompletionCreateParamsNonStreaming,
) {
  for (let attempt = 0; ; attempt++) {
    try {
      return await client.chat.completions.create(params);
    } catch (e: any) {
      const isToolUseFailure = e?.error?.error?.code === "tool_use_failed";
      if (!isToolUseFailure || attempt >= MAX_GENERATION_RETRIES) throw e;
    }
  }
}

export async function runAssistantTurn(
  ctx: ToolCtx,
  history: ChatCompletionMessageParam[],
  userMessage: string,
): Promise<AssistantTurnResult> {
  const client = getGroqClient();
  const messages: ChatCompletionMessageParam[] = [
    { role: "system", content: buildSystemPrompt(ctx.lang) },
    ...history,
    { role: "user", content: userMessage },
  ];
  const toolCallAudit: ToolCallAudit[] = [];

  for (let iteration = 0; iteration < MAX_TOOL_ITERATIONS; iteration++) {
    const completion = await createCompletionWithRetry(client, {
      model: MODEL,
      messages,
      tools: ASSISTANT_TOOLS,
      max_completion_tokens: MAX_COMPLETION_TOKENS,
    });

    const choice = completion.choices[0];
    const message = choice?.message;
    const toolCalls = message?.tool_calls;

    if (choice?.finish_reason !== "tool_calls" || !toolCalls?.length) {
      const replyText = sanitizeReply(message?.content ?? "");
      return {
        replyText: replyText || "I'm not sure how to answer that - could you rephrase?",
        toolCallAudit,
      };
    }

    // Push the assistant's turn (including its tool_calls) as-is so the
    // call ids line up with the tool results we send next.
    messages.push({ role: "assistant", content: message.content, tool_calls: toolCalls });

    for (const call of toolCalls) {
      const name = call.function.name;
      let args: unknown = {};
      try {
        args = call.function.arguments ? JSON.parse(call.function.arguments) : {};
      } catch {
        // Malformed JSON from the model - treat as no args.
      }

      const executor = toolExecutors[name];
      let result: string;
      let isError: boolean;
      if (!executor) {
        result = `Unknown tool: ${name}`;
        isError = true;
      } else {
        try {
          const outcome = await executor(args, ctx);
          result = outcome.result;
          isError = outcome.isError;
        } catch (e: any) {
          result = e?.message ?? "Tool execution failed.";
          isError = true;
        }
      }
      toolCallAudit.push({
        toolName: name,
        input: args,
        outputSummary: result.slice(0, 300),
        isError,
      });
      messages.push({ role: "tool", tool_call_id: call.id, content: result });
    }
  }

  // Loop exhausted without a final answer - return whatever we have
  // rather than looping forever or erroring out to the user.
  return {
    replyText:
      "I looked into a few things but couldn't finish - could you rephrase your question?",
    toolCallAudit,
  };
}
