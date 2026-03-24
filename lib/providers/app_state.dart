import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/session.dart';
import '../models/subject.dart';
import '../models/timetable_entry.dart';
import '../models/attendance_record.dart';
import '../models/modifier.dart';
import '../models/preset.dart';
import '../repositories/session_repository.dart';
import '../repositories/subject_repository.dart';
import '../repositories/timetable_repository.dart';
import '../repositories/attendance_repository.dart';
import '../repositories/modifier_repository.dart';
import '../repositories/preset_repository.dart';
import '../services/preferences_service.dart';

class AppState extends ChangeNotifier {
  final SessionRepository _sessionRepo = SessionRepository();
  final SubjectRepository _subjectRepo = SubjectRepository();
  final TimetableRepository _timetableRepo = TimetableRepository();
  final AttendanceRepository _attendanceRepo = AttendanceRepository();
  final ModifierRepository _modifierRepo = ModifierRepository();
  final PresetRepository _presetRepo = PresetRepository();
  final PreferencesService _prefs = PreferencesService();

  Session? currentSession;
  List<Subject> subjects = [];
  List<TimetableEntry> timetableEntries = [];
  List<AttendanceRecord> attendanceRecords = [];
  final Map<String, List<AttendanceRecord>> _recordsByDate = {};
  List<Modifier> modifiers = [];
  List<Preset> presets = [];

  ThemeMode themeMode = ThemeMode.system;
  double minAttendancePercentage = 75.0;
  bool isInitialized = false;

  Future<void> init() async {
    themeMode = await _prefs.getThemeMode();
    minAttendancePercentage = await _prefs.getMinAttendancePercentage();

    // Load modifiers (global – not per session)
    modifiers = await _modifierRepo.getAllModifiers();

    // Determine which session to show: last viewed (if still exists), else most recent active
    final lastId = await _prefs.getLastViewedSessionId();
    Session? session;
    if (lastId != null) {
      final all = await _sessionRepo.getAllSessions();
      session = all.where((s) => s.id == lastId).firstOrNull;
    }
    session ??= await _sessionRepo.getActiveSession();

    if (session != null) {
      currentSession = session;
      await loadSessionData(session.id!);
    }
    isInitialized = true;
    notifyListeners();
  }

  void _updateRecordsByDate() {
    _recordsByDate.clear();
    for (var r in attendanceRecords) {
      final dateStr = r.date.toIso8601String().split('T')[0];
      _recordsByDate.putIfAbsent(dateStr, () => []).add(r);
    }
  }

  Future<void> updateMinAttendance(double pct) async {
    minAttendancePercentage = pct;
    await _prefs.setMinAttendancePercentage(pct);
    notifyListeners();
  }

  Future<void> loadSessionData(int sessionId) async {
    subjects = await _subjectRepo.getSubjectsForSession(sessionId);
    timetableEntries = await _timetableRepo.getEntriesForSession(sessionId);
    attendanceRecords = await _attendanceRepo.getRecordsForSession(sessionId);
    presets = await _presetRepo.getAllPresets();
    _updateRecordsByDate();
    notifyListeners();
  }

  Future<void> deleteSession(int sessionId) async {
    await _sessionRepo.delete(sessionId);
    if (currentSession?.id == sessionId) {
      currentSession = null;
      subjects.clear();
      timetableEntries.clear();
      attendanceRecords.clear();
      _recordsByDate.clear();
    }
    notifyListeners();
  }

  // ─── Session Management ──────────────────────────────────────

  /// Create a new session without ending the current one.
  /// Multiple sessions can be active/isActive simultaneously.
  Future<void> startNewSession(String name, DateTime start) async {
    final newSession = Session(name: name, startDate: start, isActive: true);
    currentSession = await _sessionRepo.create(newSession);
    subjects.clear();
    timetableEntries.clear();
    attendanceRecords.clear();
    _recordsByDate.clear();
    presets.clear();
    await _prefs.setLastViewedSessionId(currentSession!.id!);
    notifyListeners();
  }

  Future<void> switchSession(Session session) async {
    currentSession = session;
    await _prefs.setLastViewedSessionId(session.id!);
    await loadSessionData(session.id!);
  }

  Future<void> updateTheme(ThemeMode mode) async {
    themeMode = mode;
    await _prefs.setThemeMode(mode);
    notifyListeners();
  }

  // ─── Empty-state lecture display status ──────────────────────

