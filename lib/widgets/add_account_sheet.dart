import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import '../../core/platform/platform_helpers.dart';
import '../../core/theme/app_colors.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../core/utils/utils.dart';
import 'card_network_badge.dart';

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
  String? _imagePath;
  String _cardType = CardNetworkType.mastercard;
  bool _isEnabledForCalc = true;
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
      _imagePath = a.imagePath;
      _cardType = a.cardType;
      _isEnabledForCalc = a.isEnabledForCalc;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked != null) {
        final targetPath = await persistPickedImage(
          folder: 'account_icons',
          sourceName: picked.name,
          sourcePath: kIsWeb ? null : picked.path,
          readBytes: picked.readAsBytes,
        );
        setState(() {
          _imagePath = targetPath;
          _showEmojiPicker = false;
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

  Future<void> _pickCustomColor() async {
    final Color colorBefore = _color;
    final bool colorChanged = await ColorPicker(
      color: _color,
      onColorChanged: (Color color) => setState(() => _color = color),
      width: 40,
      height: 40,
      borderRadius: 10,
      spacing: 5,
      runSpacing: 5,
      wheelDiameter: 165,
      heading: Text('Select Color Theme', style: Theme.of(context).textTheme.titleSmall),
      subheading: Text('Select color shade', style: Theme.of(context).textTheme.bodySmall),
      wheelSubheading: Text('Selected color and its shades', style: Theme.of(context).textTheme.bodySmall),
      showMaterialName: false,
      showColorName: false,
      showColorCode: true,
      copyPasteBehavior: const ColorPickerCopyPasteBehavior(
        longPressMenu: true,
      ),
      materialNameTextStyle: Theme.of(context).textTheme.bodySmall,
      colorNameTextStyle: Theme.of(context).textTheme.bodySmall,
      colorCodeTextStyle: Theme.of(context).textTheme.bodySmall,
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

    if (!colorChanged) {
      setState(() => _color = colorBefore);
    }
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
      a.imagePath = _imagePath;
      a.cardType = _cardType;
      a.notes = _notesCtrl.text;
      a.isEnabledForCalc = _isEnabledForCalc;
      await widget.ref.read(accountsProvider.notifier).update(a);
    } else {
      final account = Account(
        id: '',
        name: _nameCtrl.text,
        balance: balance,
        currency: _currency,
        colorValue: _color.toARGB32(),
        emoji: _emoji,
        imagePath: _imagePath,
        cardType: _cardType,
        notes: _notesCtrl.text,
        isEnabledForCalc: _isEnabledForCalc,
      );
      await widget.ref.read(accountsProvider.notifier).add(account);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hasCustomImage = localImageExists(_imagePath);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                                  child: const Text('Delete', style: TextStyle(color: AppColors.expense))),
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
                    // Icon / Image preview
                    Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
                            child: Container(
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
                                        child: Image(
                                          image: localImageProvider(_imagePath)!,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Text(_emoji, style: const TextStyle(fontSize: 36)),
                              ),
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

                    // Choose Emoji & Image Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
                          icon: const Icon(Icons.emoji_emotions_outlined, size: 16),
                          label: Text(_showEmojiPicker ? 'Hide Emojis' : 'Choose Emoji', style: const TextStyle(fontSize: 12)),
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

                    if (_showEmojiPicker) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 250,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: EmojiPicker(
                            onEmojiSelected: (_, emoji) {
                              setState(() {
                                _emoji = emoji.emoji;
                                _imagePath = null;
                                _showEmojiPicker = false;
                              });
                            },
                            config: Config(
                              height: 250,
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
                    ],
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
                      dropdownColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                    ),
                    const SizedBox(height: 16),

                    // Card & Account Network Selection (RuPay, Visa, Mastercard, Wallet, Other)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Card / Account Network',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              Text(
                                _cardType,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: CardNetworkType.all.map((type) {
                              final isSelected =
                                  _cardType.toLowerCase() == type.toLowerCase();
                              return InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => setState(() => _cardType = type),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary.withValues(
                                            alpha: isDark ? 0.25 : 0.15)
                                        : (isDark
                                            ? AppColors.darkCardAlt
                                            : AppColors.lightCard),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : (isDark
                                              ? AppColors.darkBorder
                                              : AppColors.lightBorder),
                                      width: isSelected ? 2 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.25),
                                              blurRadius: 6,
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CardNetworkBadge(
                                        cardType: type,
                                        onCard: false,
                                        scale: 0.8,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        type,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? AppColors.primary
                                              : (isDark
                                                  ? Colors.white70
                                                  : AppColors.lightText),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Color theme picker
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Color Theme', style: Theme.of(context).textTheme.bodyMedium),
                        TextButton.icon(
                          onPressed: _pickCustomColor,
                          icon: const Icon(Icons.palette_outlined, size: 16),
                          label: const Text('Custom Color', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ...AppColors.accountColors.map((c) => GestureDetector(
                          onTap: () => setState(() => _color = c),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _color.toARGB32() == c.toARGB32()
                                    ? (isDark ? Colors.white : Colors.black)
                                    : Colors.transparent,
                                width: 2,
                              ),
                              boxShadow: _color.toARGB32() == c.toARGB32()
                                  ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 8)]
                                  : null,
                            ),
                          ),
                        )),
                        // Custom color button
                        GestureDetector(
                          onTap: _pickCustomColor,
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: _color,
                              shape: BoxShape.circle,
                              border: Border.all(color: isDark ? Colors.white70 : Colors.black54, width: 1.5),
                            ),
                            child: const Icon(Icons.colorize_rounded, size: 18, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Include in Net Wallet Balance toggle
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCardAlt : AppColors.lightBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _isEnabledForCalc
                              ? AppColors.primary.withValues(alpha: 0.4)
                              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        ),
                      ),
                      child: SwitchListTile(
                        value: _isEnabledForCalc,
                        onChanged: (val) => setState(() => _isEnabledForCalc = val),
                        activeThumbColor: AppColors.primary,
                        title: const Text(
                          'Include in Total Net Balance',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Text(
                          _isEnabledForCalc
                              ? 'This account balance counts toward Total Net Wallet Balance'
                              : 'Excluded from Total Net Wallet Balance (e.g. credit/loan/archived)',
                          style: TextStyle(
                            fontSize: 11,
                            color: _isEnabledForCalc
                                ? AppColors.primary
                                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          ),
                        ),
                      ),
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
