import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class CustomSticker {
  final String id;
  final String localPath;
  final DateTime createdAt;

  const CustomSticker({
    required this.id,
    required this.localPath,
    required this.createdAt,
  });
}

class VelzaSticker {
  final String id;
  final String name;
  final String category;
  final String emoji;
  final List<Color> gradientColors;
  final IconData? icon;
  final String? localCustomPath;

  const VelzaSticker({
    required this.id,
    required this.name,
    required this.category,
    required this.emoji,
    required this.gradientColors,
    this.icon,
    this.localCustomPath,
  });

  bool get isCustom => localCustomPath != null && localCustomPath!.isNotEmpty;

  String get assetPath => isCustom ? localCustomPath! : 'velza://sticker/$id';
}

typedef StickerModel = VelzaSticker;

class StickerService {
  static const List<VelzaSticker> starterStickers = [
    // Love & Hearts
    VelzaSticker(
      id: 'velza_fire_heart',
      name: 'Heart on Fire',
      category: 'Love',
      emoji: '❤️‍🔥',
      gradientColors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
      icon: Icons.local_fire_department_rounded,
    ),
    VelzaSticker(
      id: 'velza_golden_sparkle',
      name: 'Golden Glow',
      category: 'Love',
      emoji: '💖',
      gradientColors: [Color(0xFFF7971E), Color(0xFFFFD200)],
      icon: Icons.auto_awesome_rounded,
    ),
    VelzaSticker(
      id: 'velza_purple_pulse',
      name: 'Velza Pulse',
      category: 'Love',
      emoji: '💜',
      gradientColors: [Color(0xFF8A2387), Color(0xFFE94057)],
      icon: Icons.favorite_rounded,
    ),

    // Celebration & Vibes
    VelzaSticker(
      id: 'velza_party_popper',
      name: 'Celebration',
      category: 'Vibes',
      emoji: '🎉',
      gradientColors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
      icon: Icons.celebration_rounded,
    ),
    VelzaSticker(
      id: 'velza_moon_rocket',
      name: 'To The Moon',
      category: 'Vibes',
      emoji: '🚀',
      gradientColors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
      icon: Icons.rocket_launch_rounded,
    ),
    VelzaSticker(
      id: 'velza_fire_energy',
      name: 'Lit / Fire',
      category: 'Vibes',
      emoji: '🔥',
      gradientColors: [Color(0xFFF857A6), Color(0xFFFF5858)],
      icon: Icons.whatshot_rounded,
    ),

    // Expressions & Mood
    VelzaSticker(
      id: 'velza_laugh_cry',
      name: 'Tears of Joy',
      category: 'Mood',
      emoji: '😂',
      gradientColors: [Color(0xFFF7971E), Color(0xFFFFD200)],
      icon: Icons.sentiment_very_satisfied_rounded,
    ),
    VelzaSticker(
      id: 'velza_royal_cool',
      name: 'Royal Chill',
      category: 'Mood',
      emoji: '😎',
      gradientColors: [Color(0xFF11998E), Color(0xFF38EF7D)],
      icon: Icons.mood_rounded,
    ),
    VelzaSticker(
      id: 'velza_mind_blown',
      name: 'Mind Blown',
      category: 'Mood',
      emoji: '🤯',
      gradientColors: [Color(0xFFFC5C7D), Color(0xFF6A82FB)],
      icon: Icons.psychology_rounded,
    ),

    // Gestures & Badges
    VelzaSticker(
      id: 'velza_gold_thumbs',
      name: 'Gold Approval',
      category: 'Gestures',
      emoji: '👍',
      gradientColors: [Color(0xFFD4AF37), Color(0xFFFFDF73)],
      icon: Icons.thumb_up_rounded,
    ),
    VelzaSticker(
      id: 'velza_peace_vibe',
      name: 'Peace Out',
      category: 'Gestures',
      emoji: '✌️',
      gradientColors: [Color(0xFF36D1DC), Color(0xFF5B86E5)],
      icon: Icons.pan_tool_rounded,
    ),
    VelzaSticker(
      id: 'velza_warm_hug',
      name: 'Warm Hug',
      category: 'Gestures',
      emoji: '🤗',
      gradientColors: [Color(0xFFFF8008), Color(0xFFFFC837)],
      icon: Icons.volunteer_activism_rounded,
    ),
  ];

  static List<String> get categories => ['All', 'Custom', 'Love', 'Vibes', 'Mood', 'Gestures'];

  static VelzaSticker? findById(String id) {
    try {
      return starterStickers.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  // Load all user created custom stickers from local disk
  static Future<List<VelzaSticker>> loadCustomStickers() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final stickersDir = Directory('${appDir.path}/custom_stickers');
      if (!await stickersDir.exists()) {
        return [];
      }
      final files = stickersDir.listSync();
      final List<VelzaSticker> list = [];
      for (final entity in files) {
        if (entity is File &&
            (entity.path.endsWith('.png') ||
                entity.path.endsWith('.webp') ||
                entity.path.endsWith('.jpg') ||
                entity.path.endsWith('.jpeg'))) {
          final id = entity.uri.pathSegments.last
              .replaceAll('sticker_', '')
              .replaceAll(RegExp(r'\.[a-zA-Z]+$'), '');
          list.add(VelzaSticker(
            id: 'custom_$id',
            name: 'Custom Sticker',
            category: 'Custom',
            emoji: '🎨',
            gradientColors: const [Color(0xFF6A1B9A), Color(0xFFD4AF37)],
            localCustomPath: entity.path,
          ));
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  // Save custom sticker file to disk
  static Future<VelzaSticker> saveCustomSticker(File file) async {
    final appDir = await getApplicationDocumentsDirectory();
    final stickersDir = Directory('${appDir.path}/custom_stickers');
    if (!await stickersDir.exists()) {
      await stickersDir.create(recursive: true);
    }
    final stickerId = const Uuid().v4();
    final targetPath = '${stickersDir.path}/sticker_$stickerId.png';
    final saved = await file.copy(targetPath);
    return VelzaSticker(
      id: 'custom_$stickerId',
      name: 'Custom Sticker',
      category: 'Custom',
      emoji: '🎨',
      gradientColors: const [Color(0xFF6A1B9A), Color(0xFFD4AF37)],
      localCustomPath: saved.path,
    );
  }
}
