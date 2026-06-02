import 'package:flutter/material.dart';
import '../models/wish_model.dart';
import '../services/auth_service.dart';
import '../services/wish_service.dart';
import 'edit_wish_screen.dart';
import 'wish_detail_screen.dart';

class WishScreen extends StatefulWidget {
  final String partnerId;
  final int initialIndex;
  const WishScreen({super.key, required this.partnerId, this.initialIndex = 0});

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
  String? _category;
  bool _isSecret = false;
  DateTime _scheduledAt = DateTime.now().add(const Duration(days: 1));
  String? _message;
  // 篩選狀態
  String? _myWishesFilter;
  WishStatus? _myWishesStatusFilter;
  bool _myWishesFilterOpen = false;
  String? _reviewFilter;
  WishStatus? _reviewStatusFilter;
  bool _reviewFilterOpen = false;

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final price = _priceCtrl.text.trim();
    final productUrl = _productUrlCtrl.text.trim();
    final description = _descriptionCtrl.text.trim();
    final reason = _reasonCtrl.text.trim();

    if (title.isEmpty) {
      setState(() => _message = '請填寫「許下我的願望」');
      return;
    }
    if (price.isEmpty) {
      setState(() => _message = '請填寫「費用參考」');
      return;
    }
    if (_heartRating == 0) {
      setState(() => _message = '請選擇「心動指數」');
      return;
    }
    if (_category == null) {
      setState(() => _message = '請選擇「願望類別」');
      return;
    }
    if (description.isEmpty) {
      setState(() => _message = '請填寫「商品描述」');
      return;
    }
    if (reason.isEmpty) {
      setState(() => _message = '請填寫「我的理由」');
      return;
    }

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
        category: _category!,
        isSecret: _isSecret,
      );
      _titleCtrl.clear();
      _priceCtrl.clear();
      _productUrlCtrl.clear();
      _descriptionCtrl.clear();
      _reasonCtrl.clear();
      setState(() {
        _heartRating = 0;
        _category = null;
        _isSecret = false;
        _message = null;
      });
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite, color: Colors.pinkAccent, size: 56),
                SizedBox(height: 16),
                Text(
                  '許願送出成功！',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('等待另一半審核吧 💝', style: TextStyle(color: Colors.grey)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('好的'),
              ),
            ],
          ),
        );
      }
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
      initialIndex: widget.initialIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('許願'),
          bottom: TabBar(
            tabs: [
              const Tab(text: '送出許願'),
              const Tab(text: '我的許願'),
              Tab(
                child: StreamBuilder<List<WishModel>>(
                  stream: _wishService.watchIncomingWishes(widget.partnerId),
                  builder: (context, snap) {
                    final count = _actionableCount(snap.data);
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('審核許願'),
                        if (count > 0) ...[
                          const SizedBox(width: 6),
                          _countChip(count),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildSendTab(), _buildMyWishesTab(), _buildReviewTab()],
        ),
      ),
    );
  }

  Widget _buildSendTab() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            children: [
              const Text(
                '許下我的願望 *',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(hintText: '我想要...'),
              ),
              const SizedBox(height: 24),
              const Text(
                '費用參考 *',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _priceCtrl,
                decoration: const InputDecoration(hintText: '例如：NT\$500 或 無價'),
              ),
              const SizedBox(height: 24),
              const Text(
                '心動指數 ♡ *',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
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
              const Text(
                '願望類別 *',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: wishCategories.map((cat) {
                  final selected = _category == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: selected,
                    onSelected: (_) => setState(() => _category = cat),
                    selectedColor: Colors.pink.shade100,
                    checkmarkColor: Colors.pink,
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              const Text(
                '許願方式 *',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              WishTypeSelector(
                isSecret: _isSecret,
                onChanged: (val) => setState(() => _isSecret = val),
              ),
              const SizedBox(height: 24),
              const Text(
                '商品網址',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _productUrlCtrl,
                decoration: const InputDecoration(hintText: 'https://...'),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 24),
              const Text(
                '商品描述 *',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionCtrl,
                decoration: InputDecoration(
                  hintText: '描述一下這個商品...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
              const Text(
                '我的理由 *',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonCtrl,
                decoration: InputDecoration(
                  hintText: '說服另一半的理由...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                  Text(
                    '預定時間：${_scheduledAt.toLocal().toString().split(' ')[0]}',
                  ),
                  const SizedBox(width: 12),
                  TextButton(onPressed: _pickDate, child: const Text('選擇日期')),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        // 按鈕固定在底部，不隨鍵盤消失
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _message!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('送出許願'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyWishesTab() {
    return StreamBuilder<List<WishModel>>(
      stream: _wishService.watchMyWishes(widget.partnerId),
      builder: (_, snap) {
        if (snap.hasError) {
          return Center(child: Text('錯誤：${snap.error}', style: const TextStyle(color: Colors.red)));
        }
        if (!snap.hasData) return const Center(child: Text('載入中...'));

        var filtered = snap.data!;
        if (_myWishesFilter != null) {
          filtered = filtered.where((w) => w.category == _myWishesFilter).toList();
        }
        if (_myWishesStatusFilter != null) {
          filtered = filtered.where((w) => w.status == _myWishesStatusFilter).toList();
        }

        return Column(
          children: [
            _buildFilterPanel(
              isOpen: _myWishesFilterOpen,
              onToggle: () => setState(() => _myWishesFilterOpen = !_myWishesFilterOpen),
              selectedCat: _myWishesFilter,
              onCatSelected: (cat) => setState(() => _myWishesFilter = cat),
              selectedStatus: _myWishesStatusFilter,
              onStatusSelected: (s) => setState(() => _myWishesStatusFilter = s),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('沒有符合條件的許願'))
                  : _buildMyWishesList(filtered),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMyWishesList(List<WishModel> wishes) {
    return ListView.builder(
      itemCount: wishes.length,
      itemBuilder: (_, i) {
        final w = wishes[i];
        if (w.status == WishStatus.negotiating) {
          return _NegotiatingCard(wish: w, wishService: _wishService);
        }
        return ListTile(
          title: Row(
            children: [
              if (w.isSecret) ...[
                const Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
              ],
              Expanded(child: Text(w.title)),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (w.category != null)
                Text(w.category!, style: const TextStyle(fontSize: 12, color: Colors.pink)),
              Text('費用：${w.price}'),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < w.heartRating ? Icons.favorite : Icons.favorite_border,
                    color: Colors.pink,
                    size: 14,
                  ),
                ),
              ),
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
              if (w.status == WishStatus.approved) _fulfilledCheckbox(w),
            ],
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => WishDetailScreen(wish: w)),
          ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
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
        SliverToBoxAdapter(
          child: _buildFilterPanel(
            isOpen: _reviewFilterOpen,
            onToggle: () => setState(() => _reviewFilterOpen = !_reviewFilterOpen),
            selectedCat: _reviewFilter,
            onCatSelected: (cat) => setState(() => _reviewFilter = cat),
            selectedStatus: _reviewStatusFilter,
            onStatusSelected: (s) => setState(() => _reviewStatusFilter = s),
          ),
        ),
        // 待審核（狀態篩選為非 pending 時隱藏）
        if (_reviewStatusFilter == null || _reviewStatusFilter == WishStatus.pending) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                '待審核',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
          StreamBuilder<List<WishModel>>(
            stream: _wishService.watchIncomingWishes(widget.partnerId),
            builder: (_, snap) {
              if (snap.hasError) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Text(
                      '錯誤：${snap.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                );
              }
              if (!snap.hasData) {
                return const SliverToBoxAdapter(
                  child: Center(child: Text('載入中...')),
                );
              }
              final pending = _reviewFilter == null
                  ? snap.data!
                  : snap.data!.where((w) => w.category == _reviewFilter).toList();
              if (pending.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('目前沒有待審核的許願', style: TextStyle(color: Colors.grey)),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final w = pending[i];
                    if (w.isLockedSecret) {
                      return FutureBuilder(
                        future: AuthService().fetchUser(w.requesterId),
                        builder: (_, snap) => _LockedSecretCard(
                          wish: w,
                          requesterName: snap.data?.displayName,
                        ),
                      );
                    }
                    return _WishReviewCard(wish: w, wishService: _wishService);
                  },
                  childCount: pending.length,
                ),
              );
            },
          ),
        ],

        // 已審核（狀態篩選為 pending 時隱藏）
        if (_reviewStatusFilter == null || _reviewStatusFilter != WishStatus.pending) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                '已審核',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
          StreamBuilder<List<WishModel>>(
            stream: _wishService.watchReviewedWishes(widget.partnerId),
            builder: (_, snap) {
              if (!snap.hasData) {
                return const SliverToBoxAdapter(
                  child: Center(child: Text('載入中...')),
                );
              }
              var reviewed = _reviewFilter == null
                  ? snap.data!
                  : snap.data!.where((w) => w.category == _reviewFilter).toList();
              if (_reviewStatusFilter != null) {
                reviewed = reviewed.where((w) => w.status == _reviewStatusFilter).toList();
              }
            if (reviewed.isEmpty) {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('還沒有審核過任何許願', style: TextStyle(color: Colors.grey)),
                ),
              );
            }
            return SliverList(
              delegate: SliverChildBuilderDelegate((_, i) {
                final w = reviewed[i];
                return ListTile(
                  title: Text(w.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (w.reviewNote != null && w.reviewNote!.isNotEmpty)
                        Text('回覆：${w.reviewNote}'),
                      if (w.fulfillmentNote != null && w.fulfillmentNote!.isNotEmpty)
                        Text(
                          '✨ ${w.fulfillmentNote}',
                          style: const TextStyle(color: Colors.pink),
                        ),
                    ],
                  ),
                  trailing: _statusChip(w.status),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WishDetailScreen(wish: w),
                    ),
                  ),
                );
              }, childCount: reviewed.length),
            );
          },
        ),
        ],
      ],
    );
  }

  Widget _fulfilledCheckbox(WishModel wish) {
    return Tooltip(
      message: wish.isFulfilled ? '取消已實現' : '標記為已實現',
      child: Checkbox(
        value: wish.isFulfilled,
        onChanged: (value) async {
          final next = value ?? false;
          if (next) {
            await _showFulfillDialog(wish);
          } else {
            try {
              await _wishService.setWishFulfilled(
                wishId: wish.id,
                isFulfilled: false,
              );
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('更新已實現狀態失敗：$e')),
                );
              }
            }
          }
        },
        activeColor: Colors.green,
        checkColor: Colors.white,
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.green;
          return Colors.white;
        }),
        side: BorderSide(color: Colors.grey.shade500, width: 1.4),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Future<void> _showFulfillDialog(WishModel wish) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite, color: Colors.pinkAccent, size: 48),
            const SizedBox(height: 12),
            const Text(
              '願望實現了！',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              '想對另一半說什麼嗎？',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(
                hintText: '謝謝你 ❤️',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.pink, width: 2),
                ),
              ),
              maxLines: 3,
              maxLength: 100,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('略過'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
            child: const Text('送出', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final note = noteCtrl.text.trim();
        await _wishService.setWishFulfilled(
          wishId: wish.id,
          isFulfilled: true,
          fulfillmentNote: note.isEmpty ? null : note,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('更新已實現狀態失敗：$e')),
          );
        }
      }
    }
  }

  /// 可實際審核的待審願望數（排除尚未解鎖的秘密許願，否則紅點永遠清不掉）
  static int _actionableCount(List<WishModel>? wishes) {
    if (wishes == null) return 0;
    return wishes.where((w) => !w.isLockedSecret).length;
  }

  Widget _countChip(int count) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFilterPanel({
    required bool isOpen,
    required VoidCallback onToggle,
    required String? selectedCat,
    required void Function(String?) onCatSelected,
    required WishStatus? selectedStatus,
    required void Function(WishStatus?) onStatusSelected,
  }) {
    final hasFilter = selectedCat != null || selectedStatus != null;
    const statuses = [
      (WishStatus.pending,     '審核中', Colors.orange),
      (WishStatus.approved,    '通過',   Colors.green),
      (WishStatus.negotiating, '協商中', Colors.deepOrange),
      (WishStatus.rejected,    '駁回',   Colors.red),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toggle bar
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.tune,
                  size: 18,
                  color: hasFilter ? Colors.pink : Colors.grey,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hasFilter
                        ? '篩選：${[
                            if (selectedCat != null) selectedCat,
                            if (selectedStatus != null)
                              switch (selectedStatus) {
                                WishStatus.pending     => '審核中',
                                WishStatus.approved    => '通過',
                                WishStatus.negotiating => '協商中',
                                WishStatus.rejected    => '駁回',
                              },
                          ].join(' · ')}'
                        : '篩選',
                    style: TextStyle(
                      fontSize: 13,
                      color: hasFilter ? Colors.pink : Colors.grey,
                      fontWeight: hasFilter ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more, size: 18, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ),
        // Collapsible panel
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: isOpen
              ? Container(
                  color: Colors.grey.shade50,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('類別', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, letterSpacing: 0.3)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          FilterChip(
                            label: const Text('全部'),
                            selected: selectedCat == null,
                            onSelected: (_) => onCatSelected(null),
                            selectedColor: Colors.pink.shade100,
                            checkmarkColor: Colors.pink,
                          ),
                          ...wishCategories.map((cat) => FilterChip(
                            label: Text(cat),
                            selected: selectedCat == cat,
                            onSelected: (_) => onCatSelected(selectedCat == cat ? null : cat),
                            selectedColor: Colors.pink.shade100,
                            checkmarkColor: Colors.pink,
                          )),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('狀態', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, letterSpacing: 0.3)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          FilterChip(
                            label: const Text('全部'),
                            selected: selectedStatus == null,
                            onSelected: (_) => onStatusSelected(null),
                            selectedColor: Colors.grey.shade200,
                            checkmarkColor: Colors.grey.shade700,
                          ),
                          ...statuses.map((s) {
                            final (status, label, color) = s;
                            return FilterChip(
                              label: Text(label),
                              selected: selectedStatus == status,
                              onSelected: (_) => onStatusSelected(selectedStatus == status ? null : status),
                              selectedColor: color.withValues(alpha: 0.2),
                              checkmarkColor: color,
                              labelStyle: selectedStatus == status
                                  ? TextStyle(color: color, fontWeight: FontWeight.w600)
                                  : null,
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _statusChip(WishStatus status) {
    final (label, color) = switch (status) {
      WishStatus.pending      => ('審核中', Colors.orange),
      WishStatus.approved     => ('通過',   Colors.green),
      WishStatus.rejected     => ('駁回',   Colors.red),
      WishStatus.negotiating  => ('協商中', Colors.deepOrange),
    };
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.2),
    );
  }
}

// ─── 協商中願望卡片（許願者視角） ───────────────────────────────
class _NegotiatingCard extends StatelessWidget {
  final WishModel wish;
  final WishService wishService;
  const _NegotiatingCard({required this.wish, required this.wishService});

  Future<void> _accept(BuildContext context) async {
    try {
      await wishService.acceptNegotiation(wish.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('錯誤：$e')));
      }
    }
  }

  Future<void> _decline(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放棄協商'),
        content: const Text('確定放棄？願望將標記為駁回。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('放棄', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await wishService.declineNegotiation(wish.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('錯誤：$e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.deepOrange.shade200, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.handshake_outlined, color: Colors.deepOrange, size: 18),
                const SizedBox(width: 6),
                const Text(
                  '協商中',
                  style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  wish.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '另一半的提案：',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    wish.negotiationNote ?? '',
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () => _accept(context),
                    child: const Text('接受提案', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () => _decline(context),
                    child: const Text('放棄'),
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

class _WishReviewCard extends StatefulWidget {
  final WishModel wish;
  final WishService wishService;
  const _WishReviewCard({required this.wish, required this.wishService});

  @override
  State<_WishReviewCard> createState() => _WishReviewCardState();
}

class _WishReviewCardState extends State<_WishReviewCard> {
  final _noteCtrl = TextEditingController();
  final _negotiationCtrl = TextEditingController();
  bool _showNegotiationField = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    _negotiationCtrl.dispose();
    super.dispose();
  }

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

  Future<void> _proposeNegotiation() async {
    final note = _negotiationCtrl.text.trim();
    if (note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請填寫修改提案內容')),
      );
      return;
    }
    try {
      await widget.wishService.proposeNegotiation(
        wishId: widget.wish.id,
        negotiationNote: note,
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
            Text(
              widget.wish.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('價格：${widget.wish.price}'),
            Row(
              children: [
                const Text('渴望程度：'),
                ...List.generate(
                  5,
                  (i) => Icon(
                    i < widget.wish.heartRating ? Icons.favorite : Icons.favorite_border,
                    color: Colors.pink,
                    size: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('理由：${widget.wish.reason}'),
            Text('希望時間：${widget.wish.scheduledAt.toLocal().toString().split(' ')[0]}'),
            const SizedBox(height: 12),
            // 協商模式：顯示協商輸入框；一般模式：顯示審核理由
            if (_showNegotiationField) ...[
              TextField(
                controller: _negotiationCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '修改提案內容 *',
                  hintText: '例如：日期改週末？預算改 NT\$800？',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.orange, width: 2),
                  ),
                ),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      onPressed: _proposeNegotiation,
                      child: const Text('送出提案', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _showNegotiationField = false),
                    child: const Text('取消'),
                  ),
                ],
              ),
            ] else ...[
              TextField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: '審核理由（選填）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              // 按鈕順序：通過 | 修改提案 | 駁回
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: () => _review(WishStatus.approved),
                      child: const Text('通過', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      onPressed: () => setState(() => _showNegotiationField = true),
                      child: const Text('修改提案', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => _review(WishStatus.rejected),
                      child: const Text('駁回', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── 公開 / 秘密 選項卡 ──────────────────────────────────────────
class WishTypeSelector extends StatelessWidget {
  final bool isSecret;
  final ValueChanged<bool> onChanged;
  const WishTypeSelector({required this.isSecret, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: WishTypeCard(
            icon: Icons.visibility_outlined,
            title: '公開許願',
            desc: '讓另一半馬上知道你想要什麼',
            selected: !isSecret,
            onTap: () => onChanged(false),
          )),
          const SizedBox(width: 10),
          Expanded(child: WishTypeCard(
            icon: Icons.lock_outline,
            title: '秘密許願',
            desc: '讓另一半帶著期待，到日期才知道驚喜是什麼',
            selected: isSecret,
            onTap: () => onChanged(true),
          )),
        ],
      ),
    );
  }
}

class WishTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final bool selected;
  final VoidCallback onTap;
  const WishTypeCard({
    required this.icon, required this.title, required this.desc,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? Colors.pink.shade50 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.pink : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: selected ? Colors.pink : Colors.grey, size: 22),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: selected ? Colors.pink : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 審核許願：秘密許願鎖定卡（B 視角，解鎖日前） ────────────────
class _LockedSecretCard extends StatelessWidget {
  final WishModel wish;
  final String? requesterName;
  const _LockedSecretCard({required this.wish, this.requesterName});

  @override
  Widget build(BuildContext context) {
    final dateStr = wish.scheduledAt.toLocal().toString().split(' ')[0];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_outline, color: Colors.grey, size: 18),
                const SizedBox(width: 6),
                const Text(
                  '秘密心願',
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (wish.category != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(wish.category!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${requesterName ?? '對方'} 有個心願想在 $dateStr 解鎖',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) => Icon(
                i < wish.heartRating ? Icons.favorite : Icons.favorite_border,
                color: Colors.pink.shade200,
                size: 16,
              )),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    '將在 $dateStr 自動解鎖',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
