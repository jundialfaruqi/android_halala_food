import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    String displayPhone = u?.phone ?? '';
    if (displayPhone.startsWith('62')) {
      displayPhone = displayPhone.substring(2);
    } else if (displayPhone.startsWith('0')) {
      displayPhone = displayPhone.substring(1);
    }
    _phoneController = TextEditingController(text: displayPhone);
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

    final phoneDigits = _phoneController.text.trim();
    if (phoneDigits.isNotEmpty) {
      payload['phone'] = phoneDigits;
    } else if (widget.isEdit) {
      payload['phone'] = null;
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
              // Input Nama Lengkap
              AppTextField(
                controller: _nameController,
                labelText: 'Nama Lengkap',
                hintText: 'Contoh: Ahmad Fauzi',
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
                hintText: '81234567890',
                keyboardType: TextInputType.phone,
                inputFormatters: const [IndonesianPhoneInputFormatter()],
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '+62',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                      SizedBox(width: 8),
                      SizedBox(
                        height: 20,
                        child: VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: AppColors.brandBorder,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Pemilihan Peran (Material 3 Menus Core Widget)
              AppMenuSelect<String>(
                labelText: 'Peran / Jabatan',
                hintText: 'Pilih peran pengguna',
                initialSelection: _selectedRole,
                entries: _roleOptions.entries.map((entry) {
                  return AppMenuSelectEntry<String>(
                    value: entry.key,
                    label: entry.value,
                  );
                }).toList(),
                onSelected: (val) {
                  if (val != null) {
                    setState(() => _selectedRole = val);
                  }
                },
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Pilih peran untuk pengguna.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Input Kata Sandi
              AppTextField(
                controller: _passwordController,
                labelText: widget.isEdit ? 'Kata Sandi Baru' : 'Kata Sandi',
                hintText: widget.isEdit
                    ? 'Kosongkan jika tidak ingin mengubah sandi'
                    : 'Minimal 6 karakter',
                isPassword: true,
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
}
