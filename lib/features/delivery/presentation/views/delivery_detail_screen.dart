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
      if ((_delivery!.isDiproses || _delivery!.isDikirim) && canEditPermission) {
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
    final canEditPermission = user?.hasPermission('pengantaran-edit') ?? false;
    if (!canEditPermission) return null;

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
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.brandBorder),
                const SizedBox(height: 12),

                // Clean Status Text (NO BADGE, NO DOTS)
                Text(
                  'Status: ${d.statusLabel}',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandEspresso,
                  ),
                ),
                if (d.dispatchedAt != null && d.dispatchedAt!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Waktu Diberangkatkan: ${d.formattedDispatchedAt}',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.brandWarmGray,
                    ),
                  ),
                ],
                if (d.deliveredAt != null && d.deliveredAt!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Waktu Selesai Serah Terima: ${d.formattedDeliveredAt}',
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.brandWarmGray,
                    ),
                  ),
                ],
                if (d.notes != null && d.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
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

          // 3. Info Kurir Bertugas
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kurir Bertugas',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandEspresso,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  d.courier?.name ?? 'Belum Ditugaskan',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandEspresso,
                  ),
                ),
                if (d.courier?.phone != null && d.courier!.phone!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _buildPhoneRow(
                    context,
                    label: 'No. HP',
                    rawPhone: d.courier!.phone!,
                    targetName: d.courier?.name ?? 'Kurir',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

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

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 22,
                              child: Text(
                                '${index + 1}.',
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandWarmGray,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                item.productName,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandEspresso,
                                ),
                              ),
                            ),
                            Text(
                              _currencyFormat.format(item.subtotal),
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandEspresso,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 22),
                          child: Text(
                            '${item.quantity} ${item.productUnit} @ ${_currencyFormat.format(item.unitPrice)}',
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              color: AppColors.brandWarmGray,
                            ),
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
        // 1. Ringkasan Surat Jalan (Card Utama)
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
            ],
          ),
        ),
        SizedBox(height: 14),

        // 2. Status Pengantaran
        AppCard(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerLoading(width: 80, height: 13, borderRadius: 4),
                  ShimmerLoading(width: 90, height: 15, borderRadius: 4),
                ],
              ),
              SizedBox(height: 12),
              Divider(height: 1, color: AppColors.brandBorder),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerLoading(width: 110, height: 13, borderRadius: 4),
                  ShimmerLoading(width: 110, height: 13, borderRadius: 4),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 14),

        // 3. Info Mitra Toko
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

        // 4. Info Kurir
        AppCard(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerLoading(width: 100, height: 14, borderRadius: 4),
              SizedBox(height: 10),
              Divider(height: 1, color: AppColors.brandBorder),
              SizedBox(height: 12),
              ShimmerLoading(width: 160, height: 15, borderRadius: 4),
              SizedBox(height: 6),
              ShimmerLoading(width: 120, height: 13, borderRadius: 4),
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
}
