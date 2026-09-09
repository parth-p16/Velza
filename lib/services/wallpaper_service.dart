import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:velza/models/chat_model.dart';

enum WallpaperType { preset, localImage, remoteUrl }

enum WallpaperPattern { none, stars, geometric, velvet, emerald, nebula }

class WallpaperModel {
  final String id;
  final String name;
  final WallpaperType type;
  final String? localPath;
  final String? remoteUrl;
  final List<Color>? gradientColors;
  final String? patternType;

  const WallpaperModel({
    required this.id,
    required this.name,
    required this.type,
    this.localPath,
    this.remoteUrl,
    this.gradientColors,
    this.patternType,
  });

  bool get isPreset => type == WallpaperType.preset;
  bool get isRemote => type == WallpaperType.remoteUrl;
  bool get isLocal => type == WallpaperType.localImage;
  String? get imagePath => localPath ?? remoteUrl;

  WallpaperPattern get pattern {
    switch (patternType) {
      case 'stars':
        return WallpaperPattern.stars;
      case 'geometry':
        return WallpaperPattern.geometric;
      case 'velvet':
        return WallpaperPattern.velvet;
      case 'emerald':
        return WallpaperPattern.emerald;
      case 'nebula':
        return WallpaperPattern.nebula;
      default:
        return WallpaperPattern.none;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'localPath': localPath,
        'remoteUrl': remoteUrl,
        'patternType': patternType,
      };
}

typedef ChatWallpaper = WallpaperModel;

class WallpaperService {
  static final WallpaperService _instance = WallpaperService._internal();
  factory WallpaperService() => _instance;
  WallpaperService._internal();

  static const String _prefPrefix = 'velza_wallpaper_chat_';
  final Map<String, WallpaperModel> _cache = {};

  Future<void> init() async {
    await SharedPreferences.getInstance();
  }

