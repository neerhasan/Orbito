import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/local/app_database.dart';
import '../../domain/dates.dart';
import '../../domain/focus.dart';
import '../../domain/sleep.dart' show formatTime, timeOf;
import '../../ui/ember.dart';
import '../../ui/motion.dart';
import '../../ui/widgets.dart';

/// Redraws its widget once a second while it is shown, so a clock moves.
mixin _EverySecond<T extends StatefulWidget> on State<T> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }
}

/// `9:05 AM` from a stored time.
String _clockOf(String stored) {
  final moment = parseStoredTime(stored);
  if (moment == null) return '';
  return formatTime(timeOf(moment.hour * 60 + moment.minute));
}

/// Starts a session and tells the user when that fails.
Future<void> startFocus(
  BuildContext context,
  WidgetRef ref, {
  String? taskId,
  int? targetMinutes,
}) async {
  final userId = ref.read(userIdProvider);
  if (userId == null) return;
  try {
    await ref
        .read(focusRepositoryProvider)
        .start(userId: userId, taskId: taskId, targetMinutes: targetMinutes);
  } catch (error) {
    if (context.mounted) {
      showMessage(context, 'Could not start the timer. ($error)');
    }
  }
}

/// The Focus page while no timer runs: pick a task (or none), pick a
/// planned length, start. Today's sessions are listed below.
class FocusPage extends ConsumerStatefulWidget {
  const FocusPage({super.key});

  @override
  ConsumerState<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends ConsumerState<FocusPage> {
  int? _target = 25;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider).value ?? const <Task>[];
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final sessions =
        ref.watch(focusSessionsProvider).value ?? const <FocusSession>[];
    final today = dayKey(ref.watch(clockProvider)());
    final byTask = secondsByTask(sessions);
    final open = tasks.where((task) => task.status != TaskStatus.done).toList()
      ..sort((a, b) => (a.dueDate ?? '9999').compareTo(b.dueDate ?? '9999'));
    final todaySessions = sessionsOn(sessions, today);
    final todaySeconds = todaySessions.fold<int>(
      0,
      (sum, session) => sum + session.focusSeconds,
    );
    Task? taskOf(String? id) =>
        tasks.where((task) => task.id == id).firstOrNull;

    return PageLayout(
      main: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: PageHeader(
                title: 'Focus',
                subtitle:
                    'Pick a task. Its time adds to the task and its project.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                key: const Key('focus-start-free'),
                onPressed: () =>
                    startFocus(context, ref, targetMinutes: _target),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Start without a task'),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Text('Planned length', style: Ember.meta),
            const SizedBox(width: 12),
            Segmented<int?>(
              keyPrefix: 'focus-length',
              value: _target,
              options: [
                for (final minutes in targetChoices)
                  (minutes, minutes == null ? 'No limit' : '${minutes}m'),
              ],
              onChanged: (value) => setState(() => _target = value),
            ),
          ],
        ),
        if (open.isEmpty)
          const EmptyHint(
            title: 'No open tasks',
            text: 'Start without a task, or add one first.',
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final task in open.take(12))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _TaskToStart(
                    task: task,
                    project: projects
                        .where((project) => project.id == task.projectId)
                        .firstOrNull,
                    seconds: byTask[task.id] ?? 0,
                    onStart: () => startFocus(
                      context,
                      ref,
                      taskId: task.id,
                      targetMinutes: _target,
                    ),
                  ),
                ),
            ],
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              icon: Icons.schedule,
              title: 'Today',
              trailing: Text(
                '${formatWorked(todaySeconds)} focused · '
                '${countOf(todaySessions.length, 'session')}',
                key: const Key('focus-today-total'),
                style: Ember.meta,
              ),
            ),
            if (todaySessions.isEmpty)
              Text('No sessions yet today.', style: Ember.meta)
            else
              for (final session in todaySessions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Tile(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            taskOf(session.taskId)?.title ?? 'No task',
                            overflow: TextOverflow.ellipsis,
                            style: Ember.item.copyWith(color: Ember.ink),
                          ),
                        ),
                        Text(_clockOf(session.startedAt), style: Ember.meta),
                        SizedBox(
                          width: 70,
                          child: Text(
                            formatWorked(session.focusSeconds),
                            textAlign: TextAlign.right,
                            style: Ember.item.copyWith(color: Ember.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ],
    );
  }
}

