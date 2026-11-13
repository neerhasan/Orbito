import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// The frame around every page once the user is signed in: the dark shell,
/// the side menu on the left and the open page on the right.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.email, required this.pageBuilder});

  /// Shown at the bottom of the side menu.
  final String email;

  /// Builds the content for a page.
  final Widget Function(AppPage page) pageBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(currentPageProvider);
    return Scaffold(
      backgroundColor: Ember.shell,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 236, child: _SideMenu(email: email)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
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
    );
  }
}

class _SideMenu extends ConsumerWidget {
  const _SideMenu({required this.email});

  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(currentPageProvider);
    final areas = ref.watch(lifeAreasProvider).value ?? const [];
    void open(AppPage target) =>
        ref.read(currentPageProvider.notifier).open(target);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Text(
              'Orbito',
              style: Ember.text(18, 22, weight: 700, color: Ember.onShell),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                const _GroupLabel('Plan'),
                for (final item in [
                  AppPage.tasks,
                  AppPage.projects,
                  AppPage.goals,
                ])
                  _MenuItem(
                    key: Key('menu-${item.name}'),
                    label: item.label,
                    leading: Icon(item.icon, size: 16),
                    selected: page == item,
                    onTap: () => open(item),
                  ),
                const _GroupLabel('Daily'),
                for (final item in [AppPage.habits])
                  _MenuItem(
                    key: Key('menu-${item.name}'),
                    label: item.label,
                    leading: Icon(item.icon, size: 16),
                    selected: page == item,
                    onTap: () => open(item),
                  ),
                const _GroupLabel('Life areas'),
                _MenuItem(
                  key: const Key('menu-areas'),
                  label: areas.isEmpty ? 'Add your first area' : 'All areas',
                  leading: Icon(AppPage.areas.icon, size: 16),
                  selected: page == AppPage.areas,
                  onTap: () => open(AppPage.areas),
                ),
                for (final area in areas)
                  _MenuItem(
                    label: area.name,
                    leading: AreaMark(color: area.color, icon: area.icon),
                    selected: false,
                    onTap: () => open(AppPage.areas),
                  ),
              ],
            ),
          ),
          const _SyncStatus(),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              email,
              overflow: TextOverflow.ellipsis,
              style: Ember.text(12, 15, weight: 400, color: Ember.onShell2),
            ),
          ),
          const SizedBox(height: 4),
          _MenuItem(
            key: const Key('sign-out'),
            label: 'Sign out',
            leading: const Icon(Icons.logout, size: 16),
            selected: false,
            onTap: () async {
              try {
                await ref.read(syncServiceProvider).signOut();
              } catch (error) {
                if (context.mounted) {
                  showMessage(context, 'Could not sign out. ($error)');
                }
              }
            },
          ),
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

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    super.key,
    required this.label,
    required this.leading,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Widget leading;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Ember.onShell : Ember.onShell2;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.base),
        curve: Motion.soft,
        decoration: BoxDecoration(
          color: selected ? Ember.active : Ember.shell.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            hoverColor: Ember.raised,
            child: SizedBox(
              height: 30,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconTheme.merge(
                      data: IconThemeData(color: color),
                      child: leading,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: Ember.text(13, 16, color: color),
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
