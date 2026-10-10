import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../constants/app_colors.dart';

/// Reusable App Core Widget untuk Input Dropdown Searchable dengan Overlay Menu.
/// Mengadopsi pola UX & UI Halala Food (seperti pada Toko Mitra di Buat Surat Jalan):
/// - Label opsional di atas input
/// - TextField dengan prefix icon, clear button ('x'), dan toggle chevron
/// - Overlay menu interaktif di bawah field dengan daftar item, subtitle, divider, dan checkmark
/// - Pencarian real-time (lokal sinkron via [searchMatcher] atau remote asinkron via [asyncSearch])
/// - Terintegrasi penuh dengan [FormField] dan [AppDynamicValidationForm] untuk validasi dinamis
class AppDropdownSearchField<T> extends StatefulWidget {
  final String? labelText;
  final String? hintText;
  final T? initialValue;
  final List<T> items;
  final ValueChanged<T?>? onSelected;
  final FormFieldValidator<T>? validator;
  final String Function(T item) itemLabel;
  final String? Function(T item)? itemSubtitle;
  final Widget Function(T item)? itemLeading;
  final bool Function(T item, String query)? searchMatcher;
  final Future<List<T>> Function(String query)? asyncSearch;
  final bool Function(T? a, T? b)? itemEquals;
  final Widget? prefixIcon;
  final bool enabled;
  final int maxDropdownItems;
  final String? emptyMessage;
  final String? showAllText;
  final VoidCallback? onShowAll;
  final AutovalidateMode? autovalidateMode;
  final Duration debounceDuration;

  const AppDropdownSearchField({
    super.key,
    this.labelText,
    this.hintText,
    this.initialValue,
    this.items = const [],
    this.onSelected,
    this.validator,
    required this.itemLabel,
    this.itemSubtitle,
    this.itemLeading,
    this.searchMatcher,
    this.asyncSearch,
    this.itemEquals,
    this.prefixIcon,
    this.enabled = true,
    this.maxDropdownItems = 5,
    this.emptyMessage,
    this.showAllText,
    this.onShowAll,
    this.autovalidateMode,
    this.debounceDuration = const Duration(milliseconds: 250),
  });

  @override
  State<AppDropdownSearchField<T>> createState() =>
      _AppDropdownSearchFieldState<T>();
}

