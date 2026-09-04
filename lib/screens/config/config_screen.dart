import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/category_icon.dart';

class ConfigScreen extends ConsumerWidget {
  const ConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final income = categories.where((c) => c.type == 'income').toList();
    final expense = categories.where((c) => c.type == 'expense').toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/dashboard');
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          drawer: const AppDrawer(),
          appBar: AppBar(
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            title: const Text('Categories & Subcategories'),
            bottom: const TabBar(tabs: [Tab(text: 'Expense'), Tab(text: 'Income')]),
          ),
          floatingActionButton: Builder(builder: (ctx) {
            final tabCtrl = DefaultTabController.of(ctx);
            return FloatingActionButton(
              onPressed: () {
                final type = tabCtrl.index == 0 ? 'expense' : 'income';
                _showAddSheet(context, ref, type: type);
              },
              child: const Icon(Icons.add_rounded, size: 28),
            );
          }),
          body: TabBarView(
            children: [
              _CatList(items: expense, type: 'expense', ref: ref),
              _CatList(items: income, type: 'income', ref: ref),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSheet(
    BuildContext context,
    WidgetRef ref, {
    required String type,
    Category? existing,
    String? initialParentId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CategorySheet(
        ref: ref,
        type: type,
        existing: existing,
        initialParentId: initialParentId,
      ),
    );
  }
}

class _CatList extends StatelessWidget {
  final List<Category> items;
  final String type;
  final WidgetRef ref;

  const _CatList({
    required this.items,
    required this.type,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.category_outlined, size: 56, color: AppColors.darkTextMuted),
            const SizedBox(height: 12),
            Text('No categories yet', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text('Tap + New Category to add one', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    }

    final parents = items.where((c) => c.parentId == null || c.parentId!.isEmpty).toList();
    final parentIds = parents.map((p) => p.id).toSet();
    final orphans = items.where((c) => c.parentId != null && c.parentId!.isNotEmpty && !parentIds.contains(c.parentId)).toList();

    return CustomScrollView(
      slivers: [
        // Drag hint
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.drag_indicator_rounded, size: 16, color: AppColors.darkTextMuted),
                const SizedBox(width: 6),
                Text(
                  'Long press & drag to reorder categories',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: AppColors.darkTextMuted,
                      ),
                ),
              ],
            ),
          ),
        ),

        // Reorderable parent categories
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverReorderableList(
            itemCount: parents.length,
            onReorderItem: (oldIndex, newIndex) {
              final reordered = List<Category>.from(parents);
              final item = reordered.removeAt(oldIndex);
              reordered.insert(newIndex, item);
              ref.read(categoriesProvider.notifier).reorderParents(reordered, type);
            },
            itemBuilder: (context, i) {
              final parent = parents[i];
              final subcategories = items.where((c) => c.parentId == parent.id).toList();
              final color = Color(parent.colorValue);

              return ReorderableDelayedDragStartListener(
                key: ValueKey(parent.id),
                index: i,
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Parent Category Header Row
                        Row(
                          children: [
                            // Drag handle
                            const Icon(Icons.drag_indicator_rounded, size: 20, color: AppColors.darkTextMuted),
                            const SizedBox(width: 8),
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: CategoryIcon(category: parent, size: 24, fontSize: 22),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    parent.name,
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subcategories.isEmpty
                                        ? 'Main category • No subcategories'
                                        : '${subcategories.length} subcategor${subcategories.length == 1 ? 'y' : 'ies'}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            // Add Subcategory button
                            IconButton(
                              tooltip: 'Add Subcategory under ${parent.name}',
                              icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 22),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                  ),
                                  builder: (_) => _CategorySheet(
                                    ref: ref,
                                    type: type,
                                    initialParentId: parent.id,
                                  ),
                                );
                              },
                            ),
                            // Edit parent category
                            IconButton(
                              tooltip: 'Edit Category',
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                  ),
                                  builder: (_) => _CategorySheet(
                                    ref: ref,
                                    type: type,
                                    existing: parent,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),

                        // Subcategories Chips Wrap
                        if (subcategories.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: subcategories.map((sub) {
                              final subColor = Color(sub.colorValue);
                              return InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                    ),
                                    builder: (_) => _CategorySheet(
                                      ref: ref,
                                      type: type,
                                      existing: sub,
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.darkCardAlt,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.darkBorder),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CategoryIcon(category: sub, size: 16, fontSize: 14),
                                      const SizedBox(width: 6),
                                      Text(
                                        sub.name,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: subColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: Duration(milliseconds: i * 35), duration: 300.ms),
              );
            },
          ),
        ),

        // Orphan subcategories (non-reorderable)
        if (orphans.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Other / Standalone Subcategories',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.darkTextSecondary),
                  ),
                ),
                ...orphans.map((sub) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CategoryIcon(category: sub, size: 24, fontSize: 22),
                        title: Text(sub.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: const Icon(Icons.edit_outlined, size: 18),
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                            ),
                            builder: (_) => _CategorySheet(
                              ref: ref,
                              type: type,
                              existing: sub,
                            ),
                          );
                        },
                      ),
                    )),
              ]),
            ),
          ),

        // Bottom spacing
        const SliverToBoxAdapter(child: SizedBox(height: 90)),
      ],
    );
  }
}

