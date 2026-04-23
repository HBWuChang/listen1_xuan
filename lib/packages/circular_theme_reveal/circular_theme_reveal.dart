/// A beautiful Telegram-style circular reveal animation for theme transitions in Flutter.
///
/// This package provides a smooth, performant circular reveal effect that
/// works seamlessly with Flutter's theme system.
///
/// ## Features
/// - 🔄 Smooth circular reveal animation
/// - 🌓 Bidirectional transition (expands when going dark, contracts when going light)
/// - 🎯 Center-based animation (starts from any point, e.g., your theme toggle button)
/// - ⚡ High performance (uses efficient snapshot + blend mode technique)
/// - 🎨 Works with any theme colors
/// - 📦 Zero dependencies
///
/// ## Usage
///
/// 1. Wrap your MaterialApp with [CircularThemeRevealOverlay]:
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData.light(),
///   darkTheme: ThemeData.dark(),
///   builder: (context, child) {
///     return CircularThemeRevealOverlay(
///       child: child ?? SizedBox.shrink(),
///     );
///   },
/// )
/// ```
///
/// 2. In your theme toggle button:
///
/// ```dart
/// IconButton(
///   icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
///   onPressed: () async {
///     final center = CircularThemeRevealOverlay.getCenterFromContext(context);
///     final overlay = CircularThemeRevealOverlay.of(context);
///
///     await overlay?.startTransition(
///       center: center,
///       reverse: isDark,
///       onThemeChange: () {
///         setState(() {
///           isDark = !isDark;
///         });
///       },
///     );
///   },
/// )
/// ```
library;

export 'src/circular_theme_reveal_overlay.dart';
