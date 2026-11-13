import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/local/app_database.dart';
import '../../domain/dates.dart';
import '../../domain/sleep.dart';
import '../../ui/ember.dart';
import '../../ui/motion.dart';
import '../../ui/widgets.dart';

/// The Sleep page (design: `docs/design/source/Sleep.dc.html`): numbers at
/// the top, a chart of when the user slept, and on the right a form to log
/// a night and the recent nights.
class SleepPage extends ConsumerStatefulWidget {
  const SleepPage({super.key});

  @override
  ConsumerState<SleepPage> createState() => _SleepPageState();
}

class _SleepPageState extends ConsumerState<SleepPage> {
  int _range = 14;

  /// The morning shown in the form, or null for a new night.
  String? _editing;

  @override
  Widget build(BuildContext context) {
    final nights = ref.watch(sleepLogsProvider).value ?? const <SleepLog>[];
    final today = dayKey(ref.watch(clockProvider)());
    final shown = nightsBefore(nights, end: today, count: _range);
    final before = nightsBefore(
      nights,
      end: addDays(today, -_range),
      count: _range,
    );
    final lastNight = nightOn(nights, today);
    final average = averageMinutes(shown);
    final previous = averageMinutes(before);
    final usual = usualTimes(shown);
    final steady = consistency(shown);
    final logged = shown.whereType<SleepLog>().length;

    return PageLayout(
      main: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: PageHeader(
                title: 'Sleep',
                subtitle: 'Logged by hand · device sync comes later',
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Segmented<int>(
                keyPrefix: 'sleep-range',
                value: _range,
                options: const [
                  (7, '7 nights'),
                  (14, '14 nights'),
                  (30, '30 nights'),
                ],
                onChanged: (value) => setState(() => _range = value),
              ),
            ),
          ],
        ),
        TileGrid(
          children: [
            StatTile(
              key: const Key('sleep-last-night'),
              label: 'Last night',
              value: lastNight == null
                  ? '—'
                  : formatMinutes(
                      sleepMinutes(lastNight.bedTime, lastNight.wakeTime),
                    ),
              detail: lastNight == null
                  ? 'Not logged yet'
                  : '${formatTime(lastNight.bedTime)} to '
                        '${formatTime(lastNight.wakeTime)}',
            ),
            StatTile(
              key: const Key('sleep-average'),
              label: 'Average, $_range nights',
              value: average == null ? '—' : formatMinutes(average),
              detail: previous == null
                  ? '${countOf(logged, 'night')} logged'
                  : 'Previous $_range: ${formatMinutes(previous)}',
            ),
            StatTile(
              key: const Key('sleep-consistency'),
              label: 'Schedule consistency',
              value: steady == null ? '—' : '$steady%',
              detail: 'Bedtime within 45 min of usual',
            ),
            StatTile(
              label: 'Usual times',
              value: usual == null
                  ? '—'
                  : '${_short(usual.bed)} · ${_short(usual.wake)}',
              valueSize: 20,
              detail: 'Middle bed and wake time',
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              icon: Icons.bedtime_outlined,
              title: 'When you slept',
              trailing: Wrap(
                spacing: 12,
                children: [
                  _legend(Ember.ink, '7h or more'),
                  _legend(Ember.ring, 'Under 7h'),
                  _legend(Ember.now, 'Last night'),
                ],
              ),
            ),
            Tile(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SleepChart(
                    key: ValueKey(_range),
                    nights: shown,
                    end: today,
                    usual: usual,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    usual == null
                        ? 'Log a few nights to see your usual window.'
                        : 'Shaded band: your usual window, '
                              '${formatTime(usual.bed)} to '
                              '${formatTime(usual.wake)}.',
                    style: Ember.meta,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
      rail: [
        _NightForm(
          key: ValueKey(_editing ?? 'new'),
          night: _editing == null ? null : nightOn(nights, _editing!),
          nights: nights,
          today: today,
          onDone: () => setState(() => _editing = null),
        ),
        _RecentNights(
          nights: nights,
          today: today,
          editing: _editing,
          onPick: (day) => setState(() {
            _editing = day == _editing ? null : day;
          }),
        ),
      ],
    );
  }

  /// `11:40` style, without AM or PM, for the narrow "Usual times" tile.
  static String _short(String time) =>
      formatTime(time).replaceAll(' AM', '').replaceAll(' PM', '');

  static Widget _legend(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: Ember.meta),
    ],
  );
}

