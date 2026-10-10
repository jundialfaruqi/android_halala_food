import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../data/models/delivery_model.dart';
import '../../data/repositories/delivery_repository_impl.dart';
import '../viewmodels/delivery_viewmodel.dart';
import 'delivery_complete_screen.dart';
import 'delivery_edit_screen.dart';

class DeliveryDetailScreen extends ConsumerStatefulWidget {
  final int deliveryId;

  const DeliveryDetailScreen({
    super.key,
    required this.deliveryId,
  });

  @override
  ConsumerState<DeliveryDetailScreen> createState() =>
      _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends ConsumerState<DeliveryDetailScreen> {
  bool _isLoading = true;
  DeliveryModel? _delivery;
  String? _errorMessage;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(deliveryRepositoryProvider);
      final delivery = await repository.getDeliveryDetail(widget.deliveryId);
      if (mounted) {
        setState(() {
          _delivery = delivery;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _openMap(DeliveryStoreModel store) async {
    Uri? uri;
    if (store.latitude != null && store.longitude != null) {
      uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${store.latitude},${store.longitude}');
    } else if (store.address != null && store.address!.isNotEmpty) {
      final encodedAddress = Uri.encodeComponent(store.address!);
      uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$encodedAddress');
    }

    if (uri != null) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          AppSnackBar.showError(context, message: 'Tidak dapat membuka Google Maps');
        }
      }
    } else {
      if (mounted) {
        AppSnackBar.showInfo(context, message: 'Alamat atau koordinat toko tidak tersedia');
      }
    }
  }

  Future<void> _dispatchDelivery() async {
    if (_delivery == null) return;

    AppConfirmDialog.show(
      context,
      title: 'Berangkatkan Pengantaran',
      message:
          'Mulai perjalanan pengantaran untuk surat jalan ${_delivery!.deliveryNumber}?',
      confirmText: 'Mulai Kirim',
      cancelText: 'Batal',
      onConfirm: () async {
        final notifier = ref.read(deliveryViewModelProvider.notifier);
        final success = await notifier.dispatchDelivery(_delivery!.id);
        if (mounted) {
          if (success) {
            AppSnackBar.showSuccess(
              context,
              message:
                  'Surat jalan ${_delivery!.deliveryNumber} kini dalam status sedang dikirim.',
            );
            _loadDetail();
          } else {
            AppSnackBar.showError(
              context,
              message: 'Gagal memberangkatkan pengantaran.',
            );
          }
        }
      },
    );
  }

  Future<void> _cancelDelivery() async {
    if (_delivery == null) return;

    AppConfirmDialog.show(
      context,
      title: 'Batalkan Surat Jalan',
      message:
          'Apakah Anda yakin ingin membatalkan surat jalan ${_delivery!.deliveryNumber}? Stok produk muatan akan otomatis dikembalikan ke gudang.',
      confirmText: 'Ya, Batalkan',
      cancelText: 'Kembali',
      isDanger: true,
      onConfirm: () async {
        final notifier = ref.read(deliveryViewModelProvider.notifier);
        final success = await notifier.cancelDelivery(_delivery!.id);
        if (mounted) {
          if (success) {
            AppSnackBar.showSuccess(
              context,
              message: 'Surat jalan berhasil dibatalkan dan stok dikembalikan.',
            );
            _loadDetail();
          } else {
            AppSnackBar.showError(
              context,
              message: 'Gagal membatalkan surat jalan.',
            );
          }
        }
      },
    );
  }

  Future<void> _deleteDelivery() async {
    if (_delivery == null) return;

    AppConfirmDialog.show(
      context,
      title: 'Hapus Surat Jalan',
      message:
          'Hapus permanen surat jalan ${_delivery!.deliveryNumber}? Tindakan ini tidak dapat dibatalkan.',
      confirmText: 'Hapus Permanen',
      cancelText: 'Batal',
      isDanger: true,
      onConfirm: () async {
        final notifier = ref.read(deliveryViewModelProvider.notifier);
        final success = await notifier.deleteDelivery(_delivery!.id);
        if (mounted) {
          if (success) {
            AppSnackBar.showSuccess(
              context,
              message: 'Surat jalan berhasil dihapus.',
            );
            Navigator.pop(context);
          } else {
            AppSnackBar.showError(
              context,
              message: 'Gagal menghapus surat jalan.',
            );
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authViewModelProvider).user;
    final canEditPermission = user?.hasPermission('pengantaran-edit') ?? false;
    final canDeletePermission = user?.hasPermission('pengantaran-delete') ?? false;

    // Dropdown menu options for AppAppBar actions
    final List<AppDropdownItem<String>> actionItems = [];
    if (_delivery != null) {
      if (_delivery!.canEdit && canEditPermission) {
        actionItems.add(const AppDropdownItem(
          value: 'edit',
          label: 'Edit Surat Jalan',
        ));
      }
      if ((_delivery!.isDiproses || _delivery!.isDikirim) && canDeletePermission) {
        actionItems.add(const AppDropdownItem(
          value: 'cancel',
          label: 'Batalkan Pengantaran',
          isDestructive: true,
        ));
      }
      if (!_delivery!.isSelesai && canDeletePermission) {
        actionItems.add(const AppDropdownItem(
          value: 'delete',
          label: 'Hapus Surat Jalan',
          isDestructive: true,
        ));
      }
    }

    return AppStatusBar(
      child: AppScaffold(
        appBar: AppAppBar(
          title: 'Rincian Surat Jalan',
          actions: [
            if (actionItems.isNotEmpty)
              AppDropdownMenu<String>(
                padding: const EdgeInsets.only(right: 14),
                items: actionItems,
                onSelected: (val) {
                  if (val == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DeliveryEditScreen(deliveryId: _delivery!.id),
                      ),
                    ).then((_) => _loadDetail());
                  } else if (val == 'cancel') {
                    _cancelDelivery();
                  } else if (val == 'delete') {
                    _deleteDelivery();
                  }
                },
              ),
          ],
        ),
        bottomNavigationBar: _buildBottomActionBar(),
        body: _buildBody(),
      ),
    );
  }

  Widget? _buildBottomActionBar() {
    if (_delivery == null) return null;

    final user = ref.watch(authViewModelProvider).user;
    final canStatusPermission = (user?.hasPermission('pengantaran-status') ?? false) ||
        (user?.hasPermission('pengantaran-edit') ?? false);
    if (!canStatusPermission) return null;

    if (_delivery!.isDiproses) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppColors.brandBorder, width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: AppButton(
            text: 'Berangkatkan Pengantaran',
            height: 48,
            borderRadius: 12,
            onPressed: _dispatchDelivery,
          ),
        ),
      );
    }

