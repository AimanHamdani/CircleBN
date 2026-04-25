import 'dart:async';

import 'package:flutter/material.dart';

abstract final class AppAdCreatives {
  // Configure your ad images/GIFs once here.
  // Supports both local assets and URLs.
  static const List<String> all = <String>[
    'assets/ads/conceptA_optionC_animated.gif',
    'assets/ads/conceptA_optionE_style2_animated.gif',
  ];
}

class AppAdBanner extends StatefulWidget {
  final EdgeInsetsGeometry padding;
  final double height;
  final BorderRadius borderRadius;
  final Color backgroundColor;

  const AppAdBanner({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(18, 12, 18, 0),
    this.height = 76,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.backgroundColor = const Color(0xFFF1F3F5),
  });

  @override
  State<AppAdBanner> createState() => _AppAdBannerState();
}

class _AppAdBannerState extends State<AppAdBanner> {
  late final PageController _pageController;
  Timer? _autoSlideTimer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoSlide();
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    if (AppAdCreatives.all.length <= 1) {
      return;
    }
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }
      final next = (_currentIndex + 1) % AppAdCreatives.all.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final creatives = AppAdCreatives.all;
    return Padding(
      padding: widget.padding,
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: Container(
          height: widget.height,
          width: double.infinity,
          color: widget.backgroundColor,
          child: creatives.isEmpty
              ? _fallbackIcon()
              : Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: creatives.length,
                      onPageChanged: (idx) {
                        setState(() => _currentIndex = idx);
                      },
                      itemBuilder: (context, idx) => _AdCreativeImage(
                        pathOrUrl: creatives[idx],
                        fallbackColor: widget.backgroundColor,
                      ),
                    ),
                    if (creatives.length > 1)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 6,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < creatives.length; i++)
                              Container(
                                width: i == _currentIndex ? 12 : 7,
                                height: 7,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: i == _currentIndex
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _fallbackIcon() {
    return Icon(
      Icons.campaign_outlined,
      size: 28,
      color: Colors.black.withValues(alpha: 0.22),
    );
  }
}

class _AdCreativeImage extends StatelessWidget {
  final String pathOrUrl;
  final Color fallbackColor;

  const _AdCreativeImage({
    required this.pathOrUrl,
    required this.fallbackColor,
  });

  bool get _isUrl {
    return pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: fallbackColor,
      alignment: Alignment.center,
      child: Icon(
        Icons.campaign_outlined,
        size: 28,
        color: Colors.black.withValues(alpha: 0.22),
      ),
    );

    if (_isUrl) {
      return Image.network(
        pathOrUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    }

    return Image.asset(
      pathOrUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}
