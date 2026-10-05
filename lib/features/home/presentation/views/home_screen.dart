import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../../auth/presentation/views/profile_screen.dart';
import '../../../store/presentation/views/store_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with RouteAware {
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
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPushNext() {
    // Sinkronisasi instan saat layar lain (Profil/Toko) mulai di-push di atas Home
    AppStatusBar.setDark();
  }

  @override
  void didPopNext() {
    // Sinkronisasi instan saat layar di atasnya di-pop dan kembali ke Home
    AppStatusBar.setLight();
  }

  /// Helper navigasi sinkron yang langsung mengubah status bar di frame ke-0
  Future<T?> _navigateTo<T>(Widget screen) async {
    AppStatusBar.setDark();
    final result = await Navigator.of(context).push<T>(
      MaterialPageRoute(
        builder: (_) => screen,
      ),
    );
    if (mounted) {
      AppStatusBar.setLight();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final user = authState.user;

    return AppScaffold(
      backgroundColor: Colors.white,
      safeAreaTop: false,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      appBar: null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final headerHeight = constraints.maxWidth * 9 / 16;

          return SingleChildScrollView(
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
                          const ColoredBox(
                            color: Color(0xFF1E293B),
                          ),
                          // Gambar Background Aspek Video
                          const Image(
                            image: AssetImage(AppAssets.whyChooseUs),
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                          // Dark Gradient Overlay untuk kontras teks & icon status bar
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.72),
                                  Colors.black.withValues(alpha: 0.28),
                                  Colors.black.withValues(alpha: 0.65),
                                ],
                                stops: const [0.0, 0.45, 1.0],
                              ),
                            ),
                          ),
                          // Konten Header dalam SafeArea top
                          SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Avatar inisial dengan border putih dan shadow
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.35),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        (user?.name.isNotEmpty ?? false)
                                            ? user!.name[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.brandPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Info Nama & Role (Teks bersih tanpa badge)
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
                                              color: Colors.white,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black.withValues(alpha: 0.8),
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
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white.withValues(alpha: 0.90),
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black.withValues(alpha: 0.8),
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
                                    const SizedBox(width: 8),

                                    // Tombol Dropdown Menu Akun (Frosted circular button)
                                    AppDropdownMenu<String>(
                                      tooltip: 'Menu Akun',
                                      triggerWidget: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.35),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.35),
                                            width: 1.2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.25),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          TablerIcons.dots_vertical,
                                          size: 20,
                                          color: Colors.white,
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
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Spacing proporsional untuk efek stack 3 card statistik (~73px) + jarak visual konsisten ke menu (24px)
                    const SizedBox(height: 96),

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

                          // Section Menu: Grid 4 Kolom Tanpa Card Pembungkus
                          if (user != null)
                            _buildFourColumnMenuGrid(context, user)
                          else
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: CircularProgressIndicator(color: AppColors.brandPrimary),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Layer 2: Card Statistik Floating simetris di atas batas Header & Body (Dipaint paling atas)
                Positioned(
                  top: headerHeight - 60,
                  left: 16,
                  right: 16,
                  child: _buildStatsCard(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Menampilkan grid menu 4 kolom tanpa card pembungkus
  Widget _buildFourColumnMenuGrid(BuildContext context, UserModel user) {
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
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        crossAxisSpacing: 10,
        mainAxisExtent: 90, // tinggi konsisten setiap item
      ),
      itemCount: accessibleMenus.length,
      itemBuilder: (context, index) {
        final menu = accessibleMenus[index];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (menu.title == 'Mitra Toko') {
              _navigateTo(const StoreScreen());
              return;
            }

            // Menu lainnya
            AppSnackBar.showInfo(
              context,
              message: 'Membuka menu ${menu.title}',
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon container rounded circle tanpa border dengan shadow tipis
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.brandSoftCream,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(
                  menu.icon,
                  color: AppColors.brandPrimary,
                  size: 25,
                ),
              ),
              const SizedBox(height: 8),
              // Label menu di bawah icon
              Text(
                menu.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
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

  /// Daftar menu yang disesuaikan dengan permission Spatie backend
  List<({String title, IconData icon, String permission})> _getAccessibleMenus(
      UserModel user) {
    final List<({String title, IconData icon, String permission})> allMenus = [
      (title: 'Produk', icon: TablerIcons.box, permission: 'produk-view'),
      (title: 'Pengantaran', icon: TablerIcons.truck, permission: 'pengantaran-view'),
      (title: 'Faktur', icon: TablerIcons.file_invoice, permission: 'faktur-view'),
      (title: 'Mitra Toko', icon: TablerIcons.building_store, permission: 'toko-view'),
      (title: 'Produksi', icon: TablerIcons.tools, permission: 'produksi-view'),
      (title: 'Bahan Baku', icon: TablerIcons.packages, permission: 'bahan-baku-view'),
      (title: 'Buku Kas', icon: TablerIcons.wallet, permission: 'buku-kas-view'),
      (title: 'Pembelian', icon: TablerIcons.shopping_cart, permission: 'pembelian-view'),
      (title: 'Laporan', icon: TablerIcons.chart_histogram, permission: 'laporan-view'),
      (title: 'Pengguna', icon: TablerIcons.users, permission: 'user-manage'),
      (title: 'Pengaturan', icon: TablerIcons.settings, permission: 'pengaturan-view'),
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

  /// Card statistik ringkasan operasional Halala Food dengan widget core AppCard.stacked
  Widget _buildStatsCard() {
    return AppCard.stacked(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header ringkasan
          Row(
            children: const [
              Icon(
                TablerIcons.chart_pie,
                size: 16,
                color: AppColors.brandPrimary,
              ),
              SizedBox(width: 7),
              Text(
                'Ringkasan Hari Ini',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandEspresso,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.brandBorder),
          const SizedBox(height: 12),

          // 3 Kolom Metrik Statistik Bisnis Halala Food (Space Evenly, Rata Kiri)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatColumn(
                icon: TablerIcons.coin,
                label: 'Penjualan',
                value: 'Rp 4,8 Jt',
              ),
              Container(
                width: 1,
                height: 38,
                color: AppColors.brandBorder,
              ),
              _buildStatColumn(
                icon: TablerIcons.packages,
                label: 'Produksi',
                value: '180 Box',
              ),
              Container(
                width: 1,
                height: 38,
                color: AppColors.brandBorder,
              ),
              _buildStatColumn(
                icon: TablerIcons.truck_delivery,
                label: 'Pengantaran',
                value: '14 Toko',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: AppColors.brandPrimary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.brandWarmGray,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.brandEspresso,
          ),
        ),
      ],
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
        AppSnackBar.showSuccess(
          null,
          message: 'Anda telah berhasil keluar.',
        );
      },
    );
  }
}