class _AppDropdownSearchFieldState<T> extends State<AppDropdownSearchField<T>> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  OverlayEntry? _overlayEntry;
  Timer? _debounceTimer;

  T? _selectedItem;
  List<T> _filteredItems = [];
  bool _isSearching = false;
  FormFieldState<T>? _currentFormFieldState;

  bool _isEqual(T? a, T? b) {
    if (widget.itemEquals != null) {
      return widget.itemEquals!(a, b);
    }
    return a == b;
  }

  @override
  void initState() {
    super.initState();
    _selectedItem = widget.initialValue;
    if (_selectedItem != null) {
      _textController.text = widget.itemLabel(_selectedItem as T);
    }
    _resetFilteredItems();

    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant AppDropdownSearchField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEqual(widget.initialValue, oldWidget.initialValue) ||
        !_isEqual(widget.initialValue, _selectedItem)) {
      _selectedItem = widget.initialValue;
      if (_selectedItem != null) {
        _textController.text = widget.itemLabel(_selectedItem as T);
      } else if (!_focusNode.hasFocus) {
        _textController.clear();
      }
    }
    if (widget.items != oldWidget.items ||
        widget.items.length != oldWidget.items.length) {
      if (!_focusNode.hasFocus || _textController.text.trim().isEmpty) {
        _resetFilteredItems();
      }
      _overlayEntry?.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _hideOverlay();
    _focusNode.removeListener(_handleFocusChange);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      _resetFilteredItems();
      _showOverlay();
    } else {
      _hideOverlay();
      if (_selectedItem != null) {
        _textController.text = widget.itemLabel(_selectedItem as T);
      } else {
        _textController.clear();
      }
    }
  }

  void _resetFilteredItems() {
    _filteredItems = widget.items.take(widget.maxDropdownItems).toList();
  }

  void _showOverlay() {
    if (!widget.enabled) return;
    _hideOverlay();

    final overlay = Overlay.of(context);
    final renderBox = _fieldKey.currentContext?.findRenderObject() as RenderBox? ??
        context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final fieldHeight = renderBox.size.height;
    final fieldWidth = renderBox.size.width;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          width: fieldWidth,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, fieldHeight + 4),
            child: TapRegion(
              onTapOutside: (_) {
                _focusNode.unfocus();
              },
              child: Material(
                elevation: 6,
                shadowColor: Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 330),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.brandBorder),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // List item dropdown
                      Flexible(
                        child: _buildDropdownItems(),
                      ),

                      // Tombol footer opsional (misal: "Tampilkan semua...")
                      if (widget.showAllText != null && widget.onShowAll != null) ...[
                        const Divider(
                          height: 1,
                          thickness: 0.8,
                          color: AppColors.brandBorder,
                        ),
                        InkWell(
                          onTap: () {
                            _hideOverlay();
                            _focusNode.unfocus();
                            widget.onShowAll!();
                          },
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: const BoxDecoration(
                              color: AppColors.brandSoftCreamLight,
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  TablerIcons.list_search,
                                  size: 16,
                                  color: AppColors.brandPrimary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.showAllText!,
                                  style: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.brandPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _onTextChanged(String text) {
    _debounceTimer?.cancel();
    final trimmed = text.trim();

    if (_selectedItem != null &&
        trimmed.toLowerCase() ==
            widget.itemLabel(_selectedItem as T).trim().toLowerCase()) {
      setState(() {
        _resetFilteredItems();
      });
      _overlayEntry?.markNeedsBuild();
      return;
    }

    if (widget.asyncSearch != null) {
      if (trimmed.isEmpty) {
        setState(() {
          _isSearching = false;
          _resetFilteredItems();
        });
        _overlayEntry?.markNeedsBuild();
        return;
      }

      _debounceTimer = Timer(widget.debounceDuration, () async {
        if (!mounted) return;
        setState(() {
          _isSearching = true;
        });
        _overlayEntry?.markNeedsBuild();

        try {
          final results = await widget.asyncSearch!(trimmed);
          if (!mounted) return;
          setState(() {
            _isSearching = false;
            _filteredItems = results.take(widget.maxDropdownItems).toList();
          });
          _overlayEntry?.markNeedsBuild();
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _isSearching = false;
            _filteredItems = [];
          });
          _overlayEntry?.markNeedsBuild();
        }
      });
    } else {
      // Local filter sinkron
      setState(() {
        if (trimmed.isEmpty) {
          _resetFilteredItems();
        } else {
          final q = trimmed.toLowerCase();
          _filteredItems = widget.items.where((item) {
            if (widget.searchMatcher != null) {
              return widget.searchMatcher!(item, trimmed);
            }
            final label = widget.itemLabel(item).toLowerCase();
            final subtitle =
                widget.itemSubtitle?.call(item)?.toLowerCase() ?? '';
            return label.contains(q) || subtitle.contains(q);
          }).take(widget.maxDropdownItems).toList();
        }
      });
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _selectItem(T item) {
    setState(() {
      _selectedItem = item;
      _textController.text = widget.itemLabel(item);
    });

    if (_currentFormFieldState != null) {
      _currentFormFieldState!.didChange(item);
      _currentFormFieldState!.validate();
    }
    widget.onSelected?.call(item);

    _focusNode.unfocus();
    _hideOverlay();
  }

  void _clearSelection() {
    setState(() {
      _selectedItem = null;
      _textController.clear();
      _resetFilteredItems();
    });

    if (_currentFormFieldState != null) {
      _currentFormFieldState!.didChange(null);
      _currentFormFieldState!.validate();
    }
    widget.onSelected?.call(null);
  }

  Widget _buildDropdownItems() {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.brandPrimary,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Text(
                'Mencari data...',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12.5,
                  color: AppColors.brandWarmGray,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final query = _textController.text.trim();

    if (_filteredItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(
          query.isNotEmpty
              ? 'Tidak ada data ditemukan dengan kata kunci "$query".'
              : (widget.emptyMessage ?? 'Tidak ada data pilihan.'),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 12,
            color: AppColors.brandWarmGray,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      shrinkWrap: true,
      itemCount: _filteredItems.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        thickness: 0.6,
        color: AppColors.brandBorder,
      ),
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        final isSelected = _isEqual(_selectedItem, item);
        final subtitle = widget.itemSubtitle?.call(item);

        return InkWell(
          onTap: () => _selectItem(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                if (widget.itemLeading != null) ...[
                  widget.itemLeading!(item),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.itemLabel(item),
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected
                              ? AppColors.brandPrimary
                              : AppColors.brandEspresso,
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11.5,
                            color: AppColors.brandWarmGray,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    TablerIcons.check,
                    size: 18,
                    color: AppColors.brandPrimary,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      initialValue: _selectedItem,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
      enabled: widget.enabled,
      builder: (fieldState) {
        _currentFormFieldState = fieldState;
        final hasError = fieldState.hasError;
        final errorText = fieldState.errorText;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.labelText != null) ...[
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
            ],
            CompositedTransformTarget(
              key: _fieldKey,
              link: _layerLink,
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                enabled: widget.enabled,
                onTap: () {
                  if (!_focusNode.hasFocus) {
                    _focusNode.requestFocus();
                  } else {
                    _resetFilteredItems();
                    _showOverlay();
                  }
                },
                onChanged: (text) {
                  _onTextChanged(text);
                  _showOverlay();
                },
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  fontWeight:
                      widget.enabled ? FontWeight.normal : FontWeight.w600,
                  color: widget.enabled
                      ? AppColors.brandEspresso
                      : AppColors.brandWarmGray,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText ?? 'Pilih salah satu...',
                  hintStyle: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13.5,
                    color: AppColors.brandPlaceholder,
                  ),
                  filled: true,
                  fillColor: !widget.enabled
                      ? const Color(0xFFF7F7F7)
                      : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: hasError ? AppColors.error : AppColors.brandBorder,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: hasError ? AppColors.error : AppColors.brandBorder,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.brandBorder.withValues(alpha: 0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color:
                          hasError ? AppColors.error : AppColors.brandPrimary,
                      width: 1.5,
                    ),
                  ),
                  prefixIcon: widget.prefixIcon,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectedItem != null ||
                          _textController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(
                            TablerIcons.x,
                            size: 16,
                            color: AppColors.brandWarmGray,
                          ),
                          splashRadius: 16,
                          onPressed: widget.enabled
                              ? () {
                                  _clearSelection();
                                  _showOverlay();
                                }
                              : null,
                        ),
                      IconButton(
                        icon: Icon(
                          _focusNode.hasFocus
                              ? TablerIcons.chevron_up
                              : TablerIcons.chevron_down,
                          size: 18,
                          color: _focusNode.hasFocus
                              ? AppColors.brandPrimary
                              : AppColors.brandWarmGray,
                        ),
                        splashRadius: 18,
                        onPressed: widget.enabled
                            ? () {
                                if (_focusNode.hasFocus) {
                                  _focusNode.unfocus();
                                } else {
                                  _focusNode.requestFocus();
                                }
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (hasError && errorText != null) ...[
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 6),
                child: Text(
                  errorText,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
