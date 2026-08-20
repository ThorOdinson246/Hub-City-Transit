import 'package:flutter/widgets.dart';

/// Material 3 window size classes.
///
/// Keyed off width only. Height matters for the onboarding flow, which is why
/// [Breakpoints.isShortViewport] exists separately rather than folding height
/// into the class.
enum WindowSize {
  compact,
  medium,
  expanded;

  bool get isCompact => this == WindowSize.compact;

  /// True where a navigation rail replaces the bottom navigation bar.
  bool get prefersRail => this != WindowSize.compact;
}

abstract final class Breakpoints {
  static const double medium = 600;
  static const double expanded = 840;

  /// Widest a column of text or list rows is allowed to grow.
  ///
  /// Rows wider than this put their leading icon and trailing chevron so far
  /// apart that they stop reading as one control.
  static const double readableContent = 720;

  /// Below this the fixed-height onboarding art cannot fit alongside its text,
  /// and the layout must scroll instead of overflowing. Landscape phones in a
  /// browser and vertically-resized desktop windows both land here; a portrait
  /// phone never does.
  static const double shortViewport = 640;

  static WindowSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static WindowSize fromWidth(double width) {
    if (width >= expanded) return WindowSize.expanded;
    if (width >= medium) return WindowSize.medium;
    return WindowSize.compact;
  }

  static bool isShortViewport(BuildContext context) =>
      MediaQuery.sizeOf(context).height < shortViewport;
}

/// Centres [child] and stops it growing past a readable width.
///
/// The app was laid out for a 360–420dp phone. In a desktop browser window the
/// same widgets are handed 1400+dp and stretch to fill it, so this caps them
/// without every page needing its own `LayoutBuilder`.
class ContentPane extends StatelessWidget {
  const ContentPane({
    required this.child,
    this.maxWidth = Breakpoints.readableContent,
    this.alignment = Alignment.topCenter,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
