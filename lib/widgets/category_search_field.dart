import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import 'category_icon.dart';
import 'quick_category_dialog.dart';

/// One row in the dropdown: an existing category, or "Create" for a new name.
class _CatOption {
  final Category? category;
  final String? createName;
  const _CatOption.category(Category this.category) : createName = null;
  const _CatOption.create(String this.createName) : category = null;
}

/// A searchable category picker.
///
/// Tapping it lists the categories of [type] (top-level ones, or the children
/// of [parentId] when [subcategory] is true). Typing filters the list; when
/// nothing matches exactly, a "Create" option opens the category dialog
/// prefilled with the typed name, and the new category is selected once
/// saved. Each option has a pencil to edit it.
///
/// A subcategory field is disabled until [parentId] is set.
class CategorySearchField extends ConsumerStatefulWidget {
  /// 'income' or 'expense'.
  final String type;

  /// Selected category id, or null.
  final String? value;
  final ValueChanged<Category?> onChanged;

  /// Lists the children of [parentId] instead of top-level categories.
  final bool subcategory;
  final String? parentId;

  final String? label;
  final String? disabledHint;

  const CategorySearchField({
    super.key,
    required this.type,
    required this.value,
    required this.onChanged,
    this.subcategory = false,
    this.parentId,
    this.label,
    this.disabledHint,
  });

  @override
  ConsumerState<CategorySearchField> createState() => _CategorySearchFieldState();
}