/// One bar per night from bedtime to wake time on a clock that runs from
/// 8 PM to noon. The usual window is shaded. Bars grow softly into place.
class _SleepChart extends StatelessWidget {
  const _SleepChart({
    super.key,
    required this.nights,
    required this.end,
    required this.usual,
  });

  final List<SleepLog?> nights;
  final String end;
  final ({String bed, String wake})? usual;

  @override
  Widget build(BuildContext context) {
    final count = nights.length;
    final labels = [
      for (var i = count - 1; i >= 0; i--)
        weekdayShort[parseDayKey(addDays(end, -i))!.weekday - 1].substring(
          0,
          count > 14 ? 1 : 2,
        ),
    ];
    return Semantics(
      label:
          'Chart of bedtimes and wake times for the last $count nights. '
          '${nights.whereType<SleepLog>().length} nights logged.',
      child: SizedBox(
        height: 230,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Motion.of(context, Motion.slow),
          curve: Motion.soft,
          builder: (context, grow, _) => CustomPaint(
            size: Size.infinite,
            painter: _SleepChartPainter(
              nights: nights,
              labels: labels,
              usual: usual,
              grow: grow,
            ),
          ),
        ),
      ),
    );
  }
}

class _SleepChartPainter extends CustomPainter {
  _SleepChartPainter({
    required this.nights,
    required this.labels,
    required this.usual,
    required this.grow,
  });

  final List<SleepLog?> nights;
  final List<String> labels;
  final ({String bed, String wake})? usual;
  final double grow;

  // The clock runs from 8 PM (20:00) to noon the next day.
  static const _from = 20 * 60;
  static const _to = 36 * 60;
  static const _left = 52.0;
  static const _bottom = 22.0;
  static const _ticks = [
    '8 PM',
    '10 PM',
    '12 AM',
    '2 AM',
    '4 AM',
    '6 AM',
    '8 AM',
    '10 AM',
    '12 PM',
  ];

  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    Color color = Ember.ink3,
    bool alignRight = false,
    bool center = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: Ember.text(10, 12, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alignRight
        ? at.dx - painter.width
        : center
        ? at.dx - painter.width / 2
        : at.dx;
    painter.paint(canvas, Offset(dx, at.dy - painter.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final height = size.height - _bottom;
    final width = size.width - _left;
    double y(int minutes) =>
        (minutes.clamp(_from, _to) - _from) / (_to - _from) * height;

    final grid = Paint()
      ..color = Ember.line
      ..strokeWidth = 1;
    for (var i = 0; i < _ticks.length; i++) {
      final at = y(_from + i * 120);
      canvas.drawLine(Offset(_left, at), Offset(size.width, at), grid);
      _text(canvas, _ticks[i], Offset(_left - 8, at), alignRight: true);
    }

    final usual = this.usual;
    if (usual != null) {
      final top = y(bedScale(usual.bed));
      final bottom = y(bedScale(usual.wake));
      if (bottom > top) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(_left, top, size.width, bottom),
            const Radius.circular(6),
          ),
          Paint()..color = Ember.ink.withValues(alpha: 0.04),
        );
      }
    }