class _CategorySheet extends StatefulWidget {
  final WidgetRef ref;
  final String type;
  final Category? existing;
  final String? initialParentId;

  const _CategorySheet({
    required this.ref,
    required this.type,
    this.existing,
    this.initialParentId,
  });

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  final _nameCtrl = TextEditingController();
  Color _color = AppColors.primary;
  String _icon = '📦';
  String? _imagePath;
  String? _parentId;
  bool _saving = false;
  bool _showEmoji = false;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    if (c != null) {
      _nameCtrl.text = c.name;
      _color = Color(c.colorValue);
      _icon = c.icon;
      _imagePath = c.imagePath;
      _parentId = c.parentId;
    } else {
      _parentId = widget.initialParentId;
      if (_parentId != null) {
        final categories = widget.ref.read(categoriesProvider);
        final parent = categories.where((cat) => cat.id == _parentId).firstOrNull;
        if (parent != null) {
          _color = Color(parent.colorValue);
        }
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final originalFile = File(result.files.single.path!);
        final appDir = await getApplicationDocumentsDirectory();
        final iconsDir = Directory('${appDir.path}/category_icons');
        if (!await iconsDir.exists()) {
          await iconsDir.create(recursive: true);
        }
        final ext = originalFile.path.split('.').last;
        final targetPath = '${iconsDir.path}/${const Uuid().v4()}.$ext';
        await originalFile.copy(targetPath);
        setState(() {
          _imagePath = targetPath;
          _showEmoji = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);

    if (widget.existing != null) {
      final c = widget.existing!;
      c.name = _nameCtrl.text.trim();
      c.colorValue = _color.toARGB32();
      c.icon = _icon;
      c.imagePath = _imagePath;
      c.parentId = _parentId;
      await widget.ref.read(categoriesProvider.notifier).update(c);
    } else {
      final cat = Category(
        id: '',
        name: _nameCtrl.text.trim(),
        type: widget.type,
        colorValue: _color.toARGB32(),
        icon: _icon,
        imagePath: _imagePath,
        parentId: _parentId,
      );
      await widget.ref.read(categoriesProvider.notifier).add(cat);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final allCategories = widget.ref.watch(categoriesProvider);
    // Potential parents: top-level categories of same type, excluding self
    final potentialParents = allCategories
        .where((c) =>
            c.type == widget.type &&
            (c.parentId == null || c.parentId!.isEmpty) &&
            c.id != widget.existing?.id)
        .toList();

    final hasCustomImage = _imagePath != null && _imagePath!.isNotEmpty && File(_imagePath!).existsSync();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: AppColors.darkBorder, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text(
                    widget.existing != null
                        ? (_parentId != null ? 'Edit Subcategory' : 'Edit Category')
                        : (_parentId != null ? 'Add Subcategory' : 'Add Category'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  if (widget.existing != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Category'),
                            content: Text(widget.existing!.parentId == null
                                ? 'Are you sure? Deleting this category will also remove all its subcategories.'
                                : 'Are you sure you want to delete this subcategory?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete', style: TextStyle(color: AppColors.expense)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await widget.ref.read(categoriesProvider.notifier).delete(widget.existing!);
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon / Image preview
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: _color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _color, width: 2),
                            ),
                            child: Center(
                              child: hasCustomImage
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.file(
                                        File(_imagePath!),
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Text(_icon, style: const TextStyle(fontSize: 34)),
                            ),
                          ),
                          if (hasCustomImage)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: GestureDetector(
                                onTap: () => setState(() => _imagePath = null),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: AppColors.expense,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Icon selection mode buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => setState(() => _showEmoji = !_showEmoji),
                          icon: const Icon(Icons.emoji_emotions_outlined, size: 16),
                          label: Text(_showEmoji ? 'Hide Emojis' : 'Choose Emoji', style: const TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            foregroundColor: AppColors.primary,
                            elevation: 0,
                          ),
                          onPressed: _pickImage,
                          icon: const Icon(Icons.photo_library_outlined, size: 16),
                          label: Text(hasCustomImage ? 'Change Image' : 'Add Image',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),

                    if (_showEmoji) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.darkCardAlt,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            '📦','💼','🍔','🚗','🛍️','🧾','🏥','🎬','📚','🏠',
                            '💻','📈','🎁','✈️','⚽','🎮','🐾','🌿','💊','🔧',
                            '💰','🧴','☕','🎵','🏋️','📱','🛒','🏦','💡','🎓',
                            '🍕','🍎','🚌','⛽','🚆','🎟️','🍿','🎧','👗','🚕',
                            '🚲','🏍️','⛵','🏖️','🍣','🍩','🍦','🍻','🍷','🎂',
                          ].map((e) => GestureDetector(
                            onTap: () => setState(() {
                              _icon = e;
                              _imagePath = null;
                              _showEmoji = false;
                            }),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Text(e, style: const TextStyle(fontSize: 26)),
                            ),
                          )).toList(),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: _parentId != null ? 'Subcategory Name (e.g. Bus, Train, Flight)' : 'Category Name',
                        hintText: _parentId != null ? 'e.g. Bus, Flight, Train' : 'e.g. Transport, Food',
                      ),
                    ),

                    const SizedBox(height: 16),
                    // Parent Category Selector
                    DropdownButtonFormField<String?>(
                      initialValue: _parentId,
                      decoration: const InputDecoration(
                        labelText: 'Parent Category (Optional)',
                        helperText: 'Select a parent to make this a subcategory',
                      ),
                      dropdownColor: AppColors.darkCard,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Row(
                            children: [
                              Icon(Icons.folder_open_rounded, size: 18, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text('None (Top-Level Category)'),
                            ],
                          ),
                        ),
                        ...potentialParents.map((p) => DropdownMenuItem(
                              value: p.id,
                              child: Row(
                                children: [
                                  CategoryIcon(category: p, size: 18),
                                  const SizedBox(width: 8),
                                  Text(p.name),
                                ],
                              ),
                            )),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _parentId = v;
                          if (v != null) {
                            final parent = potentialParents.where((p) => p.id == v).firstOrNull;
                            if (parent != null) _color = Color(parent.colorValue);
                          }
                        });
                      },
                    ),

                    const SizedBox(height: 16),
                    Text('Color Theme', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: AppColors.chartColors.map((c) => GestureDetector(
                        onTap: () => setState(() => _color = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _color == c ? Colors.white : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                        ),
                      )).toList(),
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(widget.existing != null ? 'Update Category' : 'Save Category'),
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
