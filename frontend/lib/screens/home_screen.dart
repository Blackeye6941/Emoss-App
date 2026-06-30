import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/services.dart';
import '../theme/theme.dart';
import '../widgets/common_widgets.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  List<ConversationModel> _conversations = [];
  late AnimationController _fabAnim;

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _reload();
  }

  @override
  void dispose() {
    _fabAnim.dispose();
    super.dispose();
  }

  void _reload() =>
      setState(() => _conversations = HiveService.getAllConversations());

  Future<void> _newChat() async {
    final c = await HiveService.createConversation('New session');
    if (!mounted) return;
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ChatScreen(conversation: c)));
    _reload();
  }

  Future<void> _openChat(ConversationModel c) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ChatScreen(conversation: c)));
    _reload();
  }

  Future<void> _delete(ConversationModel c) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: T.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              title: Text('Delete Session',
                  style: GoogleFonts.playfairDisplay(
                      color: T.textHi,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
              content: Text('This session will be permanently removed.',
                  style: GoogleFonts.jetBrainsMono(color: T.textMid, fontSize: 15)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('Cancel',
                        style: GoogleFonts.jetBrainsMono(color: T.textMid))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text('Delete',
                        style: GoogleFonts.jetBrainsMono(color: Colors.redAccent))),
              ],
            ));
    if (ok == true) {
      await HiveService.deleteConversation(c.id);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: T.bg,
        appBar: AppBar(
          backgroundColor: T.bg,
          centerTitle: false,
          title: Row(children: [
            Image.asset(
              'assets/logo/emo.png',
              width: 32,
              height: 32,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: T.sage.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.shield_moon_rounded, color: T.sage, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text('EMO',
                style: GoogleFonts.playfairDisplay(
                    color: T.textHi,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2)),
          ]),
          actions: [
            const OfflinePill(),
            const SizedBox(width: 8),
            ListenableBuilder(
                listenable: TinyLlamaService(),
                builder: (_, __) => StatusDot(
                      color: switch (TinyLlamaService().state) {
                        ModelState.ready => T.sage,
                        ModelState.loading => T.gold,
                        _ => Colors.redAccent
                      },
                      tooltip: switch (TinyLlamaService().state) {
                        ModelState.ready => 'AI ready',
                        ModelState.loading => 'Loading AI…',
                        _ => 'AI error'
                      },
                    )),
            const SizedBox(width: 8),
            IconButton(
                icon: const Icon(Icons.health_and_safety_rounded,
                    color: Colors.redAccent, size: 24),
                tooltip: 'Support Resources',
                onPressed: () => Navigator.pushNamed(context, '/emergency')),
            const SizedBox(width: 8),
          ],
        ),
        body: _conversations.isEmpty ? _empty() : _list(),
        floatingActionButton: ScaleTransition(
          scale: CurvedAnimation(parent: _fabAnim, curve: Curves.elasticOut),
          child: FloatingActionButton.extended(
            onPressed: _newChat,
            backgroundColor: T.sage,
            elevation: 4,
            icon: const Icon(Icons.add_rounded,
                color: Colors.black, size: 24),
            label: Text('New Session',
                style: GoogleFonts.jetBrainsMono(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ),
        ),
      );

  Widget _empty() => SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(40),
          alignment: Alignment.center,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.auto_awesome_mosaic_rounded,
                size: 80, color: T.sage.withOpacity(0.5)),
            const SizedBox(height: 32),
            Text('Begin Your Journey',
                style: GoogleFonts.playfairDisplay(
                    color: T.textHi, fontSize: 28, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text('Step into a private sanctuary\nfor your mind and soul.',
                textAlign: TextAlign.center,
                style: GoogleFonts.jetBrainsMono(
                    color: T.textMid, fontSize: 16, height: 1.5)),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _newChat,
              style: ElevatedButton.styleFrom(
                  backgroundColor: T.sage,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text('Start Session',
                  style: GoogleFonts.jetBrainsMono(
                      fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ]),
        ),
      );

  Widget _list() => ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        itemCount: _conversations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _ConvTile(
            conv: _conversations[i],
            onTap: () => _openChat(_conversations[i]),
            onDelete: () => _delete(_conversations[i])),
      );
}

class _ConvTile extends StatelessWidget {
  final ConversationModel conv;
  final VoidCallback onTap, onDelete;
  const _ConvTile(
      {required this.conv, required this.onTap, required this.onDelete});

  String _fmt(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (d.inDays < 1) return DateFormat('HH:mm').format(dt);
    if (d.inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final ec = EmotionDetector.getEmotionColor(conv.dominantEmotion);
    return Dismissible(
      key: Key(conv.id),
      direction: DismissDirection.endToStart,
      background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.delete_sweep_rounded,
              color: Colors.redAccent, size: 28)),
      onDismissed: (_) => onDelete(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: T.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: T.border, width: 1.5)),
            child: Row(children: [
              Container(
                  width: 12,
                  height: 48,
                  decoration: BoxDecoration(
                      color: ec,
                      borderRadius: BorderRadius.circular(6))),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Expanded(
                          child: Text(conv.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.playfairDisplay(
                                  color: T.textHi,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18))),
                      const SizedBox(width: 8),
                      Text(_fmt(conv.updatedAt),
                          style: GoogleFonts.jetBrainsMono(
                              color: T.textLo, fontSize: 12, fontWeight: FontWeight.w500)),
                    ]),
                    const SizedBox(height: 6),
                    Text(conv.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(
                            color: T.textMid, fontSize: 14, height: 1.2)),
                  ])),
              const SizedBox(width: 12),
              Icon(Icons.arrow_forward_ios_rounded, color: T.textLo, size: 16),
            ]),
          ),
        ),
      ),
    );
  }
}
