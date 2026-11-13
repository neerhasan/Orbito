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
/// the top, today's checklist, the last 30 days, and on the right a form to
/// add or change a habit.
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

  Future<void> _mark(Habit habit, String today, String? status) async {
    final userId = ref.read(userIdProvider);
    if (userId == null) return;
    try {
      await ref
          .read(habitRepositoryProvider)
          .setMark(
            userId: userId,
            habitId: habit.id,
            day: today,
            status: status,
          );
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                icon: Icons.repeat,
                title: 'Today’s checklist',
                trailing: Text(
                  'Tap the ring when done · Skip keeps a rest day fair',
                  style: Ember.meta,
                ),
              ),
              for (final habit in habits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _HabitRow(
                    habit: habit,
                    area: areas
                        .where((area) => area.id == habit.lifeAreaId)
                        .firstOrNull,
                    marks: marksOf(habit.id, logs),
                    today: today,
                    selected: habit.id == _selectedId,
                    onTap: () => setState(() {
                      _selectedId = habit.id == _selectedId ? null : habit.id;
                    }),
                    onMark: (status) => _mark(habit, today, status),
                  ),
                ),
            ],
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

/// The large round button that marks a habit done today.
class _HabitRing extends StatelessWidget {
  const _HabitRing({
    required this.state,
    required this.label,
    required this.onTap,
  });

  final HabitDay state;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final done = state == HabitDay.done;
    return Semantics(
      button: true,
      checked: done,
      label: label,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.base),
            curve: Motion.soft,
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? Ember.ink : Colors.transparent,
              border: Border.all(
                color: done
                    ? Ember.ink
                    : state == HabitDay.open
                    ? Ember.ink2
                    : Ember.ring,
                width: 1.6,
              ),
            ),
            child: AnimatedScale(
              scale: done ? 1 : 0,
              duration: Motion.of(context, Motion.base),
              curve: Motion.settle,
              child: const Icon(Icons.check, size: 14, color: Ember.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// The last 7 days as dots: black done, orange ring today, grey ring
/// skipped, grey dot missed, faint dot for days off.
class _WeekDots extends StatelessWidget {
  const _WeekDots(this.days);

  final List<HabitDay> days;

  @override
  Widget build(BuildContext context) {
    final done = days.where((day) => day == HabitDay.done).length;
    return Semantics(
      label: 'Last 7 days: $done done',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < days.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            AnimatedContainer(
              duration: Motion.of(context, Motion.base),
              curve: Motion.soft,
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: switch (days[i]) {
                  HabitDay.done => Ember.ink,
                  HabitDay.missed => const Color(0xFFDAD8D1),
                  HabitDay.off => Ember.line,
                  HabitDay.open || HabitDay.skipped => Colors.transparent,
                },
                border: switch (days[i]) {
                  HabitDay.open => Border.all(color: Ember.now, width: 1.6),
                  HabitDay.skipped => Border.all(color: Ember.ring, width: 1.6),
                  _ => null,
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  const _HabitRow({
    required this.habit,
    required this.area,
    required this.marks,
    required this.today,
    required this.selected,
    required this.onTap,
    required this.onMark,
  });

  final Habit habit;
  final LifeArea? area;
  final Map<String, String> marks;
  final String today;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<String?> onMark;

  @override
  Widget build(BuildContext context) {
    final state = dayState(habit, marks, today, today: today);
    final week = lastDays(habit, marks, today: today);
    final kept = keptOver(habit, marks, end: today, today: today);
    final weekDone = week.where((day) => day == HabitDay.done).length;
    final weekPlanned = week
        .where((day) => day != HabitDay.off && day != HabitDay.skipped)
        .length;
    final time = habit.usualTime;
    final when = [
      describeDays(habit.days),
      if (time != null) formatTime(time),
    ].join(' · ');

    return Tile(
      key: Key('habit-${habit.id}'),
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _HabitRing(
            state: state,
            label: '${state == HabitDay.done ? 'Undo' : 'Done'} ${habit.name}',
            onTap: state == HabitDay.off && marks[today] == null
                ? null
                : () => onMark(state == HabitDay.done ? null : HabitMark.done),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedDefaultTextStyle(
                  duration: Motion.of(context, Motion.base),
                  curve: Motion.soft,
                  style: Ember.text(
                    13,
                    16,
                    weight: 600,
                    color: state == HabitDay.done ? Ember.ink3 : Ember.ink,
                  ),
                  child: Text(habit.name, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (area != null)
                      NameChip(
                        label: area!.name,
                        swatch: AreaColors.of(area!.color),
                        icon: ItemIcons.all[area!.icon],
                      ),
                    Text(when, style: Ember.meta),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _WeekDots(week),
          const SizedBox(width: 14),
          SizedBox(
            width: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  kept.percent == null ? '—' : '${kept.percent}%',
                  style: Ember.item.copyWith(color: Ember.ink),
                ),
                Text(
                  weekPlanned == 0
                      ? 'No planned days'
                      : '$weekDone of $weekPlanned days',
                  style: Ember.meta,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Align(
              alignment: Alignment.centerRight,
              child: switch (state) {
                HabitDay.open => OutlinedButton(
                  key: Key('habit-skip-${habit.id}'),
                  onPressed: () => onMark(HabitMark.skip),
                  child: const Text('Skip'),
                ),
                HabitDay.skipped => OutlinedButton(
                  key: Key('habit-unskip-${habit.id}'),
                  onPressed: () => onMark(null),
                  child: const Text('Unskip'),
                ),
                HabitDay.done => Text('Done', style: Ember.meta),
                _ => Text('Day off', style: Ember.meta),
              },
            ),
          ),
        ],
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
