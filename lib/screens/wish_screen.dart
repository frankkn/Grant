import 'package:flutter/material.dart';
import '../models/wish_model.dart';
import '../services/wish_service.dart';
import 'edit_wish_screen.dart';
import 'wish_detail_screen.dart';

class WishScreen extends StatefulWidget {
  final String partnerId;
  const WishScreen({super.key, required this.partnerId});

  @override
  State<WishScreen> createState() => _WishScreenState();
}

class _WishScreenState extends State<WishScreen> {
  final _wishService = WishService();
  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _productUrlCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  int _heartRating = 0;
  DateTime _scheduledAt = DateTime.now().add(const Duration(days: 1));
  String? _message;

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final price = _priceCtrl.text.trim();
    final productUrl = _productUrlCtrl.text.trim();
    final description = _descriptionCtrl.text.trim();
    final reason = _reasonCtrl.text.trim();

    if (title.isEmpty) { setState(() => _message = '請填寫「許下我的願望」'); return; }
    if (price.isEmpty) { setState(() => _message = '請填寫「費用參考」'); return; }
    if (_heartRating == 0) { setState(() => _message = '請選擇「心動指數」'); return; }
    if (description.isEmpty) { setState(() => _message = '請填寫「商品描述」'); return; }
    if (reason.isEmpty) { setState(() => _message = '請填寫「我的理由」'); return; }

    if (productUrl.isNotEmpty) {
      final uri = Uri.tryParse(productUrl);
      if (uri == null || !uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        setState(() => _message = '商品網址格式不正確，請輸入完整網址（例如 https://...）');
        return;
      }
    }

