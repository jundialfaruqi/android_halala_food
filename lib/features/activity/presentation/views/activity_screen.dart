import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../viewmodels/activity_viewmodel.dart';
import '../widgets/activity_chat_bubble.dart';
import '../widgets/activity_date_chip.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Infinite scroll listener: saat di-scroll ke atas (mendekati data lama),
  /// muat 10 data berikutnya dari buffer lokal atau fetch 50 data lama dari server.
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(activityViewModelProvider.notifier).loadMoreOlder();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final user = authState.user;
    final state = ref.watch(activityViewModelProvider);

    // Verifikasi permission hak akses
    final canViewAll = user?.hasPermission('aktifitas-semua') ?? false;
    final canViewCourier = user?.hasPermission('aktifitas-kurir') ?? false;
    final hasAccess = canViewAll || canViewCourier;

    final subtitle = canViewAll
        ? 'Semua Aktifitas Sistem'
        : (canViewCourier ? 'Aktifitas Tugas Kurir' : 'Akses Terbatas');

    return AppStatusBar(
      child: AppScaffold(
        appBar: const AppAppBar(
          title: 'Linimasa Aktifitas',
        ),
        body: Container(
          // Latar belakang khas ruang obrolan WhatsApp (soft light gray)
          color: const Color(0xFFF3F4F6),
          child: !hasAccess
              ? _buildNoAccessView()
              : Column(
                  children: [
                    // Subtitle status permission bar di atas obrolan
                    _buildPermissionStatusBar(subtitle, canViewAll),

                    // Konten Linimasa Chat
                    Expanded(
                      child: _buildChatBody(state, user?.id ?? 0),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Bar status hak akses di bawah AppBar (Bersih, minimalis tanpa badge warna-warni)
  Widget _buildPermissionStatusBar(String subtitle, bool canViewAll) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: AppColors.brandBorder.withValues(alpha: 0.6),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.brandEspresso,
            ),
          ),
          Text(
            canViewAll ? 'Semua User' : 'Khusus Kurir',
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.brandWarmGray,
            ),
          ),
        ],
      ),
    );
  }

  /// Tampilan ketika user tidak memiliki permission
  Widget _buildNoAccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: AppEmptyCard(
          icon: TablerIcons.lock_access,
          title: 'Akses Dibatasi',
          message:
              'Akun Anda tidak memiliki izin untuk melihat linimasa aktifitas sistem. Hubungi administrator/manager untuk informasi lebih lanjut.',
        ),
      ),
    );
  }

  /// Tampilan utama daftar obrolan WhatsApp aktifitas
  Widget _buildChatBody(ActivityState state, int currentUserId) {
    if (state.isLoading) {
      return _buildLoadingList();
    }

    if (state.errorMessage != null && state.activities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                TablerIcons.alert_circle,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  color: AppColors.brandWarmGray,
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                text: 'Coba Lagi',
                onPressed: () {
                  ref
                      .read(activityViewModelProvider.notifier)
                      .loadActivities(refresh: true);
                },
              ),
            ],
          ),
        ),
      );
    }

    final visibleList = state.visibleActivities;

    if (visibleList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: AppEmptyCard(
            icon: TablerIcons.message_circle_2,
            title: 'Belum Ada Aktifitas',
            message:
                'Aktifitas surat pengiriman, faktur, dan pembayaran akan muncul di sini secara real-time seperti ruang chat.',
          ),
        ),
      );
    }

    // Menggunakan ListView reversed (format obrolan chat WhatsApp):
    // index 0 berada di paling BAWAH (aktifitas TERBARU).
    // index bertambah ke ATAS (aktifitas LEBIH LAMA).
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 16),
      itemCount: visibleList.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Loading spinner di bagian atas saat scroll ke atas memuat data lama
        if (index == visibleList.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.brandPrimary,
                ),
              ),
            ),
          );
        }

        final activity = visibleList[index];

        // Cek apakah perlu menampilkan chip batas tanggal di tengah:
        // Dalam urutan reverse: index berikutnya (index + 1) adalah pesan yang LEBIH LAMA.
        // Jika pesan ini adalah pesan paling lama yang terlihat (index == visibleList.length - 1)
        // ATAU tanggal pesan ini berbeda dari pesan sebelumnya (index + 1),
        // maka tampilkan ActivityDateChip di atas bubble ini!
        final bool isLastVisible = index == visibleList.length - 1;
        final bool isNewDay = isLastVisible ||
            (activity.dateGroupKey != visibleList[index + 1].dateGroupKey);

        // Hitung jarak vertikal dinamis:
        // - Antar chat saya dengan chat user lain: lebih berjarak lega (22px)
        // - Antar chat saya sendiri: jarak bertambah (10px)
        // - Antar user lain yang berbeda: (12px)
        // - Antar pesan user lain yang sama: (8px)
        double topSpacing = 6.0;
        if (!isLastVisible) {
          final nextActivity = visibleList[index + 1]; // Pesan di atas pesan ini
          final isCurrentMe = activity.userId == currentUserId;
          final isAboveMe = nextActivity.userId == currentUserId;

          if (isCurrentMe != isAboveMe) {
            // Transisi antara chat saya dan chat user lain (tambah sedikit lagi dari 16px -> 22px)
            topSpacing = 22.0;
          } else if (isCurrentMe && isAboveMe) {
            // Jarak antar chat saya sendiri (tambah dari 3px -> 10px)
            topSpacing = 10.0;
          } else if (activity.userId != nextActivity.userId) {
            // Antar user lain yang berbeda
            topSpacing = 12.0;
          } else {
            // Pesan beruntun dari user lain yang sama
            topSpacing = 8.0;
          }
        } else {
          topSpacing = 8.0;
        }

        final bubbleWidget = ActivityChatBubble(
          activity: activity,
          currentUserId: currentUserId,
          topSpacing: isNewDay ? 4.0 : topSpacing,
        );

        if (isNewDay && activity.createdAt != null) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ActivityDateChip(date: activity.createdAt!),
              bubbleWidget,
            ],
          );
        }

        return bubbleWidget;
      },
    );
  }

  /// Skeleton shimmer loader saat memuat chat pertama kali
  Widget _buildLoadingList() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: 6,
      itemBuilder: (context, index) {
        final isRight = index % 2 == 1;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment:
                isRight ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isRight) ...[
                const ShimmerLoading(width: 34, height: 34, borderRadius: 17),
                const SizedBox(width: 8),
              ],
              ShimmerLoading(
                width: 240,
                height: 90,
                borderRadius: 16,
              ),
              if (isRight) ...[
                const SizedBox(width: 8),
                const ShimmerLoading(width: 34, height: 34, borderRadius: 17),
              ],
            ],
          ),
        );
      },
    );
  }
}
