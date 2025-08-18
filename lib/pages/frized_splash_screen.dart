import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:G4A4/config.dart';
import 'dart:io' as io;

class SplashScreenFrize extends StatefulWidget {
  final String? lottoiePath;
  final String? imagePath;
  final double splashTimeFrized;
  final CustomSplashScreenType type;

  const SplashScreenFrize({
    super.key,
    required this.splashTimeFrized,
    required this.type,
    this.lottoiePath,
    this.imagePath,
  });

  @override
  _SplashScreenFrizeState createState() => _SplashScreenFrizeState();
}

class _SplashScreenFrizeState extends State<SplashScreenFrize>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  ImageProvider? _preloadedImage;
  @override
  void initState() {
    super.initState();
    // if (widget.type == CustomSplashScreenType.lottie) {
    _controller = AnimationController(
      vsync: this,
      value: widget.splashTimeFrized,
    );
    // } else {
    _preloadAssets();
    // }
  }

  Future<void> _preloadAssets() async {
    final String path = widget.imagePath ??
        (await io.File(LOGO_MOTION_IMAGE).exists() ? LOGO_MOTION_IMAGE : LOGO);
    _preloadedImage = AssetImage(path);
    await precacheImage(_preloadedImage!, context);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: widget.type == CustomSplashScreenType.lottie
            ? Lottie.asset(
                widget.lottoiePath ?? LOGO_MOTION_LOTTIE,
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.height * 0.8,
                controller: _controller,
                frameRate: FrameRate.max, // Ensure smooth freeze
                // fit: BoxFit.contain,
                backgroundLoading: true,
                filterQuality: FilterQuality.medium,
              )
            : _preloadedImage == null
                ? const SizedBox.shrink()
                : Image(
                    image: _preloadedImage!,
                    width: MediaQuery.of(context).size.width *
                        LOGO_MOTION_WIDTH_PER,
                    height: MediaQuery.of(context).size.height *
                        LOGO_MOTION_HEIGHT_PER,
                    fit: BoxFit.contain,
                    filterQuality:
                        FilterQuality.medium, // Balance quality and performance
                  ),
      ),
    );
  }
}
