import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../auth/auth_service.dart';
import '../auth/google_button_stub.dart'
    if (dart.library.js_interop) '../auth/google_button_web.dart';
import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../theme/app_style.dart';

/// The page in front of everything: the app opens only for a signed-in
/// account. Same look as the landing page: the night sky with a few static
/// stars, a large title with its second line in gold, soft blue-grey text and
/// a gold pill button.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.auth,
    required this.locale,
    required this.onLocaleChanged,
  });

  final AuthService auth;
  final String locale;
  final ValueChanged<String> onLocaleChanged;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuthChanged);
    // Google's own button on the web needs Firebase and Google Sign-In ready.
    widget.auth.ensureReady();
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.auth.signInWithGoogle();
    } catch (_) {
      // A cancelled account picker is not worth a message; a real failure is.
      if (mounted) setState(() => _failed = widget.auth.lastError != null);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retry() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    await widget.auth.retry();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final quiet = MediaQuery.disableAnimationsOf(context);
    final unavailable = widget.auth.initFailed;
    final showFailure =
        _failed || (widget.auth.lastError != null && !unavailable);

    return Scaffold(
      backgroundColor: colors.night,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(child: CustomPaint(painter: _NightSky())),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _Header(
                        locale: widget.locale,
                        onLocaleChanged: widget.onLocaleChanged,
                        label: strings.loginLanguageLabel,
                      ),
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: quiet ? 1 : 0, end: 1),
                              duration: const Duration(milliseconds: 700),
                              curve: Curves.easeOut,
                              builder: (context, t, child) => Opacity(
                                opacity: t,
                                child: Transform.translate(
                                  offset: Offset(0, (1 - t) * 14),
                                  child: child,
                                ),
                              ),
                              child: _Hero(
                                colors: colors,
                                before: strings.loginHeroBefore,
                                accent: strings.loginHeroAccent,
                                text: strings.loginText,
                                action: _action(colors, unavailable),
                                note: unavailable
                                    ? strings.loginUnavailable
                                    : (showFailure
                                          ? strings.accountSignInFailed
                                          : strings.loginNote),
                                noteIsError: unavailable || showFailure,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(AppColors colors, bool unavailable) {
    final strings = context.strings;
    if (_busy) {
      return SizedBox(
        height: 48,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.gold,
            ),
          ),
        ),
      );
    }
    if (unavailable) {
      return _PillButton(
        key: const ValueKey('login-retry'),
        label: strings.loginRetry,
        onPressed: _retry,
        colors: colors,
        filled: false,
      );
    }
    if (kIsWeb) {
      // Google requires its own button on the web; it reports the sign-in
      // through the authentication events.
      return SizedBox(
        key: const ValueKey('login-google-web'),
        height: 48,
        child: widget.auth.isResolved
            ? buildGoogleWebButton()
            : const SizedBox.shrink(),
      );
    }
    return _PillButton(
      key: const ValueKey('login-sign-in'),
      label: strings.accountSignIn,
      onPressed: _signIn,
      colors: colors,
      icon: Icons.login,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.locale,
    required this.onLocaleChanged,
    required this.label,
  });

  final String locale;
  final ValueChanged<String> onLocaleChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        ExcludeSemantics(
          child: SvgPicture.asset(
            'assets/icon/Logo.svg',
            width: 34,
            height: 34,
            colorFilter: ColorFilter.mode(colors.gold, BlendMode.srcIn),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Inner Stars',
          style: TextStyle(
            fontFamily: kFontBranding,
            fontSize: 25,
            height: 1,
            color: colors.text,
          ),
        ),
        const Spacer(),
        Semantics(
          label: label,
          child: Row(
            children: [
              for (final (index, code) in const ['it', 'en', 'ro'].indexed) ...[
                if (index > 0)
                  Text(
                    '  /  ',
                    style: TextStyle(color: colors.muted, fontSize: 10),
                  ),
                InkWell(
                  key: ValueKey('login-locale-$code'),
                  onTap: () => onLocaleChanged(code),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      code.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1,
                        fontWeight: locale == code
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: locale == code
                            ? colors.gold
                            : const Color(0xFFA4ADBD),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.colors,
    required this.before,
    required this.accent,
    required this.text,
    required this.action,
    required this.note,
    required this.noteIsError,
  });

  final AppColors colors;
  final String before;
  final String accent;
  final String text;
  final Widget action;
  final String note;
  final bool noteIsError;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final size = (width * .105).clamp(36.0, 64.0);
    TextStyle title(Color color) => TextStyle(
      fontFamily: kFontBody,
      fontSize: size,
      height: 1.12,
      fontWeight: FontWeight.w700,
      letterSpacing: -.035 * size,
      color: color,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(before, textAlign: TextAlign.center, style: title(colors.text)),
        Text(accent, textAlign: TextAlign.center, style: title(colors.gold)),
        const SizedBox(height: 28),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: kFontBody,
              fontSize: 17,
              height: 1.7,
              color: Color(0xFF98A2BB),
            ),
          ),
        ),
        const SizedBox(height: 32),
        action,
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(
            note,
            key: const ValueKey('login-note'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kFontBody,
              fontSize: 11,
              height: 1.5,
              color: noteIsError ? colors.danger : colors.muted,
            ),
          ),
        ),
      ],
    );
  }
}

/// The landing page's pill: gold fill with dark text, or an outline.
class _PillButton extends StatelessWidget {
  const _PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.colors,
    this.icon,
    this.filled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final AppColors colors;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? colors.onGold : colors.gold;
    return Material(
      color: filled ? colors.gold : Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: colors.gold)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 12),
              ],
              AppButtonLabel(label, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

/// The landing page's sky: a deep blue glow off to one side fading to near
/// black, with a few still stars. Painted once, never animated.
class _NightSky extends CustomPainter {
  const _NightSky();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(.36, -.1),
          radius: 1.15,
          colors: [Color(0xFF1C2747), Color(0xFF10162B), Color(0xFF05070D)],
          stops: [0, .48, 1],
        ).createShader(rect),
    );
    final random = math.Random(11);
    final paint = Paint();
    final count = (size.width * size.height / 9000).clamp(40, 140).round();
    for (var i = 0; i < count; i++) {
      final gold = random.nextInt(9) == 0;
      paint.color = (gold ? const Color(0xFFF2B84B) : const Color(0xFFDDE4F5))
          .withValues(alpha: .15 + random.nextDouble() * .5);
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        .4 + random.nextDouble() * 1.1,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_NightSky oldDelegate) => false;
}
