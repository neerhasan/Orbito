import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/app_database.dart';
import '../domain/dates.dart';
import '../domain/habits.dart' show todayProgress;
import '../features/focus/focus_page.dart';
import '../ui/ember.dart';
import '../ui/motion.dart';
import '../ui/widgets.dart';
import 'providers.dart';

/// The pages the side menu can open.
enum AppPage {
  tasks('Tasks', Icons.check_circle_outline),
  projects('Projects', Icons.folder_outlined),
  goals('Goals', Icons.flag_outlined),
  habits('Habits', Icons.repeat),
  sleep('Sleep', Icons.bedtime_outlined),
  focus('Focus', Icons.timer_outlined),
  areas('Life areas', Icons.blur_circular_outlined);

  const AppPage(this.label, this.icon);

  final String label;
  final IconData icon;
}

class CurrentPage extends Notifier<AppPage> {
  @override
  AppPage build() => AppPage.tasks;

  void open(AppPage page) => state = page;
}

/// The page that is open now.
final currentPageProvider = NotifierProvider<CurrentPage, AppPage>(
  CurrentPage.new,
);

/// True after the user asked for a new task (the "New" button) until the
/// Tasks page has put the cursor in its "Add a task" box.
class AddTaskRequest extends Notifier<bool> {
  @override
  bool build() => false;

  void ask() => state = true;

  void handled() => state = false;
}

final addTaskRequestProvider = NotifierProvider<AddTaskRequest, bool>(
  AddTaskRequest.new,
);

