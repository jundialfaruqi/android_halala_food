import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/models/user_management_model.dart';
import '../viewmodels/user_viewmodel.dart';
import 'user_form_screen.dart';

/// Halaman Master Pengguna (Staf & Hak Akses) Halala Food.
/// Menggunakan seluruh Core Widget yang seragam dengan Produk Screen:
/// - AppScaffold (background putih bersih, handling keyboard)
/// - AppStatusBar
/// - AppAppBar
/// - AppCard
/// - AppEmptyCard
/// - AppSearchField
/// - AppFloatingActionButton
/// - AppConfirmDialog
/// - AppSnackBar
/// - Inisial avatar circle no border
class UserScreen extends ConsumerStatefulWidget {
  const UserScreen({super.key});

  @override
  ConsumerState<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends ConsumerState<UserScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (currentScroll >= maxScroll - 200) {
      ref.read(userViewModelProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userViewModelProvider);
    final notifier = ref.read(userViewModelProvider.notifier);
    final authState = ref.watch(authViewModelProvider);

    // Permission check sama seperti di web: user-manage
    final canManageUser = authState.user?.hasRole('dev') == true ||
        (authState.user?.hasPermission('user-manage') ?? false);

    return AppScaffold(
      appBar: const AppAppBar(
        title: 'Pengguna',
      ),
      floatingActionButton: canManageUser
          ? AppFloatingActionButton.extended(
              onPressed: () => _onCreateUser(),
              icon: const Icon(TablerIcons.plus, size: 20),
              label: 'Tambah Pengguna',
              tooltip: 'Tambah Pengguna Baru',
            )
          : null,
      body: Column(
        children: [
          // Filter & Search Bar Atas
          _buildFilterHeader(state, notifier),

          // Ringkasan Total Data Pengguna
          if (!state.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 4.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      state.hasFilter
                          ? 'Menampilkan ${state.users.length} dari ${state.total} Pengguna'
                          : 'Menampilkan ${state.total} Pengguna',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandWarmGray,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (state.hasFilter) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        notifier.resetFilters();
                      },
                      child: const Text(
                        'Reset Filter',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 6),

          // Konten Daftar Pengguna
          Expanded(
            child: _buildUserContent(state, notifier, canManageUser),
          ),
        ],
      ),
    );
  }

  /// Bagian Atas: Search Input dan Filter Select Peran
  Widget _buildFilterHeader(UserState state, UserViewModel notifier) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Input menggunakan AppSearchField Core Widget
          AppSearchField(
            controller: _searchController,
            hintText: 'Cari nama staf, email, nomor HP...',
            onChanged: (query) => notifier.onSearchChanged(query),
            onSubmitted: (query) => notifier.onSearchChanged(query),
            onClear: () => notifier.clearSearch(),
          ),

          const SizedBox(height: 10),

