import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../constants/app_colors.dart';

/// Status state untuk setiap tahapan pada stepper
enum AppStepState {
  completed,
  current,
  pending,
  cancelled,
}

/// Model data item untuk tahapan stepper
class AppStepItem {
  final String title;
  final String? subtitle;
  final AppStepState state;
  final IconData? icon;
  final Widget? trailing;

  const AppStepItem({
    required this.title,
    this.subtitle,
    this.state = AppStepState.pending,
    this.icon,
    this.trailing,
  });
}

/// Widget Accordion Stepper core Halala Food:
/// - Saat collapsed: Hanya menampilkan 1 tahapan (tahapan aktif / terkini) untuk menghemat ruang.
/// - Saat expanded: Menampilkan seluruh tahapan stepper vertikal secara lengkap dengan garis penghubung.
/// - Animasi mulus saat expand / collapse dengan interaksi sentuh intuitif.
class AppAccordionStepper extends StatefulWidget {
  final List<AppStepItem> steps;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final bool showBorder;

  const AppAccordionStepper({
    super.key,
    required this.steps,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 10,
    this.showBorder = true,
  });

  @override
  State<AppAccordionStepper> createState() => _AppAccordionStepperState();
}

class _AppAccordionStepperState extends State<AppAccordionStepper>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    widget.onExpansionChanged?.call(_isExpanded);
  }

  /// Menentukan index step aktif yang paling relevan untuk ditampilkan saat collapsed
  int get _activeStepIndex {
    if (widget.steps.isEmpty) return 0;

    // 1. Cari step yang sedang current
    final currentIndex =
        widget.steps.indexWhere((s) => s.state == AppStepState.current);
    if (currentIndex != -1) return currentIndex;

    // 2. Jika ada cancelled, tampilkan cancelled
    final cancelledIndex =
        widget.steps.indexWhere((s) => s.state == AppStepState.cancelled);
    if (cancelledIndex != -1) return cancelledIndex;

    // 3. Jika semua completed, tampilkan step terakhir yang completed
    final lastCompletedIndex =
        widget.steps.lastIndexWhere((s) => s.state == AppStepState.completed);
    if (lastCompletedIndex != -1) return lastCompletedIndex;

    // 4. Default: step pertama
    return 0;
  }

  Color _getTitleColor(AppStepState state) {
    switch (state) {
      case AppStepState.completed:
        return AppColors.brandEspresso;
      case AppStepState.current:
        return AppColors.brandPrimary;
      case AppStepState.cancelled:
        return AppColors.error;
      case AppStepState.pending:
        return AppColors.brandWarmGray;
    }
  }

  Widget _buildStepNode(AppStepState state, {IconData? customIcon}) {
    switch (state) {
      case AppStepState.completed:
        return Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: AppColors.brandPrimary,
            shape: BoxShape.circle,
          ),
          child: Icon(
            customIcon ?? TablerIcons.check,
            size: 12,
            color: Colors.white,
          ),
        );
      case AppStepState.current:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.brandPrimary,
              width: 2.2,
            ),
          ),
          child: Center(
            child: customIcon != null
                ? Icon(
                    customIcon,
                    size: 10,
                    color: AppColors.brandPrimary,
                  )
                : Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.brandPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
          ),
        );
      case AppStepState.cancelled:
        return Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: AppColors.error,
            shape: BoxShape.circle,
          ),
          child: Icon(
            customIcon ?? TablerIcons.x,
            size: 12,
            color: Colors.white,
          ),
        );
      case AppStepState.pending:
        return Container(
          width: 20,
          height: 20,
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
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();

    final activeIndex = _activeStepIndex;
    final activeStep = widget.steps[activeIndex];
    final bgColor = widget.backgroundColor ?? AppColors.brandSoftCreamLight;
    final borderColor = widget.borderColor ?? AppColors.brandBorder;

    return Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: widget.showBorder ? Border.all(color: borderColor) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleExpanded,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: Padding(
            padding: widget.padding,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: _isExpanded
                  ? _buildExpandedContent()
                  : _buildCollapsedContent(activeStep),
            ),
          ),
        ),
      ),
    );
  }

  /// Tampilan 1 baris stepper (collapsed) - hemat ruang
  Widget _buildCollapsedContent(AppStepItem activeStep) {
    return Row(
      children: [
        _buildStepNode(activeStep.state, customIcon: activeStep.icon),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                activeStep.title,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _getTitleColor(activeStep.state),
                ),
              ),
              if (activeStep.subtitle != null &&
                  activeStep.subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  activeStep.subtitle!,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppColors.brandWarmGray,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        if (widget.steps.length > 1) ...[
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.steps.length} Tahap',
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandWarmGray,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(
                TablerIcons.chevron_down,
                size: 15,
                color: AppColors.brandWarmGray,
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Tampilan seluruh tahapan stepper (expanded)
  Widget _buildExpandedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header Accordion
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Riwayat Status Pengantaran',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.brandEspresso,
              ),
            ),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tutup',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandPrimary,
                  ),
                ),
                SizedBox(width: 2),
                Icon(
                  TablerIcons.chevron_up,
                  size: 15,
                  color: AppColors.brandPrimary,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Vertical Stepper
        Column(
          children: widget.steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isLast = index == widget.steps.length - 1;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Node + Vertical Line
                  SizedBox(
                    width: 20,
                    child: Column(
                      children: [
                        _buildStepNode(step.state, customIcon: step.icon),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: step.state == AppStepState.completed
                                  ? AppColors.brandPrimary
                                  : AppColors.brandBorder,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 9),

                  // Konten teks step
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            step.title,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 12.5,
                              fontWeight: (step.state == AppStepState.completed ||
                                      step.state == AppStepState.current)
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _getTitleColor(step.state),
                            ),
                          ),
                          if (step.subtitle != null &&
                              step.subtitle!.trim().isNotEmpty) ...[
                            const SizedBox(height: 1.5),
                            Text(
                              step.subtitle!,
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 11,
                                fontWeight: step.state == AppStepState.current
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                                color: step.state == AppStepState.cancelled
                                    ? AppColors.error
                                    : AppColors.brandWarmGray,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (step.trailing != null) step.trailing!,
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
