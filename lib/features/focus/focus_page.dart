import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/local/app_database.dart';
import '../../domain/dates.dart';
import '../../domain/focus.dart';
import '../../domain/focus_report.dart';
import '../../ui/ember.dart';
import '../../ui/motion.dart';
import '../../ui/widgets.dart';
import '../../ui/window_frame.dart';
import 'focus_parts.dart';
import 'focus_report_view.dart';

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

/// Starts a session and tells the user when that fails.
Future<void> startFocus(
  BuildContext context,
  WidgetRef ref, {
  String? taskId,
  int? targetMinutes,
}) async {
  final userId = ref.read(userIdProvider);
  if (userId == null) return;
  ref.read(focusBreakProvider.notifier).end();
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

/// How long a break after a countdown lasts.
const focusBreakLength = Duration(minutes: 5);

/// The end of the running break, or null when there is none. A break is
/// kept only while the app is open and is never saved as focus.
class FocusBreak extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void start(DateTime now) => state = now.add(focusBreakLength);

  void end() => state = null;
}

final focusBreakProvider = NotifierProvider<FocusBreak, DateTime?>(
  FocusBreak.new,
);

/// The countdown lengths offered, in minutes.
const _lengths = [25, 45, 60, 90];

/// The Focus page while no timer runs: the timer in the middle (countdown
/// or stopwatch), today's tasks and records on the right, and the report
/// one tap away.
class FocusPage extends ConsumerStatefulWidget {
  const FocusPage({super.key});

  @override
  ConsumerState<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends ConsumerState<FocusPage> {
  var _stopwatch = false;
  var _length = 25;
  String? _picked;
  var _report = false;
  var _allTasks = false;

  int? get _target => _stopwatch ? null : _length;

  Future<void> _complete(Task task) async {
    try {
      await ref.read(taskRepositoryProvider).setDone(task.id, done: true);
      if (_picked == task.id) setState(() => _picked = null);
      if (mounted) showMessage(context, 'Done: ${task.title}');
    } catch (error) {
      if (mounted) showMessage(context, 'Could not save. ($error)');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_report) {
      return FocusReportView(onBack: () => setState(() => _report = false));
    }
    final tasks = ref.watch(tasksProvider).value ?? const <Task>[];
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final sessions =
        ref.watch(focusSessionsProvider).value ?? const <FocusSession>[];
    final today = dayKey(ref.watch(clockProvider)());
    final tasksById = {for (final task in tasks) task.id: task};
    final projectsById = {for (final project in projects) project.id: project};
    final todaySessions = sessionsOn(sessions, today);
    final todaySeconds = totalSeconds(todaySessions);
    final sessionsToday = <String, int>{};
    for (final session in todaySessions) {
      final id = session.taskId;
      if (id != null) sessionsToday[id] = (sessionsToday[id] ?? 0) + 1;
    }
    // Tasks due soonest first; tasks with no date last.
    final open = tasks.where((task) => task.status != TaskStatus.done).toList()
      ..sort((a, b) => (a.dueDate ?? '9999').compareTo(b.dueDate ?? '9999'));
    final picked = tasksById[_picked];
    final shownTasks = _allTasks ? open : open.take(8).toList();

    return PageLayout(
      main: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: PageHeader(
                title: 'Focus',
                subtitle:
                    'Pick a task, then start. Its time adds to the '
                    'task and its project.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SoftButton(
                key: const Key('focus-report'),
                label: 'Report',
                icon: Icons.insights_outlined,
                onPressed: () => setState(() => _report = true),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Segmented<bool>(
              keyPrefix: 'focus-stopwatch',
              value: _stopwatch,
              options: const [(false, 'Countdown'), (true, 'Stopwatch')],
              onChanged: (value) => setState(() => _stopwatch = value),
            ),
            if (!_stopwatch)
              Segmented<int>(
                keyPrefix: 'focus-length',
                value: _length,
                options: [for (final m in _lengths) (m, '${m}m')],
                onChanged: (value) => setState(() => _length = value),
              ),
          ],
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _PickedTask(
              task: picked,
              project: projectsById[picked?.projectId],
              sessionsToday: sessionsToday[picked?.id] ?? 0,
              onClear: () => setState(() => _picked = null),
            ),
          ),
        ),
        _ReadyTimer(
          target: _target,
          taskPicked: picked != null,
          onStart: () => startFocus(
            context,
            ref,
            taskId: picked?.id,
            targetMinutes: _target,
          ),
          onStartFree: () => startFocus(context, ref, targetMinutes: _target),
        ),
      ],
      rail: [
        StatTile(
          key: const Key('focus-today-stat'),
          label: 'Focus time today',
          value: formatWorked(todaySeconds),
          detail: countOf(todaySessions.length, 'session'),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              icon: Icons.checklist_rounded,
              title: 'Tasks',
              trailing: Text(
                countOf(open.length, 'open task'),
                style: Ember.meta,
              ),
            ),
            if (open.isEmpty)
              const EmptyHint(
                title: 'No open tasks',
                text: 'Start without a task, or add one first.',
              )
            else ...[
              for (final task in shownTasks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: FocusTaskRow(
                    task: task,
                    project: projectsById[task.projectId],
                    sessionsToday: sessionsToday[task.id] ?? 0,
                    picked: task.id == _picked,
                    onPick: () => setState(
                      () => _picked = _picked == task.id ? null : task.id,
                    ),
                    onStart: () => startFocus(
                      context,
                      ref,
                      taskId: task.id,
                      targetMinutes: _target,
                    ),
                    onDone: () => _complete(task),
                  ),
                ),
              if (open.length > 8)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const Key('focus-tasks-more'),
                    onPressed: () => setState(() => _allTasks = !_allTasks),
                    child: Text(
                      _allTasks ? 'Show fewer' : 'Show all ${open.length}',
                    ),
                  ),
                ),
            ],
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
            FocusDayRecords(
              sessions: todaySessions,
              day: today,
              tasks: tasksById,
              projects: projectsById,
            ),
          ],
        ),
      ],
    );
  }
}