          // Bar Filter Select Peran
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildRoleDropdown(state, notifier),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Dropdown Filter Peran (Semua Peran, Developer, Manager, Kurir)
  Widget _buildRoleDropdown(UserState state, UserViewModel notifier) {
    final roleMap = <String, String>{
      'all': 'Semua Peran',
      'dev': 'Developer / Super Admin',
      'manager': 'Manager Operasional',
      'kurir': 'Kurir Pengantaran',
    };

    // Tambahkan peran dinamis jika ada dari backend
    for (final role in state.availableRoles) {
      if (!roleMap.containsKey(role.name.toLowerCase())) {
        roleMap[role.name.toLowerCase()] = role.displayName;
      }
    }

    final isFiltered = state.selectedRole != 'all';
    final currentLabel = roleMap[state.selectedRole.toLowerCase()] ?? 'Peran';

    return PopupMenuButton<String>(
      tooltip: 'Pilih Peran',
      offset: const Offset(0, 36),
      elevation: 6,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.brandBorder),
      ),
      onSelected: (role) => notifier.selectRole(role),
      itemBuilder: (context) {
        return roleMap.entries.map((entry) {
          final isSelected = state.selectedRole.toLowerCase() == entry.key;
          return PopupMenuItem<String>(
            value: entry.key,
            height: 38,
            child: Text(
              entry.value,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.brandPrimary
                    : AppColors.brandEspresso,
              ),
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isFiltered ? AppColors.brandPrimary : AppColors.brandBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentLabel,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isFiltered
                    ? AppColors.brandPrimary
                    : AppColors.brandEspresso,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              TablerIcons.chevron_down,
              size: 14,
              color: isFiltered
                  ? AppColors.brandPrimary
                  : AppColors.brandWarmGray,
            ),
          ],
        ),
      ),
    );
  }

  /// Bagian Konten Pengguna: Loading, Error, Empty, atau List
  Widget _buildUserContent(
    UserState state,
    UserViewModel notifier,
    bool canManageUser,
  ) {
    if (state.isLoading) {
      return _buildShimmerLoadingList();
    }

    if (state.errorMessage != null && state.users.isEmpty) {
      return AppEmptyCard(
        title: 'Gagal Memuat Pengguna',
        message: state.errorMessage!,
        actionText: 'Coba Lagi',
        onAction: () => notifier.fetchUsers(refresh: true),
      );
    }

    if (state.users.isEmpty) {
      return AppEmptyCard(
        title: 'Pengguna Tidak Ditemukan',
        message: state.hasFilter
            ? 'Tidak ada data pengguna yang cocok dengan pencarian atau peran yang dipilih.'
            : 'Belum ada data staf/pengguna yang terdaftar dalam sistem.',
        actionText: state.hasFilter
            ? 'Hapus Filter'
            : (canManageUser ? 'Tambah Pengguna' : null),
        actionIcon: state.hasFilter
            ? null
            : (canManageUser ? TablerIcons.plus : null),
        onAction: state.hasFilter
            ? () {
                _searchController.clear();
                notifier.resetFilters();
              }
            : (canManageUser ? () => _onCreateUser() : null),
      );
    }

    return RefreshIndicator(
      color: AppColors.brandPrimary,
      backgroundColor: Colors.white,
      onRefresh: () => notifier.fetchUsers(refresh: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: state.users.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.users.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
            );
          }

          final user = state.users[index];
          return _buildUserCardItem(user, canManageUser);
        },
      ),
    );
  }

  /// Shimmer loading list skeleton
  Widget _buildShimmerLoadingList() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: 6,
      itemBuilder: (context, index) {
        return _buildShimmerUserCard();
      },
    );
  }

  /// Shimmer skeleton untuk satu card data pengguna
  Widget _buildShimmerUserCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        backgroundColor: Colors.white,
        borderRadius: 16,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const ShimmerLoading(
                  width: 48,
                  height: 48,
                  borderRadius: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerLoading(
                        width: double.infinity,
                        height: 16,
                        borderRadius: 4,
                      ),
                      SizedBox(height: 6),
                      ShimmerLoading(
                        width: 140,
                        height: 12,
                        borderRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.brandBorder),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerLoading(width: 70, height: 11, borderRadius: 3),
                      SizedBox(height: 5),
                      ShimmerLoading(width: 100, height: 14, borderRadius: 4),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerLoading(width: 80, height: 11, borderRadius: 3),
                      SizedBox(height: 5),
                      ShimmerLoading(width: 100, height: 14, borderRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Card Item Pengguna: Inisial Avatar Circle No Border, Tipografi Bersih
  Widget _buildUserCardItem(UserManagementModel user, bool canManageUser) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        backgroundColor: Colors.white,
        borderRadius: 16,
        padding: const EdgeInsets.all(16),
        onTap: canManageUser ? () => _onEditUser(user) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baris Header: Inisial Avatar Circle No Border + Nama & Email + Kebab Menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Inisial avatar circle tanpa border (Core style sesuai request)
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.brandSoftCream,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    user.initials,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Nama Pengguna & Email
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.name,
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandEspresso,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (user.isCurrentUser) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brandSoftCream,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Anda',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandPrimary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user.email,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          color: AppColors.brandWarmGray,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Kebab Action Menu jika diizinkan
                if (canManageUser)
                  PopupMenuButton<String>(
                    icon: const Icon(
                      TablerIcons.dots_vertical,
                      size: 20,
                      color: AppColors.brandWarmGray,
                    ),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _onEditUser(user);
                      } else if (value == 'delete') {
                        _confirmDeleteUser(user);
                      } else if (value == 'wa') {
                        _openWhatsApp(user.whatsappUrl);
                      }
                    },
                    itemBuilder: (context) => [
                      if (user.whatsappUrl != null)
                        const PopupMenuItem(
                          value: 'wa',
                          height: 40,
                          child: Row(
                            children: [
                              Icon(
                                TablerIcons.brand_whatsapp,
                                size: 18,
                                color: Color(0xFF25D366),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Chat WhatsApp',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'edit',
                        height: 40,
                        child: Row(
                          children: [
                            Icon(
                              TablerIcons.edit,
                              size: 18,
                              color: AppColors.brandEspresso,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Edit Pengguna',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!user.isCurrentUser)
                        const PopupMenuItem(
                          value: 'delete',
                          height: 40,
                          child: Row(
                            children: [
                              Icon(
                                TablerIcons.trash,
                                size: 18,
                                color: AppColors.error,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Hapus Pengguna',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.brandBorder),
            const SizedBox(height: 10),

            // 2x2 Grid Informasi: Peran, No. Telepon, Bergabung, WhatsApp Cepat
            Row(
              children: [
                Expanded(
                  child: _buildColumnInfo(
                    'Peran / Jabatan',
                    user.primaryRoleLabel,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildColumnInfo(
                    'No. WhatsApp / HP',
                    user.formattedPhone ?? '-',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _buildColumnInfo(
                    'Terdaftar Sejak',
                    user.createdAtHuman ?? '-',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: user.whatsappUrl != null
                      ? GestureDetector(
                          onTap: () => _openWhatsApp(user.whatsappUrl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Aksi Cepat',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.brandWarmGray,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: const [
                                  Icon(
                                    TablerIcons.brand_whatsapp,
                                    size: 14,
                                    color: Color(0xFF25D366),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Hubungi WA',
                                    style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF25D366),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      : _buildColumnInfo('Status Kontak', 'Tanpa WhatsApp'),
                ),
              ],
            ),

            // Footer Tombol Aksi (Seragam dengan Produk Screen)
            if (canManageUser) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.brandBorder),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      label: 'Edit',
                      icon: TablerIcons.edit,
                      isDanger: false,
                      onTap: () => _onEditUser(user),
                    ),
                  ),
                  if (!user.isCurrentUser) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButton(
                        label: 'Hapus',
                        icon: TablerIcons.trash,
                        isDanger: true,
                        onTap: () => _confirmDeleteUser(user),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Kolom Ringkasan Informasi Sederhana & Bersih
  Widget _buildColumnInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.brandWarmGray,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.brandEspresso,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Tombol Aksi Footer Item Pengguna (Seragam dengan Produk Screen)
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required bool isDanger,
    required VoidCallback onTap,
  }) {
    final iconColor = isDanger ? AppColors.error : AppColors.brandWarmGray;
    final textColor = isDanger ? AppColors.error : AppColors.brandEspresso;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.brandBorder),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: iconColor,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Action Buka Halaman Tambah Pengguna Baru
  Future<void> _onCreateUser() async {
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (routeContext) => const UserFormScreen(),
      ),
    );

    if (result != null && mounted) {
      final userName = (result is UserManagementModel) ? result.name : '';
      AppSnackBar.showSuccess(
        context,
        message: userName.isNotEmpty
            ? 'Pengguna "$userName" berhasil ditambahkan.'
            : 'Pengguna baru berhasil ditambahkan.',
      );
      ref.read(userViewModelProvider.notifier).fetchUsers(refresh: true);
    }
  }

  /// Action Buka Halaman Edit Pengguna
  Future<void> _onEditUser(UserManagementModel user) async {
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (routeContext) => UserFormScreen(user: user),
      ),
    );

    if (result != null && mounted) {
      final userName =
          (result is UserManagementModel) ? result.name : user.name;
      AppSnackBar.showSuccess(
        context,
        message: 'Data pengguna "$userName" berhasil diperbarui.',
      );
      ref.read(userViewModelProvider.notifier).fetchUsers(refresh: true);
    }
  }

  /// Dialog Konfirmasi Hapus Pengguna Menggunakan AppConfirmDialog
  void _confirmDeleteUser(UserManagementModel user) {
    AppConfirmDialog.show(
      context,
      title: 'Hapus Pengguna',
      message:
          'Apakah Anda yakin ingin menghapus akun staf "${user.name}"? Pengguna tidak akan dapat masuk ke sistem lagi.',
      confirmText: 'Hapus',
      cancelText: 'Batal',
      isDanger: true,
      icon: TablerIcons.trash,
      onConfirm: () => _executeDeleteUser(user),
    );
  }

  /// Eksekusi Penghapusan Pengguna
  Future<void> _executeDeleteUser(UserManagementModel user) async {
    try {
      await ref.read(userViewModelProvider.notifier).deleteUser(user.id);
      if (!mounted) return;
      AppSnackBar.showSuccess(
        context,
        message: 'Pengguna "${user.name}" berhasil dihapus.',
      );
    } catch (e) {
      if (!mounted) return;
      String errorMsg = 'Gagal menghapus pengguna.';
      if (e is DioException) {
        if (e.response?.statusCode == 403) {
          errorMsg = 'Anda tidak memiliki hak akses untuk menghapus pengguna.';
        } else if (e.response?.data is Map &&
            e.response?.data['message'] != null) {
          errorMsg = e.response?.data['message'].toString() ?? errorMsg;
        }
      }
      AppSnackBar.showError(
        context,
        message: errorMsg,
      );
    }
  }

  /// Buka Tautan Direct Chat WhatsApp
  Future<void> _openWhatsApp(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        AppSnackBar.showInfo(
          context,
          message: 'Tidak dapat membuka aplikasi WhatsApp.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.showInfo(
        context,
        message: 'Tidak dapat membuka aplikasi WhatsApp.',
      );
    }
  }
}
