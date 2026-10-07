import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/widgets.dart';

/// True on a native Android/iOS build — false on web, even running on a
/// phone's own browser (web is treated as "desktop-like" throughout the
/// app: see e.g. `NebulaScreen`'s roll knob, which only hides on native
/// mobile since web has no two-finger rotate gesture to replace it with).
/// Reacts to platform, not [isWideLayout]'s own screen-width check — a
/// phone in landscape can trip [isWideLayout] while still very much being
/// a phone, which is exactly the case `RootScreen`'s own side rail uses
/// this for (its wide-layout desktop chrome still needs to fit/behave
/// differently on an actual phone turned sideways).
bool get isTouchOnlyMobile =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Below this width the app renders exactly as it always has (phone chrome,
/// edge-to-edge content). At or above it, [RootScreen] switches to a side
/// nav rail and screen content centers in a capped-width column via
/// `ResponsiveContent` — see both for why. Matches Material 3's "expanded"
/// window-size-class threshold, so a resized browser window or a tablet
/// held in portrait stays on the phone-tuned layout rather than flip-
/// flopping between chrome styles.
const double kWideLayoutBreakpoint = 840;

/// Reacts to actual available width, not platform — the same check applies
/// whether this is Chrome resized narrow, the native Windows build snapped
/// to half-screen, or a phone.
bool isWideLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;

/// The width of the phone-shaped 9:16 column the "Vedi" pages (star,
/// constellation, area) keep their header, content and dock inside on a wide
/// layout — the same shape the Star Reader gives a photo — or null on a phone
/// layout, where the page is edge to edge anyway.
double? readerFrameWidth(BuildContext context) {
  if (!isWideLayout(context)) return null;
  final size = MediaQuery.sizeOf(context);
  return math.min(size.width, size.height * 9 / 16);
}