  /// Returns the effective status of a lecture for a given date.
  /// - If a record exists → use stored status.
  /// - If no record and lecture has ended → missed (automatically, no DB write).
  /// - If no record and lecture hasn't ended → empty.
  AttendanceStatus getDisplayStatus(TimetableEntry entry, DateTime date) {
    final dateStr = date.toIso8601String().split('T')[0];
    final dayRecords = _recordsByDate[dateStr] ?? [];
    final record = dayRecords
        .where((r) => r.timetableEntryId == entry.id)
        .firstOrNull;

    if (record != null) return record.status;

    // Auto-missed: only if the lecture time has already passed today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDate = DateTime(date.year, date.month, date.day);

    if (entryDate.isBefore(today)) {
      // Past day → auto missed
      return AttendanceStatus.missed;
    }
    if (entryDate == today) {
      // Same day: check if lecture end time has passed
      final endMins = entry.endTime.hour * 60 + entry.endTime.minute;
      final nowMins = now.hour * 60 + now.minute;
      if (nowMins > endMins) {
        return AttendanceStatus.missed;
      }
    }
    return AttendanceStatus.empty;
  }

  // ─── Calendar Status ──────────────────────────────────────────

  /// Returns a summary for calendar cell coloring:
  ///   0 = all attended, 1 = partial, 2 = all missed, 3 = holiday, null = empty/no data
  int? getDayStatus(DateTime date) {
    if (currentSession == null) return null;

    final dateStr = date.toIso8601String().split('T')[0];
    final dayRecords = _recordsByDate[dateStr] ?? [];

    if (dayRecords.any((r) => r.status == AttendanceStatus.holiday)) return 3;

    // Find all non-break entries for this day-of-week
    final dayOfWeek = date.weekday;
    final scheduledEntries =
        timetableEntries.where((e) => e.dayOfWeek == dayOfWeek && !e.isBreak);
    if (scheduledEntries.isEmpty) return null;

    int attended = 0, missed = 0, empty = 0;
    for (final entry in scheduledEntries) {
      final status = getDisplayStatus(entry, date);
      if (status == AttendanceStatus.attended) {
        attended++;
      } else if (status == AttendanceStatus.missed) {
        missed++;
      } else if (status == AttendanceStatus.empty) {
        empty++;
      }
      // cancelled and holiday skipped from count
    }

    if (empty > 0) return null; // Still undecided
    if (attended > 0 && missed == 0) return 0; // All attended
    if (attended == 0 && missed > 0) return 2; // All missed
    if (attended > 0 && missed > 0) return 1; // Mixed
    return null;
  }

  // ─── Subject Management ───────────────────────────────────────

  Future<void> addSubject(Subject subject) async {
    final created = await _subjectRepo.create(subject);
    subjects.add(created);
    notifyListeners();
  }

  Future<void> updateSubject(Subject subject) async {
    await _subjectRepo.update(subject);
    final idx = subjects.indexWhere((s) => s.id == subject.id);
    if (idx != -1) subjects[idx] = subject;
    notifyListeners();
  }

  Future<void> deleteSubject(int subjectId) async {
    await _subjectRepo.delete(subjectId);
    subjects.removeWhere((s) => s.id == subjectId);
    notifyListeners();
  }

  // ─── Timetable Management ─────────────────────────────────────

  Future<void> addTimetableEntry(TimetableEntry entry) async {
    final created = await _timetableRepo.create(entry);
    timetableEntries.add(created);
    notifyListeners();
  }

  Future<void> updateTimetableEntry(TimetableEntry entry) async {
    await _timetableRepo.update(entry);
    final idx = timetableEntries.indexWhere((e) => e.id == entry.id);
    if (idx != -1) timetableEntries[idx] = entry;
    notifyListeners();
  }

  Future<void> deleteTimetableEntry(int entryId) async {
    await _timetableRepo.delete(entryId);
    timetableEntries.removeWhere((e) => e.id == entryId);
    notifyListeners();
  }

  // ─── Modifier Management ──────────────────────────────────────

  Future<void> addModifier(Modifier modifier) async {
    final created = await _modifierRepo.create(modifier);
    modifiers.add(created);
    notifyListeners();
  }

  Future<void> updateModifier(Modifier modifier) async {
    await _modifierRepo.update(modifier);
    final idx = modifiers.indexWhere((m) => m.id == modifier.id);
    if (idx != -1) modifiers[idx] = modifier;
    notifyListeners();
  }

