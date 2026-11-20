import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/local/app_database.dart';
import '../../domain/dates.dart';
import '../../domain/habits.dart';
import '../../domain/sleep.dart' show formatTime;
import '../../ui/ember.dart';
import '../../ui/motion.dart';
import '../../ui/widgets.dart';

/// The Habits page (design: `docs/design/source/Habits.dc.html`): numbers at
/// the top, the log of the last 7 days (one click per box, founder's
/// layout), the last 30 days, and on the right a form to add or change a
/// habit.
///
/// No streaks (the spec says no streak pressure): each habit shows how many
/// of its planned days were kept. A missed day is data, not a failure.
class HabitsPage extends ConsumerStatefulWidget {
  const HabitsPage({super.key});

  @override
  ConsumerState<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends ConsumerState<HabitsPage> {
  String? _selectedId;

  Future<void> _mark(Habit habit, String day, String? status) async {
    final userId = ref.read(userIdProvider);
    if (userId == null) return;
    try {
      await ref
          .read(habitRepositoryProvider)
          .setMark(userId: userId, habitId: habit.id, day: day, status: status);
    } catch (error) {
      if (mounted) showMessage(context, 'Could not save. Try again. ($error)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(habitsProvider).value ?? const <Habit>[];
    final logs = ref.watch(habitLogsProvider).value ?? const <HabitLog>[];
    final areas = ref.watch(lifeAreasProvider).value ?? const <LifeArea>[];
    final today = dayKey(ref.watch(clockProvider)());
    final selected = habits.where((h) => h.id == _selectedId).firstOrNull;
    final progress = todayProgress(habits, logs, today: today);

    return PageLayout(
      main: [
        PageHeader(
          title: 'Habits',
          subtitle: habits.isEmpty
              ? formatLongDay(today)
              : '${formatLongDay(today)} · ${progress.done} of '
                    '${progress.planned} done',
        ),
        if (habits.isEmpty)
          const EmptyHint(
            title: 'No habits yet',
            text: 'Add one on the right. Three or four is a good start.',
          )
        else ...[
          _Numbers(habits: habits, logs: logs, today: today),
          _LogGrid(
            habits: habits,
            logs: logs,
            today: today,
            selectedId: _selectedId,
            onPickHabit: (habit) => setState(() {
              _selectedId = habit.id == _selectedId ? null : habit.id;
            }),
            onMark: _mark,
          ),
          _LastThirtyDays(habits: habits, logs: logs, today: today),
        ],
        Text(
          'A missed day is data, not a failure. Skip keeps a planned rest '
          'day from counting against you.',
          style: Ember.meta,
        ),
      ],
      rail: [
        _HabitForm(
          key: ValueKey(selected?.id ?? 'new'),
          habit: selected,
          areas: areas,
          onClose: () => setState(() => _selectedId = null),
        ),
      ],
    );
  }
}

/// The four number tiles at the top.
class _Numbers extends StatelessWidget {
  const _Numbers({
    required this.habits,
    required this.logs,
    required this.today,
  });

  final List<Habit> habits;
  final List<HabitLog> logs;
  final String today;

  @override
  Widget build(BuildContext context) {
    final progress = todayProgress(habits, logs, today: today);
    final week = keptOverAll(habits, logs, end: today, today: today, days: 7);
    final month = keptOverAll(habits, logs, end: today, today: today);
    final before = keptOverAll(
      habits,
      logs,
      end: addDays(today, -30),
      today: today,
    );
    final best = mostKept(habits, logs, today: today);
    String percent(Kept kept) =>
        kept.percent == null ? '—' : '${kept.percent}%';
    final planned = progress.planned;
    return TileGrid(
      children: [
        StatTile(
          key: const Key('habits-today'),
          label: 'Today',
          value: planned == 0 ? 'Rest day' : '${progress.done} of $planned',
          below: ProgressBar(
            planned == 0 ? 0 : (progress.done * 100 / planned).round(),
          ),
        ),
        StatTile(
          label: 'Last 7 days',
          value: percent(week),
          detail: week.counted == 0
              ? 'Nothing to count yet'
              : '${week.done} of ${week.counted} planned days',
        ),
        StatTile(
          label: 'Last 30 days',
          value: percent(month),
          detail: before.percent == null
              ? '${month.done} of ${month.counted} planned days'
              : 'Previous 30: ${before.percent}%',
        ),
        StatTile(
          label: 'Most kept',
          value: best?.habit.name ?? '—',
          valueSize: 20,
          detail: best == null
              ? 'Shows after a few days'
              : '${best.percent}% over 30 days',
        ),
      ],
    );
  }
}

/// The habit log: the last 7 days, newest first, with one box per habit.
/// One click on a box logs that habit done on that day, so a forgotten day
/// (gym yesterday) is filled in later. A second click clears it.
/// Right-click or a long press skips the day instead (a planned rest day).
class _LogGrid extends StatelessWidget {
  const _LogGrid({
    required this.habits,
    required this.logs,
    required this.today,
    required this.selectedId,
    required this.onPickHabit,
    required this.onMark,
  });

  final List<Habit> habits;
  final List<HabitLog> logs;
  final String today;
  final String? selectedId;
  final ValueChanged<Habit> onPickHabit;
  final void Function(Habit habit, String day, String? status) onMark;

  static const _dayWidth = 150.0;
  static const _minColumn = 84.0;
  static const _rowHeight = 40.0;

  @override
  Widget build(BuildContext context) {
    final days = [for (var i = 0; i < 7; i++) addDays(today, -i)];
    final marks = {
      for (final habit in habits) habit.id: marksOf(habit.id, logs),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          icon: Icons.check_box_outlined,
          title: 'Log',
          trailing: Text(
            'Click a box to log a day · right-click to skip',
            style: Ember.meta,
          ),
        ),
        Tile(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final column = math.max(
                _minColumn,
                (constraints.maxWidth - _dayWidth) / habits.length,
              );
              final width = _dayWidth + column * habits.length;
              final grid = SizedBox(
                width: width,
                child: Column(
                  children: [
                    SizedBox(
                      height: 36,
                      child: Row(
                        children: [
                          const SizedBox(width: _dayWidth),
                          for (final habit in habits)
                            SizedBox(
                              width: column,
                              child: _HabitHeader(
                                habit: habit,
                                selected: habit.id == selectedId,
                                onTap: () => onPickHabit(habit),
                              ),
                            ),
                        ],
                      ),
                    ),
                    for (final day in days)
                      Container(
                        height: _rowHeight,
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: Ember.line)),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: _dayWidth,
                              child: Row(
                                children: [
                                  Icon(
                                    day == today
                                        ? Icons.wb_sunny_outlined
                                        : Icons.wb_twilight_outlined,
                                    size: 15,
                                    color: day == today
                                        ? Ember.ink
                                        : Ember.ink3,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      logDayLabel(day, today: today),
                                      overflow: TextOverflow.ellipsis,
                                      style: Ember.text(
                                        13,
                                        16,
                                        weight: day == today ? 600 : 500,
                                        color: day == today
                                            ? Ember.ink
                                            : Ember.ink2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            for (final habit in habits)
                              SizedBox(
                                width: column,
                                child: Center(
                                  child: _LogBox(
                                    key: Key('habit-cell-${habit.id}-$day'),
                                    habit: habit,
                                    marks: marks[habit.id]!,
                                    day: day,
                                    today: today,
                                    onMark: (status) =>
                                        onMark(habit, day, status),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
              // Many habits: the grid scrolls sideways inside the tile.
              return width > constraints.maxWidth + 0.5
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: grid,
                    )
                  : grid;
            },
          ),
        ),
      ],
    );
  }
}

/// A habit's name at the top of its column. Clicking it opens the habit in
/// the form on the right.
class _HabitHeader extends StatelessWidget {
  const _HabitHeader({
    required this.habit,
    required this.selected,
    required this.onTap,
  });

  final Habit habit;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Edit ${habit.name}',
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        key: Key('habit-${habit.id}'),
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? Ember.ink : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            habit.name,
            overflow: TextOverflow.ellipsis,
            style: Ember.text(
              12,
              15,
              weight: 600,
              color: selected ? Ember.ink : Ember.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

/// One box of the habit log. Black with a tick: done. A dash: skipped.
/// Orange edge: planned today and not done yet (now). Faint edge: not a
/// planned day, but it can still be logged.
class _LogBox extends StatelessWidget {
  const _LogBox({
    super.key,
    required this.habit,
    required this.marks,
    required this.day,
    required this.today,
    required this.onMark,
  });

  final Habit habit;
  final Map<String, String> marks;
  final String day;
  final String today;
  final ValueChanged<String?> onMark;

  @override
  Widget build(BuildContext context) {
    final state = dayState(habit, marks, day, today: today);
    final done = state == HabitDay.done;
    final skipped = state == HabitDay.skipped;
    final words = switch (state) {
      HabitDay.done => 'done',
      HabitDay.skipped => 'skipped',
      HabitDay.off => 'day off',
      HabitDay.open || HabitDay.missed => 'not done',
    };
    void skip() => onMark(skipped ? null : HabitMark.skip);
    return Semantics(
      button: true,
      checked: done,
      label: '${habit.name}, ${logDayLabel(day, today: today)}: $words',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onMark(done ? null : HabitMark.done),
        onSecondaryTap: skip,
        onLongPress: skip,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.base),
            curve: Motion.soft,
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: done ? Ember.ink : Ember.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                width: 1.5,
                color: switch (state) {
                  HabitDay.done => Ember.ink,
                  HabitDay.open => Ember.now,
                  HabitDay.missed => Ember.ink3,
                  HabitDay.skipped || HabitDay.off => Ember.ring,
                },
              ),
            ),
            child: done
                ? const Icon(Icons.check, size: 14, color: Ember.white)
                : skipped
                ? const Icon(Icons.remove, size: 14, color: Ember.ink3)
                : null,
          ),
        ),
      ),
    );
  }
}

/// One row of 30 squares per habit, oldest on the left.
class _LastThirtyDays extends StatelessWidget {
  const _LastThirtyDays({
    required this.habits,
    required this.logs,
    required this.today,
  });

  final List<Habit> habits;
  final List<HabitLog> logs;
  final String today;

  @override
  Widget build(BuildContext context) {
    Widget legend(Color color, String label, {Color? border}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: border == null ? null : Border.all(color: border),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Ember.meta),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          icon: Icons.calendar_today_outlined,
          title: 'Last 30 days',
          trailing: Wrap(
            spacing: 12,
            children: [
              legend(Ember.ink, 'Done'),
              legend(Ember.ring, 'Skipped'),
              legend(Ember.line, 'Missed'),
            ],
          ),
        ),
        Tile(
          child: Column(
            children: [
              for (final habit in habits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _HeatRow(
                    habit: habit,
                    marks: marksOf(habit.id, logs),
                    today: today,
                  ),
                ),
              Row(
                children: [
                  const SizedBox(width: 110),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatShortDay(addDays(today, -29), today: today),
                          style: Ember.caption,
                        ),
                        Text(
                          formatShortDay(addDays(today, -15), today: today),
                          style: Ember.caption,
                        ),
                        Text('Today', style: Ember.caption),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeatRow extends StatelessWidget {
  const _HeatRow({
    required this.habit,
    required this.marks,
    required this.today,
  });

  final Habit habit;
  final Map<String, String> marks;
  final String today;

  @override
  Widget build(BuildContext context) {
    final days = lastDays(habit, marks, today: today, count: 30);
    final kept = keptOver(habit, marks, end: today, today: today);
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            habit.name,
            overflow: TextOverflow.ellipsis,
            style: Ember.meta.copyWith(color: Ember.ink),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              for (var i = 0; i < days.length; i++) ...[
                if (i > 0) const SizedBox(width: 3),
                Expanded(
                  child: AnimatedContainer(
                    duration: Motion.of(context, Motion.base),
                    curve: Motion.soft,
                    height: 16,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: switch (days[i]) {
                        HabitDay.done => Ember.ink,
                        HabitDay.skipped => Ember.ring,
                        HabitDay.missed => Ember.line,
                        HabitDay.open => Colors.transparent,
                        HabitDay.off => const Color(0xFFF7F6F2),
                      },
                      border: days[i] == HabitDay.open
                          ? Border.all(color: Ember.now, width: 1.6)
                          : null,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            kept.percent == null ? '—' : '${kept.percent}%',
            textAlign: TextAlign.right,
            style: Ember.meta,
          ),
        ),
      ],
    );
  }
}

class _HabitForm extends ConsumerStatefulWidget {
  const _HabitForm({
    super.key,
    required this.habit,
    required this.areas,
    required this.onClose,
  });

  /// The habit being changed, or null to add a new one.
  final Habit? habit;
  final List<LifeArea> areas;
  final VoidCallback onClose;

  @override
  ConsumerState<_HabitForm> createState() => _HabitFormState();
}

class _HabitFormState extends ConsumerState<_HabitForm> {
  late final _name = TextEditingController(text: widget.habit?.name ?? '');
  late String? _areaId = widget.habit?.lifeAreaId;
  late String? _time = widget.habit?.usualTime;
  late String _days = widget.habit?.days ?? allDays;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final current = _time?.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 7, minute: 0)
          : TimeOfDay(
              hour: int.parse(current[0]),
              minute: int.parse(current[1]),
            ),
      helpText: 'Usual time',
    );
    if (picked != null && mounted) {
      setState(() {
        _time =
            '${picked.hour.toString().padLeft(2, '0')}:'
            '${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _toggleDay(int weekday) {
    final digit = '$weekday';
    setState(() {
      _days = _days.contains(digit)
          ? _days.replaceAll(digit, '')
          : ((_days + digit).split('')..sort()).join();
    });
  }

  Future<void> _save() async {
    final userId = ref.read(userIdProvider);
    if (userId == null) return;
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Give the habit a name.');
      return;
    }
    if (_days.isEmpty) {
      setState(() => _error = 'Pick at least one day.');
      return;
    }
    final habits = ref.read(habitRepositoryProvider);
    try {
      final habit = widget.habit;
      if (habit == null) {
        await habits.addHabit(
          userId: userId,
          name: _name.text,
          lifeAreaId: _areaId,
          usualTime: _time,
          days: _days,
        );
        if (!mounted) return;
        _name.clear();
        setState(() {
          _error = null;
          _time = null;
          _days = allDays;
        });
      } else {
        await habits.updateHabit(
          habit.id,
          name: _name.text,
          lifeAreaId: _areaId,
          usualTime: _time,
          days: _days,
        );
        if (!mounted) return;
        setState(() => _error = null);
        showMessage(context, 'Saved.');
      }
    } catch (error) {
      // The typed name stays in the box, so nothing is lost.
      if (mounted) showMessage(context, 'Could not save. Try again. ($error)');
    }
  }

  Future<void> _delete() async {
    final habit = widget.habit!;
    final confirmed = await confirmDialog(
      context,
      title: 'Delete ${habit.name}?',
      message: 'The habit and its history are removed from all your devices.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await ref.read(habitRepositoryProvider).deleteHabit(habit.id);
      widget.onClose();
    } catch (error) {
      if (mounted) showMessage(context, 'Could not delete. ($error)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.habit != null;
    final areaIds = {for (final area in widget.areas) area.id};
    final time = _time;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(editing ? Icons.edit_outlined : Icons.add, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                editing ? 'Edit habit' : 'New habit',
                style: Ember.h2,
              ),
            ),
            if (editing)
              IconButton(
                tooltip: 'Close',
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const FieldLabel('Name'),
        TextField(
          key: const Key('habit-name'),
          controller: _name,
          onSubmitted: (_) => _save(),
          decoration: InputDecoration(
            hintText: 'Read 20 minutes',
            errorText: _error,
          ),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Life area'),
        DropdownButtonFormField<String?>(
          key: const Key('habit-area'),
          initialValue: areaIds.contains(_areaId) ? _areaId : null,
          isExpanded: true,
          style: Ember.text(13, 16, weight: 400, color: Ember.ink),
          items: [
            const DropdownMenuItem(value: null, child: Text('None')),
            for (final area in widget.areas)
              DropdownMenuItem(
                value: area.id,
                child: Text(area.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) => setState(() => _areaId = value),
        ),
        const SizedBox(height: 14),
        const FieldLabel('Days'),
        Row(
          children: [
            for (var weekday = 1; weekday <= 7; weekday++) ...[
              if (weekday > 1) const SizedBox(width: 4),
              Expanded(
                child: _DayToggle(
                  key: Key('habit-day-$weekday'),
                  letter: dayLetters[weekday - 1],
                  name: weekdayNames[weekday - 1],
                  on: _days.contains('$weekday'),
                  onTap: () => _toggleDay(weekday),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(describeDays(_days), style: Ember.meta),
        const SizedBox(height: 14),
        const FieldLabel('Usual time (optional)'),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('habit-time'),
                onPressed: _pickTime,
                icon: const Icon(Icons.schedule, size: 16),
                label: Text(time == null ? 'Any time' : formatTime(time)),
              ),
            ),
            if (time != null)
              IconButton(
                tooltip: 'Remove the time',
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _time = null),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const SizedBox(height: 18),
        FilledButton(
          key: const Key('habit-save'),
          onPressed: _save,
          child: Text(editing ? 'Save' : 'Add habit'),
        ),
        if (editing) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            key: const Key('habit-delete'),
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete habit'),
          ),
        ],
      ],
    );
  }
}

/// One weekday button in the days picker.
class _DayToggle extends StatelessWidget {
  const _DayToggle({
    super.key,
    required this.letter,
    required this.name,
    required this.on,
    required this.onTap,
  });

  final String letter;
  final String name;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on,
      label: name,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.base),
        curve: Motion.soft,
        height: 32,
        decoration: BoxDecoration(
          color: on ? Ember.ink : Ember.tile,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Text(
                letter,
                style: Ember.text(12, 15, color: on ? Ember.white : Ember.ink2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