class _TaskToStart extends StatelessWidget {
  const _TaskToStart({
    required this.task,
    required this.project,
    required this.seconds,
    required this.onStart,
  });

  final Task task;
  final Project? project;
  final int seconds;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Tile(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              task.title,
              overflow: TextOverflow.ellipsis,
              style: Ember.item.copyWith(color: Ember.ink),
            ),
          ),
          if (project != null) ...[
            NameChip(
              label: project!.name,
              swatch: ProjectColors.of(project!.color),
              icon: ItemIcons.of(project!.icon),
            ),
            const SizedBox(width: 10),
          ],
          SizedBox(
            width: 64,
            child: Text(
              seconds == 0 ? '' : formatWorked(seconds),
              textAlign: TextAlign.right,
              style: Ember.meta,
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            key: Key('focus-start-${task.id}'),
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Start'),
          ),
        ],
      ),
    );
  }
}

/// The full-window focus mode (design: `Focus.dc.html`), shown while a timer
/// runs and the Focus page is open. [onExit] goes back to the app; the
/// timer keeps running.
class FocusModeView extends ConsumerStatefulWidget {
  const FocusModeView({super.key, required this.timer, required this.onExit});

  final FocusTimer timer;
  final VoidCallback onExit;

  @override
  ConsumerState<FocusModeView> createState() => _FocusModeViewState();
}