    try {
      await _wishService.createWish(
        partnerId: widget.partnerId,
        title: title,
        price: price,
        heartRating: _heartRating,
        productUrl: productUrl.isEmpty ? null : productUrl,
        description: description,
        reason: reason,
        scheduledAt: _scheduledAt,
      );
      _titleCtrl.clear();
      _priceCtrl.clear();
      _productUrlCtrl.clear();
      _descriptionCtrl.clear();
      _reasonCtrl.clear();
      setState(() { _heartRating = 0; _message = '許願已送出！'; });
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
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('許願'),
          bottom: const TabBar(tabs: [
            Tab(text: '送出許願'),
            Tab(text: '我的許願'),
            Tab(text: '審核許願'),
          ]),
        ),
        body: TabBarView(children: [_buildSendTab(), _buildMyWishesTab(), _buildReviewTab()]),
      ),
    );
  }

  Widget _buildSendTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
          const Text('許下我的願望 *', style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(hintText: '我想要...'),
          ),
          const SizedBox(height: 24),
          const Text('費用參考 *', style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(
            controller: _priceCtrl,
            decoration: const InputDecoration(hintText: '例如：NT\$500 或 無價'),
          ),
          const SizedBox(height: 24),
          const Text('心動指數 ♡ *', style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) {
              final filled = i < _heartRating;
              return GestureDetector(
                onTap: () => setState(() => _heartRating = i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    filled ? Icons.favorite : Icons.favorite_border,
                    color: Colors.pink,
                    size: 36,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          const Text('商品網址', style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(
            controller: _productUrlCtrl,
            decoration: const InputDecoration(hintText: 'https://...'),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 24),
          const Text('商品描述 *', style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionCtrl,
            decoration: InputDecoration(
              hintText: '描述一下這個商品...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.pinkAccent),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.pink, width: 2),
              ),
            ),
            minLines: 3,
            maxLines: 6,
          ),
          const SizedBox(height: 24),
          const Text('我的理由 *', style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(
            controller: _reasonCtrl,
            decoration: InputDecoration(
              hintText: '說服另一半的理由...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.pinkAccent),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.pink, width: 2),
              ),
            ),
            minLines: 4,
            maxLines: 8,
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
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_message!,
                  style: TextStyle(
                    color: _message!.startsWith('錯誤') || _message!.startsWith('請') ? Colors.red : Colors.green,
                  )),
            ),
        ],
    );
  }

  Widget _buildMyWishesTab() {
    return StreamBuilder<List<WishModel>>(
      stream: _wishService.watchMyWishes(),
      builder: (_, snap) {
        if (snap.hasError) return Center(child: Text('錯誤：${snap.error}', style: const TextStyle(color: Colors.red)));
        if (!snap.hasData) return const Center(child: Text('載入中...'));
        if (snap.data!.isEmpty) return const Center(child: Text('還沒有送出許願'));
        return ListView.builder(
          itemCount: snap.data!.length,
          itemBuilder: (_, i) {
            final w = snap.data![i];
            return ListTile(
              title: Text(w.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('費用：${w.price}'),
                  Row(children: List.generate(5, (i) => Icon(
                    i < w.heartRating ? Icons.favorite : Icons.favorite_border,
                    color: Colors.pink, size: 14,
                  ))),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _statusChip(w.status),
                  const SizedBox(width: 4),
                  if (w.status == WishStatus.pending)
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => EditWishScreen(wish: w)),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: () => _confirmDelete(context, w),
                  ),
                ],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => WishDetailScreen(wish: w)),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, WishModel wish) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除許願'),
        content: Text('確定要刪除「${wish.title}」嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _wishService.deleteWish(wish.id);
    }
  }

  Widget _buildReviewTab() {
    return CustomScrollView(
      slivers: [
        // 待審核
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('待審核', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.grey.shade600)),
          ),
        ),
        StreamBuilder<List<WishModel>>(
          stream: _wishService.watchIncomingWishes(),
          builder: (_, snap) {
            if (snap.hasError) return SliverToBoxAdapter(child: Center(child: Text('錯誤：${snap.error}', style: const TextStyle(color: Colors.red))));
            if (!snap.hasData) return const SliverToBoxAdapter(child: Center(child: Text('載入中...')));
            if (snap.data!.isEmpty) return const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(16), child: Text('目前沒有待審核的許願', style: TextStyle(color: Colors.grey))));
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _WishReviewCard(wish: snap.data![i], wishService: _wishService),
                childCount: snap.data!.length,
              ),
            );
          },
        ),

        // 已審核
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text('已審核', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.grey.shade600)),
          ),
        ),
        StreamBuilder<List<WishModel>>(
          stream: _wishService.watchReviewedWishes(),
          builder: (_, snap) {
            if (!snap.hasData) return const SliverToBoxAdapter(child: Center(child: Text('載入中...')));
            if (snap.data!.isEmpty) return const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(16), child: Text('還沒有審核過任何許願', style: TextStyle(color: Colors.grey))));
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final w = snap.data![i];
                  return ListTile(
                    title: Text(w.title),
                    subtitle: w.reviewNote != null && w.reviewNote!.isNotEmpty
                        ? Text('回覆：${w.reviewNote}')
                        : null,
                    trailing: _statusChip(w.status),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WishDetailScreen(wish: w))),
                  );
                },
                childCount: snap.data!.length,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _statusChip(WishStatus status) {
    final (label, color) = switch (status) {
      WishStatus.pending => ('審核中', Colors.orange),
      WishStatus.approved => ('通過', Colors.green),
      WishStatus.rejected => ('駁回', Colors.red),
    };
    return Chip(label: Text(label), backgroundColor: color.withValues(alpha: 0.2));
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
            if (widget.wish.price != null) Text('價格：${widget.wish.price}'),
            Row(children: [
              const Text('渴望程度：'),
              ...List.generate(5, (i) => Icon(
                i < widget.wish.heartRating ? Icons.favorite : Icons.favorite_border,
                color: Colors.pink, size: 16,
              )),
            ]),
            const SizedBox(height: 4),
            Text('理由：${widget.wish.reason}'),
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