  // 16 Built-in Velza Luxury Themes
  static const List<WallpaperModel> presets = [
    WallpaperModel(
      id: 'velza_default',
      name: 'Midnight',
      type: WallpaperType.preset,
      gradientColors: [Color(0xFF0E0B16), Color(0xFF1E162B)],
      patternType: 'default',
    ),
    WallpaperModel(
      id: 'amoled_black',
      name: 'AMOLED',
      type: WallpaperType.preset,
      gradientColors: [Color(0xFF000000), Color(0xFF050505), Color(0xFF080808)],
      patternType: 'none',
    ),
    WallpaperModel(
      id: 'ocean_breeze',
      name: 'Ocean',
      type: WallpaperType.preset,
      gradientColors: [Color(0xFF0B192C), Color(0xFF1E3E62), Color(0xFF050C16)],
      patternType: 'emerald',
    ),
    WallpaperModel(
      id: 'sunset_glow',
      name: 'Sunset',
      type: WallpaperType.preset,
      gradientColors: [Color(0xFF2C061F), Color(0xFF371B58), Color(0xFF180315)],
      patternType: 'velvet',
    ),
    WallpaperModel(
      id: 'lavender_dream',
      name: 'Lavender',
      type: WallpaperType.preset,
      gradientColors: [Color(0xFF231942), Color(0xFF5E548E), Color(0xFF1B1333)],
      patternType: 'velvet',
    ),
    WallpaperModel(
      id: 'rose_gold',
      name: 'Rose',
      type: WallpaperType.preset,
      gradientColors: [Color(0xFF2B0927), Color(0xFF4A1942), Color(0xFF170415)],
      patternType: 'geometry',
    ),
    WallpaperModel(
      id: 'forest_emerald',
      name: 'Forest',
      type: WallpaperType.preset,
      gradientColors: [Color(0xFF061A1C), Color(0xFF0F2B26), Color(0xFF051110)],
      patternType: 'emerald',
    ),
    WallpaperModel(
      id: 'neon_cyber',
      name: 'Neon',
      type: WallpaperType.preset,
      gradientColors: [Color(0xFF0D0221), Color(0xFF0F084B), Color(0xFF26408B)],
      patternType: 'stars',
    ),
    WallpaperModel(
      id: 'aurora_borealis',
      name: 'Aurora',
      type: WallpaperType.preset,
      gradientColors: [Color(0xFF051923), Color(0xFF003554), Color(0xFF006466)],
      patternType: 'nebula',
    ),
    WallpaperModel(
      id: 'galaxy_nebula',
      name: 'Galaxy',
      type: WallpaperType.preset,
      gradientColors: [Color(0xFF1A0A2A), Color(0xFF2C1342), Color(0xFF0F041B)],
      patternType: 'nebula',
    ),
    WallpaperModel(
      id: 'luxury_royal',
      name: 'Luxury',
      type: WallpaperType.preset,
      gradientColors: [Color(0xFF121016), Color(0xFF2B1F3D), Color(0xFF1D162B)],
      patternType: 'geometry',
    ),
    WallpaperModel(
      id: 'minimal_slate',
      name: 'Minimal',
      type: WallpaperType.preset,
      gradientColors: [Color(0xFF1E2022), Color(0xFF232528), Color(0xFF121314)],
      patternType: 'none',
    ),
    WallpaperModel(
      id: 'glass_frost',
      name: 'Glass',
      type: WallpaperType.preset,
      gradientColors: [Color(0xFF141E30), Color(0xFF243B55), Color(0xFF0D1322)],
      patternType: 'default',
    ),
    WallpaperModel(
      id: 'classic_charcoal',
      name: 'Classic',
      type: WallpaperType.preset,
      gradientColors: [Color(0xFF1A1A1A), Color(0xFF2D2D2D), Color(0xFF141414)],
      patternType: 'none',
    ),
    WallpaperModel(
      id: 'vintage_paper',
      name: 'Paper',
      type: WallpaperType.preset,
      gradientColors: [Color(0xFF1F1D1A), Color(0xFF2B2823), Color(0xFF191815)],
      patternType: 'velvet',
    ),
    WallpaperModel(
      id: 'retro_synthwave',
      name: 'Retro',
      type: WallpaperType.preset,
      gradientColors: [Color(0xFF1F0322), Color(0xFF380835), Color(0xFF160118)],
      patternType: 'stars',
    ),
  ];

  List<WallpaperModel> get allPresets => presets;

  static WallpaperModel getPresetById(String id) {
    return presets.firstWhere((p) => p.id == id, orElse: () => presets.first);
  }

  // --- Personal Wallpaper Storage & Resolution ---

  WallpaperModel getPersonalWallpaper(String uid, String chatId) {
    final key = '${uid}_$chatId';
    if (_cache.containsKey(key)) return _cache[key]!;
    if (_cache.containsKey(chatId)) return _cache[chatId]!;
    return presets.first;
  }

  Future<WallpaperModel> loadPersonalWallpaper(String uid, String chatId) async {
    final key = '${uid}_$chatId';
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('velza_personal_${uid}_${chatId}_id');
    final typeName = prefs.getString('velza_personal_${uid}_${chatId}_type');
    final localPath = prefs.getString('velza_personal_${uid}_${chatId}_path');
    final remoteUrl = prefs.getString('velza_personal_${uid}_${chatId}_url');

    if (id != null) {
      if (typeName == WallpaperType.localImage.name && localPath != null) {
        final file = File(localPath);
        if (await file.exists()) {
          final model = WallpaperModel(
            id: id,
            name: 'Gallery Wallpaper',
            type: WallpaperType.localImage,
            localPath: localPath,
          );
          _cache[key] = model;
          return model;
        }
      } else if (typeName == WallpaperType.remoteUrl.name && remoteUrl != null) {
        final model = WallpaperModel(
          id: id,
          name: 'Custom Wallpaper',
          type: WallpaperType.remoteUrl,
          remoteUrl: remoteUrl,
        );
        _cache[key] = model;
        return model;
      } else {
        final preset = presets.firstWhere((p) => p.id == id, orElse: () => presets.first);
        _cache[key] = preset;
        return preset;
      }
    }

    final fallback = presets.first;
    _cache[key] = fallback;
    return fallback;
  }

