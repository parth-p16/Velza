import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:velza/services/wallpaper_service.dart';
import 'package:velza/viewmodels/auth_viewmodel.dart';
import 'package:velza/viewmodels/chat_viewmodel.dart';

class WallpaperPickerDialog extends StatefulWidget {
  final String chatId;
  final WallpaperModel currentWallpaper;
  final Function(WallpaperModel) onWallpaperSelected;

  const WallpaperPickerDialog({
    super.key,
    required this.chatId,
    required this.currentWallpaper,
    required this.onWallpaperSelected,
  });

  @override
  State<WallpaperPickerDialog> createState() => _WallpaperPickerDialogState();
}

class _WallpaperPickerDialogState extends State<WallpaperPickerDialog> {
  bool _isUploading = false;

  Future<void> _selectPreset(BuildContext context, WallpaperModel preset) async {
    final currentUid = Provider.of<AuthViewModel>(context, listen: false).currentUserModel?.uid ?? '';
    final chatVM = Provider.of<ChatViewModel>(context, listen: false);

    await chatVM.setPersonalWallpaper(
      uid: currentUid,
      chatId: widget.chatId,
      wallpaper: preset,
    );

    widget.onWallpaperSelected(preset);
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _resetToDefault(BuildContext context) async {
    final defaultPreset = WallpaperService.presets.first;
    final currentUid = Provider.of<AuthViewModel>(context, listen: false).currentUserModel?.uid ?? '';
    final chatVM = Provider.of<ChatViewModel>(context, listen: false);

    await chatVM.setPersonalWallpaper(
      uid: currentUid,
      chatId: widget.chatId,
      wallpaper: defaultPreset,
    );

    widget.onWallpaperSelected(defaultPreset);
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _chooseFromGallery(BuildContext context) async {
    final currentUid = Provider.of<AuthViewModel>(context, listen: false).currentUserModel?.uid ?? '';
    final chatVM = Provider.of<ChatViewModel>(context, listen: false);

    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;

      setState(() {
        _isUploading = true;
      });

      final file = File(picked.path);
      final newModel = await chatVM.savePersonalGalleryWallpaper(
        uid: currentUid,
        chatId: widget.chatId,
        file: file,
      );

      widget.onWallpaperSelected(newModel);
      if (!context.mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not set gallery wallpaper: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Personal Chat Theme',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => _resetToDefault(context),
                  child: const Text('Reset Default', style: TextStyle(color: Color(0xFFD4AF37))),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Personal to you. Your conversation partner keeps their own wallpaper.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 16),

            // Gallery Option Button
            InkWell(
              onTap: _isUploading ? null : () => _chooseFromGallery(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                  color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.photo_library_rounded, color: Color(0xFFD4AF37)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose from Gallery',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Saved locally on your device for fast, private rendering',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    if (_isUploading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4AF37)),
                      )
                    else
                      const Icon(Icons.chevron_right, color: Color(0xFFD4AF37)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              'Velza Luxury Themes (16 Built-in)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFD4AF37)),
            ),
            const SizedBox(height: 12),

            // Presets List
            SizedBox(
              height: 145,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: WallpaperService.presets.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final preset = WallpaperService.presets[index];
                  final isSelected = widget.currentWallpaper.id == preset.id && !widget.currentWallpaper.isRemote && !widget.currentWallpaper.isLocal;

                  return GestureDetector(
                    onTap: () => _selectPreset(context, preset),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: preset.gradientColors ?? [Colors.black, Colors.deepPurple],
                            ),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFD4AF37) : Colors.white24,
                              width: isSelected ? 2.5 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                                      blurRadius: 8,
                                    )
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Center(
                                  child: Icon(Icons.check_circle_rounded, color: Color(0xFFD4AF37)),
                                )
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          preset.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? const Color(0xFFD4AF37) : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
