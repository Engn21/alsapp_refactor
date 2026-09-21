import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/disease_classifier_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../utils/photo_picker.dart';
import '../widgets/language_selector.dart';

// What a photo sent from the chat shows. The chat isn't tied to one crop, so
// the farmer says what it is: that picks the on-device model and restricts
// the answer to that crop's own classes. Only what the shipped models can
// actually diagnose is offered (see DiseaseClassifierService.availablePlantCrops);
// everything else goes under "Other crop", which says so instead of guessing.
class _PhotoSubject {
  final String labelKey;
  final IconData icon;
  // Null for "other crop": no model covers it.
  final DiagnosisModel? model;
  final String? labelPrefix;

  const _PhotoSubject(this.labelKey, this.icon, this.model, this.labelPrefix);
}

const _cattleSubject =
    _PhotoSubject('Cattle', Icons.pets, DiagnosisModel.cattle, null);
const _otherCropSubject =
    _PhotoSubject('Other crop', Icons.help_outline, null, null);

// Display order and translation key for each crop the plant model may cover.
const _plantSubjectKeys = <String, String>{
  'wheat': 'Wheat',
  'olive': 'Olive',
  'tomato': 'Tomato',
  'corn': 'Corn',
  'grape': 'Grape',
};

// AI farm assistant chat screen. Reached from the Dashboard app bar, next
// to the notification bell. Messages render newest-first in a reversed
// ListView; sending is optimistic (the outgoing bubble appears
// immediately) and failures stay visible with a retry affordance rather
// than being silently dropped.
class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String? initialTitle;
  // Auto-sent once history has loaded - used by flows that hand off into a
  // fresh conversation with something to say already in hand (e.g. photo
  // diagnosis results), so the farmer sees it arrive like a normal message
  // instead of having to type it themselves.
  final String? initialMessage;

  const ChatScreen({
    super.key,
    required this.conversationId,
    this.initialTitle,
    this.initialMessage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  // Newest-first, matching the reversed ListView.
  final List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  double? _lat;
  double? _lon;
  List<_PhotoSubject> _photoSubjects = const [_cattleSubject];

  @override
  void initState() {
    super.initState();
    _loadPhotoSubjects();
    _loadHistory().then((_) {
      if (widget.initialMessage != null && mounted) {
        _controller.text = widget.initialMessage!;
        _send();
      }
    });
    _loadLocation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await ChatService.history(widget.conversationId);
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(history.reversed);
      _loading = false;
    });
  }

  Future<void> _loadPhotoSubjects() async {
    final crops = await DiseaseClassifierService.availablePlantCrops();
    if (!mounted) return;
    setState(() {
      _photoSubjects = [
        for (final e in _plantSubjectKeys.entries)
          if (crops.contains(e.key))
            _PhotoSubject(e.value, Icons.eco_outlined, DiagnosisModel.plant,
                plantLabelPrefixByCrop[e.key]),
        _cattleSubject,
      ];
    });
  }

  Future<void> _loadLocation() async {
    // Best-effort, fetched once (not per-message) since it's a device
    // permission prompt - used to ground weather questions.
    try {
      final coords = await LocationService.getCoords();
      if (!mounted || coords == null) return;
      setState(() {
        _lat = coords.lat;
        _lon = coords.lon;
      });
    } catch (_) {
      // No location - the assistant will ask the farmer for their city.
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    _controller.clear();

    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final outgoing = ChatMessage(
      id: localId,
      role: 'user',
      content: text,
      createdAt: DateTime.now(),
    );
    setState(() {
      _messages.insert(0, outgoing);
      _sending = true;
    });

    await _dispatch(outgoing);
  }

  Future<void> _dispatch(ChatMessage outgoing) async {
    final lang = Localizations.localeOf(context).languageCode;
    final result = await ChatService.send(
      widget.conversationId,
      outgoing.content,
      lang: lang,
      lat: _lat,
      lon: _lon,
    );
    if (!mounted) return;

    setState(() {
      _sending = false;
      final idx = _messages.indexWhere((m) => m.id == outgoing.id);
      if (result.isSuccess) {
        if (idx != -1) {
          _messages[idx] = outgoing.copyWith(failed: false);
        }
        _messages.insert(
          0,
          ChatMessage(
            id: 'local-reply-${DateTime.now().microsecondsSinceEpoch}',
            role: 'assistant',
            content: result.reply!,
            createdAt: DateTime.now(),
          ),
        );
      } else if (idx != -1) {
        _messages[idx] = outgoing.copyWith(failed: true);
      }
    });

    if (!result.isSuccess) {
      final message = result.errorMessage == 'rate_limited'
          ? context.tr('Too many messages, please wait a moment.')
          : context.tr('Failed to send. Tap to retry.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: context.tr('Retry'),
            onPressed: () => _retry(outgoing),
          ),
        ),
      );
    }
  }

  Future<void> _retry(ChatMessage outgoing) async {
    if (_sending) return;
    setState(() => _sending = true);
    await _dispatch(outgoing);
  }

  Future<_PhotoSubject?> _chooseSubject() {
    // Scrollable: with every crop offered the list is taller than the default
    // sheet (9/16 of the screen) on short phones and would overflow.
    return showModalBottomSheet<_PhotoSubject>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  ctx.tr('What is in the photo?'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
              for (final subject in [..._photoSubjects, _otherCropSubject])
                ListTile(
                  leading: Icon(subject.icon),
                  title: Text(ctx.tr(subject.labelKey)),
                  onTap: () => Navigator.pop(ctx, subject),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // Photo diagnosis runs entirely on-device with our own trained models -
  // the photo never goes to the LLM. The result is shown as a normal
  // exchange in the chat and saved to the conversation, so a follow-up text
  // question ("what should I do?") reaches the assistant with it as context.
  Future<void> _sendPhoto() async {
    if (_sending) return;
    final subject = await _chooseSubject();
    if (subject == null || !mounted) return;

    final model = subject.model;
    if (model == null) {
      // No model for this crop: say so plainly rather than guessing, and
      // point at the text chat, which can still help. Not saved to history.
      setState(() {
        _messages.insert(
          0,
          ChatMessage(
            id: 'local-note-${DateTime.now().microsecondsSinceEpoch}',
            role: 'assistant',
            content: context.tr(
                'Photo diagnosis is not available for this crop yet. Describe what you see - leaf colour, spots, how much of the field is affected - and I will help from that.'),
            createdAt: DateTime.now(),
          ),
        );
      });
      return;
    }

    final photo = await pickPhoto(context);
    if (photo == null || !mounted) return;

    setState(() => _sending = true);
    final result = await DiseaseClassifierService.classify(
      photo,
      model,
      labelPrefix: subject.labelPrefix,
    );
    if (!mounted) return;

    if (result == null) {
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.tr('Diagnosis model is not available yet.'))),
      );
      return;
    }

    final userText = context.tr('Photo: {subject}',
        params: {'subject': context.tr(subject.labelKey)});
    final replyText = [
      result.prettyLabel,
      context.tr('{value}% confidence',
          params: {'value': result.confidencePercent}),
      '',
      context.tr(
          'This is an AI estimate from an on-device model, not a confirmed diagnosis.'),
    ].join('\n');

    final stamp = DateTime.now();
    final id = stamp.microsecondsSinceEpoch;
    setState(() {
      _sending = false;
      _messages.insert(
        0,
        ChatMessage(
            id: 'local-photo-$id',
            role: 'user',
            content: userText,
            createdAt: stamp),
      );
      _messages.insert(
        0,
        ChatMessage(
          id: 'local-photo-reply-$id',
          role: 'assistant',
          content: replyText,
          createdAt: stamp,
        ),
      );
    });

    await ChatService.savePhotoDiagnosis(
        widget.conversationId, userText, replyText);
  }

  Widget _bubble(ChatMessage m) {
    final isUser = m.isUser;
    final bg = isUser
        ? (m.failed ? Colors.red.shade300 : AppTheme.accent)
        : Colors.white;
    final fg = isUser ? Colors.white : Colors.black87;

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isUser
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(.06),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Text(m.content, style: TextStyle(color: fg, fontSize: 14.5)),
    );

    final retryHint = isUser && m.failed
        ? Padding(
            padding: const EdgeInsets.only(top: 3),
            child: GestureDetector(
              onTap: () => _retry(m),
              child: Text(
                context.tr('Failed to send. Tap to retry.'),
                style: TextStyle(fontSize: 11, color: Colors.red.shade700),
              ),
            ),
          )
        : const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [bubble],
          ),
          retryHint,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(widget.initialTitle ?? context.tr('AI Assistant')),
        actions: const [LanguageSelector()],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.smart_toy_outlined,
                                  size: 56, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                context.tr('No messages yet'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.tr(
                                    'Ask me anything about your crops, livestock, weather, or support programs.'),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) => _bubble(_messages[i]),
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.photo_camera_outlined),
                    color: AppTheme.primary,
                    tooltip: context.tr('Send a photo for diagnosis'),
                    onPressed: _sending ? null : _sendPhoto,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: context.tr(
                            'Ask about your crops, livestock, or weather...'),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _sending
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send),
                          color: AppTheme.primary,
                          tooltip: context.tr('Send'),
                          onPressed: _send,
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
