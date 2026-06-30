import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../emotion_classifier.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../theme/theme.dart';
import '../widgets/common_widgets.dart';
import 'emergency_screen.dart';

class ChatScreen extends StatefulWidget {
  final ConversationModel conversation;
  const ChatScreen({super.key, required this.conversation});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final _ctl = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  final _llm = TinyLlamaService();

  List<MessageModel> _msgs = [];
  bool _generating = false;
  String _streaming = '';
  String _emotion = 'neutral';
  double _conf = 0.5;
  late AnimationController _dotAnim;

  @override
  void initState() {
    super.initState();
    _dotAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _ctl.dispose();
    _scroll.dispose();
    _focus.dispose();
    _dotAnim.dispose();
    super.dispose();
  }

  void _load() {
    setState(() => _msgs = HiveService.getMessages(widget.conversation.id));
    _end();
  }

  void _end() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _ctl.text.trim();
    if (text.isEmpty || _generating) return;
    _ctl.clear();

    final result = EmotionClassifier.classify(text);
    _emotion = result.emotion;
    _conf = result.confidence;

    final isCrisis = result.crisisAlert ||
        (!result.crisisAlert && CrisisDetector.isCrisis(text));

    if (isCrisis) {
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => const EmergencyScreen()));
      return;
    }

    final um = await HiveService.saveMessage(
        conversationId: widget.conversation.id,
        content: text,
        isUser: true,
        emotion: _emotion,
        emotionConfidence: _conf);
    await HiveService.updateConversation(
        widget.conversation.id, text, _emotion);

    if (_msgs.isEmpty) {
      widget.conversation.title =
          text.length > 40 ? '${text.substring(0, 40)}…' : text;
      await widget.conversation.save();
    }

    setState(() {
      _msgs.add(um);
      _generating = true;
      _streaming = '';
    });
    _end();

    final buf = StringBuffer();
    await for (final t in _llm.streamResponse(text, _emotion)) {
      buf.write(t);
      setState(() => _streaming = buf.toString());
      _end();
    }

    final aiText = buf.toString().trim();
    final am = await HiveService.saveMessage(
        conversationId: widget.conversation.id,
        content: aiText,
        isUser: false,
        emotion: _emotion,
        emotionConfidence: _conf);
    await HiveService.updateConversation(
        widget.conversation.id, aiText, _emotion);
    setState(() {
      _msgs.add(am);
      _generating = false;
      _streaming = '';
    });
    _end();
  }

  @override
  Widget build(BuildContext context) {
    final ec = EmotionDetector.getEmotionColor(_emotion);
    return Scaffold(
      backgroundColor: T.bg,
      appBar: AppBar(
        backgroundColor: T.surface,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: T.textMid, size: 18),
            onPressed: () => Navigator.pop(context)),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('EMO',
              style: GoogleFonts.playfairDisplay(
                  color: T.textHi, fontWeight: FontWeight.w700, fontSize: 18)),
          Row(children: [
            Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                    color: _llm.isReady ? T.sage : T.gold,
                    shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(_llm.isReady ? 'OFFLINE · PRIVATE' : 'LOADING MODEL…',
                style:
                    GoogleFonts.jetBrainsMono(
color: T.textLo, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1)),
          ]),
        ]),
        actions: [
          if (_emotion != 'neutral') EmotionBadge(_emotion),
          IconButton(
              icon: const Icon(Icons.volunteer_activism_rounded,
                  color: Colors.redAccent, size: 20),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const EmergencyScreen()))),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            height: 2,
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
              ec.withOpacity(0.0),
              ec.withOpacity(0.7),
              ec.withOpacity(0.0)
            ]))),
        Expanded(
            child: _msgs.isEmpty && !_generating
                ? _welcome()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _msgs.length + (_generating ? 1 : 0),
                    itemBuilder: (_, i) => i == _msgs.length && _generating
                        ? _StreamBubble(text: _streaming, dot: _dotAnim)
                        : _Bubble(msg: _msgs[i]))),
        _bar(),
      ]),
    );
  }

  Widget _welcome() => LayoutBuilder(builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_moon_rounded,
                          size: 60, color: T.sage.withOpacity(0.5)),
                      const SizedBox(height: 24),
                      Text("I'm here with you",
                          style: GoogleFonts.playfairDisplay(
                              color: T.textHi,
                              fontSize: 28,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Text('Everything you share stays\nentirely on your device.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.jetBrainsMono(
                              color: T.textMid, fontSize: 16, height: 1.6)),
                      const SizedBox(height: 48),
                      Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            "I'm feeling anxious",
                            "I had a great day!",
                            "I need to vent",
                            "I feel so alone"
                          ]
                              .map((s) => _Chip(
                                  text: s,
                                  onTap: () {
                                    _ctl.text = s;
                                    _send();
                                  }))
                              .toList()),
                    ]),
              ),
            ),
          ),
        );
      });

  Widget _bar() => Container(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, MediaQuery.of(context).padding.bottom + 16),
        decoration: const BoxDecoration(
            color: T.bg, border: Border(top: BorderSide(color: T.border))),
        child: Row(children: [
          Expanded(
              child: TextField(
                  controller: _ctl,
                  focusNode: _focus,
                  style:
                      GoogleFonts.jetBrainsMono(
color: T.textHi, fontSize: 15),
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                      hintText: 'Share what\'s on your mind…',
                      hintStyle: GoogleFonts.jetBrainsMono(
                          color: T.textLo, fontSize: 15),
                      filled: true,
                      fillColor: T.surface,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: T.border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: T.border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: T.sage)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14)),
                  onSubmitted: (_) => _send())),
          const SizedBox(width: 12),
          GestureDetector(
              onTap: _generating ? null : _send,
              child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      color: _generating ? T.surface : T.sage,
                      borderRadius: BorderRadius.circular(16)),
                  child: _generating
                      ? const Center(
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: T.textLo)))
                      : const Icon(Icons.send_rounded,
                          color: Colors.black, size: 22))),
        ]),
      );
}

