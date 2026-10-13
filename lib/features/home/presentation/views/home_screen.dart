import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/notification_badge_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../activity/presentation/views/activity_screen.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../auth/presentation/views/profile_screen.dart';
import '../../../cash_book/presentation/views/cash_book_screen.dart';
import '../../../delivery/presentation/views/delivery_screen.dart';
import '../../../invoice/presentation/views/invoice_screen.dart';
import '../../../product/presentation/views/product_screen.dart';
import '../../../production/presentation/views/production_screen.dart';
import '../../../purchase/presentation/views/purchase_screen.dart';
import '../../../raw_material/presentation/views/raw_material_screen.dart';
import '../../../report/presentation/views/report_screen.dart';
import '../../../store/presentation/views/store_coordinates_screen.dart';
import '../../../store/presentation/views/store_screen.dart';
import '../../../store/data/models/store_model.dart';
import '../../../user/presentation/views/user_screen.dart';
import '../../data/models/dashboard_stat_model.dart';
import '../viewmodels/home_stat_viewmodel.dart';
import '../viewmodels/home_top_stores_viewmodel.dart';
import '../widgets/home_bottom_navigation_bar.dart';
import '../widgets/home_donut_chart.dart';
import 'package:shimmer/shimmer.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with RouteAware {
  int _currentNavIndex = 0;
  DateTime? _lastBackPressTime;
  late final ScrollController _scrollController;
  final ValueNotifier<bool> _isHeaderScrolledNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final isScrolled = _scrollController.offset > 10;
    if (isScrolled != _isHeaderScrolledNotifier.value) {
      _isHeaderScrolledNotifier.value = isScrolled;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _isHeaderScrolledNotifier.dispose();
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPushNext() {
    // Status bar konsisten hitam di semua layar
    AppStatusBar.setDark();
  }

  @override
  void didPopNext() {
    // Status bar konsisten hitam saat kembali ke Home
    AppStatusBar.setDark();
    // Muat ulang stat card agar selalu terupdate dengan data terbaru
    ref.read(homeStatViewModelProvider.notifier).loadStat();
  }

  /// Helper navigasi sinkron yang langsung memastikan status bar gelap (ikon hitam)
  Future<T?> _navigateTo<T>(Widget screen) async {
    AppStatusBar.setDark();
    final result = await Navigator.of(
      context,
    ).push<T>(MaterialPageRoute(builder: (_) => screen));
    if (mounted) {
      AppStatusBar.setDark();
    }
    return result;
  }

  /// Memuat ulang seluruh data halaman Home (profil pengguna & permissions, ringkasan statistik, dan toko terlaris)
  Future<void> _handleRefresh() async {
    final user = ref.read(authViewModelProvider).user;
    await Future.wait([
      ref.read(authViewModelProvider.notifier).refreshUserProfile(),
      ref.read(homeStatViewModelProvider.notifier).loadStat(),
      if (user != null && user.hasPermission('toko-view'))
        ref.read(homeTopStoresViewModelProvider.notifier).loadTopStores(),
    ]);
  }

  /// Mencegah pengguna tidak sengaja keluar saat menekan tombol back navigasi di halaman Home.
  /// Menampilkan pesan lewat snackbar: "Tekan sekali lagi untuk keluar aplikasi".
  void _handleDoubleBackToExit() {
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      AppSnackBar.showInfo(
        context,
        message: 'Tekan sekali lagi untuk keluar aplikasi',
        duration: const Duration(seconds: 2),
      );
      return;
    }

    AppSnackBar.hide();
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final user = authState.user;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleDoubleBackToExit();
      },
      child: AppScaffold(
      safeAreaTop: false,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      appBar: null,
      bottomNavigationBar: HomeBottomNavigationBar(
        currentIndex: _currentNavIndex,
        activityBadgeCount: ref.watch(notificationBadgeProvider),
        onTap: (index) {
          if (index == 1) {
            final hasAccess = (user?.hasPermission('aktifitas-semua') ?? false) ||
                (user?.hasPermission('aktifitas-kurir') ?? false);
            if (!hasAccess) {
              AppSnackBar.showError(
                context,
                message: 'Anda tidak memiliki hak akses untuk membuka halaman aktifitas.',
              );
              return;
            }
            _navigateTo(const ActivityScreen());
            return;
          }
          if (index == 4) {
            _navigateTo(const ProfileScreen());
            return;
          }
          setState(() {
            _currentNavIndex = index;
          });
        },
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final headerHeight = constraints.maxWidth * 9 / 16;
          final statusBarHeight = MediaQuery.of(context).padding.top;

          return Stack(
            children: [
              // 1. Konten Scrollable
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.axis == Axis.vertical) {
                    final isScrolled = notification.metrics.pixels > 10;
                    if (isScrolled != _isHeaderScrolledNotifier.value) {
                      _isHeaderScrolledNotifier.value = isScrolled;
                    }
                  }
                  return false;
                },
                child: RefreshIndicator(
                  color: AppColors.brandPrimary,
                  backgroundColor: Colors.white,
                  edgeOffset: statusBarHeight + 64,
                  onRefresh: _handleRefresh,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Stack(
                    children: [
                      // Layer 1: Background Banner & Konten Halaman
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Background Gambar Aspek Video (16:9)
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Base dark placeholder agar tidak ada kilatan putih saat gambar di-decode
                                const ColoredBox(color: Color(0xFF1E293B)),
                                // Gambar Background Aspek Video
                                const Image(
                                  image: AssetImage(AppAssets.whyChooseUs),
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                ),
                                // Gradient Overlay disesuaikan agar icon status bar hitam di bagian atas kontras dan teks header terbaca jelas
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.30),
                                        Colors.black.withValues(alpha: 0.25),
                                        Colors.black.withValues(alpha: 0.70),
                                      ],
                                      stops: const [0.0, 0.40, 1.0],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Spacing proporsional untuk card statistik stack floating + jarak visual yang lega
                          const SizedBox(height: 116),

                          // Section Baru: Daftar Toko Mitra Terlaris (Material 3 Carousel)
                          _buildTopStoresCarouselSection(context, user),

                          const SizedBox(height: 24),

                          // Section Konten Menu
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Section Header Menu
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Menu Utama',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.brandEspresso,
                                      ),
                                    ),
                                    if (user != null)
                                      Text(
                                        '${_getAccessibleMenus(user).length} Menu',
                                        style: const TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.brandWarmGray,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Section Menu: Grid 5 Kolom Tanpa Card Pembungkus
                                if (user != null)
                                  _buildFiveColumnMenuGrid(context, user)
                                else
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(24.0),
                                      child: CircularProgressIndicator(
                                        color: AppColors.brandPrimary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Layer 2: Card Statistik Floating simetris di atas batas Header & Body (Dipaint paling atas)
                      Positioned(
                        top: headerHeight - 72,
                        left: 16,
                        right: 16,
                        child: _buildStatsCard(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

              // 2. Sticky User Info Header dengan White Glass Blur & Fade In/Out Bertingkat
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: RepaintBoundary(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _isHeaderScrolledNotifier,
                    builder: (context, isScrolled, _) {
                      return TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: 0.0,
                          end: isScrolled ? 1.0 : 0.0,
                        ),
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOutCubic,
                        builder: (context, value, _) {
                          final isVisible = value > 0.001;
                          final statusBarHeight =
                              MediaQuery.of(context).padding.top;

                          return Stack(
                            children: [
                              // Background sticky header: satu bidang putih solid seragam utuh menyatu dari status bar hingga app bar
                              if (isVisible)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    ignoring: true,
                                    child: Opacity(
                                      opacity: value,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: const Border(
                                            bottom: BorderSide(
                                              color: Color(0xFFE2E8F0),
                                              width: 1.0,
                                            ),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          children: [
                                            // 1. Status Bar key keeper (warna seragam putih murni)
                                            Container(
                                              key: const Key(
                                                'home_sticky_status_bar_solid',
                                              ),
                                              height: statusBarHeight,
                                              width: double.infinity,
                                              color: Colors.white,
                                            ),

                                            // 2. App Bar key keeper (warna seragam putih murni menyatu tanpa shadow terpisah)
                                            Expanded(
                                              child: Container(
                                                key: const Key(
                                                  'home_sticky_glass_blur',
                                                ),
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                              // Konten User Info Header (Sticky di atas dengan warna kontras dinamis)
                              SafeArea(
                                bottom: false,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                                  child: _buildUserInfoRow(context, user, value),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

  /// Konten info pengguna (Avatar, Nama, Role, Bell Icon, Account Dropdown)
  /// dengan warna dinamis kontras tinggi terhadap background banner video & white glass blur
  Widget _buildUserInfoRow(
    BuildContext context,
    UserModel? user,
    double transitionValue,
  ) {
    // Warna teks & ikon: Putih bersih di atas banner video -> Slate gelap kontras di atas white glass blur
    final textColor = Color.lerp(
      Colors.white,
      const Color(0xFF0F172A),
      transitionValue,
    )!;

    final subtextColor = Color.lerp(
      Colors.white.withValues(alpha: 0.92),
      const Color(0xFF475569),
      transitionValue,
    )!;

    final iconColor = Color.lerp(
      Colors.white,
      const Color(0xFF0F172A),
      transitionValue,
    )!;

    // Bayangan teks hanya aktif saat di atas banner gelap (pudar saat glass blur aktif)
    final shadowAlpha = 0.8 * (1.0 - transitionValue);

    return Align(
      alignment: Alignment.topLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar gambar statis app_icon dengan border dan shadow kontras
          Container(
            key: const Key('home_user_avatar_image'),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: Color.lerp(
                  Colors.white,
                  AppColors.brandPrimary.withValues(alpha: 0.35),
                  transitionValue,
                )!,
                width: 2.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color.lerp(
                    Colors.black.withValues(alpha: 0.35),
                    const Color(0xFF0F172A).withValues(alpha: 0.12),
                    transitionValue,
                  )!,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                AppAssets.appIcon,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info Nama & Role (Teks bersih dengan kontras dinamis)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user?.name ?? 'Pengguna Halala Food',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    shadows: [
                      if (shadowAlpha > 0.05)
                        Shadow(
                          color: Colors.black.withValues(alpha: shadowAlpha),
                          blurRadius: 8,
                          offset: const Offset(0, 1),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  _formatRoleName(user),
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: subtextColor,
                    shadows: [
                      if (shadowAlpha > 0.05)
                        Shadow(
                          color: Colors.black.withValues(alpha: shadowAlpha),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Icon Lonceng Notifikasi dengan kontras dinamis & badge merah
          Consumer(
            builder: (context, ref, _) {
              final unreadCount = ref.watch(notificationBadgeProvider);
              return InkWell(
                onTap: () {
                  final hasAccess =
                      (user?.hasPermission('aktifitas-semua') ?? false) ||
                      (user?.hasPermission('aktifitas-kurir') ?? false);
                  if (hasAccess) {
                    _navigateTo(const ActivityScreen());
                  } else {
                    AppSnackBar.showInfo(
                      context,
                      message: 'Belum ada notifikasi baru.',
                    );
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        TablerIcons.bell,
                        size: 26,
                        color: iconColor,
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            key: const Key('home_bell_badge'),
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Center(
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                textAlign: TextAlign.center,
                                textHeightBehavior: const TextHeightBehavior(
                                  applyHeightToFirstAscent: false,
                                  applyHeightToLastDescent: false,
                                ),
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 4),

          // Tombol Dropdown Menu Akun (Frosted circular button kontras dinamis)
          AppDropdownMenu<String>(
            tooltip: 'Menu Akun',
            padding: EdgeInsets.zero,
            triggerWidget: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color.lerp(
                  Colors.black.withValues(alpha: 0.35),
                  const Color(0xFFF1F5F9),
                  transitionValue,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Color.lerp(
                    Colors.white.withValues(alpha: 0.35),
                    const Color(0xFFCBD5E1),
                    transitionValue,
                  )!,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color.lerp(
                      Colors.black.withValues(alpha: 0.25),
                      const Color(0xFF0F172A).withValues(alpha: 0.08),
                      transitionValue,
                    )!,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                TablerIcons.dots_vertical,
                size: 20,
                color: iconColor,
              ),
            ),
            items: const [
              AppDropdownItem(
                value: 'profile',
                label: 'Profil Saya',
                icon: TablerIcons.user,
                isDividerAfter: true,
              ),
              AppDropdownItem(
                value: 'logout',
                label: 'Keluar dari aplikasi',
                icon: TablerIcons.logout,
                isDestructive: true,
              ),
            ],
            onSelected: (value) {
              if (value == 'profile') {
                _navigateTo(const ProfileScreen());
              } else if (value == 'logout') {
                _confirmLogout(context, ref);
              }
            },
          ),
        ],
      ),
    );
  }

  /// Menampilkan grid menu 5 kolom tanpa card pembungkus
  Widget _buildFiveColumnMenuGrid(BuildContext context, UserModel user) {
    final accessibleMenus = _getAccessibleMenus(user);

    if (accessibleMenus.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Column(
            children: const [
              Icon(
                TablerIcons.lock_access,
                size: 48,
                color: AppColors.brandWarmGray,
              ),
              SizedBox(height: 12),
              Text(
                'Belum ada menu yang diberikan izin untuk akun ini.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  color: AppColors.brandWarmGray,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 6,
        mainAxisExtent: 78, // tinggi konsisten setiap item
      ),
      itemCount: accessibleMenus.length,
      itemBuilder: (context, index) {
        final menu = accessibleMenus[index];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (menu.title == 'Produk') {
              _navigateTo(const ProductScreen());
              return;
            }

            if (menu.title == 'Mitra Toko') {
              _navigateTo(const StoreScreen());
              return;
            }

            if (menu.title == 'Kordinat') {
              _navigateTo(const StoreCoordinatesScreen());
              return;
            }

            if (menu.title == 'Pengguna') {
              _navigateTo(const UserScreen());
              return;
            }

            if (menu.title == 'Pengantaran') {
              _navigateTo(const DeliveryScreen());
              return;
            }

            if (menu.title == 'Faktur') {
              _navigateTo(const InvoiceScreen());
              return;
            }

            if (menu.title == 'Produksi') {
              _navigateTo(const ProductionScreen());
              return;
            }

            if (menu.title == 'Bahan Baku') {
              _navigateTo(const RawMaterialScreen());
              return;
            }

            if (menu.title == 'Buku Kas') {
              _navigateTo(const CashBookScreen());
              return;
            }

            if (menu.title == 'Pembelian') {
              _navigateTo(const PurchaseScreen());
              return;
            }

            if (menu.title == 'Laporan') {
              _navigateTo(const ReportScreen());
              return;
            }

            // Menu lainnya
            AppSnackBar.showInfo(
              context,
              message: 'Menu ${menu.title} belum tersedia',
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon container custom rounded: sudut kiri atas & kanan bawah rounded full, sudut kanan atas & kiri bawah no rounded
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.zero,
                    bottomRight: Radius.circular(22),
                    bottomLeft: Radius.zero,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(menu.icon, color: AppColors.brandPrimary, size: 28),
              ),
              const SizedBox(height: 5),
              // Label menu di bawah icon
              Text(
                menu.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandEspresso,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Section Toko Mitra Terlaris menggunakan Material 3 Carousel
  Widget _buildTopStoresCarouselSection(BuildContext context, UserModel? user) {
    if (user != null && !user.hasPermission('toko-view')) {
      return const SizedBox.shrink();
    }

    final topStoresState = ref.watch(homeTopStoresViewModelProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Section Toko Mitra Terlaris
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Toko Mitra Terlaris',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brandEspresso,
                  ),
                ),
              ),
              if (user != null && user.hasPermission('toko-view')) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _navigateTo(const StoreScreen()),
                  child: const Text(
                    'Lihat Semua',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Carousel Material 3
        if (topStoresState.isLoading && topStoresState.stores.isEmpty)
          _buildTopStoresLoadingSkeleton()
        else if (topStoresState.stores.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.brandBorder),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Belum ada data toko mitra aktif.',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  color: AppColors.brandWarmGray,
                ),
              ),
            ),
          )
        else
          AppCarousel.builder(
            height: 200,
            itemExtent: 285,
            shrinkExtent: 40,
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            itemCount: topStoresState.stores.length,
            itemBuilder: (context, index) {
              final store = topStoresState.stores[index];
              return _buildStoreCarouselItem(
                context,
                store,
                index,
                topStoresState.stores.length,
              );
            },
          ),
      ],
    );
  }

  /// Shimmer loading placeholder untuk Carousel Toko Mitra
  Widget _buildTopStoresLoadingSkeleton() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            width: 285,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: ShimmerLoading(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 20,
            ),
          );
        },
      ),
    );
  }

  /// Hitung jumlah bintang (1..5) berdasarkan total produk fisik (pcs/item) terjual dari faktur lunas
  int _getStoreStarCount(StoreModel store, int index, int totalStores) {
    return store.starRating;
  }

  /// Tampilan item card Toko Mitra di dalam Material 3 Carousel
  Widget _buildStoreCarouselItem(
    BuildContext context,
    StoreModel store,
    int index,
    int totalStores,
  ) {
    final starCount = _getStoreStarCount(store, index, totalStores);
    final soldCount = store.soldItemsCount ?? 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Foto Toko sebagai Background
          if (store.photoUrl != null && store.photoUrl!.isNotEmpty)
            AppCachedImage(
              imageUrl: store.photoUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            )
          else
            Container(
              color: const Color(0xFF1E293B),
              alignment: Alignment.center,
              child: const Icon(
                TablerIcons.building_store,
                size: 54,
                color: Colors.white24,
              ),
            ),

          // 2. Dark Gradient Overlay untuk kontras teks yang optimal
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.38),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.88),
                ],
                stops: const [0.0, 0.35, 1.0],
              ),
            ),
          ),

          // 3. Di atas gambar bagian atas: Badge glass blur berisi angka total penjualan di sebelah kiri bintang
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Angka total penjualan fisik produk dari faktur lunas di sebelah kiri bintang
                        Text(
                          '$soldCount',
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 4.5),
                        // Bintang
                        for (int i = 0; i < starCount; i++) ...[
                          if (i > 0) const SizedBox(width: 2),
                          const Icon(
                            TablerIcons.star_filled,
                            size: 13,
                            color: Color(0xFFF59E0B),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 4. Di atas gambar bagian bawah: Nama toko, alamat, dan tombol Lihat Toko
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Baris 1: Nama Toko
                Text(
                  store.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black87,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),

                // Alamat Toko
                Text(
                  store.address ?? 'Alamat belum ditentukan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                    shadows: const [
                      Shadow(
                        color: Colors.black87,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Baris 3: Tombol teks "Lihat Toko" + icon arrow kanan (card rounded full white no border rounded pill full width)
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  elevation: 0,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () {
                      _navigateTo(
                        StoreCoordinatesScreen(
                          initialFocusedStore: store,
                          initialFocusedStoreId: store.id,
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 10,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              'Lihat Toko',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandEspresso,
                              ),
                            ),
                            SizedBox(width: 5),
                            Icon(
                              TablerIcons.arrow_right,
                              size: 15,
                              color: AppColors.brandEspresso,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Daftar menu yang disesuaikan dengan permission Spatie backend
  List<({String title, IconData icon, String permission})> _getAccessibleMenus(
    UserModel user,
  ) {
    final List<({String title, IconData icon, String permission})> allMenus = [
      (title: 'Produk', icon: TablerIcons.box, permission: 'produk-view'),
      (
        title: 'Pengantaran',
        icon: TablerIcons.truck,
        permission: 'pengantaran-view',
      ),
      (
        title: 'Faktur',
        icon: TablerIcons.file_invoice,
        permission: 'faktur-view',
      ),
      (
        title: 'Mitra Toko',
        icon: TablerIcons.building_store,
        permission: 'toko-view',
      ),
      (title: 'Kordinat', icon: TablerIcons.map_pin, permission: 'toko-view'),
      (title: 'Produksi', icon: TablerIcons.tools, permission: 'produksi-view'),
      (
        title: 'Bahan Baku',
        icon: TablerIcons.packages,
        permission: 'bahan-baku-view',
      ),
      (
        title: 'Buku Kas',
        icon: TablerIcons.wallet,
        permission: 'buku-kas-view',
      ),
      (
        title: 'Pembelian',
        icon: TablerIcons.shopping_cart,
        permission: 'pembelian-view',
      ),
      (
        title: 'Laporan',
        icon: TablerIcons.chart_histogram,
        permission: 'laporan-view',
      ),
      (title: 'Pengguna', icon: TablerIcons.users, permission: 'user-manage'),
    ];

    return allMenus
        .where((menu) => user.hasPermission(menu.permission))
        .toList();
  }

  String _formatRoleName(UserModel? user) {
    if (user == null || user.roles.isEmpty) return 'Staff';
    final role = user.roles.first.toLowerCase();
    switch (role) {
      case 'dev':
        return 'Developer / Super Admin';
      case 'manager':
        return 'Manager Operasional';
      case 'kurir':
        return 'Kurir Pengantaran';
      default:
        return user.roles.first.toUpperCase();
    }
  }

  String _getFormattedTodayDate() {
    final now = DateTime.now();
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    final dayName = days[now.weekday - 1];
    final monthName = months[now.month - 1];

    return '$dayName, ${now.day} $monthName ${now.year}';
  }

  /// Format dan pastikan tanggal stat card selalu dalam bahasa Indonesia
  String _formatStatCardDate(String? apiDate) {
    if (apiDate == null || apiDate.trim().isEmpty) {
      return _getFormattedTodayDate();
    }
    String formatted = apiDate;
    const dayMap = {
      'Sunday': 'Minggu',
      'Monday': 'Senin',
      'Tuesday': 'Selasa',
      'Wednesday': 'Rabu',
      'Thursday': 'Kamis',
      'Friday': 'Jumat',
      'Saturday': 'Sabtu',
    };
    const monthMap = {
      'Jan': 'Jan',
      'Feb': 'Feb',
      'Mar': 'Mar',
      'Apr': 'Apr',
      'May': 'Mei',
      'Jun': 'Jun',
      'Jul': 'Jul',
      'Aug': 'Agu',
      'Sep': 'Sep',
      'Oct': 'Okt',
      'Nov': 'Nov',
      'Dec': 'Des',
    };
    dayMap.forEach((en, id) {
      formatted = formatted.replaceAll(en, id);
    });
    monthMap.forEach((en, id) {
      formatted = formatted.replaceAll(en, id);
    });
    return formatted;
  }

  /// Card statistik ringkasan operasional Halala Food dengan widget core AppCard.stacked
  Widget _buildStatsCard() {
    final statState = ref.watch(homeStatViewModelProvider);
    final stat = statState.stat;

    return AppCard.stacked(
      stackAtTop: true,
      isGlass: false,
      backgroundColor: Colors.white,
      borderWidth: 0.0,
      borderColor: Colors.transparent,
      stackOffsetVertical: 9.0,
      stackInsetHorizontal: 13.0,
      customBorderRadius: const BorderRadius.only(
        topLeft: Radius.zero,
        topRight: Radius.circular(24),
        bottomRight: Radius.zero,
        bottomLeft: Radius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header ringkasan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      stat?.type == 'pengantaran'
                          ? TablerIcons.truck_delivery
                          : TablerIcons.chart_pie,
                      size: 16,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        stat?.title ?? 'Ringkasan Hari Ini',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatStatCardDate(stat?.dateFormatted),
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.brandWarmGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          const Divider(height: 1, color: AppColors.brandBorder),
          const SizedBox(height: 10),

          // Konten Utama: Donut Chart (Kiri) + 3 Baris Metrik (Kanan)
          if (statState.isLoading && stat == null)
            _buildStatsLoadingSkeleton()
          else if (stat != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Sisi Kiri: Donut Chart
                HomeDonutChart(
                  donut: stat.donut,
                  size: 74,
                ),
                const SizedBox(width: 14),

                // Sisi Kanan: Baris Keterangan Metrik
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < stat.metrics.length; i++) ...[
                        if (i > 0) const SizedBox(height: 6),
                        _buildMetricRow(stat.metrics[i]),
                      ],
                    ],
                  ),
                ),
              ],
            )
          else
            // Fallback default stat display
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                HomeDonutChart(
                  donut: const DashboardDonutModel(
                    percentage: 100,
                    centerLabel: '100%',
                    centerSublabel: 'Aktif',
                    slices: [
                      DashboardDonutSliceModel(
                        label: 'Normal',
                        value: 1,
                        color: AppColors.brandPrimary,
                      ),
                    ],
                  ),
                  size: 74,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      _FallbackMetricRow(
                        label: 'Sistem',
                        value: 'Online',
                        color: AppColors.brandNaturalGreen,
                      ),
                      SizedBox(height: 6),
                      _FallbackMetricRow(
                        label: 'Operasional',
                        value: 'Berjalan',
                        color: AppColors.brandPrimary,
                      ),
                      SizedBox(height: 6),
                      _FallbackMetricRow(
                        label: 'Koneksi',
                        value: 'Terhubung',
                        color: Color(0xFF3B82F6),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Baris Keterangan Metrik: Teks tetap hitam, bullet persegi di-rotate 45 derajat
  Widget _buildMetricRow(DashboardMetricModel metric) {
    return Row(
      children: [
        // Indikator persegi di-rotate 45 derajat (Diamond / Belah Ketupat)
        DiamondIndicator(color: metric.color, size: 7.5),
        const SizedBox(width: 8),

        // Teks Keterangan & Angka: Tetap berwarna hitam pekat
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A), // Hitam pekat
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                metric.value,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A), // Hitam pekat
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Shimmer loading skeleton saat stat sedang dimuat
  Widget _buildStatsLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE2E8F0),
      highlightColor: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 14,
                  width: 110,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Memanggil widget core AppConfirmDialog untuk logout
  void _confirmLogout(BuildContext context, WidgetRef ref) {
    AppConfirmDialog.show(
      context,
      title: 'Keluar dari Aplikasi',
      message: 'Apakah Anda yakin ingin keluar dari akun Halala Food?',
      confirmText: 'Keluar',
      cancelText: 'Batal',
      isDanger: true,
      onConfirm: () async {
        await ref.read(authViewModelProvider.notifier).logout();
        AppSnackBar.showSuccess(null, message: 'Anda telah berhasil keluar.');
      },
    );
  }
}

class _FallbackMetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _FallbackMetricRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DiamondIndicator(color: color, size: 7.5),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
