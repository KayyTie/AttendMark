import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/preset.dart';
import '../models/attendance_record.dart';

class PresetManagerScreen extends StatelessWidget {
  const PresetManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Presets')),
      body: appState.presets.isEmpty
          ? const Center(child: Text('No saved presets.'))
          : ListView.builder(
              itemCount: appState.presets.length,
              itemBuilder: (ctx, i) {
                final preset = appState.presets[i];
                final actions = appState.decodePresetActions(preset);
                final summary = _buildSummary(actions);

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(preset.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle:
                        Text(summary, style: const TextStyle(fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              color: Colors.blue),
                          onPressed: () =>
                              showEditPresetDialog(context, appState, preset),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: ctx,
                              builder: (c) => AlertDialog(
                                title: const Text('Delete Preset?'),
                                content: Text('Delete "${preset.name}"?'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Cancel')),
                                  FilledButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Delete')),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await appState.deletePreset(preset.id!);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _buildSummary(Map<String, AttendanceStatus> actions) {
    final parts = <String>[];
    for (final entry in actions.entries) {
      final icon = entry.value == AttendanceStatus.attended
          ? '✅'
          : entry.value == AttendanceStatus.cancelled
              ? '🚫'
              : '❌';
      parts.add('$icon ${entry.key}');
    }
    return parts.isEmpty ? '(empty)' : parts.join(' · ');
  }
}

/// Stateless helper to show the "Create Preset" dialog for a specific day.
Future<void> showCreatePresetDialog(
    BuildContext context, AppState appState, DateTime forDate) async {
  final dayOfWeek = forDate.weekday;
  final nameCtrl = TextEditingController();

  final lectures = appState.timetableEntries
      .where((e) => e.dayOfWeek == dayOfWeek && !e.isBreak)
      .toList()
    ..sort((a, b) {
      final aMin = a.startTime.hour * 60 + a.startTime.minute;
      final bMin = b.startTime.hour * 60 + b.startTime.minute;
      return aMin.compareTo(bMin);
    });

  if (lectures.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No lectures scheduled for this day.')),
    );
    return;
  }

  // Step 1: Pick lecture count
  int? lectureCount = await showDialog<int>(
    context: context,
    builder: (ctx) {
      int selectedCount = lectures.length;
      return StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Lectures to include'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How many lectures from the start of the day?'),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: selectedCount,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: List.generate(
                    lectures.length,
                    (i) => DropdownMenuItem(
                        value: i + 1, child: Text('${i + 1}'))),
                onChanged: (v) => setSt(() => selectedCount = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, selectedCount),
                child: const Text('Next')),
          ],
        ),
      );
    },
  );

  if (lectureCount == null || !context.mounted) return;

  final selectedLectures = lectures.take(lectureCount).toList();
  // Use time-slot keys instead of entry IDs
  final Map<String, AttendanceStatus> statuses = {
    for (final l in selectedLectures)
      AppState.slotKey(l): AttendanceStatus.attended,
  };

  // Step 2: Name + per-lecture status
  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => AlertDialog(
        title: const Text('Define Preset'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Preset Name', border: OutlineInputBorder()),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text('Status for each time slot:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...selectedLectures.map((entry) {
                final slotK = AppState.slotKey(entry);
                final timeLabel =
                    '${entry.startTime.format(ctx)} – ${entry.endTime.format(ctx)}';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(timeLabel,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: AttendanceStatus.values
                            .where((s) => s != AttendanceStatus.holiday)
                            .map((s) {
                          final label = s == AttendanceStatus.attended
                              ? 'Attended'
                              : s == AttendanceStatus.missed
                                  ? 'Missed'
                                  : 'Cancelled';
                          return ChoiceChip(
                            label: Text(label,
                                style: const TextStyle(fontSize: 11)),
                            selected: statuses[slotK] == s,
                            showCheckmark: false,
                            selectedColor: s == AttendanceStatus.attended
                                ? Colors.green.shade200
                                : s == AttendanceStatus.missed
                                    ? Colors.red.shade200
                                    : Colors.orange.shade200,
                            onSelected: (sel) {
                              if (sel) setSt(() => statuses[slotK] = s);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final statusStrings = statuses.map((k, v) => MapEntry(
                  k,
                  v == AttendanceStatus.attended
                      ? 'attended'
                      : v == AttendanceStatus.cancelled
                          ? 'cancelled'
                          : 'missed'));
              await appState.createPreset(
                nameCtrl.text.trim(),
                statusStrings,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Preset'),
          ),
        ],
      ),
    ),
  );
}

/// Dialog to edit an existing preset.
Future<void> showEditPresetDialog(
    BuildContext context, AppState appState, Preset preset) async {
  final nameCtrl = TextEditingController(text: preset.name);
  final actions = appState.decodePresetActions(preset);
  final statuses = Map<String, AttendanceStatus>.from(actions);

  if (statuses.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This preset has no valid slots.')),
    );
    return;
  }

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => AlertDialog(
        title: const Text('Edit Preset'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Preset Name', border: OutlineInputBorder()),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text('Update status for each time slot:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...statuses.keys.map((slotK) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(slotK,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: AttendanceStatus.values
                            .where((s) => s != AttendanceStatus.holiday)
                            .map((s) {
                          final label = s == AttendanceStatus.attended
                              ? 'Attended'
                              : s == AttendanceStatus.missed
                                  ? 'Missed'
                                  : 'Cancelled';
                          return ChoiceChip(
                            label: Text(label,
                                style: const TextStyle(fontSize: 11)),
                            selected: statuses[slotK] == s,
                            showCheckmark: false,
                            selectedColor: s == AttendanceStatus.attended
                                ? Colors.green.shade200
                                : s == AttendanceStatus.missed
                                    ? Colors.red.shade200
                                    : Colors.orange.shade200,
                            onSelected: (sel) {
                              if (sel) setSt(() => statuses[slotK] = s);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;

              final mapStr = statuses.map((k, v) => MapEntry(
                  k,
                  v == AttendanceStatus.attended
                      ? 'attended'
                      : v == AttendanceStatus.cancelled
                          ? 'cancelled'
                          : 'missed'));
              final json = jsonEncode(mapStr);

              final updated = Preset(
                id: preset.id,
                name: nameCtrl.text.trim(),
                actionsJson: json,
              );

              await appState.updatePreset(updated);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
