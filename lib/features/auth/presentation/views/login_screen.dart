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

      if (!success) {
        if (mounted) {
          final errorMsg = ref.read(authViewModelProvider).errorMessage ??
              'Email atau password yang Anda masukkan salah.';
          setState(() {
            _emailInlineError = errorMsg;
          });
          AppSnackBar.showError(context, message: errorMsg);
        }
      } else {
        final userName = ref.read(authViewModelProvider).user?.name;
        AppSnackBar.showSuccess(
          null,
          message: (userName != null && userName.isNotEmpty)
              ? 'Selamat datang kembali, $userName!'
              : 'Berhasil masuk ke aplikasi Halala Food.',
        );
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
      safeAreaTop: false,
      safeAreaBottom: false,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      body: Stack(
        children: [
          // 1. Background image fullscreen (portrait version of why_choose_us)
          Positioned.fill(
            child: Image.asset(
              AppAssets.loginBg,
              fit: BoxFit.cover,
            ),
          ),

          // Subtle gradient overlay for contrast and atmosphere
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.40),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.25),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // 2. Scrollable content with bottom card
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header area above the card
                        SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.20),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    AppAssets.logo,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      TablerIcons.building_store,
                                      size: 36,
                                      color: AppColors.brandPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'HALALA FOOD',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2.5,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        blurRadius: 12,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Cita Rasa Tradisional Indonesia',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.92),
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Card Form Login with BG White Rounded Top
                        Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(32),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 24,
                                offset: Offset(0, -6),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.fromLTRB(
                            24,
                            16,
                            24,
                            MediaQuery.of(context).padding.bottom + 24,
                          ),
                          child: Form(
                            key: _formKey,
                            autovalidateMode: _autoValidateMode,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Handle bar / drag indicator
                                Center(
                                  child: Container(
                                    width: 44,
                                    height: 4,
                                    margin: const EdgeInsets.only(bottom: 20),
                                    decoration: BoxDecoration(
                                      color: AppColors.brandBorder,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),

                                // Card Title & Subtitle
                                const Text(
                                  'Selamat Datang!',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.brandEspresso,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Silakan masuk dengan akun Halala Food Anda',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 13,
                                    color: AppColors.brandWarmGray,
                                  ),
                                ),
                                const SizedBox(height: 24),

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
                                const SizedBox(height: 16),

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
                                const SizedBox(height: 24),

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
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
