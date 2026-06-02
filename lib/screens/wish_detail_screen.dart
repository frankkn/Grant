import 'package:flutter/material.dart';
import '../models/wish_model.dart';

class WishDetailScreen extends StatelessWidget {
  final WishModel wish;
  const WishDetailScreen({super.key, required this.wish});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('許願詳情')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _statusBanner(wish.status, wish.reviewNote),
          const SizedBox(height: 24),
          _section('許下我的願望', wish.title),
          _section('費用參考', wish.price),
          _heartRow(wish.heartRating),
          if (wish.productUrl != null && wish.productUrl!.isNotEmpty)
            _section('商品網址', wish.productUrl!),
          if (wish.description != null && wish.description!.isNotEmpty)
            _section('商品描述', wish.description!),
          _section('我的理由', wish.reason),
          _section('希望日期', wish.scheduledAt.toLocal().toString().split(' ')[0]),
        ],
      ),
    );
  }

  Widget _statusBanner(WishStatus status, String? reviewNote) {
    final (label, color) = switch (status) {
      WishStatus.pending      => ('審核中',   Colors.orange),
      WishStatus.approved     => ('已通過 ✓', Colors.green),
      WishStatus.rejected     => ('已駁回',   Colors.red),
      WishStatus.negotiating  => ('協商中 🤝', Colors.deepOrange),
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          if (reviewNote != null && reviewNote.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('另一半的回覆：$reviewNote', style: TextStyle(color: color)),
          ],
          if (status == WishStatus.negotiating && wish.negotiationNote != null && wish.negotiationNote!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('修改提案：${wish.negotiationNote}', style: TextStyle(color: color)),
          ],
        ],
      ),
    );
  }

  Widget _section(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _heartRow(int rating) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('心動指數', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 6),
          Row(
            children: List.generate(5, (i) => Icon(
              i < rating ? Icons.favorite : Icons.favorite_border,
              color: Colors.pink,
              size: 24,
            )),
          ),
        ],
      ),
    );
  }
}