  Future<void> setPersonalWallpaper({
    required String uid,
    required String chatId,
    required WallpaperModel wallpaper,
  }) async {
    final key = '${uid}_$chatId';
    _cache[key] = wallpaper;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('velza_personal_${uid}_${chatId}_id', wallpaper.id);
    await prefs.setString('velza_personal_${uid}_${chatId}_type', wallpaper.type.name);
    if (wallpaper.localPath != null) {
      await prefs.setString('velza_personal_${uid}_${chatId}_path', wallpaper.localPath!);
    } else {
      await prefs.remove('velza_personal_${uid}_${chatId}_path');
    }
    if (wallpaper.remoteUrl != null) {
      await prefs.setString('velza_personal_${uid}_${chatId}_url', wallpaper.remoteUrl!);
    } else {
      await prefs.remove('velza_personal_${uid}_${chatId}_url');
    }
  }

  // Save personal gallery photo locally on user's device
  Future<WallpaperModel> savePersonalGalleryWallpaper({
    required String uid,
    required String chatId,
    required File sourceFile,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final wallpaperDir = Directory('${appDir.path}/wallpapers');
    if (!await wallpaperDir.exists()) {
      await wallpaperDir.create(recursive: true);
    }
    final targetPath = '${wallpaperDir.path}/personal_${uid}_$chatId.jpg';
    final savedFile = await sourceFile.copy(targetPath);

    final model = WallpaperModel(
      id: 'gallery_local',
      name: 'Gallery Wallpaper',
      type: WallpaperType.localImage,
      localPath: savedFile.path,
    );
    await setPersonalWallpaper(uid: uid, chatId: chatId, wallpaper: model);
    return model;
  }

  // Synchronous cache lookup fallback
  WallpaperModel getChatWallpaperSync(String chatId) {
    return _cache[chatId] ?? presets.first;
  }

  Future<void> setChatWallpaper(String chatId, WallpaperModel wallpaper) async {
    _cache[chatId] = wallpaper;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefPrefix${chatId}_id', wallpaper.id);
    await prefs.setString('$_prefPrefix${chatId}_type', wallpaper.type.name);
    if (wallpaper.localPath != null) {
      await prefs.setString('$_prefPrefix${chatId}_path', wallpaper.localPath!);
    } else {
      await prefs.remove('$_prefPrefix${chatId}_path');
    }
  }

  Future<void> setPresetWallpaper(String chatId, String presetId) async {
    final preset = presets.firstWhere((p) => p.id == presetId, orElse: () => presets.first);
    await setChatWallpaper(chatId, preset);
  }

  Future<void> setCustomImageWallpaper(String chatId, String filePath) async {
    final custom = WallpaperModel(
      id: 'custom_local',
      name: 'Custom Image',
      type: WallpaperType.localImage,
      localPath: filePath,
    );
    await setChatWallpaper(chatId, custom);
  }

  Future<void> resetToDefault(String chatId) async {
    await resetChatWallpaper(chatId);
  }

  Future<void> resetChatWallpaper(String chatId) async {
    _cache.remove(chatId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefPrefix${chatId}_id');
    await prefs.remove('$_prefPrefix${chatId}_type');
    await prefs.remove('$_prefPrefix${chatId}_path');
  }

  WallpaperModel getWallpaperFromChat(ChatModel chat) {
    if (chat.wallpaperType == 'gallery' && chat.wallpaperUrl.isNotEmpty) {
      return WallpaperModel(
        id: 'gallery_shared',
        name: 'Gallery Wallpaper',
        type: WallpaperType.remoteUrl,
        remoteUrl: chat.wallpaperUrl,
      );
    }
    return presets.firstWhere(
      (p) => p.id == chat.wallpaperId,
      orElse: () => presets.first,
    );
  }
}
