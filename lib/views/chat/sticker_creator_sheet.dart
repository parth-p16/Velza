import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:velza/models/sticker_model.dart';

class StickerCreatorSheet extends StatefulWidget {
  final void Function(File stickerFile) onStickerCreated;

  const StickerCreatorSheet({super.key, required this.onStickerCreated});

  static void show(BuildContext context, {required void Function(File stickerFile) onStickerCreated}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E162B)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StickerCreatorSheet(onStickerCreated: onStickerCreated),
    );
  }

  @override
  State<StickerCreatorSheet> createState() => _StickerCreatorSheetState();
}

class _StickerCreatorSheetState extends State<StickerCreatorSheet> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  String _overlayText = '';
  final TextEditingController _textController = TextEditingController();
  double _rotationAngle = 0.0;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _pickFromGallery() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }

  void _saveSticker() async {
    if (_selectedImage == null) return;

    try {
      final savedSticker = await StickerService.saveCustomSticker(_selectedImage!);
      final saved = File(savedSticker.localCustomPath!);

      if (mounted) {
        Navigator.pop(context);
        widget.onStickerCreated(saved);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Custom sticker created and saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving sticker: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        left: 20.0,
        right: 20.0,
        top: 16.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const Row(
              children: [
                Icon(Icons.palette_rounded, color: Color(0xFFD4AF37), size: 24),
                SizedBox(width: 8),
                Text(
                  'Sticker Studio',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Canvas preview area
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF261D35) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5), width: 1.5),
              ),
              child: _selectedImage == null
                  ? Center(
                      child: IconButton(
                        icon: const Icon(Icons.add_photo_alternate_rounded, size: 48, color: Color(0xFFD4AF37)),
                        onPressed: _pickFromGallery,
                        tooltip: 'Choose photo from gallery',
                      ),
                    )
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.rotate(
                          angle: _rotationAngle,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(_selectedImage!, width: 160, height: 160, fit: BoxFit.cover),
                          ),
                        ),
                        if (_overlayText.isNotEmpty)
                          Positioned(
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _overlayText,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),

            if (_selectedImage != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.rotate_90_degrees_ccw_rounded),
                    tooltip: 'Rotate',
                    onPressed: () {
                      setState(() {
                        _rotationAngle += 1.5708; // 90 degrees in radians
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.change_circle_rounded),
                    tooltip: 'Pick different image',
                    onPressed: _pickFromGallery,
                  ),
                ],
              ),
              TextField(
                controller: _textController,
                decoration: InputDecoration(
                  hintText: 'Add text overlay (optional)...',
                  prefixIcon: const Icon(Icons.text_fields_rounded),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF261D35) : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _overlayText = val;
                  });
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A1B9A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _saveSticker,
                  child: const Text('Save & Use Sticker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ] else ...[
              TextButton.icon(
                icon: const Icon(Icons.photo_library_rounded, color: Color(0xFFD4AF37)),
                label: const Text('Choose Photo from Gallery', style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
                onPressed: _pickFromGallery,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
