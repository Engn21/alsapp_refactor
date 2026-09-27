import type {
  ChatCompletionMessageParam,
  ChatCompletionCreateParamsNonStreaming,
} from "groq-sdk/resources/chat/completions";
import { getGroqClient } from "../groq";
import { ASSISTANT_TOOLS } from "./tools";
import { buildSystemPrompt } from "./systemPrompt";
import { toolExecutors, ToolCtx } from "./toolExecutors";

// llama-3.3-70b-versatile was retired from Groq's catalog; gpt-oss-120b is
// the closest available replacement that still supports tool calling.
const MODEL = "openai/gpt-oss-120b";
const MAX_COMPLETION_TOKENS = 1024;
// Prevents a pathological repeated-tool-call loop from running unbounded
// cost on a single user message.
const MAX_TOOL_ITERATIONS = 6;

// Canned replies shown when the model gives nothing usable. Keyed by the
// app's UI language so a Turkish or French farmer doesn't get English here.
const CANNED_REPLIES: Record<string, Record<"lookupFailed" | "rephrase" | "unfinished", string>> = {
  en: {
    lookupFailed: "I'm having trouble looking that up right now - please try again in a moment.",
    rephrase: "I'm not sure how to answer that - could you rephrase?",
    unfinished: "I looked into a few things but couldn't finish - could you rephrase your question?",
  },
  tr: {
    lookupFailed: "Şu an buna bakamıyorum - lütfen biraz sonra tekrar dene.",
    rephrase: "Bunu nasıl yanıtlayacağımdan emin değilim - sorunu farklı şekilde sorabilir misin?",
    unfinished: "Birkaç şeye baktım ama sonuca varamadım - sorunu farklı şekilde sorabilir misin?",
  },
  fr: {
    lookupFailed: "Je n'arrive pas à consulter cela pour le moment - réessayez dans un instant.",
    rephrase: "Je ne sais pas comment répondre à cela - pouvez-vous reformuler ?",
    unfinished: "J'ai regardé plusieurs choses sans pouvoir conclure - pouvez-vous reformuler votre question ?",
  },
  es: {
    lookupFailed: "No puedo consultar eso en este momento - inténtalo de nuevo en un momento.",
    rephrase: "No estoy seguro de cómo responder a eso - ¿podrías reformularlo?",
    unfinished: "Revisé varias cosas pero no pude llegar a una conclusión - ¿podrías reformular tu pregunta?",
  },
};

function cannedReply(lang: string, key: "lookupFailed" | "rephrase" | "unfinished"): string {
  return (CANNED_REPLIES[lang] ?? CANNED_REPLIES.tr)[key];
}

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

// Models on Groq occasionally leak formatting the system prompt explicitly
// forbids - internal tool-call pseudo-XML (e.g. malformed
// "<function=get_crops-null</function>" fragments), stray HTML tags, or
// markdown tables - into the visible reply, which render as literal
// garbage in the app's plain-text chat bubble. Strip it as a safety net
// regardless of root cause.
function sanitizeReply(text: string): string {
  return text
    .replace(/<function[\s\S]*?<\/function>/g, "")
    .replace(/<\/?[a-z][a-z0-9]*[^>]*>/gi, "") // stray HTML tags, e.g. <br>
    .split("\n")
    .filter((line) => !/^[\s|:-]+$/.test(line)) // markdown table separator rows
    .join("\n")
    .replace(/\|/g, " ") // remaining table pipes
    .replace(/^#{1,6}\s*/gm, "") // markdown headers
    .replace(/\*\*([^*]+)\*\*/g, "$1") // bold
    .replace(/(?<!\*)\*([^*]+)\*(?!\*)/g, "$1") // italics
    .replace(/[ \t]{2,}/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

const MAX_GENERATION_RETRIES = 4;

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
    let completion;
    try {
      completion = await createCompletionWithRetry(client, {
        model: MODEL,
        messages,
        tools: ASSISTANT_TOOLS,
        max_completion_tokens: MAX_COMPLETION_TOKENS,
      });
    } catch (e: any) {
      if (e?.error?.error?.code !== "tool_use_failed") throw e;
      // Tool-calling generation is still broken after retries - fall back to
      // a plain completion with no tools so the user gets some answer
      // instead of the request hard-failing.
      const fallback = await createCompletionWithRetry(client, {
        model: MODEL,
        messages,
        max_completion_tokens: MAX_COMPLETION_TOKENS,
      }).catch(() => null);
      const replyText = sanitizeReply(fallback?.choices[0]?.message?.content ?? "");
      return {
        replyText: replyText || cannedReply(ctx.lang, "lookupFailed"),
        toolCallAudit,
      };
    }

    const choice = completion.choices[0];
    const message = choice?.message;
    const toolCalls = message?.tool_calls;

    if (choice?.finish_reason !== "tool_calls" || !toolCalls?.length) {
      const replyText = sanitizeReply(message?.content ?? "");
      return {
        replyText: replyText || cannedReply(ctx.lang, "rephrase"),
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
    replyText: cannedReply(ctx.lang, "unfinished"),
    toolCallAudit,
  };
}
