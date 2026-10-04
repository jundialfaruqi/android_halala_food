import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/user_model.dart';
import '../viewmodels/auth_viewmodel.dart';

/// Halaman Profil Pengguna yang dibangun menggunakan seluruh komponen Widget Core Halala Food.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final authState = ref.watch(authViewModelProvider);
    final fallbackUser = authState.user;

    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: const AppAppBar(
        title: 'Profil Saya',
        showBottomBorder: false,
      ),
      body: RefreshIndicator(
        color: AppColors.brandPrimary,
        backgroundColor: Colors.white,
        onRefresh: () async {
          ref.invalidate(userProfileProvider);
          await ref.read(authViewModelProvider.notifier).refreshUserProfile();
        },
        child: userProfileAsync.when(
          data: (user) => _buildProfileContent(context, ref, user),
          loading: () => fallbackUser != null
              ? _buildProfileContent(context, ref, fallbackUser, isRefreshing: true)
              : _buildLoadingSkeleton(),
          error: (error, _) => fallbackUser != null
              ? _buildProfileContent(context, ref, fallbackUser)
              : _buildErrorState(context, ref, error.toString()),
        ),
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    WidgetRef ref,
    UserModel user, {
    bool isRefreshing = false,
  }) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        children: [
          if (isRefreshing)
            const Padding(
              padding: EdgeInsets.only(bottom: 12.0),
              child: LinearProgressIndicator(
                color: AppColors.brandPrimary,
                backgroundColor: AppColors.brandSoftCream,
              ),
            ),

          // 1. Avatar Inisial Large & Identitas Ringkas
          _buildLargeAvatarSection(user),

          const SizedBox(height: 24),

          // 2. List Informasi Akun dari API auth me
          AppListSection(
            title: 'INFORMASI AKUN',
            children: [
              AppListTile(
                leadingIcon: TablerIcons.user,
                title: 'Nama Lengkap',
                subtitle: user.name.isNotEmpty ? user.name : '-',
              ),
              AppListTile(
                leadingIcon: TablerIcons.mail,
                title: 'Alamat Email',
                subtitle: user.email.isNotEmpty ? user.email : '-',
              ),
              AppListTile(
                leadingIcon: TablerIcons.phone,
                title: 'Nomor Telepon',
                subtitle: (user.phone != null && user.phone!.isNotEmpty)
                    ? user.phone
                    : 'Belum ditambahkan',
              ),
            ],
          ),

          // 3. List Hak Akses & Peran Sistem
          AppListSection(
            title: 'PERAN & HAK AKSES',
            children: [
              AppListTile(
                leadingIcon: TablerIcons.shield_check,
                title: 'Peran Pengguna (Role)',
                subtitle: _formatRoleName(user),
                badge: user.roles.isNotEmpty
                    ? user.roles.first.toUpperCase()
                    : 'STAFF',
              ),
              AppListTile(
                leadingIcon: TablerIcons.key,
                title: 'Total Izin Akses Sistem',
                subtitle: user.roles.contains('dev')
                    ? 'Akses Penuh Tanpa Batas (Super Administrator)'
                    : '${user.permissions.length} Izin Akses Diberikan',
              ),
            ],
          ),

          // 4. List Tindakan & Sesi
          AppListSection(
            title: 'SESI & KEAMANAN',
            children: [
              AppListTile(
                leadingIcon: TablerIcons.logout,
                title: 'Keluar dari Akun',
                subtitle: 'Akhiri sesi login di perangkat ini',
                isDestructive: true,
                showChevron: true,
                onTap: () => _confirmLogout(context, ref),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Versi Aplikasi
          Text(
            'Halala Food App v1.0.0',
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.brandWarmGray,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// 1. Komponen Avatar Inisial Large (Diameter 92px)
  Widget _buildLargeAvatarSection(UserModel user) {
    final initialLetter =
        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U';

    return Center(
      child: Column(
        children: [
          // Avatar Bulat Besar dengan Dual Border dan Shadow Halus
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: AppColors.brandSoftCream,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 3.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandPrimary.withValues(alpha: 0.15),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              initialLetter,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 38,
                fontWeight: FontWeight.w800,
                color: AppColors.brandPrimary,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Nama Pengguna
          Text(
            user.name.isNotEmpty ? user.name : 'Pengguna Halala Food',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.brandEspresso,
            ),
          ),
          const SizedBox(height: 4),

          // Email Pengguna
          Text(
            user.email,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.brandWarmGray,
            ),
          ),
          const SizedBox(height: 10),

          // Role Badge Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.brandSoftCream,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.brandPrimary.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  TablerIcons.badge,
                  size: 14,
                  color: AppColors.brandPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatRoleName(user),
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Shimmer loading skeleton ketika profil dimuat
  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 92,
              height: 92,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 160,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 120,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: AppCard(
              child: Column(
                children: List.generate(
                  4,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppColors.brandSoftCream,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 100,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: AppColors.brandBorder,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 180,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: AppColors.brandSoftCreamLight,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              TablerIcons.alert_triangle,
              size: 48,
              color: AppColors.warning,
            ),
            const SizedBox(height: 14),
            const Text(
              'Gagal Memuat Profil',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.brandEspresso,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12.5,
                color: AppColors.brandWarmGray,
              ),
            ),
            const SizedBox(height: 20),
            AppButton(
              text: 'Coba Lagi',
              icon: const Icon(TablerIcons.refresh, size: 18),
              onPressed: () => ref.refresh(userProfileProvider),
            ),
          ],
        ),
      ),
    );
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
        if (context.mounted) {
          AppSnackBar.showSuccess(
            context,
            message: 'Berhasil keluar dari akun.',
          );
        }
      },
    );
  }
}