  Future<void> deleteModifier(int modifierId) async {
    await _modifierRepo.delete(modifierId);
    modifiers.removeWhere((m) => m.id == modifierId);
    // Nullify in-memory entries that used this modifier
    timetableEntries = timetableEntries
        .map((e) => e.modifierId == modifierId
            ? TimetableEntry(
                id: e.id,
                sessionId: e.sessionId,
                dayOfWeek: e.dayOfWeek,
                startTime: e.startTime,
                endTime: e.endTime,
                subjectId: e.subjectId,
                isBreak: e.isBreak,
                modifierId: null,
              )
            : e)
        .toList();
    notifyListeners();
  }

  // ─── Preset Management ────────────────────────────────────────

  Future<Preset> createPreset(
      String name, Map<String, String> slotStatuses) async {
    final json = jsonEncode(slotStatuses);
    final preset =
        await _presetRepo.create(Preset(name: name, actionsJson: json));
    presets.add(preset);
    notifyListeners();
    return preset;
  }

  Future<void> updatePreset(Preset preset) async {
    await _presetRepo.update(preset);
    final idx = presets.indexWhere((p) => p.id == preset.id);
    if (idx != -1) presets[idx] = preset;
    notifyListeners();
  }

  Future<void> deletePreset(int presetId) async {
    await _presetRepo.delete(presetId);
    presets.removeWhere((p) => p.id == presetId);
    notifyListeners();
  }

  Map<String, AttendanceStatus> decodePresetActions(Preset preset) {
    final map = jsonDecode(preset.actionsJson) as Map<String, dynamic>;
    return map.map((k, v) {
      AttendanceStatus status;
      switch (v as String) {
        case 'attended':
          status = AttendanceStatus.attended;
          break;
        case 'cancelled':
          status = AttendanceStatus.cancelled;
          break;
        default:
          status = AttendanceStatus.missed;
      }
      return MapEntry(k, status);
    });
  }

  static String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String slotKey(TimetableEntry e) =>
      '${_fmtTime(e.startTime)}-${_fmtTime(e.endTime)}';

  // ─── Global Attendance Marking ────────────────────────────────

  /// Mark attendance for a slot. Pass [status] = [AttendanceStatus.empty]
  /// to explicitly mark the record as empty (so it won't auto-miss).
  Future<void> markAttendance(
      DateTime date, int? timetableEntryId, AttendanceStatus status) async {
    final session = currentSession;
    if (session == null) return;

    final dateStr = date.toIso8601String().split('T')[0];

    // Find existing record
    final existingIndex = attendanceRecords.indexWhere((r) =>
        r.date.toIso8601String().split('T')[0] == dateStr &&
        r.timetableEntryId == timetableEntryId &&
        (timetableEntryId != null || r.status == AttendanceStatus.holiday));

    final record = AttendanceRecord(
      id: existingIndex >= 0 ? attendanceRecords[existingIndex].id : null,
      sessionId: session.id!,
      date: date,
      timetableEntryId: timetableEntryId,
      status: status,
    );

    AttendanceRecord saved;
    if (existingIndex >= 0) {
      await _attendanceRepo.update(record);
      saved = record;
      attendanceRecords[existingIndex] = saved;
    } else {
      saved = await _attendanceRepo.create(record);
      attendanceRecords.add(saved);
    }

    _updateRecordsByDate();
    notifyListeners();
  }

  Future<void> applyQuickPreset(DateTime date, AttendanceStatus status) async {
    final dayOfWeek = date.weekday;
    final lectures = timetableEntries
        .where((e) => e.dayOfWeek == dayOfWeek && !e.isBreak)
        .toList();
    for (final entry in lectures) {
      await markAttendance(date, entry.id, status);
    }
  }

  Future<void> applyPreset(DateTime date, Preset preset) async {
    final actions = decodePresetActions(preset);
    final dayOfWeek = date.weekday;
    final dayLectures = timetableEntries
        .where((e) => e.dayOfWeek == dayOfWeek && !e.isBreak)
        .toList();

    for (final action in actions.entries) {
      for (final lecture in dayLectures) {
        if (slotKey(lecture) == action.key) {
          await markAttendance(date, lecture.id, action.value);
          break;
        }
      }
    }
  }

  List<AttendanceRecord> getEffectiveRecordsForDate(DateTime date) {
    final dateStr = date.toIso8601String().split('T')[0];
    return _recordsByDate[dateStr] ?? [];
  }
}
