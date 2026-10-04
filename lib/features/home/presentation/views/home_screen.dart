import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/connectivity_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authViewModelProvider);
    final connectivityAsync = ref.watch(connectivityStatusProvider);

    return AppScaffold(
      appBar: AppAppBar(
        showLogo: true,
        title: 'Halala Food',
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.brandEspresso),
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authViewModelProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status bar konektivitas
            connectivityAsync.when(
              data: (results) {
                final isConnected = results.isNotEmpty;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isConnected
                        ? AppColors.brandNaturalGreen.withValues(alpha: 0.12)
                        : AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isConnected
                          ? AppColors.brandNaturalGreen.withValues(alpha: 0.3)
                          : AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                        size: 18,
                        color: isConnected ? AppColors.brandNaturalGreen : AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isConnected ? 'Terhubung ke Jaringan' : 'Tidak Ada Koneksi Internet',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isConnected ? AppColors.brandNaturalGreen : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),

            // Profile Card menggunakan AppCard
            AppCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.brandSoftCream,
                    child: Text(
                      (authState.user?.name.isNotEmpty ?? false)
                          ? authState.user!.name[0].toUpperCase()
                          : 'H',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authState.user?.name ?? 'Pengguna Halala Food',
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brandEspresso,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          authState.user?.email ?? 'admin@halalafood.com',
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            color: AppColors.brandWarmGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Banner Hero Products
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                AppAssets.heroProducts,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 24),

            // Bagian Produk Unggulan
            const Text(
              'Produk Unggulan Kami',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.brandEspresso,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildProductCard(
                    title: 'Merie Wijen',
                    imageAsset: AppAssets.marieWijen,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildProductCard(
                    title: 'Ting-Ting Susu',
                    imageAsset: AppAssets.tingTingSusu,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Demo Skeleton Shimmer & Cache Image
            const Text(
              'Skeleton Shimmer & Cache Image Demo',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.brandEspresso,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: const [
                ShimmerLoading.circular(size: 46),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerLoading(width: double.infinity, height: 14),
                      SizedBox(height: 8),
                      ShimmerLoading(width: 130, height: 12),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const AppCachedImage(
              imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c',
              height: 140,
              width: double.infinity,
              borderRadius: 12,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard({
    required String title,
    required String imageAsset,
  }) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: Image.asset(
              imageAsset,
              height: 110,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.brandEspresso,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
