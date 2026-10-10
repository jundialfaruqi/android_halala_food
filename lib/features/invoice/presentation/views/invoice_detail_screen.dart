import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/invoice_model.dart';
import '../../data/repositories/invoice_repository_impl.dart';
import 'invoice_detail_sheet.dart';

class InvoiceDetailScreen extends ConsumerStatefulWidget {
  final int invoiceId;

  const InvoiceDetailScreen({
    super.key,
    required this.invoiceId,
  });

  @override
  ConsumerState<InvoiceDetailScreen> createState() =>
      _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  InvoiceModel? _invoice;

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
      final repository = ref.read(invoiceRepositoryProvider);
      final invoice = await repository.getInvoiceDetail(widget.invoiceId);
      if (mounted) {
        setState(() {
          _invoice = invoice;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppStatusBar(
        child: AppScaffold(
          appBar: AppAppBar(title: 'Rincian Faktur'),
          body: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.brandPrimary,
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null || _invoice == null) {
      return AppStatusBar(
        child: AppScaffold(
          appBar: const AppAppBar(title: 'Rincian Faktur'),
          body: Center(
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
                    _errorMessage ?? 'Faktur tidak ditemukan.',
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
                    width: 140,
                    height: 42,
                    onPressed: _loadDetail,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return AppStatusBar(
      child: AppScaffold(
        body: SafeArea(
          child: InvoiceDetailSheet(invoice: _invoice!),
        ),
      ),
    );
  }
}
