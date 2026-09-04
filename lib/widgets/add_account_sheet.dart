import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../core/utils/utils.dart';

class AddAccountSheet extends StatefulWidget {
  final WidgetRef ref;
  final Account? existing;
  const AddAccountSheet({super.key, required this.ref, this.existing});

  @override
  State<AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends State<AddAccountSheet> {
  final _nameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _currency = 'INR';
  Color _color = AppColors.primary;
  String _emoji = '💳';
  bool _saving = false;
  bool _showEmojiPicker = false;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    if (a != null) {
      _nameCtrl.text = a.name;
      _balanceCtrl.text = a.balance.toString();
      _notesCtrl.text = a.notes;
      _currency = a.currency;
      _color = Color(a.colorValue);
      _emoji = a.emoji;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty) return;
    final balance = double.tryParse(_balanceCtrl.text) ?? 0;
    setState(() => _saving = true);

    if (widget.existing != null) {
      final a = widget.existing!;
      a.name = _nameCtrl.text;
      a.balance = balance;
      a.currency = _currency;
      a.colorValue = _color.toARGB32();
      a.emoji = _emoji;
      a.notes = _notesCtrl.text;
      await widget.ref.read(accountsProvider.notifier).update(a);
    } else {
      final account = Account(
        id: '',
        name: _nameCtrl.text,
        balance: balance,
        currency: _currency,
        colorValue: _color.toARGB32(),
        emoji: _emoji,
        notes: _notesCtrl.text,
      );
      await widget.ref.read(accountsProvider.notifier).add(account);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.darkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text(
                    widget.existing != null ? 'Edit Account' : 'Add Account',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  if (widget.existing != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete Account?'),
                            content: const Text('All transactions for this account will be removed.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(context, true),
                                  child: Text('Delete', style: TextStyle(color: AppColors.expense))),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await widget.ref.read(accountsProvider.notifier).delete(widget.existing!);
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                    ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Emoji + color preview
                    GestureDetector(
                      onTap: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
                      child: Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(
                          color: _color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _color, width: 2),
                        ),
                        child: Center(child: Text(_emoji, style: const TextStyle(fontSize: 36))),
                      ),
                    ),
                    if (_showEmojiPicker)
                      SizedBox(
                        height: 200,
                        child: EmojiPicker(
                          onEmojiSelected: (_, emoji) {
                            setState(() { _emoji = emoji.emoji; _showEmojiPicker = false; });
                          },
                          config: const Config(
                            height: 200,
                            emojiViewConfig: EmojiViewConfig(columns: 8),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Account Name'),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _balanceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      decoration: const InputDecoration(labelText: 'Current Balance'),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: _currency,
                      items: CurrencyUtil.supportedCurrencies.map((c) => DropdownMenuItem(
                        value: c,
                        child: Text('$c  ${CurrencyUtil.symbol(c)}'),
                      )).toList(),
                      onChanged: (v) => setState(() => _currency = v ?? 'INR'),
                      decoration: const InputDecoration(labelText: 'Currency'),
                      dropdownColor: AppColors.darkCard,
                    ),
                    const SizedBox(height: 16),

                    // Color picker
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Color', style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: AppColors.accountColors.map((c) => GestureDetector(
                        onTap: () => setState(() => _color = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _color == c ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: _color == c
                                ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 8)]
                                : null,
                          ),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Notes (optional)'),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(widget.existing != null ? 'Save Changes' : 'Add Account'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
