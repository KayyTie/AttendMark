import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../models/attendance_record.dart';
import '../models/timetable_entry.dart';
import '../models/subject.dart';
import '../models/preset.dart';
import '../repositories/attendance_repository.dart';
import 'statistics_screen.dart';
import 'schedule_screen.dart';
import 'preset_manager_screen.dart';
import '../widgets/app_drawer.dart';

class MainHome extends StatefulWidget {
  const MainHome({super.key});

  @override
  State<MainHome> createState() => _MainHomeState();
}

class _MainHomeState extends State<MainHome> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    final List<Widget> pages = [
      const StatisticsScreen(),
      _buildCalendarPage(appState),
      ScheduleScreen(onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer()),
    ];

    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(
        currentIndex: _currentIndex,
        onTabSelected: (idx) {
          Navigator.pop(context);
          setState(() => _currentIndex = idx);
        },
      ),
      appBar: null,
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.schedule), label: 'Schedule'),
        ],
      ),
    );
  }

  Widget _buildCalendarPage(AppState appState) {
    final firstDay =
        appState.currentSession?.startDate ?? DateTime.utc(2020, 1, 1);
    // Clamp focusedDay so it's never before firstDay (prevents assertion error)
    DateTime safeFocusedDay = _focusedDay;
    if (safeFocusedDay.isBefore(firstDay)) {
      safeFocusedDay = firstDay;
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: firstDay,
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: safeFocusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            availableCalendarFormats: const {
              CalendarFormat.month: 'Month',
              CalendarFormat.week: 'Week'
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onHeaderTapped: (_) {
              setState(() {
                _calendarFormat = _calendarFormat == CalendarFormat.month
                    ? CalendarFormat.week
                    : CalendarFormat.month;
              });
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              setState(() => _focusedDay = focusedDay);
            },
            eventLoader: (day) {
              final status = appState.getDayStatus(day);
              return status == null ? [] : [status];
            },
            calendarBuilders: CalendarBuilders(
              // Replace dot markers with thin border around the date cell
              defaultBuilder: (context, day, focusedDay) {
                return _buildDateCell(context, day, appState, false, false);
              },
              todayBuilder: (context, day, focusedDay) {
                return _buildDateCell(context, day, appState, true, false);
              },
              selectedBuilder: (context, day, focusedDay) {
                return _buildDateCell(context, day, appState, false, true);
              },
              markerBuilder: (context, day, events) => const SizedBox.shrink(),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              headerPadding: EdgeInsets.symmetric(vertical: 4.0),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _DailyDetailPanel(
              key: ValueKey(_selectedDay),
              date: _selectedDay,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCell(BuildContext context, DateTime day, AppState appState,
      bool isToday, bool isSelected) {
    final status = appState.getDayStatus(day);
    Color? statusColor;
    if (status != null) {
      switch (status) {
        case 0:
          statusColor = Colors.green;
          break;
        case 1:
          statusColor = Colors.amber;
          break;
        case 2:
          statusColor = Colors.red;
          break;
        case 3:
          statusColor = Colors.grey;
          break;
      }
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Brighter background in dark mode, no glow
    final bgColor = isSelected
        ? Theme.of(context).colorScheme.primary
        : isToday
            ? Theme.of(context).colorScheme.primaryContainer
            : statusColor?.withOpacity(0.80);

    // Auto-contrast: use black text on light backgrounds, white on dark
    Color? textColor;
    if (isSelected) {
      textColor = Theme.of(context).colorScheme.onPrimary;
    } else if (isToday) {
      textColor = Theme.of(context).colorScheme.onPrimaryContainer;
    } else if (statusColor != null) {
      // Determine luminance of the actual rendered background
      final effective = statusColor.withOpacity(isDarkMode ? 0.55 : 0.30);
      // On a dark canvas the blended color is darker, on light it's lighter
      // Simple heuristic: in dark mode colored cells are dark → white text;
      //                   in light mode colored cells are light → black text
      textColor = isDarkMode ? Colors.white : Colors.black87;
    }

    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: textColor,
          fontWeight: isToday || isSelected ? FontWeight.bold : null,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// INLINE DAILY DETAIL PANEL
// ─────────────────────────────────────────────────

class _DailyDetailPanel extends StatefulWidget {
  final DateTime date;
  const _DailyDetailPanel({super.key, required this.date});

  @override
  State<_DailyDetailPanel> createState() => _DailyDetailPanelState();
}

class _DailyDetailPanelState extends State<_DailyDetailPanel> {
  final AttendanceRepository _attendanceRepo = AttendanceRepository();
  bool _isLoading = true;

  List<TimetableEntry> _dayEntries = [];

  @override
  void initState() {
    super.initState();
    _loadDailyData();
  }

  Future<void> _loadDailyData() async {
    final appState = context.read<AppState>();
    if (appState.currentSession == null) {
      setState(() => _isLoading = false);
      return;
    }

    final dayOfWeek = widget.date.weekday;
    _dayEntries = appState.timetableEntries
        .where((e) => e.dayOfWeek == dayOfWeek)
        .toList()
      ..sort((a, b) {
        final aMin = a.startTime.hour * 60 + a.startTime.minute;
        final bMin = b.startTime.hour * 60 + b.startTime.minute;
        return aMin.compareTo(bMin);
      });

    // holiday state is derived live from appState in build()
    setState(() => _isLoading = false);
  }

  // Chips delegate to AppState which handles create/update/delete
  Future<void> _markAttendance(
      int? timetableEntryId, AttendanceStatus status) async {
    final appState = context.read<AppState>();
    await appState.markAttendance(widget.date, timetableEntryId, status);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _toggleHoliday(bool val) async {
    final appState = context.read<AppState>();
    final sessionId = appState.currentSession!.id!;

    if (val) {
      await _markAttendance(null, AttendanceStatus.holiday);
    } else {
      await _attendanceRepo.deleteHolidayForDate(sessionId, widget.date);
      await appState.loadSessionData(sessionId);
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> _applyPreset(AppState appState, Preset preset) async {
    await appState.applyPreset(widget.date, preset);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _applyQuickPreset(
      AppState appState, AttendanceStatus status) async {
    final dayOfWeek = widget.date.weekday;
    final lectures = appState.timetableEntries
        .where((e) => e.dayOfWeek == dayOfWeek && !e.isBreak)
        .toList();
    for (final entry in lectures) {
      await appState.markAttendance(widget.date, entry.id, status);
    }
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final appState = context.watch<AppState>();
    final dateLabel = DateFormat('EEEE, MMMM d').format(widget.date);
    final isToday = isSameDay(widget.date, DateTime.now());
    final hasLectures = _dayEntries.any((e) => !e.isBreak);

    // Re-derive isHoliday from live app state
    final liveRecords = appState.getEffectiveRecordsForDate(widget.date);
    final isHoliday =
        liveRecords.any((r) => r.status == AttendanceStatus.holiday);

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isToday ? 'Today — $dateLabel' : dateLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              if (appState.currentSession != null && hasLectures)
                IconButton(
                  icon: const Icon(Icons.flash_on),
                  tooltip: 'Apply Preset',
                  onPressed: () => _showPresetsSheet(appState),
                ),
            ],
          ),
        ),

        // Holiday toggle
        if (appState.currentSession != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.beach_access, size: 18),
                const SizedBox(width: 8),
                const Text('Mark as Holiday'),
                const Spacer(),
                Switch(
                  value: isHoliday,
                  onChanged: _toggleHoliday,
                ),
              ],
            ),
          ),

        const Divider(height: 1),

        if (appState.currentSession == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
                child: Text('No active session. Start one in Sessions.')),
          )
        else if (_dayEntries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No classes scheduled for this day.')),
          )
        else
          ..._dayEntries.map((entry) {
            if (entry.isBreak) {
              return ListTile(
                leading: const Icon(Icons.free_breakfast, size: 20),
                title: const Text('Break'),
                subtitle: Text(
                    '${entry.startTime.format(context)} – ${entry.endTime.format(context)}'),
                dense: true,
              );
            }

            if (entry.subjectId == null) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.event_available,
                      size: 20, color: Colors.grey),
                  title: const Text('None',
                      style: TextStyle(
                          color: Colors.grey, fontStyle: FontStyle.italic)),
                  subtitle: Text(
                      '${entry.startTime.format(context)} – ${entry.endTime.format(context)}'),
                  dense: true,
                ),
              );
            }

            final subject = appState.subjects.firstWhere(
              (s) => s.id == entry.subjectId,
              orElse: () => Subject(sessionId: 0, name: 'Unknown'),
            );
            if (subject.name == 'Unknown') return const SizedBox.shrink();

            final subjectColor = subject.colorHex != null
                ? Color(
                    int.parse(subject.colorHex!.replaceFirst('#', '0xFF')))
                : Colors.grey;

            // Use getDisplayStatus — handles auto-missed and empty
            final effectiveStatus =
                appState.getDisplayStatus(entry, widget.date);
            final isAttended = effectiveStatus == AttendanceStatus.attended;
            final isMissed = effectiveStatus == AttendanceStatus.missed;
            final isCancelled = effectiveStatus == AttendanceStatus.cancelled;
            final isEmpty = effectiveStatus == AttendanceStatus.empty;

            // Modifier name tag
            final modifier = entry.modifierId != null
                ? appState.modifiers
                    .where((m) => m.id == entry.modifierId)
                    .firstOrNull
                : null;

            final bgColor = isAttended
                ? Colors.green.withOpacity(0.15)
                : isMissed
                    ? Colors.red.withOpacity(0.15)
                    : isCancelled
                        ? Colors.grey.withOpacity(0.15)
                        : subjectColor.withOpacity(0.1);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subject.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              if (modifier != null)
                                Text(
                                  modifier.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: modifier.colorHex != null
                                        ? Color(int.parse(modifier.colorHex!
                                            .replaceFirst('#', '0xFF')))
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '${entry.startTime.format(context)} – ${entry.endTime.format(context)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (!isHoliday) ...[
                      Builder(builder: (context) {
                        final today = DateTime.now();
                        final todayOnly =
                            DateTime(today.year, today.month, today.day);
                        final dateOnly = DateTime(widget.date.year,
                            widget.date.month, widget.date.day);
                        final isFuture = dateOnly.isAfter(todayOnly);

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ChoiceChip(
                              label: const Text('Attended'),
                              selected: isAttended,
                              showCheckmark: false,
                              selectedColor: Colors.green.shade200,
                              onSelected: isFuture
                                  ? null
                                  : (v) {
                                      // Deselect = revert to empty
                                      _markAttendance(
                                          entry.id,
                                          v
                                              ? AttendanceStatus.attended
                                              : AttendanceStatus.empty);
                                    },
                            ),
                            ChoiceChip(
                              label: Text(
                                  isMissed && isEmpty ? 'Missed' : 'Missed'),
                              selected: isMissed && !isEmpty,
                              showCheckmark: false,
                              selectedColor: Colors.red.shade200,
                              onSelected: isFuture
                                  ? null
                                  : (v) {
                                      _markAttendance(
                                          entry.id,
                                          v
                                              ? AttendanceStatus.missed
                                              : AttendanceStatus.empty);
                                    },
                            ),
                            ChoiceChip(
                              label: const Text('Cancelled'),
                              selected: isCancelled,
                              showCheckmark: false,
                              selectedColor: Colors.grey.shade300,
                              onSelected: isFuture
                                  ? null
                                  : (v) {
                                      _markAttendance(
                                          entry.id,
                                          v
                                              ? AttendanceStatus.cancelled
                                              : AttendanceStatus.empty);
                                    },
                            ),
                          ],
                        );
                      }),
                    ] else ...[
                      const Text('Holiday — attendance disabled',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 16),
      ],
    );
  }

  void _showPresetsSheet(AppState appState) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Apply Preset',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              const Divider(height: 1),

              // Quick presets
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('All Attended'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final count = _dayEntries.where((e) => !e.isBreak).length;
                  await _applyQuickPreset(appState, AttendanceStatus.attended);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'All Attended applied to $count lecture(s)')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text('All Missed'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final count = _dayEntries.where((e) => !e.isBreak).length;
                  await _applyQuickPreset(appState, AttendanceStatus.missed);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('All Missed applied to $count lecture(s)')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.orange),
                title: const Text('All Cancelled'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final count = _dayEntries.where((e) => !e.isBreak).length;
                  await _applyQuickPreset(appState, AttendanceStatus.cancelled);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'All Cancelled applied to $count lecture(s)')),
                    );
                  }
                },
              ),

              // Saved custom presets
              if (appState.presets.isNotEmpty) ...[
                const Divider(),
                const Padding(
                  padding: EdgeInsets.only(left: 16, bottom: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Saved Presets',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                ...appState.presets.map((preset) => ListTile(
                      leading: const Icon(Icons.flash_on),
                      title: Text(preset.name),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final actions = appState.decodePresetActions(preset);
                        await _applyPreset(appState, preset);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Preset "${preset.name}" applied to ${actions.length} lecture(s)')),
                          );
                        }
                      },
                    )),
              ],

              // Create new preset + manage
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Create New Preset for This Day'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await showCreatePresetDialog(context, appState, widget.date);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Manage Saved Presets'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PresetManagerScreen()),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