class _StreamBubble extends StatelessWidget {
  final String text;
  final AnimationController dot;
  const _StreamBubble({required this.text, required this.dot});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const AiAvatar(),
        const SizedBox(width: 12),
        Flexible(
            child: Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
              color: T.aiBubble,
              border: Border.all(color: T.border),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4))),
          child: text.isEmpty
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                      3,
                      (i) => AnimatedBuilder(
                          animation: dot,
                          builder: (_, __) => Container(
                              margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: T.sage.withOpacity(
                                      (dot.value + i * 0.25)
                                          .clamp(0.2, 1.0)))))))
              : Text(text,
                  style: GoogleFonts.jetBrainsMono(
                      color: T.textHi, fontSize: 16, height: 1.5)),
        )),
      ]));
}

class _Bubble extends StatelessWidget {
  final MessageModel msg;
  const _Bubble({required this.msg});
  @override
  Widget build(BuildContext context) {
    final isUser = msg.isUser;
    final ec = EmotionDetector.getEmotionColor(msg.emotion);
    final time = DateFormat('HH:mm').format(msg.timestamp);
    return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[const AiAvatar(), const SizedBox(width: 12)],
              Flexible(
                  child: Column(
                      crossAxisAlignment: isUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                    Container(
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                            color: isUser ? T.userBubble : T.aiBubble,
                            border: Border.all(color: isUser ? Colors.transparent : T.border),
                            borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(20),
                                topRight: const Radius.circular(20),
                                bottomLeft: Radius.circular(isUser ? 20 : 4),
                                bottomRight: Radius.circular(isUser ? 4 : 20))),
                        child: Text(msg.content,
                            style: GoogleFonts.jetBrainsMono(
                                color: T.textHi, fontSize: 16, height: 1.5))),
                    const SizedBox(height: 6),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      if (isUser && msg.emotion != 'neutral') ...[
                        Text(msg.emotion,
                            style: GoogleFonts.jetBrainsMono(
                                color: ec.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                      ],
                      Text(time,
                          style: GoogleFonts.jetBrainsMono(
                              color: T.textLo, fontSize: 11)),
                    ]),
                  ])),
            ]));
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _Chip({required this.text, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.transparent,
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                  color: T.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: T.border)),
              child: Text(text,
                  style: GoogleFonts.jetBrainsMono(
                      color: T.textMid, fontSize: 14, fontWeight: FontWeight.w500)))));
}
