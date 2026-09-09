import 'package:flutter/material.dart';

class MoodModel {
  final String emoji;
  final int colorValue; // e.g. 0xFF4CAF50
  final String label;

  const MoodModel({
    required this.emoji,
    required this.colorValue,
    required this.label,
  });

  Color get color => Color(colorValue);

  static const List<MoodModel> presets = [
    MoodModel(emoji: '😊', colorValue: 0xFF4CAF50, label: 'Happy'),
    MoodModel(emoji: '😐', colorValue: 0xFFFFEB3B, label: 'Neutral'),
    MoodModel(emoji: '😡', colorValue: 0xFFF44336, label: 'Angry'),
    MoodModel(emoji: '😴', colorValue: 0xFF2196F3, label: 'Sleepy'),
    MoodModel(emoji: '❤️', colorValue: 0xFF9C27B0, label: 'In Love'),
    MoodModel(emoji: '🔥', colorValue: 0xFFFF9800, label: 'Hyped'),
    MoodModel(emoji: '✨', colorValue: 0xFFD4AF37, label: 'Luxury'),
  ];

  static const List<MoodModel> presetMoods = presets;
}

