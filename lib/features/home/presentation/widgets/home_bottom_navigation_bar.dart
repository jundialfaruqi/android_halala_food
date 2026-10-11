import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/constants/app_colors.dart';

/// Bottom Navigation Bar Material 3 untuk HomeScreen Halala Food.
/// Berisi 5 menu dengan Tabler Icons:
/// 1. Home
/// 2. Aktifitas (icon tabler chat / message_dots)
/// 3. Scan QR (tengah: rounded circle bg primary, icon & text putih)
/// 4. Buku Besar (icon tabler notebook)
/// 5. Profile (icon tabler user)
class HomeBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const HomeBottomNavigationBar({super.key, this.currentIndex = 0, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              // 1. Home
              _buildStandardNavItem(
                index: 0,
                icon: TablerIcons.home,
                label: 'Home',
              ),

              // 2. Aktifitas (Chat)
              _buildStandardNavItem(
                index: 1,
                icon: TablerIcons.message_dots,
                label: 'Aktifitas',
              ),

              // 3. Scan QR (Center Action Button)
              _buildCenterQrItem(),

              // 4. Buku Besar
              _buildStandardNavItem(
                index: 3,
                icon: TablerIcons.notebook,
                label: 'Buku Besar',
              ),

              // 5. Profile
              _buildStandardNavItem(
                index: 4,
                icon: TablerIcons.user,
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Membangun item navigasi standar (Home, Aktifitas, Buku Besar, Profile)
  Widget _buildStandardNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap?.call(index),
          splashColor: Colors.black.withValues(alpha: 0.05),
          highlightColor: Colors.transparent,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24, color: Colors.black),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8E8E93),
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Membangun tombol Scan QR di tengah:
  /// - Rounded circle dengan background primary
  /// - Icon Scan QR warna putih (ukuran sedikit lebih besar dari yang lain)
  /// - Teks Scan QR warna putih
  Widget _buildCenterQrItem() {
    return Expanded(
      child: Center(
        child: Transform.translate(
          offset: const Offset(0, -14),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () => onTap?.call(2),
              customBorder: const CircleBorder(),
              splashColor: Colors.white.withValues(alpha: 0.25),
              highlightColor: Colors.white.withValues(alpha: 0.15),
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 5.0,
                  ),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(TablerIcons.qrcode, size: 26, color: Colors.white),
                      SizedBox(height: 2),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Scan QR',
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.2,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