/// The frame around every page once the user is signed in (design:
/// `docs/design/source/Titlebar.dc.html` and `Sidebar.dc.html`): the title
/// bar on top, the side menu on the left and the open page on the right.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.email, required this.pageBuilder});

  /// Shown in the account menu.
  final String email;

  /// Builds the content for a page.
  final Widget Function(AppPage page) pageBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(currentPageProvider);
    final timer = ref.watch(focusTimerProvider).value;
    // While a timer runs, the Focus page is the full-window focus mode.
    // The app and focus mode flow into each other.
    return SoftSwitcher(
      child: page == AppPage.focus && timer != null
          ? FocusModeView(
              key: const ValueKey('focus-mode'),
              timer: timer,
              onExit: () =>
                  ref.read(currentPageProvider.notifier).open(AppPage.tasks),
            )
          : _frame(page),
    );
  }

  Widget _frame(AppPage page) {
    return Scaffold(
      key: const ValueKey('app-frame'),
      backgroundColor: Ember.shell,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TitleBar(email: email),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(width: 232, child: _SideMenu()),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 8, 8),
                      // Pages cross-fade and rise softly into place.
                      child: SoftSwitcher(
                        child: KeyedSubtree(
                          key: ValueKey(page),
                          child: pageBuilder(page),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The bar across the top: logo, search, the running timer, New and the
/// account button.
class _TitleBar extends ConsumerWidget {
  const _TitleBar({required this.email});

  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(focusTimerProvider).value;
    void open(AppPage target) =>
        ref.read(currentPageProvider.notifier).open(target);

    return Container(
      height: 58,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      color: Ember.shell,
      child: Row(
        children: [
          Expanded(
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
                    Icons.show_chart,
                    size: 16,
                    color: Ember.white,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Orbito',
                  style: Ember.text(14, 17, weight: 600, color: Ember.onShell),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 240, maxWidth: 480),
            child: const _SearchBox(),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // The running timer stays in view on every page.
                if (timer != null) ...[
                  Flexible(
                    child: FocusPill(
                      timer: timer,
                      onOpen: () => open(AppPage.focus),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                _NewButton(
                  onPick: (target) {
                    open(target);
                    if (target == AppPage.tasks) {
                      ref.read(addTaskRequestProvider.notifier).ask();
                    }
                  },
                ),
                const SizedBox(width: 8),
                _AccountButton(email: email),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The search box. It opens the Quick Launcher once that exists (M3).
class _SearchBox extends StatelessWidget {
  const _SearchBox();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Search, add or log anything',
      child: Material(
        color: Ember.raised,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('search'),
          onTap: () => showMessage(
            context,
            'Search and the Quick Launcher come in the next step (M3).',
          ),
          child: SizedBox(
            height: 34,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 16, color: Ember.onShell2),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Search, add or log anything…',
                      overflow: TextOverflow.ellipsis,
                      style: Ember.text(
                        13,
                        16,
                        weight: 400,
                        color: Ember.onShell2,
                      ),
                    ),
                  ),
                  const Kbd('Ctrl K', dark: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "New": a small menu of what can be added.
class _NewButton extends StatelessWidget {
  const _NewButton({required this.onPick});

  final ValueChanged<AppPage> onPick;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AppPage>(
      key: const Key('new-menu'),
      tooltip: 'New',
      position: PopupMenuPosition.under,
      color: Ember.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: onPick,
      itemBuilder: (context) => [
        for (final (page, label) in const [
          (AppPage.tasks, 'Task'),
          (AppPage.projects, 'Project'),
          (AppPage.goals, 'Goal'),
          (AppPage.habits, 'Habit'),
          (AppPage.sleep, 'Night of sleep'),
          (AppPage.areas, 'Life area'),
        ])
          PopupMenuItem(
            key: Key('new-${page.name}'),
            value: page,
            child: Row(
              children: [
                Icon(page.icon, size: 16, color: Ember.ink2),
                const SizedBox(width: 10),
                Text(label, style: Ember.item.copyWith(color: Ember.ink)),
              ],
            ),
          ),
      ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Ember.onShell,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 16, color: Ember.ink),
            const SizedBox(width: 6),
            Text(
              'New',
              style: Ember.text(13, 16, weight: 600, color: Ember.ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// The round account button with the first letter of the email. Its menu
/// shows the email and signs out.
class _AccountButton extends ConsumerWidget {
  const _AccountButton({required this.email});

  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      key: const Key('account-menu'),
      tooltip: 'Account',
      position: PopupMenuPosition.under,
      color: Ember.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (value) async {
        if (value != 'sign-out') return;
        try {
          await ref.read(syncServiceProvider).signOut();
        } catch (error) {
          if (context.mounted) {
            showMessage(context, 'Could not sign out. ($error)');
          }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(enabled: false, child: Text(email, style: Ember.meta)),
        PopupMenuItem(
          key: const Key('sign-out'),
          value: 'sign-out',
          child: Row(
            children: [
              const Icon(Icons.logout, size: 16, color: Ember.ink2),
              const SizedBox(width: 10),
              Text('Sign out', style: Ember.item.copyWith(color: Ember.ink)),
            ],
          ),
        ),
      ],
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Ember.active,
          shape: BoxShape.circle,
        ),
        child: Text(
          email.isEmpty ? '?' : email[0].toUpperCase(),
          style: Ember.text(13, 16, weight: 600, color: Ember.onShell),
        ),
      ),
    );
  }
}

class _SideMenu extends ConsumerWidget {
  const _SideMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(currentPageProvider);
    final areas = ref.watch(lifeAreasProvider).value ?? const <LifeArea>[];
    final tasks = ref.watch(tasksProvider).value ?? const <Task>[];
    final habits = ref.watch(habitsProvider).value ?? const <Habit>[];
    final logs = ref.watch(habitLogsProvider).value ?? const <HabitLog>[];
    final today = dayKey(ref.watch(clockProvider)());
    final openTasks = tasks.where((t) => t.status != TaskStatus.done).length;
    final habitsToday = todayProgress(habits, logs, today: today);
    final habitsLeft = habitsToday.planned - habitsToday.done;
    void open(AppPage target) =>
        ref.read(currentPageProvider.notifier).open(target);

    Widget item(AppPage target, {String count = ''}) => _MenuItem(
      key: Key('menu-${target.name}'),
      label: target.label,
      icon: target.icon,
      count: count,
      selected: page == target,
      onTap: () => open(target),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              children: [
                const _GroupLabel('Plan'),
                item(AppPage.tasks, count: openTasks == 0 ? '' : '$openTasks'),
                item(AppPage.projects),
                item(AppPage.goals),
                const _GroupLabel('Daily'),
                item(
                  AppPage.habits,
                  count: habitsLeft <= 0 ? '' : '$habitsLeft',
                ),
                item(AppPage.sleep),
                item(AppPage.focus),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 18, 0, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Life areas',
                          style: Ember.text(11, 13, color: Ember.onShell3),
                        ),
                      ),
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: IconButton(
                          key: const Key('menu-areas'),
                          tooltip: 'Life areas',
                          padding: EdgeInsets.zero,
                          iconSize: 14,
                          color: Ember.onShell3,
                          onPressed: () => open(AppPage.areas),
                          icon: const Icon(Icons.add),
                        ),
                      ),
                    ],
                  ),
                ),
                if (areas.isEmpty)
                  _MenuItem(
                    label: 'Add your first area',
                    icon: Icons.add_circle_outline,
                    selected: page == AppPage.areas,
                    onTap: () => open(AppPage.areas),
                  )
                else
                  for (final area in areas)
                    _MenuItem(
                      label: area.name,
                      leading: AreaMark(color: area.color, icon: area.icon),
                      selected: page == AppPage.areas,
                      quiet: true,
                      onTap: () => open(AppPage.areas),
                    ),
              ],
            ),
          ),
          const _SyncStatus(),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 18, 8, 6),
      child: Text(text, style: Ember.text(11, 13, color: Ember.onShell3)),
    );
  }
}

/// One row of the side menu. The open page has a raised background and an
/// orange icon, as in the design.
class _MenuItem extends StatefulWidget {
  const _MenuItem({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.leading,
    this.count = '',
    this.quiet = false,
  });

  final String label;
  final IconData? icon;

  /// Shown instead of [icon], for example a life area's dot.
  final Widget? leading;
  final String count;
  final bool selected;

  /// A row that shares its page with others (the life areas): it is not
  /// highlighted as the open page.
  final bool quiet;
  final VoidCallback onTap;

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.selected && !widget.quiet;
    final color = on ? Ember.onShell : Ember.onShell2;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.base),
        curve: Motion.soft,
        decoration: BoxDecoration(
          color: on
              ? Ember.active
              : _hover
              ? Ember.raised
              : Ember.shell.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHover: (hover) => setState(() => _hover = hover),
            hoverColor: Colors.transparent,
            child: SizedBox(
              height: 30,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.leading == null ? 8 : 12,
                ),
                child: Row(
                  children: [
                    widget.leading ??
                        AnimatedSwitcher(
                          duration: Motion.of(context, Motion.base),
                          child: Icon(
                            widget.icon,
                            key: ValueKey(on),
                            size: 16,
                            color: on ? Ember.now : color,
                          ),
                        ),
                    SizedBox(width: widget.leading == null ? 10 : 12),
                    Expanded(
                      child: Text(
                        widget.label,
                        overflow: TextOverflow.ellipsis,
                        style: Ember.text(13, 16, color: color),
                      ),
                    ),
                    if (widget.count.isNotEmpty)
                      Text(
                        widget.count,
                        style: Ember.text(
                          11,
                          13,
                          color: on ? Ember.onShell2 : Ember.onShell3,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The small sync status at the bottom of the side menu.
class _SyncStatus extends ConsumerWidget {
  const _SyncStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusTextProvider);
    final synced = status.label == 'Synced';
    return Container(
      key: const Key('sync-status'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Ember.raised,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ColorDot(synced ? Ember.green : Ember.amber, size: 7),
              const SizedBox(width: 8),
              Text(
                'Sync: ${status.label}',
                style: Ember.text(12, 15, color: Ember.onShell),
              ),
            ],
          ),
          if (status.detail != null) ...[
            const SizedBox(height: 4),
            Text(
              status.detail!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Ember.text(11, 14, weight: 400, color: Ember.onShell2),
            ),
          ],
        ],
      ),
    );
  }
}