/// The task the next session is for, above the timer.
class _PickedTask extends StatelessWidget {
  const _PickedTask({
    required this.task,
    required this.project,
    required this.sessionsToday,
    required this.onClear,
  });

  final Task? task;
  final Project? project;
  final int sessionsToday;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final task = this.task;
    if (task == null) {
      return Text(
        'No task picked. Pick one on the right, or start without one.',
        key: const Key('focus-picked-none'),
        textAlign: TextAlign.center,
        style: Ember.meta,
      );
    }
    final swatch = project == null
        ? noProjectSwatch
        : ProjectColors.of(project!.color);
    return Tile(
      key: const Key('focus-picked'),
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      child: Row(
        children: [
          ColorDot(swatch.dot),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ember.item.copyWith(color: Ember.ink),
                ),
                if (project != null || sessionsToday > 0) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (project != null)
                        Text(
                          project!.name,
                          style: Ember.text(11, 13, color: swatch.text),
                        ),
                      if (project != null && sessionsToday > 0)
                        const SizedBox(width: 8),
                      SessionDots(count: sessionsToday, color: swatch.dot),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            key: const Key('focus-unpick'),
            tooltip: 'Clear the task',
            visualDensity: VisualDensity.compact,
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 16),
            color: Ember.ink2,
          ),
        ],
      ),
    );
  }
}

/// The ring before a session starts: the length that will count down (or
/// 00:00 for a stopwatch), or a running break after a countdown.
class _ReadyTimer extends ConsumerStatefulWidget {
  const _ReadyTimer({
    required this.target,
    required this.taskPicked,
    required this.onStart,
    required this.onStartFree,
  });

  final int? target;
  final bool taskPicked;
  final VoidCallback onStart;
  final VoidCallback onStartFree;

  @override
  ConsumerState<_ReadyTimer> createState() => _ReadyTimerState();
}

