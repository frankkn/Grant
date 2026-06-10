import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/pair_service.dart';
import '../utils/formatters.dart';
import '../widgets/mood_emoji.dart';

const _moods = ['❤️', '😊', '🥰', '😢', '😡', '🤔', '😴', '🎉'];

class WhisperScreen extends StatefulWidget {
  final String partnerId;
  const WhisperScreen({super.key, required this.partnerId});

  @override
  State<WhisperScreen> createState() => _WhisperScreenState();
}

class _WhisperScreenState extends State<WhisperScreen> {
  final _ctrl = TextEditingController();
  final _service = PairService();
  String _mood = '';
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty && _mood.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _service.createPost(
        partnerId: widget.partnerId,
        text: text,
        mood: _mood,
      );
      _ctrl.clear();
      if (!mounted) return;
      setState(() => _mood = '');
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('傳送失敗：$e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService().currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('悄悄話')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<PostModel>>(
              stream: _service.watchPosts(widget.partnerId),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final posts = snap.data!;
                if (posts.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 64, color: Colors.teal),
                        SizedBox(height: 16),
                        Text('還沒有悄悄話',
                            style:
                                TextStyle(fontSize: 16, color: Colors.grey)),
                        SizedBox(height: 8),
                        Text('傳一則給對方，告訴他今天的心情 💌',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: posts.length,
                  itemBuilder: (context, i) => _PostBubble(
                    post: posts[i],
                    isMine: posts[i].authorId == myUid,
                  ),
                );
              },
            ),
          ),
          _Composer(
            controller: _ctrl,
            mood: _mood,
            sending: _sending,
            onMoodSelected: (m) => setState(() => _mood = _mood == m ? '' : m),
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final String mood;
  final bool sending;
  final ValueChanged<String> onMoodSelected;
  final VoidCallback onSend;
  const _Composer({
    required this.controller,
    required this.mood,
    required this.sending,
    required this.onMoodSelected,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, -2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _moods.map((m) {
                  final selected = m == mood;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: moodEmoji(m, 20),
                      selected: selected,
                      selectedColor: Colors.teal.shade100,
                      onSelected: (_) => onMoodSelected(m),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: '說點悄悄話…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: sending ? null : onSend,
                  icon: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PostBubble extends StatelessWidget {
  final PostModel post;
  final bool isMine;
  const _PostBubble({required this.post, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final scheme = Theme.of(context).colorScheme;
    final bubbleColor = isMine
        ? (scheme.brightness == Brightness.dark
            ? Colors.teal.shade700
            : Colors.teal.shade100)
        : scheme.surfaceContainerHighest;
    final time = formatMdHm(post.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (!isMine)
            _AuthorName(uid: post.authorId),
          Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text.rich(
              TextSpan(children: [
                if (post.mood.isNotEmpty)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding:
                          EdgeInsets.only(right: post.text.isEmpty ? 0 : 6),
                      child: moodEmoji(post.mood, 18),
                    ),
                  ),
                if (post.text.isNotEmpty) TextSpan(text: post.text),
              ]),
              style: const TextStyle(fontSize: 15),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(time,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}

class _AuthorName extends StatelessWidget {
  final String uid;
  const _AuthorName({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: AuthService().fetchUser(uid),
      builder: (context, snap) {
        final name = snap.data?.displayName ?? '對方';
        return Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 2),
          child: Text(name,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        );
      },
    );
  }
}
