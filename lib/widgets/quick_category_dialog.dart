import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' hide Category, CategoryIcon;
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import 'category_icon.dart';

/// Opens a small dialog that creates a category of [type] ('income' or
/// 'expense') and returns it once saved, or null when cancelled.
///
/// [initialName] prefills the name. [parentId] presets the parent; with
/// [lockParent] the parent can't be changed (used for subcategories).
/// Passing [existing] opens the dialog in edit mode: it updates that
/// category instead of creating one.
Future<Category?> showQuickCategoryDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String type,
  String? initialName,
  String? parentId,
  bool lockParent = false,
  Category? existing,
}) {
  return showDialog<Category>(
    context: context,
    builder: (_) => _QuickCategoryDialog(
      ref: ref,
      type: existing?.type ?? type,
      initialName: initialName,
      parentId: existing?.parentId ?? parentId,
      lockParent: lockParent || existing != null,
      existing: existing,
    ),
  );
}

class _QuickCategoryDialog extends StatefulWidget {
  final WidgetRef ref;
  final String type;
  final String? initialName;
  final String? parentId;
  final bool lockParent;
  final Category? existing;
  const _QuickCategoryDialog({
    required this.ref,
    required this.type,
    this.initialName,
    this.parentId,
    this.lockParent = false,
    this.existing,
  });

  @override
  State<_QuickCategoryDialog> createState() => _QuickCategoryDialogState();
}

class _QuickCategoryDialogState extends State<_QuickCategoryDialog> {
  final _nameCtrl = TextEditingController();
  String _icon = '📦';
  Color _color = AppColors.chartColors.first;
  String? _parentId;
  bool _showEmoji = false;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _icon = e.icon.isNotEmpty ? e.icon : '📦';
      _color = Color(e.colorValue);
      _parentId = (e.parentId == null || e.parentId!.isEmpty) ? null : e.parentId;
    } else {
      _nameCtrl.text = widget.initialName?.trim() ?? '';
      _parentId = widget.parentId;
      if (_parentId != null) {
        final parent = widget.ref.read(categoriesProvider).where((c) => c.id == _parentId).firstOrNull;
        if (parent != null) _color = Color(parent.colorValue);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCustomColor() async {
    final before = _color;
    final changed = await ColorPicker(
      color: _color,
      onColorChanged: (c) => setState(() => _color = c),
      width: 36,
      height: 36,
      borderRadius: 10,
      spacing: 5,
      runSpacing: 5,
      wheelDiameter: 165,
      showColorCode: true,
      pickersEnabled: const <ColorPickerType, bool>{
        ColorPickerType.both: false,
        ColorPickerType.primary: true,
        ColorPickerType.accent: true,
        ColorPickerType.bw: false,
        ColorPickerType.custom: false,
        ColorPickerType.wheel: true,
      },
    ).showPickerDialog(
      context,
      actionsPadding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minWidth: 300, minHeight: 460, maxWidth: 360),
    );
    if (!changed) setState(() => _color = before);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the category a name');
      return;
    }
    setState(() => _saving = true);
    final existing = widget.existing;
    if (existing != null) {
      existing
        ..name = name
        ..icon = _icon
        ..colorValue = _color.toARGB32();
      await widget.ref.read(categoriesProvider.notifier).update(existing);
      if (mounted) Navigator.pop(context, existing);
      return;
    }
    final cat = Category(
      id: '',
      name: name,
      type: widget.type,
      colorValue: _color.toARGB32(),
      icon: _icon,
      parentId: _parentId,
    );
    // HiveService.addCategory assigns the id.
    await widget.ref.read(categoriesProvider.notifier).add(cat);
    if (mounted) Navigator.pop(context, cat);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parents = widget.ref
        .read(categoriesProvider)
        .where((c) => c.type == widget.type && (c.parentId == null || c.parentId!.isEmpty))
        .toList();

    return AlertDialog(
      title: Text(_editing
          ? 'Edit category'
          : widget.lockParent && _parentId != null
              ? 'New subcategory'
              : widget.type == 'income'
                  ? 'New income category'
                  : 'New expense category'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() => _showEmoji = !_showEmoji),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _color, width: 2),
                      ),
                      child: Center(child: Text(_icon, style: const TextStyle(fontSize: 28))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _nameCtrl,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        hintText: widget.type == 'income' ? 'e.g. Side Project' : 'e.g. Pet Care',
                        errorText: _error,
                      ),
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                      onSubmitted: (_) => _save(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _showEmoji = !_showEmoji),
                  icon: const Icon(Icons.emoji_emotions_outlined, size: 16),
                  label: Text(_showEmoji ? 'Hide emojis' : 'Choose emoji', style: const TextStyle(fontSize: 12)),
                ),
              ),
              if (_showEmoji)
                SizedBox(
                  height: 230,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: EmojiPicker(
                      onEmojiSelected: (_, emoji) => setState(() {
                        _icon = emoji.emoji;
                        _showEmoji = false;
                      }),
                      config: Config(
                        height: 230,
                        emojiViewConfig: EmojiViewConfig(
                          columns: 8,
                          backgroundColor: isDark ? AppColors.darkCardAlt : AppColors.lightCard,
                        ),
                        categoryViewConfig: CategoryViewConfig(
                          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightBg,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              const Text('Colour', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...AppColors.chartColors.map((c) {
                    final selected = c.toARGB32() == _color.toARGB32();
                    return GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? Colors.white : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: selected ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                      ),
                    );
                  }),
                  GestureDetector(
                    onTap: _pickCustomColor,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, width: 1.5),
                      ),
                      child: const Icon(Icons.colorize_rounded, size: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: _parentId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Parent category (optional)'),
                dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                items: [
                  const DropdownMenuItem(value: null, child: Text('None (top level)')),
                  ...parents.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Row(
                          children: [
                            CategoryIcon(category: c, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(c.name, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      )),
                ],
                onChanged: widget.lockParent
                    ? null
                    : (v) => setState(() {
                  _parentId = v;
                  final parent = parents.where((p) => p.id == v).firstOrNull;
                  if (parent != null) _color = Color(parent.colorValue);
                }),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(_editing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