    final count = nights.length;
    final slot = width / count;
    final barWidth = math.min(22.0, slot * 0.6);
    for (var i = 0; i < count; i++) {
      final center = _left + slot * (i + 0.5);
      final last = i == count - 1;
      _text(
        canvas,
        labels[i],
        Offset(center, size.height - 8),
        center: true,
        color: last ? Ember.nowInk : Ember.ink3,
      );
      final night = nights[i];
      if (night == null) continue;
      final bed = bedScale(night.bedTime);
      var wake = bedScale(night.wakeTime);
      if (wake <= bed) wake += 1440;
      final top = y(bed);
      final bottom = top + (y(wake) - top) * grow;
      final minutes = sleepMinutes(night.bedTime, night.wakeTime);
      final color = last
          ? Ember.now
          : minutes >= 7 * 60
          ? Ember.ink
          : Ember.ring;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            center - barWidth / 2,
            top,
            center + barWidth / 2,
            math.max(bottom, top + 2),
          ),
          const Radius.circular(5),
        ),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_SleepChartPainter old) =>
      old.nights != nights || old.grow != grow || old.usual != usual;
}

/// The form on the right: log a night, or change the one picked below.
class _NightForm extends ConsumerStatefulWidget {
  const _NightForm({
    super.key,
    required this.night,
    required this.nights,
    required this.today,
    required this.onDone,
  });

  /// The night being changed, or null for a new one.
  final SleepLog? night;
  final List<SleepLog> nights;
  final String today;
  final VoidCallback onDone;

  @override
  ConsumerState<_NightForm> createState() => _NightFormState();
}

