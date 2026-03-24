import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../models/attendance_record.dart';
import 'subject_detail_screen.dart';

import '../models/timetable_entry.dart';
import 'dart:async';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Rebuild every minute to keep ongoing lecture live
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (appState.currentSession == null) {
      return const Center(child: Text('No active session.'));
    }
    if (appState.subjects.isEmpty) {
      return const Center(
          child: Text('No subjects yet. Add them in the Schedule tab.'));
    }

    // Build stats
    int totalClasses = 0, totalAttended = 0;

    // ModId -> {total: int, attended: int}
    final Map<int, Map<String, int>> globalModifierStats = {
      for (var m in appState.modifiers) m.id!: {'total': 0, 'attended': 0},
      -1: {'total': 0, 'attended': 0}, // -1 represents 'None'
    };

    final Map<int, Map<String, dynamic>> subjectStats = {
      for (var s in appState.subjects)
        s.id!: {
          'total': 0,
          'attended': 0,
          'modifiers': <int, Map<String, int>>{
            for (var m in appState.modifiers)
              m.id!: {'total': 0, 'attended': 0},
            -1: {'total': 0, 'attended': 0},
          },
        },
    };

    // Collect holiday dates so we can exclude them from totals
    final Set<String> holidayDates = {};
    for (var record in appState.attendanceRecords) {
      if (record.status == AttendanceStatus.holiday) {
        holidayDates.add(record.date.toIso8601String().split('T')[0]);
      }
    }

    final startDate = appState.currentSession!.startDate;
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    DateTime d = startDate;

    int safetyCounter = 0;
    while (!d.isAfter(todayOnly) && safetyCounter < 3000) {
      safetyCounter++;
      final dateStr = d.toIso8601String().split('T')[0];
      
      if (holidayDates.contains(dateStr)) {
        d = d.add(const Duration(days: 1));
        continue;
      }

      final dayOfWeek = d.weekday;
      for (var entry in appState.timetableEntries) {
        if (entry.dayOfWeek == dayOfWeek && !entry.isBreak) {
          if (entry.subjectId == null) continue;
          if (!subjectStats.containsKey(entry.subjectId)) continue; // in case subject was deleted

          final status = appState.getDisplayStatus(entry, d);
          
          if (status == AttendanceStatus.holiday ||
              status == AttendanceStatus.cancelled ||
              status == AttendanceStatus.empty) {
            continue;
          }

          final modId = entry.modifierId ?? -1;

          totalClasses++;
          subjectStats[entry.subjectId!]!['total'] =
              (subjectStats[entry.subjectId!]!['total'] as int) + 1;

          if (globalModifierStats.containsKey(modId)) {
            globalModifierStats[modId]!['total'] =
                globalModifierStats[modId]!['total']! + 1;
            (subjectStats[entry.subjectId!]!['modifiers'] as Map<int, Map<String, int>>)[modId]!['total'] =
                (subjectStats[entry.subjectId!]!['modifiers'] as Map<int, Map<String, int>>)[modId]!['total']! + 1;
          }

          if (status == AttendanceStatus.attended) {
            totalAttended++;
            subjectStats[entry.subjectId!]!['attended'] =
                (subjectStats[entry.subjectId!]!['attended'] as int) + 1;
                
            if (globalModifierStats.containsKey(modId)) {
              globalModifierStats[modId]!['attended'] =
                  globalModifierStats[modId]!['attended']! + 1;
              (subjectStats[entry.subjectId!]!['modifiers'] as Map<int, Map<String, int>>)[modId]!['attended'] =
                  (subjectStats[entry.subjectId!]!['modifiers'] as Map<int, Map<String, int>>)[modId]!['attended']! + 1;
            }
          }
        }
      }
      d = d.add(const Duration(days: 1));
    }

    final overallPct =
        totalClasses == 0 ? 0.0 : (totalAttended / totalClasses) * 100;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dashboard Header (Date & Preset shortcut)
            Row(
              children: [
                Builder(
                  builder: (context) => IconButton(
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    icon: const Icon(Icons.menu),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE').format(DateTime.now()),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        DateFormat('MMMM d, yyyy').format(DateTime.now()),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Builder(builder: (context) {
              final now = DateTime.now();
              final todayOnly = DateTime(now.year, now.month, now.day);
              final todayStr = todayOnly.toIso8601String().split('T')[0];

              // Holiday Check
              final isHoliday = appState.attendanceRecords.any((r) =>
                  r.status == AttendanceStatus.holiday &&
                  r.date.toIso8601String().split('T')[0] == todayStr);

              if (isHoliday) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 24),
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide.none),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.celebration,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Today is marked as a holiday. No ongoing lectures.',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final dayOfWeek = now.weekday;
              final currentMins = now.hour * 60 + now.minute;

              TimetableEntry? ongoingEntry;
              for (var entry in appState.timetableEntries) {
                if (entry.dayOfWeek == dayOfWeek && !entry.isBreak) {
                  int startMins =
                      entry.startTime.hour * 60 + entry.startTime.minute;
                  int endMins = entry.endTime.hour * 60 + entry.endTime.minute;
                  if (currentMins >= startMins && currentMins <= endMins) {
                    ongoingEntry = entry;
                    break;
                  }
                }
              }

              if (ongoingEntry == null || ongoingEntry.subjectId == null) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 24),
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide.none),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.event_available,
                            color:
                                Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        Text('No classes happening right now',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              }

              final sub = appState.subjects
                  .where((s) => s.id == ongoingEntry!.subjectId)
                  .firstOrNull;
              if (sub == null) return const SizedBox.shrink();

              final existingRecord = appState.attendanceRecords
                  .where((r) =>
                      r.timetableEntryId == ongoingEntry!.id &&
                      r.date.toIso8601String().split('T')[0] == todayStr)
                  .firstOrNull;

              final status = existingRecord?.status ?? AttendanceStatus.empty;
              final isAttended = status == AttendanceStatus.attended;
              final isMissed = status == AttendanceStatus.missed;
              final isCancelled = status == AttendanceStatus.cancelled;

              final subjectColor = sub.colorHex != null
                  ? Color(int.parse(sub.colorHex!.replaceFirst('#', '0xFF')))
                  : Theme.of(context).colorScheme.primary;

              return Card(
                margin: const EdgeInsets.only(bottom: 24),
                color: subjectColor.withOpacity(0.12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide.none),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                              isAttended
                                  ? Icons.check_circle
                                  : Icons.play_circle_fill,
                              color: isAttended
                                  ? Colors.grey
                                  : Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text('Ongoing Lecture',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                      color: isAttended
                                          ? Colors.grey
                                          : Theme.of(context)
                                              .colorScheme
                                              .primary,
                                      fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(sub.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                          '${ongoingEntry.startTime.format(context)} – ${ongoingEntry.endTime.format(context)}',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(
                                  child: Text('Attended',
                                      style: TextStyle(fontSize: 12))),
                              selected: isAttended,
                              selectedColor: Colors.green.shade100,
                              onSelected: (_) async {
                                await appState.markAttendance(
                                    todayOnly,
                                    ongoingEntry!.id!,
                                    isAttended
                                        ? AttendanceStatus.empty
                                        : AttendanceStatus.attended);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(
                                  child: Text('Missed',
                                      style: TextStyle(fontSize: 12))),
                              selected: isMissed,
                              selectedColor: Colors.red.shade100,
                              onSelected: (_) async {
                                await appState.markAttendance(
                                    todayOnly,
                                    ongoingEntry!.id!,
                                    isMissed
                                        ? AttendanceStatus.empty
                                        : AttendanceStatus.missed);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(
                                  child: Text('Cancelled',
                                      style: TextStyle(fontSize: 12))),
                              selected: isCancelled,
                              selectedColor: Colors.grey.shade300,
                              onSelected: (_) async {
                                await appState.markAttendance(
                                    todayOnly,
                                    ongoingEntry!.id!,
                                    isCancelled
                                        ? AttendanceStatus.empty
                                        : AttendanceStatus.cancelled);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),

            // Overall card with expand/collapse
            _buildOverallCard(
                context,
                totalClasses,
                totalAttended,
                globalModifierStats,
                overallPct,
                appState.minAttendancePercentage,
                appState),
            const SizedBox(height: 24),
            Text('Subject-wise Attendance',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            // Animated subject list
            ...List.generate(appState.subjects.length, (i) {
              final subject = appState.subjects[i];
              final stats = subjectStats[subject.id!]!;
              final subTotal = stats['total']!;
              final subAttended = stats['attended']!;
              final subPct =
                  subTotal == 0 ? 0.0 : (subAttended / subTotal) * 100;

              Color barColor =
                  _colorForPct(subPct, appState.minAttendancePercentage);
              if (subject.colorHex != null) {
                barColor = Color(
                    int.parse(subject.colorHex!.replaceFirst('#', '0xFF')));
              }

              return TweenAnimationBuilder<double>(
                key: ValueKey(subject.id),
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 1200 + i * 100),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  final currentSubAttended = (subAttended * value).toInt();
                  final currentSubTotal = (subTotal * value).toInt();
                  final currentSubPct = subPct * value;

                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SubjectDetailScreen(
                              subject: subject,
                              stats: stats,
                            ),
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: barColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).brightness == Brightness.dark 
                                    ? barColor.withOpacity(0.15) 
                                    : Colors.black.withOpacity(0.04),
                                blurRadius: 4,
                                spreadRadius: Theme.of(context).brightness == Brightness.dark ? 1 : 0,
                                offset: Theme.of(context).brightness == Brightness.dark ? Offset.zero : const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(subject.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      if (subject.subjectCode?.isNotEmpty == true ||
                                          subject.professor?.isNotEmpty == true) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          [
                                            if (subject.subjectCode?.isNotEmpty ==
                                                true)
                                              subject.subjectCode!,
                                            if (subject.professor?.isNotEmpty == true)
                                              subject.professor!,
                                          ].join(' • '),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(fontStyle: FontStyle.italic),
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      LinearProgressIndicator(
                                        value: currentSubPct / 100,
                                        color: barColor,
                                        backgroundColor: barColor.withOpacity(0.2),
                                        minHeight: 6,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$currentSubAttended / $currentSubTotal  •  ${currentSubPct.toStringAsFixed(1)}%',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Row(
                                  children: [
                                    Text(
                                      '${currentSubPct.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: _colorForPct(
                                            currentSubPct, appState.minAttendancePercentage),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.chevron_right,
                                        size: 18, color: Colors.grey),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _colorForPct(double pct, double threshold) {
    if (pct >= threshold) return Colors.green;
    return Colors.red;
  }

  Widget _buildOverallCard(
      BuildContext context,
      int total,
      int attended,
      Map<int, Map<String, int>> globalModifierStats,
      double pct,
      double threshold,
      AppState appState) {
    final color = _colorForPct(pct, threshold);

    // Identify top two modifiers by total occurrences
    final sortedModifiers = globalModifierStats.entries.toList()
      ..sort((a, b) => b.value['total']!.compareTo(a.value['total']!));
    final top2 = sortedModifiers.where((e) => e.value['total']! > 0 && e.key != -1).take(2).toList();

    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => OverallDetailScreen(
                      totalClasses: total,
                      totalAttended: attended,
                      globalModifierStats: globalModifierStats,
                    )));
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, animValue, _) {
              final currentTotal = (total * animValue).toInt();
              final currentAttended = (attended * animValue).toInt();
              final currentPct = pct * animValue;

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Overall Attendance',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              '$currentAttended / $currentTotal classes',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 80,
                        width: 80,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: currentPct / 100,
                              strokeWidth: 8,
                              color: color,
                              backgroundColor: color.withOpacity(0.2),
                            ),
                            Center(
                              child: Text(
                                '${currentPct.toStringAsFixed(1)}%',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (top2.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    // Top modifiers summary row
                    Row(
                      children: top2.map((mEntry) {
                        final modId = mEntry.key;
                        final modName = modId == -1 
                            ? 'None' 
                            : appState.modifiers.where((m) => m.id == modId).firstOrNull?.name ?? 'Unknown';
                        final modColorHex = modId != -1 
                            ? appState.modifiers.where((m) => m.id == modId).firstOrNull?.colorHex 
                            : null;
                        final modColor = modColorHex != null
                            ? Color(int.parse(modColorHex.replaceFirst('#', '0xFF')))
                            : Colors.blueGrey;

                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                                right: mEntry.key == top2.last.key ? 0 : 8.0),
                            child: _miniStatChip(context, modName,
                                mEntry.value['attended']!, mEntry.value['total']!, modColor, animValue),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Details arrow
                  const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _miniStatChip(BuildContext context, String label, int attended,
      int total, Color color, double animValue) {
    final currentAttended = (attended * animValue).toInt();
    final currentTotal = (total * animValue).toInt();
    final pct = total == 0 ? 0.0 : ((attended / total) * 100) * animValue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text('$currentAttended/$currentTotal (${pct.toStringAsFixed(0)}%)',
              style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
