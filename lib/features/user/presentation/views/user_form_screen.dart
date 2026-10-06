import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/user_management_model.dart';
import '../viewmodels/user_viewmodel.dart';

/// Halaman Formulir Tambah / Edit Pengguna Halala Food.
/// Menggunakan Core Widgets:
/// - AppScaffold (background putih bersih, handling keyboard)
/// - AppStatusBar
/// - AppAppBar
/// - AppTextField
/// - AppButton
/// - AppSnackBar
class UserFormScreen extends ConsumerStatefulWidget {
  final UserManagementModel? user;

  const UserFormScreen({super.key, this.user});

  bool get isEdit => user != null;

  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;

  String? _selectedRole;
  bool _isSubmitting = false;

  final Map<String, String> _roleOptions = {
    'dev': 'Developer / Super Admin',
    'manager': 'Manager Operasional',
    'kurir': 'Kurir Pengantaran',
  };

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameController = TextEditingController(text: u?.name ?? '');
    _emailController = TextEditingController(text: u?.email ?? '');
    _phoneController = TextEditingController(text: u?.phone ?? '');
    _passwordController = TextEditingController();

    if (u != null && u.roles.isNotEmpty) {
      _selectedRole = u.roles.first;
    } else {
      _selectedRole = 'kurir'; // Default role
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == null) {
      AppSnackBar.showError(context, message: 'Pilih salah satu peran untuk pengguna.');
      return;
    }

    setState(() => _isSubmitting = true);

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'role': _selectedRole!,
    };

    if (_phoneController.text.trim().isNotEmpty) {
      payload['phone'] = _phoneController.text.trim();
    }

    if (!widget.isEdit || _passwordController.text.trim().isNotEmpty) {
      payload['password'] = _passwordController.text.trim();
    }

    try {
      final notifier = ref.read(userViewModelProvider.notifier);
      UserManagementModel resultUser;

      if (widget.isEdit) {
        resultUser = await notifier.updateUser(widget.user!.id, payload);
      } else {
        resultUser = await notifier.createUser(payload);
      }

      if (!mounted) return;
      Navigator.of(context).pop(resultUser);
    } catch (e) {
      if (!mounted) return;
      String errorMsg = widget.isEdit
          ? 'Gagal memperbarui data pengguna.'
          : 'Gagal menambahkan pengguna baru.';

      if (e is DioException) {
        if (e.response?.statusCode == 403) {
          errorMsg = 'Anda tidak memiliki hak akses untuk mengelola data pengguna.';
        } else if (e.response?.data is Map && e.response?.data['message'] != null) {
          errorMsg = e.response?.data['message'].toString() ?? errorMsg;
        }
      }

      AppSnackBar.showError(context, message: errorMsg);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEdit ? 'Edit Pengguna' : 'Tambah Pengguna';

    return AppScaffold(
      appBar: AppAppBar(
        title: title,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Info Akun
              _buildSectionTitle('Informasi Pengguna'),
              const SizedBox(height: 12),

              // Input Nama Lengkap
              AppTextField(
                controller: _nameController,
                labelText: 'Nama Lengkap',
                hintText: 'Contoh: Ahmad Fauzi',
                prefixIcon: const Icon(TablerIcons.user, size: 20),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nama lengkap pengguna wajib diisi.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Input Email
              AppTextField(
                controller: _emailController,
                labelText: 'Alamat Email',
                hintText: 'Contoh: ahmad@halala-food.id',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(TablerIcons.mail, size: 20),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Alamat email wajib diisi.';
                  }
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(val.trim())) {
                    return 'Format alamat email tidak valid.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Input Nomor Telepon
              AppTextField(
                controller: _phoneController,
                labelText: 'Nomor WhatsApp / HP',
                hintText: 'Contoh: 081234567890',
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(TablerIcons.phone, size: 20),
              ),
              const SizedBox(height: 6),
              const Text(
                'Nomor akan otomatis dinormalisasi ke format WhatsApp (+62)',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                  color: AppColors.brandWarmGray,
                ),
              ),
              const SizedBox(height: 24),

              // Section Hak Akses & Peran
              _buildSectionTitle('Peran & Hak Akses'),
              const SizedBox(height: 8),
              const Text(
                'Peran menentukan fitur apa saja yang dapat diakses oleh staf di aplikasi web dan mobile.',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  color: AppColors.brandWarmGray,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),

              // Selector Peran (Role Cards)
              ..._roleOptions.entries.map((entry) {
                final isSelected = _selectedRole == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: InkWell(
                    onTap: () => setState(() => _selectedRole = entry.key),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.brandSoftCreamLight : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.brandPrimary : AppColors.brandBorder,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getRoleIcon(entry.key),
                            size: 20,
                            color: isSelected ? AppColors.brandPrimary : AppColors.brandWarmGray,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.value,
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 13.5,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                    color: isSelected ? AppColors.brandPrimary : AppColors.brandEspresso,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _getRoleDescription(entry.key),
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 11,
                                    color: AppColors.brandWarmGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isSelected ? TablerIcons.circle_check_filled : TablerIcons.circle,
                            size: 20,
                            color: isSelected ? AppColors.brandPrimary : AppColors.brandBorder,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),

              // Section Keamanan Kata Sandi
              _buildSectionTitle(widget.isEdit ? 'Ubah Kata Sandi (Opsional)' : 'Kata Sandi'),
              const SizedBox(height: 12),

              AppTextField(
                controller: _passwordController,
                labelText: widget.isEdit ? 'Kata Sandi Baru' : 'Kata Sandi',
                hintText: widget.isEdit ? 'Kosongkan jika tidak ingin mengubah sandi' : 'Minimal 6 karakter',
                isPassword: true,
                prefixIcon: const Icon(TablerIcons.lock, size: 20),
                validator: (val) {
                  if (!widget.isEdit) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Kata sandi wajib diisi untuk pengguna baru.';
                    }
                    if (val.trim().length < 6) {
                      return 'Kata sandi minimal 6 karakter.';
                    }
                  } else if (val != null && val.trim().isNotEmpty && val.trim().length < 6) {
                    return 'Kata sandi baru minimal 6 karakter.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomActionBar(
        confirmText: widget.isEdit ? 'Simpan Perubahan' : 'Tambah Pengguna',
        isLoading: _isSubmitting,
        onConfirm: _submitForm,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.brandEspresso,
      ),
    );
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'dev':
        return TablerIcons.shield_check;
      case 'manager':
        return TablerIcons.briefcase;
      case 'kurir':
        return TablerIcons.truck;
      default:
        return TablerIcons.user;
    }
  }

  String _getRoleDescription(String role) {
    switch (role.toLowerCase()) {
      case 'dev':
        return 'Akses penuh ke seluruh sistem, master data, dan konfigurasi';
      case 'manager':
        return 'Kelola produksi, keuangan, pesanan, dan monitoring tim';
      case 'kurir':
        return 'Akses surat jalan pengantaran, rute toko, dan penerimaan retur';
      default:
        return 'Hak akses terbatas sesuai staf';
    }
  }
}