class _CategorySearchFieldState extends ConsumerState<CategorySearchField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  bool get _enabled => !widget.subcategory || widget.parentId != null;

  @override
  void initState() {
    super.initState();
    _controller.text = _selected()?.name ?? '';
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant CategorySearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value || oldWidget.parentId != widget.parentId || oldWidget.type != widget.type) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focusNode.hasFocus) _showSelectedName();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  List<Category> _options() {
    final all = ref.read(categoriesProvider);
    return all.where((c) {
      if (c.type != widget.type) return false;
      final isTop = c.parentId == null || c.parentId!.isEmpty;
      return widget.subcategory ? c.parentId == widget.parentId : isTop;
    }).toList();
  }

  Category? _selected() {
    final id = widget.value;
    if (id == null) return null;
    for (final c in ref.read(categoriesProvider)) {
      if (c.id == id) return c;
    }
    return null;
  }

  void _showSelectedName() {
    final name = _selected()?.name ?? '';
    if (_controller.text != name) {
      _controller.value = TextEditingValue(
        text: name,
        selection: TextSelection.collapsed(offset: name.length),
      );
    }
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      // Start from an empty query so the whole list shows; the current
      // choice stays visible as the hint.
      _controller.clear();
    } else {
      _showSelectedName();
    }
  }

  Iterable<_CatOption> _build(TextEditingValue v) {
    final q = v.text.trim().toLowerCase();
    final cats = _options();
    final matches = q.isEmpty ? cats : cats.where((c) => c.name.toLowerCase().contains(q)).toList();
    final exact = cats.any((c) => c.name.trim().toLowerCase() == q);
    return [...matches.map(_CatOption.category), if (q.isNotEmpty && !exact) _CatOption.create(v.text.trim())];
  }

  Future<void> _onSelected(_CatOption opt) async {
    _focusNode.unfocus();
    final cat = opt.category;
    if (cat != null) {
      widget.onChanged(cat);
      _setText(cat.name);
      return;
    }
    final created = await showQuickCategoryDialog(
      context: context,
      ref: ref,
      type: widget.type,
      initialName: opt.createName,
      parentId: widget.subcategory ? widget.parentId : null,
      lockParent: widget.subcategory,
    );
    if (!mounted) return;
    if (created != null) {
      widget.onChanged(created);
      _setText(created.name);
    } else {
      _showSelectedName();
    }
  }

  Future<void> _edit(Category cat) async {
    _focusNode.unfocus();
    final updated = await showQuickCategoryDialog(context: context, ref: ref, type: widget.type, existing: cat);
    if (!mounted || updated == null) return;
    if (updated.id == widget.value) {
      widget.onChanged(updated);
      _setText(updated.name);
    } else {
      _showSelectedName();
    }
  }

  void _setText(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _clear() {
    widget.onChanged(null);
    _focusNode.unfocus();
    _setText('');
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when categories change (created, renamed, deleted).
    ref.watch(categoriesProvider);
    final selected = _selected();
    final label = widget.label ?? (widget.subcategory ? 'Subcategory' : 'Category');

    return RawAutocomplete<_CatOption>(
      // Fresh state when the list's scope changes, so stale options never show.
      key: ValueKey('${widget.type}|${widget.subcategory}|${widget.parentId}'),
      textEditingController: _controller,
      focusNode: _focusNode,
      optionsViewOpenDirection: OptionsViewOpenDirection.mostSpace,
      displayStringForOption: (o) => o.category?.name ?? o.createName ?? '',
      optionsBuilder: _build,
      onSelected: _onSelected,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: _enabled,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmitted(),
          scrollPadding: const EdgeInsets.only(bottom: 220),
          decoration: InputDecoration(
            labelText: label,
            hintText: _enabled
                ? (selected?.name ?? 'Search or create')
                : (widget.disabledHint ?? 'Choose a category first'),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            isDense: true,
            prefixIcon: selected != null
                ? Padding(
                    padding: const EdgeInsets.all(10),
                    child: CategoryIcon(category: selected, size: 20),
                  )
                : const Icon(Icons.search_rounded, size: 20),
            prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            suffixIcon: _enabled && selected != null
                ? IconButton(tooltip: 'Clear', icon: const Icon(Icons.close_rounded, size: 18), onPressed: _clear)
                : const Icon(Icons.arrow_drop_down_rounded),
          ),
        );
      },
      optionsViewBuilder: (context, onSelect, options) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final list = options.toList();
        // RawAutocomplete aligns this above or below the field itself.
        return Material(
          elevation: 6,
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              shrinkWrap: true,
              itemCount: list.length,
              itemBuilder: (context, i) {
                final opt = list[i];
                final highlighted = AutocompleteHighlightedOption.of(context) == i;
                final cat = opt.category;
                final Widget row;
                if (cat == null) {
                  row = Row(
                    children: [
                      const Icon(Icons.add_rounded, size: 20, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Create "${opt.createName}"',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
                        ),
                      ),
                    ],
                  );
                } else {
                  row = Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Color(cat.colorValue).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: CategoryIcon(category: cat, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          cat.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: cat.id == widget.value ? FontWeight.w700 : FontWeight.w500),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        onPressed: () => _edit(cat),
                      ),
                    ],
                  );
                }
                return InkWell(
                  onTap: () => onSelect(opt),
                  child: Container(
                    color: highlighted ? AppColors.primary.withValues(alpha: 0.10) : null,
                    padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
                    constraints: const BoxConstraints(minHeight: 44),
                    child: row,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Category and Subcategory search fields side by side (stacked when narrow).
/// Changing or clearing the category clears the subcategory.
class CategoryPickerPair extends StatelessWidget {
  final String type;
  final String? categoryId;
  final String? subcategoryId;
  final void Function(String? categoryId, String? subcategoryId) onChanged;
  final String categoryLabel;
  const CategoryPickerPair({
    super.key,
    required this.type,
    required this.categoryId,
    required this.subcategoryId,
    required this.onChanged,
    this.categoryLabel = 'Category',
  });

  @override
  Widget build(BuildContext context) {
    final category = CategorySearchField(
      type: type,
      label: categoryLabel,
      value: categoryId,
      onChanged: (c) {
        if (c?.id != categoryId) onChanged(c?.id, null);
      },
    );
    final sub = CategorySearchField(
      type: type,
      subcategory: true,
      parentId: categoryId,
      value: subcategoryId,
      disabledHint: 'Pick a category first',
      onChanged: (c) => onChanged(categoryId, c?.id),
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 360) {
          return Column(children: [category, const SizedBox(height: 12), sub]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: category),
            const SizedBox(width: 10),
            Expanded(child: sub),
          ],
        );
      },
    );
  }
}
