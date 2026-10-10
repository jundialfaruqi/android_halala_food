import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../viewmodels/cash_book_viewmodel.dart';

class CashAccountFormSheet extends ConsumerStatefulWidget {
  const CashAccountFormSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CashAccountFormSheet(),
    );
  }

  @override
  ConsumerState<CashAccountFormSheet> createState() =>
      _CashAccountFormSheetState();
}

class _CashAccountFormSheetState extends ConsumerState<CashAccountFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _balanceController;
  late TextEditingController _descriptionController;

  String _selectedType = 'business';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _balanceController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  double _getParsedBalance() {
    final raw = _balanceController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(raw) ?? 0.0;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final payload = {
      'account_name': _nameController.text.trim(),
      'account_type': _selectedType,
      'initial_balance': _getParsedBalance(),
      'account_description': _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
    };

    final success = await ref
        .read(cashBookViewModelProvider.notifier)
        .createAccount(payload);

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context, true);
        AppSnackBar.showSuccess(
          context,
          message:
              "Akun kas '${_nameController.text.trim()}' berhasil ditambahkan.",
        );
      } else {
        final err = ref.read(cashBookViewModelProvider).errorMessage;
        AppSnackBar.showError(
          context,
          message: err ?? 'Gagal menambah akun kas.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.brandBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Tambah Akun Kas Baru',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Rekening kas kecil, bank operasional, atau pribadi',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          color: AppColors.brandWarmGray,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(TablerIcons.x, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.brandBorder),

            // Form Content
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Nama Akun / Rekening
                    const Text(
                      'NAMA AKUN / REKENING *',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AppTextField(
                      controller: _nameController,
                      hintText: 'Misal: Kas Toko, Rekening Mandiri...',
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Nama akun kas / rekening wajib diisi.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 2. Jenis Akun
                    const Text(
                      'JENIS AKUN *',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.brandBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedType,
                          isExpanded: true,
                          icon: const Icon(TablerIcons.chevron_down, size: 16),
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brandEspresso,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'business',
                              child: Text('Kas Usaha (Operasional / Hasil Tagihan)'),
                            ),
                            DropdownMenuItem(
                              value: 'personal',
                              child: Text('Kas Pribadi (Kebutuhan Belanja Keluarga)'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedType = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Saldo Awal (Rp)
                    const Text(
                      'SALDO AWAL (RP) *',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AppTextField(
                      controller: _balanceController,
                      hintText: '0',
                      keyboardType: TextInputType.number,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 14, right: 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Rp',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandEspresso,
                              ),
                            ),
                          ],
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 0,
                        minHeight: 0,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        ThousandsSeparatorInputFormatter(),
                      ],
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Saldo awal wajib diisi (bisa 0).';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 4. Keterangan
                    const Text(
                      'KETERANGAN',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandWarmGray,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AppTextField(
                      controller: _descriptionController,
                      hintText: 'Catatan rekening (opsional)...',
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Action Bar (Konsisten dengan screen Tambah Produk)
            AppBottomActionBar(
              confirmText: 'Simpan Akun',
              isLoading: _isSubmitting,
              onConfirm: _isSubmitting ? null : _submit,
              onCancel: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
