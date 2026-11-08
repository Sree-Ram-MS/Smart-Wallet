// Wide-screen app shell: a persistent sidebar next to the page content.
//
// It is installed through MaterialApp.router's `builder`, i.e. *around* the
// single app Navigator, rather than as a go_router ShellRoute. That keeps the
// navigator stack, back-button handling and every existing
// `Navigator.pop(context)` exactly as they are on phones; below the wide
// breakpoint the shell returns the app untouched.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/layout/responsive.dart';
import 'package:go_router/go_router.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_colors.dart';
import '../providers/providers.dart';
import 'app_drawer.dart';
import 'user_avatar.dart';

/// Counts open popup routes (dialogs, sheets, menus) so the sidebar, which
/// lives outside the Navigator, can be dimmed and disabled while one is open.
class PopupRouteTracker extends NavigatorObserver {
  final ValueNotifier<int> openPopups = ValueNotifier<int>(0);

  int _pending = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) { _pending++; _schedule(); }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) { _pending--; _schedule(); }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) { _pending--; _schedule(); }
  }

  // Observers run while the navigator is updating; publish after the frame.
  void _schedule() {
    if (_pending < 0) _pending = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      openPopups.value = _pending;
    });
  }

}

final popupRouteTracker = PopupRouteTracker();

class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _noShellRoutes = {'/login', '/biometric'};

  String _location = '';

  @override
  void initState() {
    super.initState();
    _location = _readLocation();
    appRouter.routerDelegate.addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    appRouter.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  String _readLocation() {
    try {
      return appRouter.routerDelegate.currentConfiguration.uri.path;
    } catch (_) {
      return '';
    }
  }

  void _onRouteChanged() {
    final loc = _readLocation();
    if (loc != _location && mounted) setState(() => _location = loc);
  }

  @override
  Widget build(BuildContext context) {
    if (!context.isWide || _location.isEmpty || _noShellRoutes.contains(_location)) {
      return widget.child;
    }

    final theme = Theme.of(context);
    final extended = context.isExtendedNav;
    final isDark = theme.brightness == Brightness.dark;

    return Theme(
      // Desktop niceties: scrollbars always visible on wide layouts.
      data: theme.copyWith(
        scrollbarTheme: theme.scrollbarTheme.copyWith(
          thumbVisibility: const WidgetStatePropertyAll(true),
          thickness: const WidgetStatePropertyAll(8),
          radius: const Radius.circular(8),
        ),
      ),
      child: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<int>(
              valueListenable: popupRouteTracker.openPopups,
              builder: (context, open, sidebar) => Stack(
                children: [
                  sidebar!,
                  if (open > 0)
                    const Positioned.fill(
                      child: AbsorbPointer(child: ColoredBox(color: Colors.black54)),
                    ),
                ],
              ),
              child: Overlay.wrap(
                child: Material(
                  color: theme.colorScheme.surface,
                  child: Container(
                    width: extended ? 288 : 84,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                    ),
                    child: SafeArea(
                      right: false,
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                        child: extended
                          ? AppNavigationPanel(currentLocation: _location)
                          : _CompactRail(location: _location),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: Breakpoints.maxContentWidth),
                  child: widget.child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon-only sidebar for medium-wide windows (900–1200 dp).
class _CompactRail extends ConsumerWidget {
  final String location;
  const _CompactRail({required this.location});

  BuildContext _nav(BuildContext context) => rootNavigatorKey.currentContext ?? context;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final isDark = user?.isDarkMode ?? true;

    return Column(
      children: [
        const SizedBox(height: 16),
        Tooltip(
          message: 'Settings',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _nav(context).go('/settings'),
            child: UserAvatar(user: user, radius: 22),
          ),
        ),
        const SizedBox(height: 12),
        const Divider(indent: 16, endIndent: 16),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            children: [
              for (final d in appNavDestinations)
                _RailButton(
                  icon: d.icon,
                  label: d.label,
                  selected: location == d.route,
                  onTap: () => _nav(context).go(d.route),
                ),
            ],
          ),
        ),
        const Divider(indent: 16, endIndent: 16),
        _RailButton(
          icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          label: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          selected: false,
          onTap: () => ref.read(userProvider.notifier).toggleDarkMode(),
        ),
        _RailButton(
          icon: Icons.logout_rounded,
          label: 'Sign Out',
          selected: false,
          color: AppColors.expense,
          onTap: () => confirmAndSignOut(_nav(context), ref),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _RailButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _RailButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Tooltip(
        message: label,
        waitDuration: const Duration(milliseconds: 300),
        preferBelow: false,
        child: Material(
          color: selected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            hoverColor: AppColors.primary.withValues(alpha: 0.08),
            onTap: onTap,
            child: SizedBox(
              height: 44,
              child: Icon(
                icon,
                size: 22,
                color: color ?? (selected ? AppColors.primary : Theme.of(context).listTileTheme.iconColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
