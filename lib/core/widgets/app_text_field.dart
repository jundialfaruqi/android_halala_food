import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../constants/app_colors.dart';

class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool isPassword;
  final TextInputType keyboardType;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final int maxLines;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? inputFormatters;

  final String? errorText;
  final EdgeInsets scrollPadding;
  final AutovalidateMode? autovalidateMode;
  final bool dynamicValidationClearing;
  final GlobalKey<FormFieldState<String>>? formFieldKey;
  final EdgeInsetsGeometry? contentPadding;
  final bool? isDense;
  final TextStyle? style;
  final TextAlign textAlign;
  final double? borderRadius;
  final Color? fillColor;
  final String? prefixText;
  final TextStyle? prefixStyle;
  final BoxConstraints? prefixIconConstraints;
  final BoxConstraints? suffixIconConstraints;
  final TextStyle? hintStyle;
  final Color? borderColor;
  final double? borderWidth;

  const AppTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.maxLines = 1,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.focusNode,
    this.inputFormatters,
    this.errorText,
    this.scrollPadding = const EdgeInsets.all(20.0),
    this.autovalidateMode,
    this.dynamicValidationClearing = true,
    this.formFieldKey,
    this.contentPadding,
    this.isDense,
    this.style,
    this.textAlign = TextAlign.start,
    this.borderRadius,
    this.fillColor,
    this.prefixText,
    this.prefixStyle,
    this.prefixIconConstraints,
    this.suffixIconConstraints,
    this.hintStyle,
    this.borderColor,
    this.borderWidth,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscureText;
  late final GlobalKey<FormFieldState<String>> _internalFieldKey;
  String? _currentErrorText;

  GlobalKey<FormFieldState<String>> get _fieldKey =>
      widget.formFieldKey ?? _internalFieldKey;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
    _internalFieldKey = GlobalKey<FormFieldState<String>>();
    _currentErrorText = widget.errorText;
    widget.controller?.addListener(_handleControllerChange);
  }

  @override
  void didUpdateWidget(covariant AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorText != oldWidget.errorText) {
      _currentErrorText = widget.errorText;
    }
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChange);
      widget.controller?.addListener(_handleControllerChange);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleControllerChange);
    super.dispose();
  }

  void _handleControllerChange() {
    if (!widget.dynamicValidationClearing) return;
    _clearOrRevalidate();
  }

  void _clearOrRevalidate([String? value]) {
    if (!widget.dynamicValidationClearing) return;

    bool needsSetState = false;
    if (_currentErrorText != null) {
      _currentErrorText = null;
      needsSetState = true;
    }

    final fieldState = _fieldKey.currentState;
    if (fieldState != null && fieldState.hasError) {
      fieldState.validate();
    }

    if (needsSetState && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget? computedSuffixIcon = widget.suffixIcon;

    if (widget.isPassword) {
      computedSuffixIcon = IconButton(
        icon: Icon(
          _obscureText ? TablerIcons.eye : TablerIcons.eye_off,
          color: AppColors.brandWarmGray,
          size: 20,
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      );
    }

    final effectiveBorderSide = BorderSide(
      color: widget.borderColor ?? AppColors.brandBorder,
      width: widget.borderWidth ?? 1.0,
    );

    final border = widget.borderRadius != null
        ? OutlineInputBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius!),
            borderSide: effectiveBorderSide,
          )
        : null;

    final enabledBorder = widget.borderRadius != null
        ? OutlineInputBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius!),
            borderSide: effectiveBorderSide,
          )
        : null;

    final disabledBorder = widget.borderRadius != null
        ? OutlineInputBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius!),
            borderSide: BorderSide(
              color: widget.borderColor?.withValues(alpha: 0.5) ??
                  AppColors.brandBorder.withValues(alpha: 0.5),
              width: widget.borderWidth ?? 1.0,
            ),
          )
        : null;

    final focusedBorder = widget.borderRadius != null
        ? OutlineInputBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius!),
            borderSide: BorderSide(
              color: widget.borderColor ?? AppColors.brandPrimary,
              width: (widget.borderWidth != null && widget.borderWidth! > 1.5)
                  ? widget.borderWidth!
                  : 1.5,
            ),
          )
        : null;

    final errorBorder = widget.borderRadius != null
        ? OutlineInputBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius!),
            borderSide: const BorderSide(color: AppColors.error),
          )
        : null;

    final field = TextFormField(
      key: _fieldKey,
      controller: widget.controller,
      focusNode: widget.focusNode,
      scrollPadding: widget.scrollPadding,
      obscureText: _obscureText,
      keyboardType: widget.keyboardType,
      textAlign: widget.textAlign,
      inputFormatters: widget.inputFormatters,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
      onChanged: (val) {
        if (widget.controller == null && widget.dynamicValidationClearing) {
          _clearOrRevalidate(val);
        }
        widget.onChanged?.call(val);
      },
      enabled: widget.enabled,
      maxLines: widget.maxLines,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      style: widget.style ??
          const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            color: AppColors.brandTextPrimary,
          ),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: widget.hintStyle,
        prefixText: widget.prefixText,
        prefixStyle: widget.prefixStyle,
        prefixIcon: widget.prefixIcon,
        prefixIconConstraints: widget.prefixIconConstraints,
        suffixIcon: computedSuffixIcon,
        suffixIconConstraints: widget.suffixIconConstraints,
        errorText: _currentErrorText,
        errorMaxLines: 3,
        isDense: widget.isDense,
        contentPadding: widget.contentPadding,
        filled: widget.fillColor != null,
        fillColor: widget.fillColor,
        border: border,
        enabledBorder: enabledBorder,
        disabledBorder: disabledBorder,
        focusedBorder: focusedBorder,
        errorBorder: errorBorder,
        errorStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.error,
        ),
      ),
    );

    if (widget.labelText == null) {
      return field;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.labelText!,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.brandEspresso,
          ),
        ),
        const SizedBox(height: 6),
        field,
      ],
    );
  }
}
