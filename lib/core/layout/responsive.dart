// Responsive layout helpers.
//
// Everything here is keyed on the window width, on every platform, so a phone
// in portrait (< 900 dp wide) always gets exactly the original mobile UI. Only
// wide windows (desktop browsers, tablets/foldables in landscape) switch to the
// sidebar + multi-column layouts.
import 'dart:math' as math;

import 'package:flutter/material.dart';

class Breakpoints {
  Breakpoints._();

  /// At and above this width the app uses the persistent sidebar, centred
  /// dialogs instead of bottom sheets, and multi-column content.
  static const double wide = 900;

  /// At and above this width the sidebar shows labels (extended).
  static const double extended = 1200;

  /// Max width of the page content area next to the sidebar.
  static const double maxContentWidth = 1400;

  /// Max width of a bottom sheet when shown as a centred dialog.
  static const double dialogMaxWidth = 520;

  /// Comfortable max width for single-column lists and forms.
  static const double listMaxWidth = 960;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// True when the window is wide enough for the desktop layout.
  bool get isWide => screenWidth >= Breakpoints.wide;

  /// True when the sidebar should show labels.
  bool get isExtendedNav => screenWidth >= Breakpoints.extended;
}

/// Centres [child] and caps its width on wide layouts; on narrow layouts it
/// returns [child] untouched.
class ContentWidth extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const ContentWidth({
    super.key,
    this.maxWidth = Breakpoints.listMaxWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!context.isWide) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// A list that is a plain [ListView] on narrow layouts and lays its items out
/// in rows of 2–3 columns on wide layouts (items keep their own height).
class ResponsiveList extends StatelessWidget {
  final EdgeInsetsGeometry? padding;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final IndexedWidgetBuilder? separatorBuilder;

  /// Minimum width of one column on wide layouts.
  final double minItemWidth;
  final int maxColumns;
  final double spacing;

  const ResponsiveList.builder({
    super.key,
    this.padding,
    required this.itemCount,
    required this.itemBuilder,
    this.minItemWidth = 420,
    this.maxColumns = 3,
    this.spacing = 14,
  }) : separatorBuilder = null;

  const ResponsiveList.separated({
    super.key,
    this.padding,
    required this.itemCount,
    required this.itemBuilder,
    required IndexedWidgetBuilder this.separatorBuilder,
    this.minItemWidth = 420,
    this.maxColumns = 3,
    this.spacing = 14,
  });

  @override
  Widget build(BuildContext context) {
    if (!context.isWide) {
      if (separatorBuilder != null) {
        return ListView.separated(
          padding: padding,
          itemCount: itemCount,
          itemBuilder: itemBuilder,
          separatorBuilder: separatorBuilder!,
        );
      }
      return ListView.builder(
        padding: padding,
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final resolved = padding?.resolve(Directionality.of(context)) ?? EdgeInsets.zero;
      final inner = constraints.maxWidth - resolved.horizontal;
      final columns = math.max(1, math.min(maxColumns, (inner / minItemWidth).floor()));
      final rows = (itemCount / columns).ceil();
      return ListView.builder(
        padding: padding,
        itemCount: rows,
        itemBuilder: (ctx, row) {
          final cells = <Widget>[];
          for (var c = 0; c < columns; c++) {
            final i = row * columns + c;
            if (c > 0) cells.add(SizedBox(width: spacing));
            cells.add(Expanded(child: i < itemCount ? itemBuilder(ctx, i) : const SizedBox.shrink()));
          }
          final rowWidget = Row(crossAxisAlignment: CrossAxisAlignment.start, children: cells);
          if (separatorBuilder != null && row < rows - 1) {
            return Column(children: [rowWidget, separatorBuilder!(ctx, row)]);
          }
          return rowWidget;
        },
      );
    });
  }
}

/// Lays [children] out in [columns] vertical columns (round-robin), for
/// variable-height cards on wide layouts.
class MasonryColumns extends StatelessWidget {
  final List<Widget> children;
  final int columns;
  final double spacing;

  const MasonryColumns({
    super.key,
    required this.children,
    required this.columns,
    this.spacing = 18,
  });

  @override
  Widget build(BuildContext context) {
    final cols = List.generate(columns, (_) => <Widget>[]);
    for (var i = 0; i < children.length; i++) {
      cols[i % columns].add(children[i]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var c = 0; c < columns; c++) ...[
          if (c > 0) SizedBox(width: spacing),
          Expanded(child: Column(children: cols[c])),
        ],
      ],
    );
  }
}

/// Drop-in replacement for [showModalBottomSheet]: a bottom sheet on narrow
/// layouts, a centred dialog (max ~520 wide) on wide layouts.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  Color? backgroundColor,
  ShapeBorder? shape,
  BoxConstraints? constraints,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
  bool useSafeArea = false,
  bool? showDragHandle,
}) {
  if (!context.isWide) {
    return showModalBottomSheet<T>(
      context: context,
      builder: builder,
      isScrollControlled: isScrollControlled,
      backgroundColor: backgroundColor,
      shape: shape,
      constraints: constraints,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useRootNavigator: useRootNavigator,
      useSafeArea: useSafeArea,
      showDragHandle: showDragHandle,
    );
  }

  return showDialog<T>(
    context: context,
    barrierDismissible: isDismissible,
    builder: (ctx) {
      final size = MediaQuery.sizeOf(ctx);
      final theme = Theme.of(ctx);
      final width = math.min(Breakpoints.dialogMaxWidth, size.width - 80);
      return Dialog(
        backgroundColor: backgroundColor ?? theme.bottomSheetTheme.backgroundColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width, minWidth: width, maxHeight: size.height * 0.88),
          // The dialog already moves out of the way of the keyboard; stop the
          // sheet content from adding the same inset a second time.
          child: MediaQuery.removeViewInsets(
            context: ctx,
            removeBottom: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Builder(builder: builder),
            ),
          ),
        ),
      );
    },
  );
}

/// Lays [children] out in rows of [columns] equal-width cells, keeping their
/// order left-to-right. Used for card lists inside an existing scroll view.
class GridRows extends StatelessWidget {
  final List<Widget> children;
  final int columns;
  final double spacing;

  const GridRows({
    super.key,
    required this.children,
    this.columns = 2,
    this.spacing = 14,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < children.length; start += columns) {
      final cells = <Widget>[];
      for (var c = 0; c < columns; c++) {
        final i = start + c;
        if (c > 0) cells.add(SizedBox(width: spacing));
        cells.add(Expanded(child: i < children.length ? children[i] : const SizedBox.shrink()));
      }
      rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: cells));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}
