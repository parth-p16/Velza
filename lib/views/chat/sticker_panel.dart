import 'dart:io';
import 'package:flutter/material.dart';
import 'package:velza/models/sticker_model.dart';
import 'package:velza/views/chat/sticker_creator_sheet.dart';

class StickerPanel extends StatefulWidget {
  final ValueChanged<VelzaSticker> onSelectSticker;

  const StickerPanel({super.key, required this.onSelectSticker});

  static Future<void> show({
    required BuildContext context,
    required ValueChanged<VelzaSticker> onSelectSticker,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E162B)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.52,
        child: StickerPanel(
          onSelectSticker: (sticker) {
            Navigator.pop(ctx);
            onSelectSticker(sticker);
          },
        ),
      ),
    );
  }

  @override
  State<StickerPanel> createState() => _StickerPanelState();
}

class _StickerPanelState extends State<StickerPanel> {
  String _selectedCategory = 'All';
  List<VelzaSticker> _customStickers = [];
  bool _isLoadingCustom = true;

  @override
  void initState() {
    super.initState();
    _loadCustomStickers();
  }

  Future<void> _loadCustomStickers() async {
    try {
      final custom = await StickerService.loadCustomStickers();
      if (mounted) {
        setState(() {
          _customStickers = custom;
          _isLoadingCustom = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingCustom = false);
      }
    }
  }

  void _openStickerStudio() {
    StickerCreatorSheet.show(
      context,
      onStickerCreated: (file) async {
        await _loadCustomStickers();
        if (mounted) {
          setState(() {
            _selectedCategory = 'Custom';
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final allStickers = [..._customStickers, ...StickerService.starterStickers];
    final List<VelzaSticker> displayedStickers;
    if (_selectedCategory == 'All') {
      displayedStickers = allStickers;
    } else if (_selectedCategory == 'Custom') {
      displayedStickers = _customStickers;
    } else {
      displayedStickers = StickerService.starterStickers
          .where((s) => s.category == _selectedCategory)
          .toList();
    }

    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Title and Create Sticker action
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            children: [
              const Text(
                'Velza Stickers',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.add_photo_alternate_rounded, size: 16, color: Color(0xFFD4AF37)),
                label: const Text(
                  '+ Create',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37)),
                ),
                onPressed: _openStickerStudio,
              ),
            ],
          ),
        ),

        // Category filter
        SizedBox(
          height: 38,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            scrollDirection: Axis.horizontal,
            itemCount: StickerService.categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = StickerService.categories[index];
              final isSelected = cat == _selectedCategory;
              return ChoiceChip(
                label: Text(
                  cat == 'Custom' ? '🎨 Custom (${_customStickers.length})' : cat,
                ),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.black87 : (isDark ? Colors.white70 : Colors.black87),
                ),
                selected: isSelected,
                selectedColor: const Color(0xFFD4AF37),
                backgroundColor: isDark ? const Color(0xFF2C223D) : Colors.grey.shade100,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (selected) {
                  if (selected) setState(() => _selectedCategory = cat);
                },
              );
            },
          ),
        ),

        const Divider(height: 12),

        // Stickers Grid
        Expanded(
          child: _isLoadingCustom
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
              : (displayedStickers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.palette_outlined, size: 48, color: isDark ? Colors.white24 : Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            _selectedCategory == 'Custom'
                                ? 'No custom stickers yet'
                                : 'No stickers in this category',
                            style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                          ),
                          if (_selectedCategory == 'Custom') ...[
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6A1B9A),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Create First Sticker'),
                              onPressed: _openStickerStudio,
                            ),
                          ],
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.95,
                      ),
                      itemCount: displayedStickers.length,
                      itemBuilder: (context, index) {
                        final sticker = displayedStickers[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => widget.onSelectSticker(sticker),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: sticker.gradientColors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: sticker.gradientColors.first.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: sticker.isCustom && sticker.localCustomPath != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.file(
                                      File(sticker.localCustomPath!),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Center(
                                        child: Icon(Icons.broken_image_rounded, color: Colors.white70),
                                      ),
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        sticker.emoji,
                                        style: const TextStyle(fontSize: 32),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        sticker.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          shadows: [
                                            Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    )),
        ),
      ],
    );
  }
}
