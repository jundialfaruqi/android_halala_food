import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../viewmodels/auth_state.dart';
import '../viewmodels/auth_viewmodel.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _emailInlineError;
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onInputChanged);
    _passwordController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    if (_emailInlineError != null) {
      setState(() {
        _emailInlineError = null;
      });
    }
    AppSnackBar.hide();
  }

  @override
  void dispose() {
    _emailController.removeListener(_onInputChanged);
    _passwordController.removeListener(_onInputChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _emailInlineError = null;
      _autoValidateMode = AutovalidateMode.onUserInteraction;
    });

    if (_formKey.currentState!.validate()) {
      final success = await ref
          .read(authViewModelProvider.notifier)
          .login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (!success && mounted) {
        final errorMsg = ref.read(authViewModelProvider).errorMessage ??
            'Email atau password yang Anda masukkan salah.';
        setState(() {
          _emailInlineError = errorMsg;
        });
        AppSnackBar.showError(context, message: errorMsg);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);

    ref.listen<AuthState>(authViewModelProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        setState(() {
          _emailInlineError = null;
        });
      }
    });

    return AppScaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Form(
            key: _formKey,
            autovalidateMode: _autoValidateMode,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo Header
                Center(
                  child: Image.asset(
                    AppAssets.logo,
                    width: 90,
                    height: 90,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: AppColors.brandSoftCream,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        TablerIcons.building_store,
                        size: 40,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Silakan masuk dengan akun Halala Food Anda',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    color: AppColors.brandWarmGray,
                  ),
                ),
                const SizedBox(height: 36),

                // Email Input via AppTextField
                AppTextField(
                  controller: _emailController,
                  labelText: 'Email',
                  hintText: 'nama@email.com',
                  keyboardType: TextInputType.emailAddress,
                  errorText: _emailInlineError,
                  onChanged: (_) => _onInputChanged(),
                  prefixIcon: const Icon(
                    TablerIcons.mail,
                    color: AppColors.brandWarmGray,
                    size: 20,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email wajib diisi';
                    }
                    if (!value.contains('@')) {
                      return 'Format email tidak valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Password Input via AppTextField (inline error hanya di email)
                AppTextField(
                  controller: _passwordController,
                  labelText: 'Password',
                  hintText: '••••••••',
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleLogin(),
                  onChanged: (_) => _onInputChanged(),
                  prefixIcon: const Icon(
                    TablerIcons.lock,
                    color: AppColors.brandWarmGray,
                    size: 20,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password wajib diisi';
                    }
                    if (value.length < 6) {
                      return 'Password minimal 6 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // Submit Button via AppButton
                AppButton(
                  text: 'Masuk',
                  isLoading: authState.isLoading,
                  onPressed: _handleLogin,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
