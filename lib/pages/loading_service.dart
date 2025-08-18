import 'package:flutter/material.dart';
import 'package:G4A4/pages/frized_splash_screen.dart'; // import برای SplashScreenFrize
import 'package:G4A4/config.dart'; // import برای LOGO_MOTION_TYPE
import 'package:G4A4/widgets/helpers.dart'; // import برای Globals اگر لازم باشه

class LoadingService {
  static OverlayEntry? _overlayEntry;
  static bool _isShowing = false;

  // محتوای لودینگ را cache می‌کنیم تا فقط یک بار رندر شود
  static final Widget _cachedLoadingContent = const RepaintBoundary(
    child: SplashScreenFrize(
      splashTimeFrized: 0.9,
      type: LOGO_MOTION_TYPE,
    ),
  );

  static void show(BuildContext? context) {
    if (_isShowing) {
      print('LoadingService: Already showing, skipping show'); // دیباگ
      return;
    }
    _isShowing = true;
    print('LoadingService: Showing overlay'); // دیباگ

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => IgnorePointer(
        child: Material(
          color: Colors.white, // برای تطبیق با background
          child: Center(
            child: _cachedLoadingContent,
          ),
        ),
      ),
    );

    // استفاده از root context برای جلوگیری از مشکلات contextهای nested
    final rootContext = Globals.navigatorKey.currentContext;
    if (rootContext != null && rootContext.mounted) {
      Overlay.of(rootContext).insert(_overlayEntry!);
    } else if (context != null && context.mounted) {
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      print('LoadingService: No valid context for insert'); // دیباگ
      _isShowing = false; // reset اگر شکست خورد
    }
  }

  static void hide() {
    if (!_isShowing) {
      print('LoadingService: Not showing, skipping hide'); // دیباگ
      return;
    }
    _isShowing = false;
    print('LoadingService: Hiding overlay'); // دیباگ

    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
  }
}
