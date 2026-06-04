import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/wish_model.dart';
import '../services/auth_service.dart';
import '../services/wish_service.dart';
import '../utils/formatters.dart';

class MemoryWallScreen extends StatelessWidget {
  final String partnerId;
  const MemoryWallScreen({super.key, required this.partnerId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('回憶牆'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.auto_stories), text: '時間軸'),
              Tab(icon: Icon(Icons.insights), text: '統計'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _TimelineTab(partnerId: partnerId),
            _StatsTab(partnerId: partnerId),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── 時間軸 ───────────────────────────

class _TimelineTab extends StatelessWidget {
  final String partnerId;
  const _TimelineTab({required this.partnerId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WishModel>>(
      stream: WishService().watchFulfilledWishes(partnerId),
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
                Text('還沒有實現的願望',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
                SizedBox(height: 8),
                Text('實現願望後，回憶會出現在這裡 ❤️',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        final wishes = snap.data!;
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                '已實現 ${wishes.length} 個願望',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
            ...List.generate(
              wishes.length,
              (i) => _MemoryCard(
                wish: wishes[i],
                isLast: i == wishes.length - 1,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MemoryCard extends StatelessWidget {
  final WishModel wish;
  final bool isLast;
  const _MemoryCard({required this.wish, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final dateStr = formatYmd(wish.updatedAt);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 時間軸：圓點 + 連接線
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
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: Colors.pink.shade100),
                  ),
              ],
            ),
            const SizedBox(width: 12),
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
                      Row(
                        children: [
                          Text(dateStr,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                          const Spacer(),
                          if (wish.category != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.pink.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: Colors.pink.shade100),
                              ),
                              child: Text(
                                wish.category!,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.pink),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        wish.title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder(
                        future: auth.fetchUser(wish.requesterId),
                        builder: (context, snap) {
                          final name = snap.data?.displayName ?? '對方';
                          return Text(
                            '$name 許下的願望',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey),
                          );
                        },
                      ),
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
                      if (wish.reviewNote != null &&
                          wish.reviewNote!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _NoteBox(
                          text: '💬 ${wish.reviewNote}',
                          bg: Colors.green.shade50,
                          border: Colors.green.shade100,
                          fg: Colors.green.shade700,
                        ),
                      ],
                      if (wish.fulfillmentNote != null &&
                          wish.fulfillmentNote!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _NoteBox(
                          text: '✨ ${wish.fulfillmentNote}',
                          bg: Colors.pink.shade50,
                          border: Colors.pink.shade100,
                          fg: Colors.pink.shade700,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteBox extends StatelessWidget {
  final String text;
  final Color bg, border, fg;
  const _NoteBox(
      {required this.text,
      required this.bg,
      required this.border,
      required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(text, style: TextStyle(fontSize: 13, color: fg)),
    );
  }
}

// ─────────────────────────── 統計 ───────────────────────────

class _StatsTab extends StatelessWidget {
  final String partnerId;
  const _StatsTab({required this.partnerId});

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService().currentUser?.uid;
    return StreamBuilder<List<WishModel>>(
      stream: WishService().watchAllWishes(partnerId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snap.data!;
        if (all.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.insights, size: 64, color: Colors.pink),
                SizedBox(height: 16),
                Text('還沒有資料可以統計',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
                SizedBox(height: 8),
                Text('開始許願後，這裡會出現你們的小數據 📊',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        return _StatsBody(all: all, myUid: myUid, partnerId: partnerId);
      },
    );
  }
}

class _StatsBody extends StatelessWidget {
  final List<WishModel> all;
  final String? myUid;
  final String partnerId;
  const _StatsBody(
      {required this.all, required this.myUid, required this.partnerId});

  String? _topCategory(List<WishModel> list) {
    if (list.isEmpty) return null;
    final counts = <String, int>{};
    for (final w in list) {
      final c = w.category ?? '其他';
      counts[c] = (counts[c] ?? 0) + 1;
    }
    return (counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
  }

  @override
  Widget build(BuildContext context) {
    final total = all.length;
    final fulfilled = all.where((w) => w.isFulfilled).length;
    final rate = total > 0 ? (fulfilled / total * 100).round() : 0;
    final avgHeart = total > 0
        ? all.map((w) => w.heartRating).reduce((a, b) => a + b) / total
        : 0.0;

    final mine = all.where((w) => w.requesterId == myUid).toList();
    final theirs = all.where((w) => w.requesterId == partnerId).toList();

    // 類別排行（全部）
    final catCounts = <String, int>{};
    for (final w in all) {
      final c = w.category ?? '其他';
      catCounts[c] = (catCounts[c] ?? 0) + 1;
    }
    final sortedCats = catCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCat = sortedCats.isEmpty ? 1 : sortedCats.first.value;

    // 狀態分佈
    final statusCounts = <WishStatus, int>{};
    for (final w in all) {
      statusCounts[w.status] = (statusCounts[w.status] ?? 0) + 1;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 摘要三格
        Row(
          children: [
            Expanded(
                child: _StatTile(
                    value: '$total', label: '總願望', color: Colors.pink)),
            const SizedBox(width: 10),
            Expanded(
                child: _StatTile(
                    value: '$fulfilled',
                    label: '已實現',
                    color: Colors.deepPurple)),
            const SizedBox(width: 10),
            Expanded(
                child: _StatTile(
                    value: '$rate%', label: '實現率', color: Colors.teal)),
          ],
        ),
        const SizedBox(height: 16),

        // 你 vs 對方
        _SectionCard(
          title: '你 vs 對方',
          child: Row(
            children: [
              Expanded(
                child: _PersonStat(
                  name: '你',
                  count: mine.length,
                  topCategory: _topCategory(mine),
                ),
              ),
              Container(width: 1, height: 56, color: Colors.grey.shade300),
              Expanded(
                child: FutureBuilder<UserModel?>(
                  future: AuthService().fetchUser(partnerId),
                  builder: (context, s) => _PersonStat(
                    name: s.data?.displayName ?? '對方',
                    count: theirs.length,
                    topCategory: _topCategory(theirs),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 最常許願的類別
        _SectionCard(
          title: '最常許願的類別',
          child: Column(
            children: sortedCats
                .map((e) => _CategoryBar(
                      label: e.key,
                      count: e.value,
                      ratio: e.value / maxCat,
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 12),

        // 平均心動指數
        _SectionCard(
          title: '平均心動指數',
          child: Row(
            children: [
              ...List.generate(
                5,
                (i) => Icon(
                  i < avgHeart.round()
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: Colors.pink,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Text(avgHeart.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 願望狀態
        _SectionCard(
          title: '願望狀態',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip('待審核', statusCounts[WishStatus.pending] ?? 0,
                  Colors.orange),
              _statusChip('已通過', statusCounts[WishStatus.approved] ?? 0,
                  Colors.green),
              _statusChip('協商中', statusCounts[WishStatus.negotiating] ?? 0,
                  Colors.blue),
              _statusChip('已駁回', statusCounts[WishStatus.rejected] ?? 0,
                  Colors.red),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String label, int count, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade100),
      ),
      child: Text('$label $count',
          style: TextStyle(color: color.shade700, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatTile(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _PersonStat extends StatelessWidget {
  final String name;
  final int count;
  final String? topCategory;
  const _PersonStat(
      {required this.name, required this.count, this.topCategory});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 4),
        Text('$count',
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.pink)),
        const Text('個願望', style: TextStyle(fontSize: 12, color: Colors.grey)),
        if (topCategory != null) ...[
          const SizedBox(height: 4),
          Text('最愛：$topCategory',
              style: const TextStyle(fontSize: 12, color: Colors.pink)),
        ],
      ],
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final String label;
  final int count;
  final double ratio;
  const _CategoryBar(
      {required this.label, required this.count, required this.ratio});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.05, 1.0),
                minHeight: 14,
                backgroundColor: Colors.pink.shade50,
                valueColor: AlwaysStoppedAnimation(Colors.pink.shade300),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: Text('$count',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
