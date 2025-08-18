import 'dart:io' as io;

import 'package:G4A4/pages/loading_service.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:G4A4/config.dart';

class SplashScreen extends StatefulWidget {
  final CustomSplashScreenType typeOfSplashScreen;
  final String? lottoiePath;
  final String? imagePath;
  final String? gifPath;
  final String? videoPath;
  final int splashTimeout;
  final bool? exitInEnd;
  final String? returnRoutePath;

  const SplashScreen(
      {super.key,
      required this.typeOfSplashScreen,
      required this.splashTimeout,
      this.lottoiePath,
      this.imagePath,
      this.gifPath,
      this.videoPath,
      this.exitInEnd,
      this.returnRoutePath});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPreloaded = false;
  ImageProvider? _preloadedImage;
  bool _hasAddedListener = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LoadingService.show(context); // جایگزین child: buildLoadingScreen()
    });
    _controller = AnimationController(vsync: this);

    // Add the listener immediately in initState
    if (widget.exitInEnd == true) {
      _controller.addStatusListener(_animationStatusListener);
      _hasAddedListener = true;
    }

    // Preload assets based on splash screen type
    _preloadAssets();

    // Navigate after timeout if exitInEnd is not true
    if (widget.exitInEnd != true ||
        (widget.typeOfSplashScreen == CustomSplashScreenType.image ||
            widget.typeOfSplashScreen == CustomSplashScreenType.gif)) {
      _navigateToHome();
    }
  }

  // Separate method for the animation status listener
  void _animationStatusListener(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      print(
          "Animation completed, navigating to ${widget.returnRoutePath ?? '/sphome'}");
      _controller.stop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        LoadingService.show(context); // جایگزین child: buildLoadingScreen()
      });
      if (mounted) {
        Navigator.pushReplacementNamed(
            context, widget.returnRoutePath ?? '/sphome');
      }
    }
  }

  Future<void> _preloadAssets() async {
    if (widget.typeOfSplashScreen == CustomSplashScreenType.image) {
      final String path = widget.imagePath ??
          (await io.File(LOGO_MOTION_IMAGE).exists()
              ? LOGO_MOTION_IMAGE
              : LOGO);
      _preloadedImage = AssetImage(path);
      await precacheImage(_preloadedImage!, context);
    } else if (widget.typeOfSplashScreen == CustomSplashScreenType.gif) {
      final String path = widget.gifPath ?? LOGO_MOTION_GIF;
      _preloadedImage = AssetImage(path);
      await precacheImage(_preloadedImage!, context);
    }

    // Load Lottie in the background
    if (widget.typeOfSplashScreen == CustomSplashScreenType.lottie) {
      Future.microtask(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          setState(() {
            _isPreloaded = true;
          });
        }
      });
    }

    if (mounted) {
      setState(() {
        _isPreloaded = true;
      });
    }
  }

  void _navigateToHome() async {
    // Wait for animation to complete or timeout
    await Future.delayed(Duration(seconds: widget.splashTimeout));
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        LoadingService.show(context); // جایگزین child: buildLoadingScreen()
      });
      Navigator.pushReplacementNamed(
          context, widget.returnRoutePath ?? '/sphome');
    }
  }

  @override
  void dispose() {
    // Remove listener before disposing
    if (_hasAddedListener) {
      _controller.removeStatusListener(_animationStatusListener);
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: _buildSplashContent(),
      ),
    );
  }

  Widget _buildSplashContent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LoadingService.hide(); // جایگزین child: buildLoadingScreen()
    });
    switch (widget.typeOfSplashScreen) {
      case CustomSplashScreenType.lottie:
        return Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
                child: Lottie.asset(
              widget.lottoiePath ?? LOGO_MOTION_LOTTIE,
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.height * 0.8,
              fit: BoxFit.contain,
              frameRate: FrameRate(30), // Optimize frame rate
              controller: _controller,
              backgroundLoading: true,
              renderCache: RenderCache.raster,
              repeat: false,
              onLoaded: (composition) {
                // Set the duration and start the animation
                _controller.duration = composition.duration;

                // Debug print to verify animation duration
                print("Lottie animation duration: ${composition.duration}");

                // Start the animation
                _controller.forward();
              },
            )));
      case CustomSplashScreenType.image:
        if (!_isPreloaded || _preloadedImage == null) {
          return const SizedBox.shrink();
        }
        return Image(
          image: _preloadedImage!,
          width: MediaQuery.of(context).size.width * LOGO_MOTION_WIDTH_PER,
          height: MediaQuery.of(context).size.height * LOGO_MOTION_HEIGHT_PER,
          fit: BoxFit.contain,
          filterQuality:
              FilterQuality.medium, // Balance quality and performance
        );
      case CustomSplashScreenType.gif:
        if (!_isPreloaded || _preloadedImage == null) {
          return const SizedBox.shrink();
        }
        return Image(
          image: _preloadedImage!,
          width: MediaQuery.of(context).size.width * LOGO_MOTION_WIDTH_PER,
          height: MediaQuery.of(context).size.height * LOGO_MOTION_HEIGHT_PER,
          fit: BoxFit.contain,
          filterQuality:
              FilterQuality.medium, // Balance quality and performance
        );
      case CustomSplashScreenType.video:
        return const Placeholder(); // Implement video player here
    }
  }
}