class _ReadyTimerState extends ConsumerState<_ReadyTimer> with _EverySecond {
  @override
  Widget build(BuildContext context) {
    final breakEnds = ref.watch(focusBreakProvider);
    final now = ref.watch(clockProvider)();
    final target = widget.target;
    final onBreak = breakEnds != null && now.isBefore(breakEnds);
    final breakOver = breakEnds != null && !onBreak;

    final String clock;
    final String below;
    var fill = 0.0;
    if (onBreak) {
      final left = breakEnds.difference(now).inMilliseconds;
      clock = formatClock(left + 999);
      below = 'Break · rest your eyes';
      fill = 1 - left / focusBreakLength.inMilliseconds;
    } else {
      clock = target == null ? '00:00' : formatClock(target * 60000);
      below = breakOver
          ? 'Break is over'
          : target == null
          ? 'Stopwatch'
          : 'Countdown';
    }

    return Column(
      children: [
        _Ring(
          fill: fill,
          running: onBreak,
          clock: clock,
          below: below,
          dark: false,
          breath: null,
        ),
        const SizedBox(height: 18),
        if (onBreak)
          OutlinedButton(
            key: const Key('focus-break-skip'),
            onPressed: () => ref.read(focusBreakProvider.notifier).end(),
            child: const Text('Skip the break'),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                key: const Key('focus-start'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: widget.onStart,
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text('Start to focus'),
              ),
              if (widget.taskPicked)
                OutlinedButton(
                  key: const Key('focus-start-free'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: widget.onStartFree,
                  child: const Text('Start without a task'),
                ),
            ],
          ),
      ],
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

  /// True while the window fills the whole screen.
  var _fullScreen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final calm = Motion.reduced(context);
    if (calm && _breath.isAnimating) _breath.stop();
    if (!calm && !_breath.isAnimating) _breath.repeat(reverse: true);
  }

  @override
  void dispose() {
    // Never leave the user stuck in full screen.
    if (_fullScreen) setWindowFullScreen(false);
    _breath.dispose();
    super.dispose();
  }

  void _setFullScreen(bool on) {
    setWindowFullScreen(on);
    setState(() => _fullScreen = on);
  }

  /// Esc leaves full screen first, then focus mode.
  void _escape() {
    if (_fullScreen) {
      _setFullScreen(false);
    } else {
      widget.onExit();
    }
  }

  void _exit() {
    if (_fullScreen) _setFullScreen(false);
    widget.onExit();
  }

  Future<void> _togglePause() async {
    try {
      await ref.read(focusRepositoryProvider).togglePause();
    } catch (error) {
      if (mounted) showMessage(context, 'Could not pause. ($error)');
    }
  }

  Future<void> _stop({
    required bool completeTask,
    bool takeBreak = false,
  }) async {
    if (_fullScreen) _setFullScreen(false);
    int? saved;
    try {
      saved = await ref
          .read(focusRepositoryProvider)
          .stop(completeTask: completeTask);
    } catch (error) {
      if (mounted) showMessage(context, 'Could not stop. ($error)');
      return;
    }
    if (takeBreak) {
      ref.read(focusBreakProvider.notifier).start(ref.read(clockProvider)());
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
    final today = dayKey(now);
    final tasksById = {for (final task in tasks) task.id: task};
    final projectsById = {for (final project in projects) project.id: project};
    final task = tasksById[timer.taskId];
    final project = projectsById[task?.projectId];
    final goal = goals.where((g) => g.id == project?.goalId).firstOrNull;
    final worked = workedMs(timer, now);
    final running = isRunning(timer);
    final target = timer.targetMinutes;
    final targetMs = target == null ? null : target * 60000;
    final started = clockOfStored(timer.startedAt);
    // A countdown fills towards its length and shows the time left; a
    // stopwatch makes one turn per hour and shows the time worked.
    final fill = targetMs == null
        ? (worked % 3600000) / 3600000
        : math.min(1.0, worked / targetMs);
    final reached = targetMs != null && worked >= targetMs;
    final left = remainingMs(timer, now);
    final clock = left == null ? formatClock(worked) : formatClock(left);
    final onTask = secondsByTask(sessions)[task?.id] ?? 0;
    final todaySessions = sessionsOn(sessions, today);
    final String below;
    if (reached) {
      below = 'Time is up';
    } else if (targetMs == null) {
      below = running ? 'Stopwatch' : 'Paused';
    } else {
      below = '${running ? '' : 'Paused · '}of ${formatClock(targetMs)}';
    }

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _escape},
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Ember.shell,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  // Dragging the top row moves the window.
                  WindowDragArea(
                    child: Row(
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
                          key: const Key('focus-fullscreen'),
                          onPressed: () => _setFullScreen(!_fullScreen),
                          style: TextButton.styleFrom(
                            backgroundColor: Ember.raised,
                            foregroundColor: Ember.onShell,
                          ),
                          icon: Icon(
                            _fullScreen
                                ? Icons.fullscreen_exit_rounded
                                : Icons.fullscreen_rounded,
                            size: 18,
                          ),
                          label: Text(
                            _fullScreen ? 'Leave full screen' : 'Full screen',
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          key: const Key('focus-exit'),
                          onPressed: _exit,
                          style: TextButton.styleFrom(
                            backgroundColor: Ember.raised,
                            foregroundColor: Ember.onShell,
                          ),
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text('Back to Orbito  ·  Esc'),
                        ),
                        // The window's own buttons, since Orbito hides the
                        // system title bar (not needed in full screen).
                        if (!_fullScreen) ...[
                          const SizedBox(width: 8),
                          const WindowButtons(),
                        ],
                      ],
                    ),
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
                                  running: running && !reached,
                                  clock: clock,
                                  below: below,
                                  dark: true,
                                ),
                                const SizedBox(height: 26),
                                if (reached) ...[
                                  FilledButton.icon(
                                    key: const Key('focus-break'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Ember.white,
                                      foregroundColor: Palette.light.ink,
                                      minimumSize: const Size(0, 44),
                                    ),
                                    onPressed: () => _stop(
                                      completeTask: false,
                                      takeBreak: true,
                                    ),
                                    icon: const Icon(
                                      Icons.free_breakfast_outlined,
                                      size: 18,
                                    ),
                                    label: Text(
                                      'Save and take a '
                                      '${focusBreakLength.inMinutes}-minute '
                                      'break',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
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
                                    if (!reached) ...[
                                      _PauseButton(
                                        running: running,
                                        onTap: _togglePause,
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    if (task != null)
                                      FilledButton.icon(
                                        key: const Key('focus-done'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Ember.white,
                                          foregroundColor: Palette.light.ink,
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
                                    reached
                                        ? 'The countdown is over. The '
                                              'planned '
                                              '${formatWorked(target! * 60)} '
                                              'is what gets saved.'
                                        : task == null
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
                                worked: savedMs(timer, now),
                                running: running,
                                onTaskBefore: onTask,
                                hasTask: task != null,
                              ),
                              if (task != null)
                                _QuickNote(key: ValueKey(task.id), task: task),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SectionHeader(
                                    icon: Icons.schedule,
                                    title: 'Today',
                                    trailing: Text(
                                      formatWorked(totalSeconds(todaySessions)),
                                      style: Ember.meta,
                                    ),
                                  ),
                                  FocusDayRecords(
                                    sessions: todaySessions,
                                    day: today,
                                    tasks: tasksById,
                                    projects: projectsById,
                                  ),
                                ],
                              ),
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

/// The big ring with the clock and a circle of small ticks. The orange arc
/// flows smoothly as time passes, and a soft glow breathes behind it while
/// the clock runs. [dark] is for focus mode; otherwise it sits on paper.
class _Ring extends StatelessWidget {
  const _Ring({
    required this.fill,
    required this.breath,
    required this.running,
    required this.clock,
    required this.below,
    required this.dark,
  });

  final double fill;
  final Animation<double>? breath;
  final bool running;
  final String clock;
  final String below;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final breath = this.breath;
    final idleInk = dark ? Ember.onShell3 : Ember.ink;
    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (running && breath != null)
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
              painter: _RingPainter(
                value,
                track: dark ? Ember.raised : Ember.tile,
                ticks: dark ? Ember.shellLine : Ember.line,
              ),
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
                  color: running ? Ember.now : idleInk,
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
                style: Ember.text(
                  13,
                  16,
                  weight: 400,
                  color: dark ? Ember.onShell2 : Ember.ink2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fill, {required this.track, required this.ticks});

  final double fill;
  final Color track;
  final Color ticks;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 8;
    // 60 small ticks just inside the ring, like a clock face.
    final tick = Paint()
      ..color = ticks
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 60; i++) {
      final angle = 2 * math.pi * i / 60 - math.pi / 2;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final outer = radius - 14;
      final inner = outer - (i % 5 == 0 ? 9 : 5);
      canvas.drawLine(
        center + direction * inner,
        center + direction * outer,
        tick,
      );
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
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
  bool shouldRepaint(_RingPainter old) =>
      old.fill != fill || old.track != track || old.ticks != ticks;
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

/// The running timer in the title bar, shown while the user is away from
/// focus mode. Tapping it opens focus mode again.
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
    final now = ref.watch(clockProvider)();
    // A countdown shows the time left; a stopwatch the time worked.
    final shown = remainingMs(timer, now) ?? workedMs(timer, now);
    // The title bar's timer (design: Titlebar.dc.html).
    return Appear(
      child: Material(
        color: Ember.raised,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('focus-pill'),
          onTap: widget.onOpen,
          child: SizedBox(
            height: 34,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
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
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        task?.title ?? 'Focus',
                        overflow: TextOverflow.ellipsis,
                        style: Ember.text(13, 16, color: Ember.onShell),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatClock(shown),
                    style:
                        Ember.text(
                          13,
                          16,
                          weight: 600,
                          color: running ? Ember.now : Ember.onShell2,
                        ).copyWith(
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
      ),
    );
  }
}
