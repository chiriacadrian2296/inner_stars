<h1 align="center">TooltipCard</h1>

<p align="center">
  <strong>A powerful, highly customizable tooltip and popover widget for Flutter</strong>
</p>

[![pub package](https://img.shields.io/pub/v/tooltip_card.svg)](https://pub.dev/packages/tooltip_card)
[![likes](https://img.shields.io/pub/likes/tooltip_card)](https://pub.dev/packages/tooltip_card/score)
[![popularity](https://img.shields.io/pub/popularity/tooltip_card)](https://pub.dev/packages/tooltip_card/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![points](https://img.shields.io/pub/points/tooltip_card)](https://pub.dev/packages/tooltip_card/score)
[![Live Demo](https://img.shields.io/badge/🚀_Live_Demo-View_Online-success)](https://geniussystems24.github.io/tooltip_card)


---

## 📸 Screenshots

<p align="center">
  <img src="https://raw.githubusercontent.com/geniussystems24/tooltip_card/main/screenshots/1.png" alt="Basic Tooltip"/>
  <img src="https://raw.githubusercontent.com/geniussystems24/tooltip_card/main/screenshots/2.png" alt="Structured Content"/>
  <img src="https://raw.githubusercontent.com/geniussystems24/tooltip_card/main/screenshots/3.png" alt="Placement Options"/>
  <img src="https://raw.githubusercontent.com/geniussystems24/tooltip_card/main/screenshots/4.png" alt="Modal Barrier" width="220"/>
  <img src="https://raw.githubusercontent.com/geniussystems24/tooltip_card/main/screenshots/5.png" alt="Screenshot 5" width="220"/>
  <img src="https://raw.githubusercontent.com/geniussystems24/tooltip_card/main/screenshots/6.png" alt="Screenshot 6" width="220"/>
  <img src="https://raw.githubusercontent.com/geniussystems24/tooltip_card/main/screenshots/7.png" alt="Screenshot 7" width="220"/>
</p>

---

## 🎯 Overview

**TooltipCard** is a feature-rich tooltip and popover library for Flutter, inspired by [Microsoft Fluent UI's TeachingTip](https://docs.microsoft.com/en-us/windows/apps/design/controls/teaching-tip). It provides an elegant way to display contextual information, onboarding tips, feature discovery hints, and interactive popovers.

### Why TooltipCard?

| Feature | Flutter Tooltip | TooltipCard |
|---------|-----------------|-------------|
| Smart Auto-positioning | ❌ | ✅ 12 placement options with auto-flip |
| Beak/Arrow Pointer | ❌ | ✅ With matching shadow |
| Structured Content | ❌ | ✅ Icons, titles, actions |
| Trigger Modes | Hover only | ✅ 7 modes: tap, hover, double-tap, right-click, long-press, force-press |
| Animation Types | Basic fade | ✅ 9 types: fade, scale, bounce, elastic, slide, zoom |
| Touch-Friendly | ❌ | ✅ Long press, force press (3D Touch) |
| Programmatic Control | ❌ | ✅ Controller API with data passing |
| Modal Barrier | ❌ | ✅ With blur effect |
| Material 3 | Partial | ✅ Full theming support |
| RTL Support | ❌ | ✅ Complete |
| Accessibility | Basic | ✅ Keyboard + Screen reader |

---

## ✨ Features

<table>
  <tr>
    <td width="50%">
      <h3>🎯 Smart Positioning</h3>
      <ul>
        <li>12 placement options (top, bottom, start, end + compounds)</li>
        <li>Viewport-aware auto-flip when space is limited</li>
        <li>RTL-aware directional positioning</li>
        <li>Custom offset support</li>
      </ul>
    </td>
    <td width="50%">
      <h3>🔺 Fluent Beak</h3>
      <ul>
        <li>Arrow/caret pointing to trigger element</li>
        <li>Directional shadow matching placement</li>
        <li>Optional border support</li>
        <li>Customizable size and color</li>
        <li>Automatic position adjustment</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td>
      <h3>🎨 Material 3 Theming</h3>
      <ul>
        <li>Full color scheme integration</li>
        <li>Dark mode optimization</li>
        <li>Custom background and elevation</li>
        <li>Typography from theme</li>
      </ul>
    </td>
    <td>
      <h3>⚡ 7 Trigger Modes</h3>
      <ul>
        <li><strong>Desktop:</strong> Tap, Hover, Double-tap, Right-click</li>
        <li><strong>Touch:</strong> Long press, Long press up, Force press</li>
        <li>3D Touch / Haptic Touch support (iOS)</li>
        <li>Automatic fallback for unsupported gestures</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td>
      <h3>🌫️ Modal Barrier</h3>
      <ul>
        <li>Optional backdrop scrim</li>
        <li>Blur effect support</li>
        <li>Dismissible on tap outside</li>
        <li>Custom barrier color</li>
      </ul>
    </td>
    <td>
      <h3>🎬 9 Animation Types</h3>
      <ul>
        <li><strong>Basic:</strong> fade, scale, fadeScale, none</li>
        <li><strong>Slide:</strong> slideIn, slideFade (direction-aware)</li>
        <li><strong>Dynamic:</strong> bounce, elastic, zoom</li>
        <li>Customizable per-tooltip animation</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td>
      <h3>♿ Accessibility</h3>
      <ul>
        <li>Keyboard navigation (Enter, Space, Escape)</li>
        <li>Screen reader support</li>
        <li>Focus management</li>
        <li>Semantic labels</li>
      </ul>
    </td>
    <td>
      <h3>📱 Cross-Platform</h3>
      <ul>
        <li>Android, iOS, Web</li>
        <li>Windows, macOS, Linux</li>
        <li>Responsive design</li>
        <li>Touch and mouse support</li>
      </ul>
    </td>
  </tr>
</table>

---

## 📦 Installation

Add `tooltip_card` to your `pubspec.yaml`:

```yaml
dependencies:
  tooltip_card: ^2.8.2
```

Then run:

```bash
flutter pub get
```

Import the package:

```dart
import 'package:tooltip_card/tooltip_card.dart';
```

---

## 🚀 Quick Start

### Basic Tooltip

```dart
TooltipCard.builder(
  child: const Icon(Icons.info_outline),
  builder: (context, close) => const Padding(
    padding: EdgeInsets.all(12),
    child: Text('This is a simple tooltip!'),
  ),
)
```

### With Beak and Placement

```dart
TooltipCard.builder(
  beakEnabled: true,
  placementSide: TooltipCardPlacementSide.bottom,
  child: ElevatedButton(
    onPressed: () {},
    child: const Text('Show Tip'),
  ),
  builder: (context, close) => const Padding(
    padding: EdgeInsets.all(16),
    child: Text('Tooltip appears below with an arrow'),
  ),
)
```

### Structured Content (TeachingTip Style)

```dart
TooltipCard.builder(
  beakEnabled: true,
  placementSide: TooltipCardPlacementSide.bottom,
  modalBarrierEnabled: true,
  barrierBlur: 2.0,
  child: IconButton(
    icon: const Icon(Icons.lightbulb_outline),
    onPressed: () {},
  ),
  builder: (context, close) => TooltipCardContent(
    icon: const Icon(Icons.auto_awesome),
    iconColor: Colors.amber,
    title: 'Pro Tip',
    subtitle: 'Discover this amazing feature that will boost your productivity',
    content: const Text(
      'Click the settings icon to customize your experience and unlock advanced options.',
    ),
    primaryAction: FilledButton(
      onPressed: close,
      child: const Text('Got it!'),
    ),
    secondaryAction: OutlinedButton(
      onPressed: () {
        // Learn more action
        close();
      },
      child: const Text('Learn more'),
    ),
    onClose: close,
  ),
)
```

---

## 📖 API Reference

### TooltipCard Widget

The main widget for displaying tooltips and popovers.

#### Constructors

| Constructor | Description |
|-------------|-------------|
| `TooltipCard.builder()` | Creates a tooltip with dynamic content via builder function |
| `TooltipCard()` | Creates a tooltip with static content widget |

#### Core Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `child` | `Widget` | **required** | The trigger widget that shows the tooltip |
| `builder` | `Widget Function(BuildContext, VoidCallback)` | - | Builder for dynamic tooltip content with close callback |
| `flyoutContent` | `Widget` | - | Static tooltip content (alternative to builder) |

#### Appearance Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `placementSide` | `TooltipCardPlacementSide` | `top` | Preferred placement position |
| `beakEnabled` | `bool` | `true` | Whether to show the arrow/beak |
| `beakSize` | `double` | `10.0` | Size of the beak triangle |
| `beakColor` | `Color?` | `null` | Custom beak color (defaults to background) |
| `beakInset` | `double` | `20.0` | Minimum inset from panel edges |
| `elevation` | `double` | `8.0` | Shadow elevation |
| `borderRadius` | `BorderRadius` | `circular(8)` | Corner radius of the panel |
| `flyoutBackgroundColor` | `Color?` | `null` | Custom background (defaults to theme) |
| `padding` | `EdgeInsetsGeometry?` | `EdgeInsets.zero` | Content padding |
| `constraints` | `BoxConstraints?` | `null` | Size constraints for tooltip |
| `awaySpace` | `double` | `0.0` | Gap between trigger and tooltip |
| `offset` | `Offset` | `Offset.zero` | Additional position offset |
| `borderColor` | `Color?` | `null` | Border color for panel and beak |
| `borderWidth` | `double` | `0.0` | Border stroke width |

#### Behavior Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `triggerMode` | `Set<WhenContentVisible>` | `{WhenContentVisible.pressButton}` | Trigger modes for showing |
| `whenContentHide` | `WhenContentHide` | `goAway` | Dismiss behavior |
| `hoverOpenDelay` | `Duration` | `500ms` | Delay before showing on hover |
| `hoverCloseDelay` | `Duration` | `250ms` | Delay before hiding after hover exit |
| `showDuration` | `Duration?` | `null` | Auto-close after this duration |
| `dismissOnPointerMoveAway` | `bool` | `false` | Close when pointer leaves tooltip area |

#### Viewport & Layout Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `fitToViewport` | `bool` | `true` | Ensure tooltip stays within viewport |
| `viewportMargin` | `EdgeInsetsDirectional` | `all(8)` | Margin from viewport edges |
| `autoFlipIfZeroSpace` | `bool` | `true` | Auto-flip to opposite side if no space |
| `wrapContentInScrollView` | `bool` | `true` | Wrap content in scroll view if needed |
| `useRootOverlay` | `bool` | `true` | Use root overlay for positioning |

#### Modal Barrier Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `modalBarrierEnabled` | `bool` | `false` | Show backdrop scrim |
| `barrierColor` | `Color?` | `null` | Custom backdrop color |
| `barrierBlur` | `double` | `0.0` | Backdrop blur sigma |
| `barrierDismissible` | `bool?` | `null` | Allow tap outside to dismiss |

#### Controller & Callbacks

| Property | Type | Description |
|----------|------|-------------|
| `controller` | `TooltipCardController?` | Controller for programmatic control |
| `publicState` | `TooltipCardPublicState?` | Shared state for single-open behavior |
| `onOpen` | `VoidCallback?` | Called when tooltip opens |
| `onClose` | `VoidCallback?` | Called when tooltip closes |
| `onOpenChanged` | `ValueChanged<bool>?` | Called when open state changes |

---

### TooltipCardPlacementSide

Enum defining 12 placement options for precise positioning.

#### Basic Placements

| Value | Description |
|-------|-------------|
| `top` | Above the trigger, centered |
| `bottom` | Below the trigger, centered |
| `start` | Start side (left in LTR, right in RTL) |
| `end` | End side (right in LTR, left in RTL) |

#### Compound Placements

| Value | Description |
|-------|-------------|
| `topStart` | Above, aligned to start edge |
| `topEnd` | Above, aligned to end edge |
| `bottomStart` | Below, aligned to start edge |
| `bottomEnd` | Below, aligned to end edge |
| `startTop` | Start side, aligned to top |
| `startBottom` | Start side, aligned to bottom |
| `endTop` | End side, aligned to top |
| `endBottom` | End side, aligned to bottom |

```dart
// Example: Position tooltip at bottom-start
TooltipCard.builder(
  placementSide: TooltipCardPlacementSide.bottomStart,
  // ...
)
```

---

### Trigger Modes

`triggerMode` defines a set of interactions that trigger the tooltip. You can combine multiple modes.

| Value | Description | Use Case |
|-------|-------------|----------|
| `pressButton` | Show on tap/click | Mobile primary |
| `hoverButton` | Show on hover | Desktop tooltips |
| `doubleTapButton` | Show on double tap | Secondary actions |
| `secondaryTapButton` | Show on right-click | Context menus |

```dart
// Hover tooltip for desktop
TooltipCard.builder(
  triggerMode: {WhenContentVisible.hoverButton},
  hoverOpenDelay: const Duration(milliseconds: 300),
  // ...
)
```

---

### WhenContentHide

Enum defining how the tooltip is dismissed.

| Value | Description |
|-------|-------------|
| `goAway` | Hide when pointer leaves the tooltip area |
| `pressOutSide` | Hide when tapping outside the tooltip |

---

### TooltipCardContent

A structured content widget inspired by Fluent UI's TeachingTip, perfect for onboarding and feature discovery.

#### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `icon` | `Widget?` | `null` | Leading icon widget |
| `iconColor` | `Color?` | `null` | Icon tint color |
| `iconSize` | `double` | `24.0` | Icon size |
| `title` | `String?` | `null` | Title text |
| `titleStyle` | `TextStyle?` | `null` | Custom title style |
| `subtitle` | `String?` | `null` | Subtitle/description text |
| `subtitleStyle` | `TextStyle?` | `null` | Custom subtitle style |
| `content` | `Widget?` | `null` | Custom content widget |
| `primaryAction` | `Widget?` | `null` | Primary action button |
| `secondaryAction` | `Widget?` | `null` | Secondary action button |
| `tertiaryAction` | `Widget?` | `null` | Tertiary action button |
| `onClose` | `VoidCallback?` | `null` | Close button callback |
| `showCloseButton` | `bool` | `true` | Show close button (when onClose provided) |
| `maxWidth` | `double` | `360.0` | Maximum content width |
| `padding` | `EdgeInsetsGeometry` | `all(16)` | Content padding |
| `spacing` | `double` | `12.0` | Spacing between elements |

```dart
TooltipCardContent(
  icon: const Icon(Icons.rocket_launch),
  iconColor: Theme.of(context).colorScheme.primary,
  title: 'New Feature!',
  subtitle: 'We just launched something amazing',
  content: const Text('Check out the new dashboard with real-time analytics.'),
  primaryAction: FilledButton(
    onPressed: () => Navigator.pushNamed(context, '/dashboard'),
    child: const Text('Explore'),
  ),
  secondaryAction: TextButton(
    onPressed: close,
    child: const Text('Maybe later'),
  ),
  onClose: close,
)
```

---

### TooltipCardController

Programmatic control for showing/hiding tooltips.

```dart
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TooltipCardController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TooltipCard.builder(
          controller: _controller,
          child: const Text('Trigger'),
          builder: (ctx, close) => const Text('Controlled tooltip'),
        ),
        ElevatedButton(
          onPressed: () => _controller.toggle(),
          child: const Text('Toggle Tooltip'),
        ),
      ],
    );
  }
}
```

#### Methods

| Method | Description |
|--------|-------------|
| `open({data})` | Show the tooltip (optionally with data) |
| `close()` | Hide the tooltip and clear data |
| `toggle({data})` | Toggle between open and closed |
| `updateData(data)` | Update data while tooltip stays open |

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isOpen` | `bool` | Current open state |
| `data` | `dynamic` | The data passed when opening |
| `dataAs<T>()` | `T?` | Type-safe data access |
| `hasData(value)` | `bool` | Check if data equals value |
| `isDataType<T>()` | `bool` | Check if data is of type T |

#### Data Passing Example

```dart
// Open tooltip with data
controller.open(data: {'id': 1, 'name': 'Product A'});

// Update data while tooltip is open (no close/reopen)
controller.updateData({'id': 2, 'name': 'Product B'});

// Access data in builder
TooltipCard.builder(
  controller: controller,
  builder: (ctx, close) {
    final product = controller.dataAs<Map<String, dynamic>>();
    return Text(product?['name'] ?? 'No product');
  },
  child: Text('Show Product'),
)
```

---

### TooltipCardPublicState

Global state manager ensuring only one tooltip is open at a time.

```dart
// Use global singleton (default behavior)
TooltipCard.builder(
  publicState: TooltipCardPublicState.global,
  // Opening this tooltip will close any other open tooltip
  // ...
)

// Create isolated scope
final myScope = TooltipCardPublicState();

// Tooltips in this scope won't affect other scopes
TooltipCard.builder(
  publicState: myScope,
  // ...
)
```

---

## 🎨 Theming

TooltipCard follows the GeniusLink design language used by
[`super_core`](https://github.com/GeniusSystems24/super_core): electric-blue
accent, neutral precision surfaces, Inter/Manrope typography, a 4px spacing
scale, 4/6/8/12px radii, restrained motion, hairline borders, and a dedicated
popover shadow. The package does not require `super_core`; it automatically
uses the ambient Material `ColorScheme` and exposes matching local tokens.

### SuperCore integration

Applications already using `super_core` can install both extensions on the
same generated Material theme:

```dart
final palette = SuperPalette.bluePalette;

MaterialApp(
  theme: SuperMaterialThemeData.light(
    palette: palette,
    extensions: [
      TooltipCardThemeData.superCore(
        brightness: Brightness.light,
        accentColor: palette.primary,
      ),
    ],
  ),
  darkTheme: SuperMaterialThemeData.dark(
    palette: palette,
    extensions: [
      TooltipCardThemeData.superCore(
        brightness: Brightness.dark,
        accentColor: palette.primaryDark,
      ),
    ],
  ),
);
```

Without `super_core`, use the matching built-in factories with any Material 3
theme:

```dart
MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: TooltipCardDesignTokens.accent,
    ),
    useMaterial3: true,
    extensions: [TooltipCardThemeData.light()],
  ),
  darkTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: TooltipCardDesignTokens.accent,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
    extensions: [TooltipCardThemeData.dark()],
  ),
);
```

### Factory constructors

```dart
TooltipCardThemeData.superCore(
  brightness: Brightness.light,
  accentColor: TooltipCardDesignTokens.accent,
);

TooltipCardThemeData.light();
TooltipCardThemeData.dark();
```

`TooltipCardThemeData.fluent` remains available for source compatibility and
now inherits the same SuperCore-compatible base tokens.

### Accessing the theme

```dart
final tooltipTheme = context.tooltipCardTheme;
final sameTheme = Theme.of(context).extension<TooltipCardThemeData>();
```

### TooltipCardThemeData properties

| Property | Type | Description |
|----------|------|-------------|
| `backgroundColor` | `Color?` | Panel surface color |
| `beakColor` | `Color?` | Beak/arrow fill |
| `borderColor` | `Color?` | Hairline panel and beak border |
| `borderWidth` | `double?` | Border width |
| `elevation` | `double?` | Optional Material elevation override |
| `shadows` | `List<BoxShadow>?` | Popover shadow stack |
| `borderRadius` | `BorderRadius?` | Panel corner radius |
| `padding` | `EdgeInsetsGeometry?` | Panel content padding |
| `constraints` | `BoxConstraints?` | Size constraints |
| `awaySpace` | `double?` | Gap from trigger |
| `beakEnabled` | `bool?` | Show beak |
| `beakSize` | `double?` | Beak size |
| `beakInset` | `double?` | Beak edge inset |
| `hoverOpenDelay` | `Duration?` | Hover open delay |
| `hoverCloseDelay` | `Duration?` | Hover close delay |
| `showDuration` | `Duration?` | Auto-close duration |
| `barrierColor` | `Color?` | Modal barrier color |
| `barrierBlur` | `double?` | Barrier blur amount |
| `titleStyle` | `TextStyle?` | Title text style |
| `subtitleStyle` | `TextStyle?` | Subtitle text style |
| `contentTextStyle` | `TextStyle?` | Content text style |
| `iconColor` | `Color?` | Icon tint color |
| `iconSize` | `double?` | Icon size |
| `actionSpacing` | `double?` | Action button spacing |
| `contentMaxWidth` | `double?` | Maximum content width |
| `contentPadding` | `EdgeInsetsGeometry?` | Structured content padding |
| `contentSpacing` | `double?` | Structured content rhythm |

### Custom Styling (Per Widget)

```dart
TooltipCard.builder(
  flyoutBackgroundColor: Colors.indigo.shade900,
  beakColor: Colors.indigo.shade900,
  elevation: 12.0,
  borderRadius: BorderRadius.circular(16),
  child: const Icon(Icons.palette),
  builder: (context, close) => const Padding(
    padding: EdgeInsets.all(16),
    child: Text(
      'Custom styled tooltip',
      style: TextStyle(color: Colors.white),
    ),
  ),
)
```

### Bordered Tooltip

```dart
TooltipCard.builder(
  beakEnabled: true,
  borderColor: Colors.blue.shade300,
  borderWidth: 1.5,
  elevation: 4.0,
  child: const Icon(Icons.info_outline),
  builder: (context, close) => const Padding(
    padding: EdgeInsets.all(12),
    child: Text('Tooltip with a subtle border'),
  ),
)
```

---

## 🔧 Design Tokens

Use built-in design tokens for consistency across your app:

```dart
// Spacing
TooltipCardSpacing.xs   // 4.0
TooltipCardSpacing.sm   // 8.0
TooltipCardSpacing.md   // 12.0
TooltipCardSpacing.lg   // 16.0
TooltipCardSpacing.xl   // 24.0

// Timing
TooltipCardTiming.enterDuration     // 200ms
TooltipCardTiming.exitDuration      // 150ms
TooltipCardTiming.hoverOpenDelay    // 500ms
TooltipCardTiming.hoverCloseDelay   // 250ms

// Constants
TooltipCardConstants.defaultMaxWidth      // 360.0
TooltipCardConstants.defaultElevation     // 8.0
TooltipCardConstants.defaultBeakSize      // 10.0
TooltipCardConstants.defaultBeakInset     // 20.0
TooltipCardConstants.defaultBorderRadius  // BorderRadius.circular(8)

// Animation Curves
TooltipCardCurves.fade      // Curves.easeOut
TooltipCardCurves.scaleIn   // Curves.easeOutBack
TooltipCardCurves.scaleOut  // Curves.easeIn
```

---

## ♿ Accessibility

TooltipCard is built with accessibility in mind:

### Keyboard Navigation

| Key | Action |
|-----|--------|
| `Enter` / `Space` | Open tooltip when trigger is focused |
| `Escape` | Close tooltip |
| `Tab` | Navigate through focusable elements |

### Screen Reader Support

- Semantic labels for trigger and tooltip content
- Proper role announcements
- Focus management on open/close

```dart
// Accessibility is built-in, but you can enhance it:
TooltipCard.builder(
  child: Semantics(
    label: 'Help button, tap for more information',
    child: const Icon(Icons.help_outline),
  ),
  builder: (context, close) => Semantics(
    liveRegion: true,
    child: const Text('Help content'),
  ),
)
```

---

## 📱 RTL Support

Full right-to-left language support with logical positioning:

```dart
Directionality(
  textDirection: TextDirection.rtl,
  child: TooltipCard.builder(
    placementSide: TooltipCardPlacementSide.start, // Appears on right in RTL or left in LTR
    child: const Text('مرحبا'),
    builder: (ctx, close) => const Text('محتوى التلميح'),
  ),
)
```

---


## Templates

v2.8.0 introduces `TooltipTemplate` with professional, pre-built card layouts.

### Info Card
```dart
TooltipCard.builder(
  triggerMode: {WhenContentVisible.pressButton},
  builder: (context, close) => TooltipTemplate.info(
    title: 'Did you know?',
    content: 'You can customize...',
    icon: Icons.lightbulb,
    onClose: close,
  ),
  child: Icon(Icons.info),
)
```

### Action Card
```dart
TooltipTemplate.action(
  title: 'Delete Item?',
  content: 'Are you sure?',
  primaryAction: FilledButton(onPressed: (){}, child: Text('Delete')),
  secondaryAction: TextButton(onPressed: (){}, child: Text('Cancel')),
)
```

### Profile Card
```dart
TooltipTemplate.profile(
  name: 'User Name',
  email: 'user@example.com',
  avatar: NetworkImage('...'),
  action: IconButton(icon: Icon(Icons.settings), onPressed: (){}),
)
```

### Tutorial Card
```dart
TooltipTemplate.tutorial(
  title: 'Step 1',
  content: 'Description...',
  currentStep: 1,
  totalSteps: 3,
  onNext: () => setState(() => step++),
  onPrevious: () => setState(() => step--),
)
```

### Checklist Card
```dart
TooltipTemplate.checklist(
  title: 'Setup',
  progress: 0.5,
  items: [CheckboxListTile(...)],
  onContinue: () {},
)
```


### Illustrated Card (Rich Content)

A specialized template for visual storytelling, featuring a side-by-side layout with rich text support.

**New in v2.8.0**: Support for typed paragraphs (`primary`, `normal`, `disable`, `focus`) and disabled sections.

```dart
TooltipTemplate.illustrated(
  image: NetworkImage('https://...'),
  sections: [
    TooltipSection(
      title: 'Rich Content',
      paragraphs: [
        TooltipParagraph(
          text: 'Primary text for emphasis.',
          type: TooltipParagraphType.primary,
        ),
        TooltipParagraph(
          text: 'Standard body text with justified alignment.',
          type: TooltipParagraphType.normal,
        ),
      ],
    ),
    TooltipSection(
      title: 'Disabled Feature',
      isDisabled: true, // Grays out the entire section
      paragraphs: [
        TooltipParagraph(
          text: 'This feature is currently unavailable.',
          type: TooltipParagraphType.disable,
        ),
      ],
    ),
  ],
)
```

---

## 📋 Examples

### Onboarding Tour

```dart
class OnboardingTooltip extends StatelessWidget {
  final TooltipCardController controller;
  final String title;
  final String description;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TooltipCard.builder(
      controller: controller,
      beakEnabled: true,
      modalBarrierEnabled: true,
      barrierBlur: 3.0,
      child: child,
      builder: (context, close) => TooltipCardContent(
        icon: const Icon(Icons.school),
        title: title,
        subtitle: description,
        primaryAction: FilledButton(
          onPressed: () {
            close();
            onNext();
          },
          child: const Text('Next'),
        ),
        secondaryAction: TextButton(
          onPressed: () {
            close();
            onSkip();
          },
          child: const Text('Skip'),
        ),
      ),
    );
  }
}
```

### Context Menu

```dart
TooltipCard.builder(
  whenContentVisible: WhenContentVisible.secondaryTapButton,
  whenContentHide: WhenContentHide.pressOutSide,
  placementSide: TooltipCardPlacementSide.bottomStart,
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: const ListTile(
    title: Text('Right-click me'),
  ),
  builder: (context, close) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ListTile(
        leading: const Icon(Icons.edit),
        title: const Text('Edit'),
        onTap: () { close(); /* edit action */ },
      ),
      ListTile(
        leading: const Icon(Icons.delete),
        title: const Text('Delete'),
        onTap: () { close(); /* delete action */ },
      ),
    ],
  ),
)
```

### Hover Tooltip (Desktop)

```dart
TooltipCard.builder(
  whenContentVisible: WhenContentVisible.hoverButton,
  whenContentHide: WhenContentHide.goAway,
  hoverOpenDelay: const Duration(milliseconds: 400),
  hoverCloseDelay: const Duration(milliseconds: 200),
  beakEnabled: true,
  child: const Icon(Icons.info_outline),
  builder: (context, close) => const Padding(
    padding: EdgeInsets.all(8),
    child: Text('Hover tooltip content'),
  ),
)
```

---

## 🧪 Running the Example

```bash
cd example
flutter pub get
flutter run
```

---


## 🤖 AI Agent Skills

Repository-aware instructions and copy-ready recipes are included for coding
agents:

```text
skill/
├── chatgpt_codex/
│   ├── SKILL.md
│   ├── AGENTS.md
│   └── EXAMPLES.md
└── claude_code/
    ├── SKILL.md
    ├── AGENTS.md
    └── EXAMPLES.md
```

The skills cover installation, constructors, triggers, placement, typed
controllers, theming, SuperCore integration, templates, accessibility, MVC
maintenance rules, testing, and common failure modes.

---

## 📄 License

```
MIT License

Copyright (c) 2025 Genius Systems

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 🔗 Links

- 📦 [pub.dev Package](https://pub.dev/packages/tooltip_card)
- 📖 [API Documentation](https://pub.dev/documentation/tooltip_card/latest/)
- 🐛 [Issue Tracker](https://github.com/geniussystems24/tooltip_card/issues)
- 💻 [Source Code](https://github.com/geniussystems24/tooltip_card)

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/geniussystems24">Genius Systems</a>
</p>