    if (_delivery!.isDikirim) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppColors.brandBorder, width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: AppButton(
            text: 'Selesaikan Serah Terima',
            height: 48,
            borderRadius: 12,
            backgroundColor: AppColors.brandPrimary,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DeliveryCompleteScreen(delivery: _delivery!),
                ),
              ).then((_) => _loadDetail());
            },
          ),
        ),
      );
    }

    return null;
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildShimmerDetail();
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  color: AppColors.brandEspresso,
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                text: 'Coba Lagi',
                onPressed: _loadDetail,
              ),
            ],
          ),
        ),
      );
    }

    if (_delivery == null) {
      return const Center(
        child: Text('Data surat jalan tidak ditemukan'),
      );
    }

    final d = _delivery!;

    return RefreshIndicator(
      color: AppColors.brandPrimary,
      onRefresh: _loadDetail,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // 1. Ringkasan Surat Jalan (Card Utama)
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      d.deliveryNumber,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                    Text(
                      _currencyFormat.format(d.totalAmount),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandEspresso,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Tanggal: ${d.formattedDate}',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.brandWarmGray,
                  ),
                ),
                if (d.notes != null && d.notes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Catatan: ${d.notes}',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: AppColors.brandWarmGray,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const Divider(height: 1, color: AppColors.brandBorder),
                const SizedBox(height: 14),

                // Bagian Status: Vertical Stepper 3 Baris
                _buildStatusStepperSection(d),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Info Toko Mitra Tujuan
          if (d.store != null) ...[
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Toko Mitra Tujuan',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandEspresso,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    d.store!.name,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandEspresso,
                    ),
                  ),
                  if (d.store!.ownerName != null &&
                      d.store!.ownerName!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Pemilik: ${d.store!.ownerName}',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13.5,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                  ],
                  if (d.store!.phone != null && d.store!.phone!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _buildPhoneRow(
                      context,
                      label: 'No. HP/WA',
                      rawPhone: d.store!.phone!,
                      targetName: d.store!.name,
                    ),
                  ],
                  if (d.store!.route != null && d.store!.route!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Rute Wilayah: ${d.store!.route}',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13.5,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                  ],
                  if (d.store!.address != null &&
                      d.store!.address!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      d.store!.address!,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13.5,
                        color: AppColors.brandEspresso,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  AppButton.outline(
                    text: 'Buka di Google Maps',
                    height: 40,
                    borderRadius: 10,
                    onPressed: () => _openMap(d.store!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 3. Rincian Muatan Barang (Info Kurir Bertugas telah dipindahkan ke dalam Stepper Status)

          // 4. Rincian Muatan Barang
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Muatan Barang',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                    Text(
                      '${d.totalItems} Kemasan',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.brandBorder),
                const SizedBox(height: 10),

                ...d.items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final photoUrl = item.productPhotoUrl;
                  final hasPhoto = photoUrl != null && photoUrl.trim().isNotEmpty;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          child: Text(
                            '${index + 1}.',
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brandWarmGray,
                            ),
                          ),
                        ),
                        // Foto Produk Rounded Circle
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.brandBorder, width: 1),
                            color: const Color(0xFFF1F5F9),
                          ),
                          child: ClipOval(
                            child: hasPhoto
                                ? AppCachedImage(
                                    imageUrl: photoUrl,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    borderRadius: 0,
                                  )
                                : Center(
                                    child: Text(
                                      item.productName.isNotEmpty
                                          ? item.productName[0].toUpperCase()
                                          : 'P',
                                      style: const TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.brandEspresso,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandEspresso,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${item.quantity} ${item.productUnit} @ ${_currencyFormat.format(item.unitPrice)}',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12.5,
                                  color: AppColors.brandWarmGray,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currencyFormat.format(item.subtotal),
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandEspresso,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const Divider(height: 1, color: AppColors.brandBorder),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Nilai Muatan',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                    Text(
                      _currencyFormat.format(d.totalAmount),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandEspresso,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 5. Bukti & Serah Terima (Jika Selesai)
          if (d.isSelesai) ...[
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bukti Serah Terima',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandEspresso,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Diterima Oleh: ${d.recipientName ?? "-"}',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandEspresso,
                    ),
                  ),
                  if (d.recipientRole != null &&
                      d.recipientRole!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Jabatan / Hubungan: ${d.recipientRole}',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13.5,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                  ],
                  if (d.recipientPhone != null &&
                      d.recipientPhone!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _buildPhoneRow(
                      context,
                      label: 'No. HP Penerima',
                      rawPhone: d.recipientPhone!,
                      targetName: d.recipientName ?? 'Penerima',
                    ),
                  ],
                  if (d.deliveredAt != null && d.deliveredAt!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Waktu Serah Terima: ${d.formattedDeliveredAt}',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13.5,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                  ],
                  if (d.invoice != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Faktur Piutang: ${d.invoice!.invoiceNumber} (${_currencyFormat.format(d.invoice!.totalAmount)})',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandEspresso,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                  if (d.proofImageUrl != null &&
                      d.proofImageUrl!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Foto Bukti Serah Terima:',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandEspresso,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AppCachedImage(
                        imageUrl: d.proofImageUrl!,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Skeleton shimmer saat memuat data rincian surat jalan
  Widget _buildShimmerDetail() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: const [
        // 1. Ringkasan Surat Jalan & Status Stepper (Card Utama)
        AppCard(
          padding: EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerLoading(width: 150, height: 20, borderRadius: 4),
                  ShimmerLoading(width: 100, height: 18, borderRadius: 4),
                ],
              ),
              SizedBox(height: 8),
              ShimmerLoading(width: 140, height: 13, borderRadius: 4),
              SizedBox(height: 14),
              Divider(height: 1, color: AppColors.brandBorder),
              SizedBox(height: 14),

              // Baris 1 Shimmer: Status & Lacak
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerLoading(width: 70, height: 16, borderRadius: 4),
                  ShimmerLoading(width: 55, height: 16, borderRadius: 4),
                ],
              ),
              SizedBox(height: 16),

              // Baris 2 Shimmer: Vertical Stepper 3 Steps
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerLoading(width: 22, height: 22, borderRadius: 11),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerLoading(width: 90, height: 14, borderRadius: 4),
                      SizedBox(height: 4),
                      ShimmerLoading(width: 160, height: 12, borderRadius: 3),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerLoading(width: 22, height: 22, borderRadius: 11),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerLoading(width: 110, height: 14, borderRadius: 4),
                      SizedBox(height: 4),
                      ShimmerLoading(width: 140, height: 12, borderRadius: 3),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerLoading(width: 22, height: 22, borderRadius: 11),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerLoading(width: 80, height: 14, borderRadius: 4),
                      SizedBox(height: 4),
                      ShimmerLoading(width: 150, height: 12, borderRadius: 3),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16),
              Divider(height: 1, color: AppColors.brandBorder),
              SizedBox(height: 14),

              // Baris 1 Shimmer: Teks kurir kiri dan nama kurir kanan
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerLoading(width: 45, height: 14, borderRadius: 4),
                  ShimmerLoading(width: 120, height: 14, borderRadius: 4),
                ],
              ),
              SizedBox(height: 10),

              // Baris 2 Shimmer: No. HP kiri dan nomor HP kanan
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerLoading(width: 50, height: 13, borderRadius: 4),
                  ShimmerLoading(width: 110, height: 13, borderRadius: 2),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 14),

        // 2. Info Mitra Toko
        AppCard(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerLoading(width: 120, height: 14, borderRadius: 4),
              SizedBox(height: 10),
              Divider(height: 1, color: AppColors.brandBorder),
              SizedBox(height: 12),
              ShimmerLoading(width: 180, height: 16, borderRadius: 4),
              SizedBox(height: 6),
              ShimmerLoading(width: 140, height: 13, borderRadius: 4),
              SizedBox(height: 6),
              ShimmerLoading(width: 220, height: 13, borderRadius: 4),
            ],
          ),
        ),
        SizedBox(height: 14),

        // 5. Muatan Barang
        AppCard(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerLoading(width: 100, height: 14, borderRadius: 4),
                  ShimmerLoading(width: 60, height: 14, borderRadius: 4),
                ],
              ),
              SizedBox(height: 10),
              Divider(height: 1, color: AppColors.brandBorder),
              SizedBox(height: 12),
              ShimmerLoading(
                  width: double.infinity, height: 42, borderRadius: 8),
              SizedBox(height: 8),
              ShimmerLoading(
                  width: double.infinity, height: 42, borderRadius: 8),
            ],
          ),
        ),
      ],
    );
  }

  /// Format nomor telepon agar selalu diawali '+'
  String _formatPhone(String rawPhone) {
    final clean = rawPhone.trim();
    if (clean.isEmpty) return clean;
    return clean.startsWith('+') ? clean : '+$clean';
  }

  /// Salin nomor telepon ke clipboard lengkap dengan tanda '+'
  Future<void> _copyPhoneToClipboard(
    BuildContext context,
    String rawPhone,
  ) async {
    final phoneToCopy = _formatPhone(rawPhone);

    await Clipboard.setData(ClipboardData(text: phoneToCopy));

    if (context.mounted) {
      AppSnackBar.showSuccess(
        context,
        message: 'Nomor $phoneToCopy disalin ke clipboard.',
      );
    }
  }

  /// Buka obrolan direct chat WhatsApp (wa.me)
  Future<void> _openWhatsApp(
    BuildContext context,
    String rawPhone,
    String targetName,
  ) async {
    var digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) {
      digits = '62${digits.substring(1)}';
    }

    if (digits.isEmpty) {
      AppSnackBar.showError(
        context,
        message: 'Nomor WhatsApp tidak valid.',
      );
      return;
    }

    final message = Uri.encodeComponent(
      'Halo $targetName, saya dari Halala Food terkait surat jalan ${_delivery?.deliveryNumber ?? ''}.',
    );
    final whatsappUri = Uri.parse('whatsapp://send?phone=$digits&text=$message');
    final webUri = Uri.parse('https://wa.me/$digits?text=$message');

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          AppSnackBar.showError(
            context,
            message: 'Tidak dapat membuka aplikasi WhatsApp.',
          );
        }
      }
    } catch (_) {
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (context.mounted) {
          AppSnackBar.showError(
            context,
            message: 'Gagal membuka tautan WhatsApp.',
          );
        }
      }
    }
  }

  /// Widget baris nomor HP dengan format '+' serta tombol Salin dan WhatsApp secara between
  Widget _buildPhoneRow(
    BuildContext context, {
    required String label,
    required String rawPhone,
    required String targetName,
  }) {
    final formattedPhone = _formatPhone(rawPhone);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13.5,
                    color: AppColors.brandWarmGray,
                  ),
                ),
                TextSpan(
                  text: formattedPhone,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandEspresso,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tombol Salin dengan Icon
            InkWell(
              onTap: () => _copyPhoneToClipboard(context, rawPhone),
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      TablerIcons.copy,
                      size: 14,
                      color: AppColors.brandPrimary,
                    ),
                    SizedBox(width: 3),
                    Text(
                      'Salin',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Tombol WhatsApp dengan Icon
            InkWell(
              onTap: () => _openWhatsApp(context, rawPhone, targetName),
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      TablerIcons.brand_whatsapp,
                      size: 14,
                      color: AppColors.brandNaturalGreen,
                    ),
                    SizedBox(width: 3),
                    Text(
                      'WhatsApp',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandNaturalGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Bagian Status Stepper (3 Baris):
  /// 1. Titel teks Status & Tombol teks Lacak
  /// 2. Stepper vertical
  /// 3. Teks informasi kurir
  Widget _buildStatusStepperSection(DeliveryModel d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Baris 1: Titel teks Status & Tombol teks Lacak
        _buildStatusStepperHeader(context),

        // Baris 2: Stepper vertical
        _buildVerticalStepper(d),

        // Baris 3: Teks informasi kurir
        _buildCourierInfoSection(d),
      ],
    );
  }

  /// Baris 1: Header status dengan judul 'Status' dan tombol aksi 'Lacak'
  Widget _buildStatusStepperHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Status',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.brandEspresso,
          ),
        ),
        InkWell(
          onTap: () {
            AppSnackBar.showInfo(
              context,
              message: 'Fitur pelacakan pengantaran sedang disiapkan.',
            );
          },
          borderRadius: BorderRadius.circular(6),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Lacak',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandPrimary,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  TablerIcons.chevron_right,
                  size: 15,
                  color: AppColors.brandPrimary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Baris 2: Stepper vertical perjalanan surat jalan
  Widget _buildVerticalStepper(DeliveryModel d) {
    final List<({String title, String subtitle, _DeliveryStepState state})> steps;

    if (d.isDibatalkan) {
      steps = [
        (
          title: 'Diproses',
          subtitle: 'Surat jalan disiapkan • ${d.formattedDate}',
          state: _DeliveryStepState.completed,
        ),
        (
          title: 'Dibatalkan',
          subtitle: 'Pengantaran surat jalan dibatalkan',
          state: _DeliveryStepState.cancelled,
        ),
      ];
    } else {
      // Step 1: Diproses
      final step1Subtitle = 'Disiapkan di gudang • ${d.formattedDate}';

      // Step 2: Sedang Dikirim
      final String step2Subtitle;
      final _DeliveryStepState step2State;
      if (d.isSelesai) {
        step2Subtitle = d.dispatchedAt != null
            ? 'Diberangkatkan ${d.formattedDispatchedAt}'
            : 'Pengantaran kurir selesai';
        step2State = _DeliveryStepState.completed;
      } else if (d.isDikirim) {
        step2Subtitle = d.dispatchedAt != null
            ? 'Diberangkatkan ${d.formattedDispatchedAt}'
            : 'Kurir dalam perjalanan menuju toko';
        step2State = _DeliveryStepState.current;
      } else {
        step2Subtitle = 'Menunggu keberangkatan kurir';
        step2State = _DeliveryStepState.pending;
      }

      // Step 3: Selesai
      final String step3Subtitle;
      final _DeliveryStepState step3State;
      if (d.isSelesai) {
        final recipientInfo =
            (d.recipientName != null && d.recipientName!.trim().isNotEmpty)
                ? ' • Diterima oleh ${d.recipientName}'
                : '';
        step3Subtitle = d.deliveredAt != null
            ? 'Selesai ${d.formattedDeliveredAt}$recipientInfo'
            : 'Serah terima barang selesai$recipientInfo';
        step3State = _DeliveryStepState.completed;
      } else {
        step3Subtitle = 'Menunggu serah terima di toko';
        step3State = _DeliveryStepState.pending;
      }

      steps = [
        (
          title: 'Diproses',
          subtitle: step1Subtitle,
          state: _DeliveryStepState.completed,
        ),
        (
          title: 'Sedang Dikirim',
          subtitle: step2Subtitle,
          state: step2State,
        ),
        (
          title: 'Selesai',
          subtitle: step3Subtitle,
          state: step3State,
        ),
      ];
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        children: steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isLast = index == steps.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Node + Line
                SizedBox(
                  width: 22,
                  child: Column(
                    children: [
                      _buildStepNode(step.state),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: step.state == _DeliveryStepState.completed
                                ? AppColors.brandPrimary
                                : AppColors.brandBorder,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Text Content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          step.title,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13.5,
                            fontWeight: (step.state == _DeliveryStepState.completed ||
                                    step.state == _DeliveryStepState.current)
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: step.state == _DeliveryStepState.current
                                ? AppColors.brandPrimary
                                : (step.state == _DeliveryStepState.cancelled
                                    ? AppColors.error
                                    : (step.state == _DeliveryStepState.pending
                                        ? AppColors.brandWarmGray
                                        : AppColors.brandEspresso)),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          step.subtitle,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            fontWeight: step.state == _DeliveryStepState.current
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: step.state == _DeliveryStepState.cancelled
                                ? AppColors.error
                                : AppColors.brandWarmGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Indicator node untuk vertical stepper
  Widget _buildStepNode(_DeliveryStepState state) {
    switch (state) {
      case _DeliveryStepState.completed:
        return Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: AppColors.brandPrimary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            TablerIcons.check,
            size: 13,
            color: Colors.white,
          ),
        );
      case _DeliveryStepState.current:
        return Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.brandPrimary,
              width: 2.5,
            ),
          ),
          child: Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.brandPrimary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      case _DeliveryStepState.pending:
        return Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.brandBorder,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.brandBorder,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      case _DeliveryStepState.cancelled:
        return Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: AppColors.error,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            TablerIcons.x,
            size: 13,
            color: Colors.white,
          ),
        );
    }
  }

  /// Baris 3: Teks informasi kurir pengantar (tanpa card pembungkus, di bawah border divider)
  /// Terdiri dari 2 baris item:
  /// 1. Teks kurir di kiri dan nama kurir di kanan
  /// 2. No HP di kiri dan tombol action di kanan
  Widget _buildCourierInfoSection(DeliveryModel d) {
    final courierName = d.courier?.name ?? 'Belum Ditugaskan';
    final courierPhone = d.courier?.phone;
    final hasPhone = courierPhone != null && courierPhone.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Divider(height: 1, color: AppColors.brandBorder),
        const SizedBox(height: 14),

        // 1. Teks kurir kiri dan nama kurir kanan
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Kurir',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppColors.brandWarmGray,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                courierName,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandEspresso,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 2. No. HP di kiri dan nomor HP kurir di kanan dengan border bawah
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'No. HP',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AppColors.brandWarmGray,
              ),
            ),
            const SizedBox(width: 8),
            if (hasPhone)
              GestureDetector(
                onTap: () => _showCourierContactModal(
                  context,
                  courierPhone,
                  courierName,
                ),
                child: Container(
                  padding: const EdgeInsets.only(bottom: 2),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.black,
                        width: 1.0,
                      ),
                    ),
                  ),
                  child: Text(
                    _formatPhone(courierPhone),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
              )
            else
              const Text(
                '-',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: AppColors.brandWarmGray,
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Dialog modal pilihan aksi kontak kurir (Salin & WhatsApp)
  /// Komponen action modal memakai teks berwarna hitam, tanpa badge, tanpa banyak warna
  void _showCourierContactModal(
    BuildContext context,
    String phone,
    String courierName,
  ) {
    final formattedPhone = _formatPhone(phone);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.brandBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Teks informasi nomor & kurir (Hitam, tanpa badge, tanpa warna-warni)
                Text(
                  formattedPhone,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kurir: $courierName',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: AppColors.brandBorder),
                const SizedBox(height: 6),

                // Opsi 1: Salin Nomor HP
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _copyPhoneToClipboard(context, phone);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(
                          TablerIcons.copy,
                          size: 20,
                          color: Colors.black,
                        ),
                        SizedBox(width: 14),
                        Text(
                          'Salin Nomor HP',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: AppColors.brandBorder),

                // Opsi 2: Hubungi WhatsApp
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _openWhatsApp(context, phone, courierName);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(
                          TablerIcons.brand_whatsapp,
                          size: 20,
                          color: Colors.black,
                        ),
                        SizedBox(width: 14),
                        Text(
                          'Hubungi WhatsApp',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Status state untuk setiap tahapan pada vertical stepper surat jalan
enum _DeliveryStepState {
  completed,
  current,
  pending,
  cancelled,
}

