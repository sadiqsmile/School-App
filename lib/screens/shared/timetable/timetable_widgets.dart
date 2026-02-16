import 'package:flutter/material.dart';

import '../../../services/timetable_service.dart';

class TimetablePeriod {
  TimetablePeriod({
    required this.start,
    required this.end,
    required this.subject,
    this.room,
  });

  final String start; // HH:mm
  final String end; // HH:mm
  final String subject;
  final String? room;

  Map<String, Object?> toMap() {
    return {
      'startTime': start,
      'endTime': end,
      'subject': subject,
      if (room != null) 'room': room,
    };
  }

  static TimetablePeriod fromMap(Map map) {
    return TimetablePeriod(
      start: (map['startTime'] ?? '').toString(),
      end: (map['endTime'] ?? '').toString(),
      subject: (map['subject'] ?? '').toString(),
      room: (map['room'] as String?),
    );
  }
}

Map<String, List<TimetablePeriod>> parseDays(dynamic raw) {
  final out = <String, List<TimetablePeriod>>{
    for (final k in TimetableDays.keys) k: <TimetablePeriod>[],
  };

  if (raw is! Map) return out;

  for (final key in TimetableDays.keys) {
    final list = raw[key];
    if (list is! List) continue;
    out[key] = list
        .whereType<Map>()
        .map((m) => TimetablePeriod.fromMap(m))
        .toList(growable: true);
  }

  return out;
}

Map<String, List<Map<String, Object?>>> serializeDays(Map<String, List<TimetablePeriod>> days) {
  final out = <String, List<Map<String, Object?>>>{};
  for (final key in TimetableDays.keys) {
    final items = (days[key] ?? const <TimetablePeriod>[])
        .map((p) => p.toMap())
        .toList(growable: false);
    out[key] = items;
  }
  return out;
}

String fmtTimeOfDay(TimeOfDay t) {
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

TimeOfDay? parseTimeOfDay(String s) {
  final parts = s.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  if (h < 0 || h > 23 || m < 0 || m > 59) return null;
  return TimeOfDay(hour: h, minute: m);
}

class TimetableDayView extends StatelessWidget {
  const TimetableDayView({
    super.key,
    required this.dayKey,
    required this.items,
  });

  final String dayKey;
  final List<TimetablePeriod> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No periods for ${TimetableDays.label(dayKey)}.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final p = items[i];
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text('${i + 1}')),
            title: Text(p.subject.isEmpty ? 'Period ${i + 1}' : p.subject),
            subtitle: Text('${p.start} - ${p.end}${p.room == null ? '' : ' • Room: ${p.room}'}'),
          ),
        );
      },
    );
  }
}

class TimetableDayEditor extends StatelessWidget {
  const TimetableDayEditor({
    super.key,
    required this.dayKey,
    required this.items,
    required this.onChanged,
  });

  final String dayKey;
  final List<TimetablePeriod> items;
  final ValueChanged<List<TimetablePeriod>> onChanged;

  Future<void> _editPeriod(BuildContext context, {TimetablePeriod? existing, required int index}) async {
    final subjectCtrl = TextEditingController(text: existing?.subject ?? '');
    final roomCtrl = TextEditingController(text: existing?.room ?? '');

    TimeOfDay start = parseTimeOfDay(existing?.start ?? '09:00') ?? const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay end = parseTimeOfDay(existing?.end ?? '09:40') ?? const TimeOfDay(hour: 9, minute: 40);

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existing == null ? 'Add Period' : 'Edit Period'),
          content: StatefulBuilder(
            builder: (context, setLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: subjectCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      prefixIcon: Icon(Icons.menu_book_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: roomCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Room (optional)',
                      prefixIcon: Icon(Icons.meeting_room_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showTimePicker(context: context, initialTime: start);
                            if (picked != null) setLocal(() => start = picked);
                          },
                          icon: const Icon(Icons.schedule_outlined),
                          label: Text('Start: ${fmtTimeOfDay(start)}'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showTimePicker(context: context, initialTime: end);
                            if (picked != null) setLocal(() => end = picked);
                          },
                          icon: const Icon(Icons.schedule_outlined),
                          label: Text('End: ${fmtTimeOfDay(end)}'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        );
      },
    );

    if (ok != true) return;

    final updated = TimetablePeriod(
      start: fmtTimeOfDay(start),
      end: fmtTimeOfDay(end),
      subject: subjectCtrl.text.trim(),
      room: roomCtrl.text.trim().isEmpty ? null : roomCtrl.text.trim(),
    );

    final next = List<TimetablePeriod>.from(items);
    if (existing == null) {
      next.add(updated);
    } else {
      next[index] = updated;
    }

    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Periods for ${TimetableDays.label(dayKey)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            FilledButton.icon(
              onPressed: () => _editPeriod(context, existing: null, index: -1),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No periods yet. Tap Add to create the first period.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          )
        else
          for (var i = 0; i < items.length; i++)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(items[i].subject.isEmpty ? 'Period ${i + 1}' : items[i].subject),
                subtitle: Text('${items[i].start} - ${items[i].end}${items[i].room == null ? '' : ' • Room: ${items[i].room}'}'),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _editPeriod(context, existing: items[i], index: i),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        final next = List<TimetablePeriod>.from(items)..removeAt(i);
                        onChanged(next);
                      },
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
