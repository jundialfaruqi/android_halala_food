import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/connectivity_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authViewModelProvider);
    final user = authState.user;
    final connectivityAsync = ref.watch(connectivityStatusProvider);

    return AppScaffold(
      backgroundColor: Colors.white,
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      appBar: AppAppBar(
        backgroundColor: Colors.white,
        centerTitle: false,
        titleSpacing: 16.0,
        titleWidget: Row(
          children: [
            // Avatar inisial
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.brandSoftCream,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.brandBorder),
              ),
              alignment: Alignment.center,
              child: Text(
                (user?.name.isNotEmpty ?? false)
                    ? user!.name[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info Nama & Role
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user?.name ?? 'Pengguna Halala Food',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandEspresso,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.brandNaturalGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _formatRoleName(user),
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brandWarmGray,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Widget Core Dropdown Menu (Profil Saya & Keluar dari aplikasi)
          AppDropdownMenu<String>(
            tooltip: 'Menu Akun',
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
                _showProfileDialog(context, user);
              } else if (value == 'logout') {
                _confirmLogout(context, ref);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status bar konektivitas (jika offline)
            connectivityAsync.when(
              data: (results) {
                final isConnected = results.isNotEmpty;
                if (isConnected) return const SizedBox.shrink();

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        TablerIcons.wifi_off,
                        size: 19,
                        color: AppColors.error,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Tidak Ada Koneksi Internet',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

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
            const SizedBox(height: 16),

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
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 18,
        crossAxisSpacing: 10,
        mainAxisExtent: 88, // tinggi konsisten setiap item
      ),
      itemCount: accessibleMenus.length,
      itemBuilder: (context, index) {
        final menu = accessibleMenus[index];
        return InkWell(
          onTap: () {
            // Menggunakan Material 3 AppSnackBar dengan countdown progress circle
            AppSnackBar.showInfo(
              context,
              message: 'Membuka menu ${menu.title}',
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon container tanpa card pembungkus
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.brandSoftCream,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  menu.icon,
                  color: AppColors.brandPrimary,
                  size: 26,
                ),
              ),
              const SizedBox(height: 6),
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
      (title: 'Dashboard', icon: TablerIcons.dashboard, permission: 'dashboard-view'),
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

  void _showProfileDialog(BuildContext context, UserModel? user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(TablerIcons.user, size: 22, color: AppColors.brandPrimary),
            SizedBox(width: 10),
            Text(
              'Profil Saya',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.bold,
                color: AppColors.brandEspresso,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileRow('Nama', user?.name ?? '-'),
            const SizedBox(height: 10),
            _buildProfileRow('Email', user?.email ?? '-'),
            const SizedBox(height: 10),
            _buildProfileRow('Nomor Telepon', user?.phone ?? '-'),
            const SizedBox(height: 10),
            _buildProfileRow('Role', _formatRoleName(user)),
            const SizedBox(height: 10),
            _buildProfileRow(
              'Total Hak Akses',
              user?.roles.contains('dev') ?? false
                  ? 'Semua Akses (Super Admin)'
                  : '${user?.permissions.length ?? 0} Permissions',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Tutup',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w600,
                color: AppColors.brandPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 12,
            color: AppColors.brandWarmGray,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            fontWeight: FontWeight.w600,
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
      icon: TablerIcons.logout_2,
      isDanger: true,
      onConfirm: () async {
        await ref.read(authViewModelProvider.notifier).logout();
        if (context.mounted) {
          AppSnackBar.showSuccess(
            context,
            message: 'Anda telah berhasil keluar.',
          );
        }
      },
    );
  }
}
