import 'package:flutter/material.dart';
import '../models/wish_model.dart';
import '../services/wish_service.dart';

class EditWishScreen extends StatefulWidget {
  final WishModel wish;
  const EditWishScreen({super.key, required this.wish});

  @override
  State<EditWishScreen> createState() => _EditWishScreenState();
}

class _EditWishScreenState extends State<EditWishScreen> {
  final _wishService = WishService();
  late final _titleCtrl = TextEditingController(text: widget.wish.title);
  late final _priceCtrl = TextEditingController(text: widget.wish.price);
  late final _productUrlCtrl = TextEditingController(text: widget.wish.productUrl ?? '');
  late final _descriptionCtrl = TextEditingController(text: widget.wish.description ?? '');
  late final _reasonCtrl = TextEditingController(text: widget.wish.reason);
  late int _heartRating = widget.wish.heartRating;
  late DateTime _scheduledAt = widget.wish.scheduledAt;
  bool _isLoading = false;
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
      if (uri == null || !uri.hasScheme || !uri.scheme.startsWith('http')) {
        setState(() => _message = '商品網址格式不正確');
        return;
      }
    }

    setState(() { _isLoading = true; _message = null; });
    try {
      await _wishService.updateWish(
        wishId: widget.wish.id,
        title: title,
        price: price,
        heartRating: _heartRating,
        productUrl: productUrl.isEmpty ? null : productUrl,
        description: description,
        reason: reason,
        scheduledAt: _scheduledAt,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _message = '錯誤：$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    return Scaffold(
      appBar: AppBar(title: const Text('編輯許願')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('許下我的願望 *', style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(controller: _titleCtrl, decoration: const InputDecoration(hintText: '我想要...')),
          const SizedBox(height: 24),
          const Text('費用參考 *', style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(controller: _priceCtrl, decoration: const InputDecoration(hintText: '例如：NT\$500 或 無價')),
          const SizedBox(height: 24),
          const Text('心動指數 ♡ *', style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) => GestureDetector(
              onTap: () => setState(() => _heartRating = i + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  i < _heartRating ? Icons.favorite : Icons.favorite_border,
                  color: Colors.pink, size: 36,
                ),
              ),
            )),
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
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.pinkAccent)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.pink, width: 2)),
            ),
            minLines: 3, maxLines: 6,
          ),
          const SizedBox(height: 24),
          const Text('我的理由 *', style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(
            controller: _reasonCtrl,
            decoration: InputDecoration(
              hintText: '說服另一半的理由...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.pinkAccent)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.pink, width: 2)),
            ),
            minLines: 4, maxLines: 8,
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
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_message!, style: TextStyle(color: _message!.startsWith('錯誤') || _message!.startsWith('請') ? Colors.red : Colors.green)),
            ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            ElevatedButton(onPressed: _submit, child: const Text('儲存變更')),
        ],
      ),
    );
  }
}
