/// TooltipCard — A powerful, customizable tooltip library for Flutter
///
/// This library provides a comprehensive tooltip widget with Fluent UI inspired
/// design, smart positioning, SuperCore-aligned Material 3 theming, and accessibility support.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:tooltip_card/tooltip_card.dart';
///
/// TooltipCard.builder(
///   child: Icon(Icons.info),
///   builder: (context, close) => TooltipCardContent(
///     title: 'Information',
///     subtitle: 'This is helpful information',
///     primaryAction: FilledButton(
///       onPressed: close,
///       child: Text('Got it'),
///     ),
///     onClose: close,
///   ),
/// )
/// ```
///
/// ## Features
///
/// - Multiple trigger modes (press, hover, double-tap, right-click)
/// - Smart positioning with auto-flip
/// - Beak/arrow pointing to trigger
/// - Modal barrier support with blur
/// - SuperCore-compatible Material 3 theming and design tokens
/// - RTL aware positioning
/// - Structured content with TooltipCardContent
/// - Programmatic control via TooltipCardController
library;

// Export the stable public API from the MVC layers.
export 'src/controllers/controllers.dart'
    show TooltipCardController, TooltipCardPublicState;
export 'src/models/models.dart';
export 'src/views/views.dart';
