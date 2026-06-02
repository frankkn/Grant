import 'package:flutter/material.dart';
import '../models/wish_model.dart';
import '../services/auth_service.dart';
import '../services/wish_service.dart';

class MemoryWallScreen extends StatelessWidget {
  const MemoryWallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('回憶牆')),
      body: StreamBuilder<List<WishModel>>(
        stream: WishService().watchFulfilledWishes(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.pink),
                  SizedBox(height: 16),
                  Text(
                    '還沒有實現的願望',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '實現願望後，回憶會出現在這裡 ❤️',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: snap.data!.length,
            itemBuilder: (context, i) => _MemoryCard(wish: snap.data![i]),
          );
        },
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  final WishModel wish;
  const _MemoryCard({required this.wish});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final dateStr = wish.updatedAt.toLocal().toString().split(' ')[0];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 時間軸
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.pink,
                  shape: BoxShape.circle,
                ),
              ),
              Container(width: 2, height: 140, color: Colors.pink.shade100),
            ],
          ),
          const SizedBox(width: 12),
          // 卡片內容
          Expanded(
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 日期
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 願望標題
                    Text(
                      wish.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 誰許的願
                    FutureBuilder(
                      future: auth.fetchUser(wish.requesterId),
                      builder: (context, snap) {
                        final name = snap.data?.displayName ?? '對方';
                        return Text(
                          '$name 許下的願望',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                    // 心動指數
                    const SizedBox(height: 6),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < wish.heartRating
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: Colors.pink,
                          size: 14,
                        ),
                      ),
                    ),
                    // 審核回覆
                    if (wish.reviewNote != null && wish.reviewNote!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade100),
                        ),
                        child: Text(
                          '💬 ${wish.reviewNote}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                    // 感謝話
                    if (wish.fulfillmentNote != null &&
                        wish.fulfillmentNote!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.pink.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.pink.shade100),
                        ),
                        child: Text(
                          '✨ ${wish.fulfillmentNote}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.pink.shade700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