class _NightFormState extends ConsumerState<_NightForm> {
  late String _day = widget.night?.day ?? widget.today;
  late String _bed = widget.night?.bedTime ?? '23:00';
  late String _wake = widget.night?.wakeTime ?? '07:00';
  late String? _rested = widget.night?.rested;
  late final _note = TextEditingController(text: widget.night?.note ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: parseDayKey(_day)!,
      firstDate: DateTime(2020),
      lastDate: parseDayKey(widget.today)!,
      helpText: 'The morning you woke up',
    );
    if (picked != null && mounted) setState(() => _day = dayKey(picked));
  }

  Future<void> _pickTime({required bool bed}) async {
    final minutes = minutesOf(bed ? _bed : _wake) ?? 0;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: bed ? 'Bedtime' : 'Woke up',
    );
    if (picked == null || !mounted) return;
    final value = timeOf(picked.hour * 60 + picked.minute);
    setState(() => bed ? _bed = value : _wake = value);
  }

  Future<void> _save() async {
    final userId = ref.read(userIdProvider);
    if (userId == null) return;
    final minutes = sleepMinutes(_bed, _wake);
    if (needsCheck(minutes)) {
      final keep = await confirmDialog(
        context,
        title: 'Check the times',
        message:
            'This night is ${formatMinutes(minutes)} long. Are the bedtime '
            'and the wake time right?',
        confirmLabel: 'Save anyway',
        cancelLabel: 'Go back',
      );
      if (!keep || !mounted) return;
    }
    try {
      await ref
          .read(sleepRepositoryProvider)
          .saveNight(
            userId: userId,
            day: _day,
            bedTime: _bed,
            wakeTime: _wake,
            rested: _rested,
            note: _note.text,
          );
      if (!mounted) return;
      showMessage(context, 'Night saved.');
      widget.onDone();
    } catch (error) {
      if (mounted) showMessage(context, 'Could not save. Try again. ($error)');
    }
  }

  Future<void> _delete() async {
    final night = widget.night!;
    final confirmed = await confirmDialog(
      context,
      title: 'Delete this night?',
      message: 'The night of ${formatWeekDay(night.day)} is removed.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await ref.read(sleepRepositoryProvider).deleteNight(night.id);
      widget.onDone();
    } catch (error) {
      if (mounted) showMessage(context, 'Could not delete. ($error)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.night != null;
    final minutes = sleepMinutes(_bed, _wake);
    final replaces =
        !editing && widget.nights.any((night) => night.day == _day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(editing ? Icons.edit_outlined : Icons.add, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                editing ? 'Change a night' : 'Log a night',
                style: Ember.h2,
              ),
            ),
            if (editing)
              IconButton(
                tooltip: 'Close',
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                onPressed: widget.onDone,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const FieldLabel('Night of'),
        OutlinedButton.icon(
          key: const Key('sleep-day'),
          onPressed: editing ? null : _pickDay,
          icon: const Icon(Icons.event_outlined, size: 16),
          label: Text(
            '${formatWeekDay(addDays(_day, -1))} → ${formatWeekDay(_day)}',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FieldLabel('Bedtime'),
                  OutlinedButton(
                    key: const Key('sleep-bed'),
                    onPressed: () => _pickTime(bed: true),
                    child: Text(formatTime(_bed)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FieldLabel('Woke up'),
                  OutlinedButton(
                    key: const Key('sleep-wake'),
                    onPressed: () => _pickTime(bed: false),
                    child: Text(formatTime(_wake)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedContainer(
          duration: Motion.of(context, Motion.base),
          curve: Motion.soft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Ember.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: needsCheck(minutes) ? Ember.amber : Ember.line,
            ),
          ),
          child: Row(
            children: [
              Text('Duration', style: Ember.meta),
              const Spacer(),
              Text(
                formatMinutes(minutes),
                key: const Key('sleep-duration'),
                style: Ember.text(13, 16, weight: 600, color: Ember.ink),
              ),
            ],
          ),
        ),
        if (needsCheck(minutes)) ...[
          const SizedBox(height: 6),
          Text(
            'Check the times: a night this long is unusual.',
            style: Ember.meta.copyWith(color: Ember.amberInk),
          ),
        ],
        const SizedBox(height: 12),
        const FieldLabel('How rested? Optional'),
        Segmented<String?>(
          keyPrefix: 'sleep-rested',
          expand: true,
          value: _rested,
          options: const [
            ('poor', 'Poor'),
            ('okay', 'Okay'),
            ('good', 'Good'),
            ('great', 'Great'),
          ],
          // Tapping the chosen one again clears it.
          onChanged: (value) =>
              setState(() => _rested = value == _rested ? null : value),
        ),
        const SizedBox(height: 12),
        const FieldLabel('Note · optional'),
        TextField(
          key: const Key('sleep-note'),
          controller: _note,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Late coffee, noise, travel…',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('sleep-save'),
          onPressed: _save,
          child: Text(editing ? 'Save' : 'Save night'),
        ),
        const SizedBox(height: 8),
        Text(
          replaces
              ? 'This morning already has a night. Saving replaces it.'
              : 'Saving a night for a date that already has one replaces it.',
          style: Ember.caption,
        ),
        if (editing) ...[
          const SizedBox(height: 6),
          TextButton.icon(
            key: const Key('sleep-delete'),
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete night'),
          ),
        ],
      ],
    );
  }
}

class _RecentNights extends StatelessWidget {
  const _RecentNights({
    required this.nights,
    required this.today,
    required this.editing,
    required this.onPick,
  });

  final List<SleepLog> nights;
  final String today;
  final String? editing;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Recent nights', style: Ember.h3),
        const SizedBox(height: 10),
        if (nights.isEmpty)
          Text('No nights logged yet.', style: Ember.meta)
        else
          for (final night in nights.take(14))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Tile(
                key: Key('night-${night.day}'),
                selected: night.day == editing,
                onTap: () => onPick(night.day),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        night.day == today ? 'Today' : formatWeekDay(night.day),
                        style: Ember.item.copyWith(color: Ember.ink),
                      ),
                    ),
                    Text(
                      '${formatTime(night.bedTime)} – '
                      '${formatTime(night.wakeTime)}',
                      style: Ember.meta,
                    ),
                    SizedBox(
                      width: 58,
                      child: Text(
                        formatMinutes(
                          sleepMinutes(night.bedTime, night.wakeTime),
                        ),
                        textAlign: TextAlign.right,
                        style: Ember.item.copyWith(color: Ember.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
