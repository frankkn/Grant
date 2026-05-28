import 'package:flutter/material.dart';
import '../models/wish_model.dart';
import '../services/wish_service.dart';

class WishScreen extends StatefulWidget {
  final String partnerId;
  const WishScreen({super.key, required this.partnerId});

  @override
  State<WishScreen> createState() => _WishScreenState();
}

class _WishScreenState extends State<WishScreen> {
  final _wishService = WishService();
  final _titleCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  DateTime _scheduledAt = DateTime.now().add(const Duration(days: 1));
  String? _message;

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty || _reasonCtrl.text.trim().isEmpty) {
      setState(() => _message = '請填寫標題與原因');
      return;
    }
    try {
      await _wishService.createWish(
        partnerId: widget.partnerId,
        title: _titleCtrl.text.trim(),
        reason: _reasonCtrl.text.trim(),
        scheduledAt: _scheduledAt,
      );
      _titleCtrl.clear();
      _reasonCtrl.clear();
      setState(() => _message = '許願已送出！');
    } catch (e) {
      setState(() => _message = '錯誤：$e');
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _scheduledAt = picked);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('許願'),
          bottom: const TabBar(tabs: [Tab(text: '送出許願'), Tab(text: '審核許願')]),
        ),
        body: TabBarView(children: [_buildSendTab(), _buildReviewTab()]),
      ),
    );
  }

  Widget _buildSendTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: '願望標題'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonCtrl,
            decoration: const InputDecoration(labelText: '為什麼想做這件事？'),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('預定時間：${_scheduledAt.toLocal().toString().split(' ')[0]}'),
              const SizedBox(width: 12),
              TextButton(onPressed: _pickDate, child: const Text('選擇日期')),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _submit, child: const Text('送出許願')),
          if (_message != null)
            Text(_message!,
                style: TextStyle(
                  color: _message!.startsWith('錯誤') ? Colors.red : Colors.green,
                )),
          const Divider(height: 32),
          const Text('我的許願清單', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: StreamBuilder<List<WishModel>>(
              stream: _wishService.watchMyWishes(),
              builder: (_, snap) {
                if (!snap.hasData) return const CircularProgressIndicator();
                return ListView.builder(
                  itemCount: snap.data!.length,
                  itemBuilder: (_, i) {
                    final w = snap.data![i];
                    return ListTile(
                      title: Text(w.title),
                      subtitle: Text(w.reason),
                      trailing: _statusChip(w.status),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewTab() {
    return StreamBuilder<List<WishModel>>(
      stream: _wishService.watchIncomingWishes(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        if (snap.data!.isEmpty) {
          return const Center(child: Text('目前沒有待審核的許願'));
        }
        return ListView.builder(
          itemCount: snap.data!.length,
          itemBuilder: (_, i) => _WishReviewCard(
            wish: snap.data![i],
            wishService: _wishService,
          ),
        );
      },
    );
  }

  Widget _statusChip(WishStatus status) {
    final (label, color) = switch (status) {
      WishStatus.pending => ('審核中', Colors.orange),
      WishStatus.approved => ('通過', Colors.green),
      WishStatus.rejected => ('駁回', Colors.red),
    };
    return Chip(label: Text(label), backgroundColor: color.withOpacity(0.2));
  }
}

class _WishReviewCard extends StatefulWidget {
  final WishModel wish;
  final WishService wishService;
  const _WishReviewCard({required this.wish, required this.wishService});

  @override
  State<_WishReviewCard> createState() => _WishReviewCardState();
}

class _WishReviewCardState extends State<_WishReviewCard> {
  final _noteCtrl = TextEditingController();

  Future<void> _review(WishStatus decision) async {
    try {
      await widget.wishService.reviewWish(
        wishId: widget.wish.id,
        decision: decision,
        reviewNote: _noteCtrl.text.trim(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('錯誤：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.wish.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('原因：${widget.wish.reason}'),
            Text('希望時間：${widget.wish.scheduledAt.toLocal().toString().split(' ')[0]}'),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: '審核理由（選填）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () => _review(WishStatus.approved),
                    child: const Text('通過'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => _review(WishStatus.rejected),
                    child: const Text('駁回'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