class _FocusModeViewState extends ConsumerState<FocusModeView>
    with _EverySecond, SingleTickerProviderStateMixin {
  /// A slow, soft glow behind the ring while the clock runs.
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final calm = Motion.reduced(context);
    if (calm && _breath.isAnimating) _breath.stop();
    if (!calm && !_breath.isAnimating) _breath.repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  Future<void> _togglePause() async {
    try {
      await ref.read(focusRepositoryProvider).togglePause();
    } catch (error) {
      if (mounted) showMessage(context, 'Could not pause. ($error)');
    }
  }

  Future<void> _stop({required bool completeTask}) async {
    int? saved;
    try {
      saved = await ref
          .read(focusRepositoryProvider)
          .stop(completeTask: completeTask);
    } catch (error) {
      if (mounted) showMessage(context, 'Could not stop. ($error)');
      return;
    }
    if (!mounted) return;
    showMessage(
      context,
      saved == null
          ? 'Under a minute, so it was not saved as a session.'
          : 'Saved ${formatWorked(saved)} of focus.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final timer = widget.timer;
    final tasks = ref.watch(tasksProvider).value ?? const <Task>[];
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final goals = ref.watch(goalsProvider).value ?? const <Goal>[];
    final sessions =
        ref.watch(focusSessionsProvider).value ?? const <FocusSession>[];
    final now = ref.watch(clockProvider)();
    final task = tasks.where((t) => t.id == timer.taskId).firstOrNull;
    final project = projects.where((p) => p.id == task?.projectId).firstOrNull;
    final goal = goals.where((g) => g.id == project?.goalId).firstOrNull;
    final worked = workedMs(timer, now);
    final running = isRunning(timer);
    final target = timer.targetMinutes;
    final targetMs = target == null ? null : target * 60000;
    final started = _clockOf(timer.startedAt);
    // With a planned length the ring fills towards it; without one it
    // makes one turn per hour.
    final fill = targetMs == null
        ? (worked % 3600000) / 3600000
        : math.min(1.0, worked / targetMs);
    final reached = targetMs != null && worked >= targetMs;
    final onTask = secondsByTask(sessions)[task?.id] ?? 0;
    final String below;
    if (reached) {
      below = 'Planned length reached';
    } else if (targetMs == null) {
      below = running ? 'No planned length' : 'Paused';
    } else {
      below = '${running ? '' : 'Paused · '}of ${formatClock(targetMs)}';
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onExit,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Ember.shell,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Ember.now,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: Ember.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Focus mode · started $started',
                        style: Ember.text(13, 16, color: Ember.onShell2),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        key: const Key('focus-exit'),
                        onPressed: widget.onExit,
                        style: TextButton.styleFrom(
                          backgroundColor: Ember.raised,
                          foregroundColor: Ember.onShell,
                        ),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Back to Orbito  ·  Esc'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              vertical: 24,
                              horizontal: 16,
                            ),
                            child: Column(
                              children: [
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    if (project != null)
                                      _DarkTag(project.name, strong: true),
                                    if (goal != null)
                                      _DarkTag('Goal: ${goal.title}'),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  task?.title ?? 'Focus session',
                                  key: const Key('focus-title'),
                                  textAlign: TextAlign.center,
                                  style: Ember.text(
                                    28,
                                    34,
                                    weight: 600,
                                    color: Ember.onShell,
                                    letterSpacing: -0.02,
                                  ),
                                ),
                                const SizedBox(height: 26),
                                _Ring(
                                  fill: fill,
                                  breath: _breath,
                                  running: running,
                                  clock: formatClock(worked),
                                  below: below,
                                ),
                                const SizedBox(height: 26),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    FilledButton.icon(
                                      key: const Key('focus-stop'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Ember.raised,
                                        foregroundColor: Ember.onShell,
                                        minimumSize: const Size(0, 44),
                                      ),
                                      onPressed: () =>
                                          _stop(completeTask: false),
                                      icon: const Icon(
                                        Icons.stop_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Stop and save'),
                                    ),
                                    const SizedBox(width: 12),
                                    _PauseButton(
                                      running: running,
                                      onTap: _togglePause,
                                    ),
                                    const SizedBox(width: 12),
                                    if (task != null)
                                      FilledButton.icon(
                                        key: const Key('focus-done'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Ember.white,
                                          foregroundColor: Ember.ink,
                                          minimumSize: const Size(0, 44),
                                        ),
                                        onPressed: () =>
                                            _stop(completeTask: true),
                                        icon: const Icon(Icons.check, size: 18),
                                        label: const Text('Task done'),
                                      )
                                    else
                                      const SizedBox(width: 120),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 440,
                                  ),
                                  child: Text(
                                    task == null
                                        ? 'Stop and save keeps this time as '
                                              'a session without a task.'
                                        : 'Stop and save keeps the task open '
                                              'and adds this time to it. Task '
                                              'done also completes it.',
                                    textAlign: TextAlign.center,
                                    style: Ember.text(
                                      12,
                                      15,
                                      weight: 400,
                                      color: Ember.onShell2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 340,
                          child: Panel(
                            padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                            children: [
                              _SessionSummary(
                                started: started,
                                worked: worked,
                                running: running,
                                onTaskBefore: onTask,
                                hasTask: task != null,
                              ),
                              if (task != null)
                                _QuickNote(key: ValueKey(task.id), task: task),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DarkTag extends StatelessWidget {
  const _DarkTag(this.label, {this.strong = false});

  final String label;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: strong ? Ember.active : Ember.raised,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Ember.text(
          11,
          13,
          color: strong ? Ember.onShell : Ember.onShell2,
        ),
      ),
    );
  }
}

/// The big ring with the clock. The orange arc flows smoothly as time
/// passes, and a soft glow breathes behind it while the clock runs.
class _Ring extends StatelessWidget {
  const _Ring({
    required this.fill,
    required this.breath,
    required this.running,
    required this.clock,
    required this.below,
  });

  final double fill;
  final Animation<double> breath;
  final bool running;
  final String clock;
  final String below;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (running)
            AnimatedBuilder(
              animation: breath,
              builder: (context, _) {
                final t = Curves.easeInOut.transform(breath.value);
                return Container(
                  width: 250 + 30 * t,
                  height: 250 + 30 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Ember.now.withValues(alpha: 0.10 + 0.06 * t),
                        Ember.now.withValues(alpha: 0),
                      ],
                    ),
                  ),
                );
              },
            ),
          TweenAnimationBuilder<double>(
            tween: Tween(end: fill),
            duration: Motion.of(context, const Duration(milliseconds: 900)),
            curve: Curves.linear,
            builder: (context, value, _) => CustomPaint(
              size: const Size(300, 300),
              painter: _RingPainter(value),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDefaultTextStyle(
                duration: Motion.of(context, Motion.base),
                curve: Motion.soft,
                style: Ember.text(
                  60,
                  66,
                  weight: 700,
                  color: running ? Ember.now : Ember.onShell3,
                  letterSpacing: -0.04,
                ),
                child: Text(
                  clock,
                  key: const Key('focus-clock'),
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                below,
                style: Ember.text(13, 16, weight: 400, color: Ember.onShell2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fill);

  final double fill;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 8;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Ember.raised
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
    if (fill <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * fill,
      false,
      Paint()
        ..color = Ember.now
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fill != fill;
}

class _PauseButton extends StatelessWidget {
  const _PauseButton({required this.running, required this.onTap});

  final bool running;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: running ? 'Pause' : 'Resume',
      child: Pressable(
        child: Material(
          color: Ember.now,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('focus-pause'),
            onTap: onTap,
            child: SizedBox(
              width: 64,
              height: 64,
              child: AnimatedSwitcher(
                duration: Motion.of(context, Motion.fast),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  key: ValueKey(running),
                  size: 28,
                  color: Ember.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({
    required this.started,
    required this.worked,
    required this.running,
    required this.onTaskBefore,
    required this.hasTask,
  });

  final String started;
  final int worked;
  final bool running;
  final int onTaskBefore;
  final bool hasTask;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          icon: Icons.timer_outlined,
          title: 'This session',
          trailing: Text('Started $started', style: Ember.meta),
        ),
        StatTile(
          label: running ? 'Focused so far' : 'Focused so far · paused',
          value: formatWorked(worked ~/ 1000),
          detail: hasTask
              ? 'This task in total: '
                    '${formatWorked(onTaskBefore + worked ~/ 1000)}'
              : 'Not linked to a task',
        ),
      ],
    );
  }
}

/// Notes on the task, written without leaving focus (the design's "Quick
/// note"). They are the same notes as on the task.
class _QuickNote extends ConsumerStatefulWidget {
  const _QuickNote({super.key, required this.task});

  final Task task;

  @override
  ConsumerState<_QuickNote> createState() => _QuickNoteState();
}

class _QuickNoteState extends ConsumerState<_QuickNote> {
  late final _notes = TextEditingController(text: widget.task.notes ?? '');

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final task = widget.task;
    try {
      await ref
          .read(taskRepositoryProvider)
          .updateTask(
            task.id,
            title: task.title,
            projectId: task.projectId,
            dueDate: task.dueDate,
            priority: task.priority,
            notes: _notes.text,
          );
      if (mounted) showMessage(context, 'Note saved to the task.');
    } catch (error) {
      if (mounted) showMessage(context, 'Could not save. Try again. ($error)');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Task notes', style: Ember.h3),
        const SizedBox(height: 8),
        TextField(
          key: const Key('focus-notes'),
          controller: _notes,
          minLines: 4,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: 'Jot an idea without leaving focus. Saved to the task.',
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton(
            key: const Key('focus-notes-save'),
            onPressed: _save,
            child: const Text('Save note'),
          ),
        ),
      ],
    );
  }
}

/// The small running timer in the side menu, shown while the user is away
/// from focus mode. Tapping it opens focus mode again.
class FocusPill extends ConsumerStatefulWidget {
  const FocusPill({super.key, required this.timer, required this.onOpen});

  final FocusTimer timer;
  final VoidCallback onOpen;

  @override
  ConsumerState<FocusPill> createState() => _FocusPillState();
}

class _FocusPillState extends ConsumerState<FocusPill> with _EverySecond {
  @override
  Widget build(BuildContext context) {
    final timer = widget.timer;
    final tasks = ref.watch(tasksProvider).value ?? const <Task>[];
    final task = tasks.where((t) => t.id == timer.taskId).firstOrNull;
    final running = isRunning(timer);
    final worked = workedMs(timer, ref.watch(clockProvider)());
    return Appear(
      child: Material(
        color: Ember.raised,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('focus-pill'),
          onTap: widget.onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: Motion.of(context, Motion.base),
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: running ? Ember.now : Ember.onShell3,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task?.title ?? 'Focus',
                    overflow: TextOverflow.ellipsis,
                    style: Ember.text(12, 15, color: Ember.onShell),
                  ),
                ),
                Text(
                  formatClock(worked),
                  style: Ember.text(12, 15, color: Ember.onShell2).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                IconButton(
                  key: const Key('focus-pill-pause'),
                  tooltip: running ? 'Pause' : 'Resume',
                  iconSize: 16,
                  visualDensity: VisualDensity.compact,
                  color: Ember.onShell,
                  onPressed: () =>
                      ref.read(focusRepositoryProvider).togglePause(),
                  icon: Icon(
                    running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
