import 'package:flutter/widgets.dart';

/// Keeps the persistent player at its original viewport and safe-area position.
/// Only the player loses the keyboard inset; inner routes retain it.
class KeyboardStablePlayer extends StatelessWidget {
  const KeyboardStablePlayer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        viewInsets: media.viewInsets.copyWith(bottom: 0),
        padding: media.padding.copyWith(bottom: media.viewPadding.bottom),
      ),
      child: child,
    );
  }
}

/// Lets the keyboard consume the reserved player space before moving the page.
class KeyboardPlayerSpacer extends StatelessWidget {
  const KeyboardPlayerSpacer({
    super.key,
    required this.height,
    this.includeBottomSafeArea = true,
  });

  final double height;
  final bool includeBottomSafeArea;

  @override
  Widget build(BuildContext context) {
    final safeBottom = includeBottomSafeArea ? MediaQuery.viewPaddingOf(context).bottom : 0.0;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return SizedBox(height: (height + safeBottom - keyboard).clamp(0.0, double.infinity));
  }
}
