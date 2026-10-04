import 'package:flutter/material.dart';
import '../constants/app_assets.dart';
import '../constants/app_colors.dart';

enum SnackBarType { info, success, error }

class AppSnackBar {
  static OverlayEntry? _currentEntry;
  static bool _isShowing = false;

  static void show(
    BuildContext context, {
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    hide();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _isShowing = true;
    _currentEntry = OverlayEntry(
      builder: (context) => _TopSnackBarOverlay(
        message: message,
        type: type,
        duration: duration,
        onDismiss: hide,
      ),
    );

    overlay.insert(_currentEntry!);
  }

  static void hide() {
    if (_isShowing && _currentEntry != null) {
      _isShowing = false;
      try {
        _currentEntry?.remove();
      } catch (_) {}
      _currentEntry = null;
    }
  }

  static void showSuccess(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(context, message: message, type: SnackBarType.success, duration: duration);
  }

  static void showError(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(context, message: message, type: SnackBarType.error, duration: duration);
  }

  static void showInfo(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(context, message: message, type: SnackBarType.info, duration: duration);
  }
}

class _TopSnackBarOverlay extends StatefulWidget {
  final String message;
  final SnackBarType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const _TopSnackBarOverlay({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_TopSnackBarOverlay> createState() => _TopSnackBarOverlayState();
}

class _TopSnackBarOverlayState extends State<_TopSnackBarOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _enterController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  late final AnimationController _progressController;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();

    // 1. Controller untuk transisi masuk & keluar dengan EaseOutBack
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
      reverseDuration: const Duration(milliseconds: 280),
    );

    // Animasi translasi dari atas (-1.2) ke posisi normal (0, 0) dengan kurva Ease Out Back
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _enterController,
        curve: Curves.easeOutBack, // Cepat di awal, melambat di akhir + sedikit overshoot/membal
        reverseCurve: Curves.easeInBack,
      ),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _enterController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    // 2. Controller countdown progress circle durasi tayang
    _progressController = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..reverse(from: 1.0);

    // Jalankan animasi masuk
    _enterController.forward();

    // Otomatis keluar setelah durasi selesai
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        _handleDismiss();
      }
    });
  }

  Future<void> _handleDismiss() async {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    try {
      await _enterController.reverse();
    } catch (_) {}
    if (mounted) {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _enterController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Color get _accentColor {
    switch (widget.type) {
      case SnackBarType.success:
        return AppColors.brandNaturalGreen;
      case SnackBarType.error:
        return AppColors.error;
      case SnackBarType.info:
        return AppColors.brandPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 10,
      left: 16,
      right: 16,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onVerticalDragUpdate: (details) {
                    // Swipe up untuk menutup
                    if (details.primaryDelta! < -4) {
                      _handleDismiss();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _accentColor.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.09),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: _accentColor.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 1. Logo Halala Food dalam container lingkaran
                        Container(
                          width: 38,
                          height: 38,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.brandSoftCream,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.brandBorder),
                          ),
                          child: Image.asset(
                            AppAssets.logo,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.storefront_rounded,
                              size: 20,
                              color: _accentColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // 2. Info Teks: Header "Halala Food" + Pesan
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Halala Food',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _accentColor,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: _accentColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _typeLabel,
                                    style: const TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.brandWarmGray,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.message,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.brandEspresso,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // 3. Progress circle countdown durasi tayang snack bar
                        AnimatedBuilder(
                          animation: _progressController,
                          builder: (context, child) {
                            return SizedBox(
                              width: 26,
                              height: 26,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: _progressController.value,
                                    strokeWidth: 2.5,
                                    backgroundColor:
                                        _accentColor.withValues(alpha: 0.15),
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(_accentColor),
                                  ),
                                  Text(
                                    '${(_progressController.value * widget.duration.inSeconds).ceil()}',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: _accentColor,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _typeLabel {
    switch (widget.type) {
      case SnackBarType.success:
        return 'Sukses';
      case SnackBarType.error:
        return 'Perhatian';
      case SnackBarType.info:
        return 'Informasi';
    }
  }
}
