import 'package:flutter/material.dart';

/// Centralized color definitions for easy editing.
class AppColors {
  // ── Attendance Status Colors ──────────────────────────────
  static const Color attended = Color(0xFF4CAF50); // Green
  static const Color attendedLight = Color(0xFFC8E6C9); // Light green chip bg
  static const Color missed = Color(0xFFF44336); // Red
  static const Color missedLight = Color(0xFFFFCDD2); // Light red chip bg
  static const Color cancelled = Color(0xFFFF9800); // Orange
  static const Color cancelledLight = Color(0xFFFFE0B2); // Light orange chip bg
  static const Color holiday = Color(0xFF9E9E9E); // Grey

  // ── Calendar Dot Colors ───────────────────────────────────
  static const Color calendarAllAttended = Color(0xFF4CAF50); // Green
  static const Color calendarPartial = Color(0xFFFFC107); // Amber
  static const Color calendarAllMissed = Color(0xFFF44336); // Red
  static const Color calendarHoliday = Color(0xFF9E9E9E); // Grey

  // ── Statistics / Thresholds ───────────────────────────────
  static const Color statGood = Color(0xFF4CAF50); // Green (above target)
  static const Color statBad = Color(0xFFF44336); // Red (below target)

  // ── Subject Default Color Palette ─────────────────────────
  static const List<String> subjectColorPalette = [
    '#FFCDD2',
    '#F8BBD0',
    '#E1BEE7',
    '#D1C4E9',
    '#C5CAE9',
    '#BBDEFB',
    '#B3E5FC',
    '#B2EBF2',
    '#B2DFDB',
    '#C8E6C9',
    '#DCEDC8',
    '#FFF9C4',
  ];

  // ── Session Status Colors ─────────────────────────────────
  static const Color sessionActive = Color(0xFF4CAF50);
  static const Color sessionEnded = Color(0xFF9E9E9E);

  // ── Misc UI ───────────────────────────────────────────────
  static const Color labChipColor = Color(0xFF9C27B0); // Purple
  static const Color theoryChipColor = Color(0xFF2196F3); // Blue
}
