import 'package:flutter/material.dart';
import '../models/pair_model.dart';
import '../services/pair_service.dart';

class AnniversaryScreen extends StatelessWidget {
  final String partnerId;
  const AnniversaryScreen({super.key, required this.partnerId});

  @override
  Widget build(BuildContext context) {
    final service = PairService();
    return Scaffold(
      appBar: AppBar(title: const Text('紀念日')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('新增紀念日'),
        onPressed: () => _openEditor(context, partnerId, null),
      ),
      body: StreamBuilder<PairModel?>(
        stream: service.watchPair(partnerId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = [...(snap.data?.events ?? [])]
            ..sort((a, b) => a.daysUntilNext.compareTo(b.daysUntilNext));
          if (events.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cake_outlined, size: 64, color: Colors.pink),
                  SizedBox(height: 16),
                  Text('還沒有紀念日',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('新增在一起、生日或自訂的紀念日 ❤️',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: events
                .map((e) => _EventTile(
                      event: e,
                      onTap: () => _openEditor(context, partnerId, e),
                    ))
                .toList(),
          );
        },
      ),
    );
  }

  void _openEditor(
      BuildContext context, String partnerId, AnniversaryEvent? event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EventEditor(partnerId: partnerId, event: event),
    );
  }
}

class _EventTile extends StatelessWidget {
  final AnniversaryEvent event;
  final VoidCallback onTap;
  const _EventTile({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final days = event.daysUntilNext;
    final String countdown = days == 0 ? '就是今天 🎉' : '還有 $days 天';
    final dateStr =
        '${event.date.month} 月 ${event.date.day} 日';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.pink.shade50,
          child: Icon(_iconFor(event.type), color: Colors.pink),
        ),
        title: Text(event.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$dateStr ・ $countdown'),
            if (event.type == AnniversaryType.together)
              Text('在一起 ${event.daysTogether} 天 ❤️',
                  style: TextStyle(color: Colors.pink.shade400, fontSize: 13)),
          ],
        ),
        trailing: const Icon(Icons.edit_outlined, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  static IconData _iconFor(AnniversaryType type) {
    switch (type) {
      case AnniversaryType.together:
        return Icons.favorite;
      case AnniversaryType.birthday:
        return Icons.cake;
      case AnniversaryType.custom:
        return Icons.event;
    }
  }
}

const _typeLabels = {
  AnniversaryType.together: '在一起',
  AnniversaryType.birthday: '生日',
  AnniversaryType.custom: '自訂',
};

class _EventEditor extends StatefulWidget {
  final String partnerId;
  final AnniversaryEvent? event;
  const _EventEditor({required this.partnerId, this.event});

  @override
  State<_EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<_EventEditor> {
  late final TextEditingController _titleCtrl;
  late AnniversaryType _type;
  late DateTime _date;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.event != null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _type = e?.type ?? AnniversaryType.together;
    _date = e?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '請輸入名稱');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final event = AnniversaryEvent(
        id: widget.event?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        date: _date,
        type: _type,
      );
      await PairService().saveEvent(widget.partnerId, event);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = '錯誤：$e';
        _saving = false;
      });
    }
  }

  Future<void> _delete() async {
    setState(() => _saving = true);
    try {
      await PairService().deleteEvent(widget.partnerId, widget.event!.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = '錯誤：$e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = '${_date.year} 年 ${_date.month} 月 ${_date.day} 日';
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isEdit ? '編輯紀念日' : '新增紀念日',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: '名稱',
              hintText: '例：我們在一起、他的生日',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: AnniversaryType.values.map((t) {
              return ChoiceChip(
                label: Text(_typeLabels[t]!),
                selected: _type == t,
                selectedColor: Colors.pink.shade100,
                onSelected: (_) => setState(() => _type = t),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(dateStr),
            onPressed: _pickDate,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (_isEdit)
                TextButton.icon(
                  onPressed: _saving ? null : _delete,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label:
                      const Text('刪除', style: TextStyle(color: Colors.red)),
                ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  foregroundColor: Colors.white,
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('儲存'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
