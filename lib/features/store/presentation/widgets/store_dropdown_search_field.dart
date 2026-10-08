import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/store_model.dart';
import '../../data/repositories/store_repository_impl.dart';
import 'store_search_selection_dialog.dart';

/// Model representasi seragam untuk item pilihan Toko Mitra di dropdown
class StoreSelectOption {
  final int id;
  final String name;
  final String? route;
  final String? address;

  const StoreSelectOption({
    required this.id,
    required this.name,
    this.route,
    this.address,
  });

  String get displayName {
    if (route != null && route!.trim().isNotEmpty) {
      return '$name (${route!.trim()})';
    }
    return name;
  }

  factory StoreSelectOption.fromStore(StoreModel s) {
    return StoreSelectOption(
      id: s.id,
      name: s.name,
      route: s.route,
      address: s.address,
    );
  }

  factory StoreSelectOption.fromGeneric(dynamic s) {
    if (s is StoreSelectOption) return s;
    if (s is StoreModel) return StoreSelectOption.fromStore(s);
    return StoreSelectOption(
      id: s.id as int,
      name: (s.name ?? '').toString(),
      route: s.route?.toString(),
      address: s.address?.toString(),
    );
  }
}

/// Widget Select Dropdown Toko Mitra dengan UX Halala Food:
/// 1. User ketik minimal 3 huruf baru fungsi pencarian dijalankan
/// 2. Hasil di select dropdown dibatasi maksimal 5 data
/// 3. Tombol "Tampilkan semua mitra toko" untuk membuka dialog dengan pencarian & infinite scroll per 10 data
/// 4. Terintegrasi penuh dengan [FormField] validasi
class StoreDropdownSearchField extends ConsumerStatefulWidget {
  final String? labelText;
  final String? hintText;
  final int? initialValue;
  final String? initialLabel;
  final List<dynamic>? initialStores;
  final ValueChanged<StoreSelectOption?>? onSelected;
  final FormFieldValidator<int>? validator;
  final bool enabled;

  const StoreDropdownSearchField({
    super.key,
    this.labelText,
    this.hintText,
    this.initialValue,
    this.initialLabel,
    this.initialStores,
    this.onSelected,
    this.validator,
    this.enabled = true,
  });

  @override
  ConsumerState<StoreDropdownSearchField> createState() =>
      _StoreDropdownSearchFieldState();
}

class _StoreDropdownSearchFieldState
    extends ConsumerState<StoreDropdownSearchField> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  OverlayEntry? _overlayEntry;
  Timer? _debounceTimer;

  int? _selectedStoreId;
  StoreSelectOption? _selectedOption;

  List<StoreSelectOption> _dropdownStores = [];
  bool _isSearching = false;
  FormFieldState<int>? _currentFormFieldState;

  @override
  void initState() {
    super.initState();
    _selectedStoreId = widget.initialValue;

    if (widget.initialLabel != null && widget.initialLabel!.isNotEmpty) {
      _textController.text = widget.initialLabel!;
    } else if (widget.initialValue != null && widget.initialStores != null) {
      final match = widget.initialStores!
          .map((s) => StoreSelectOption.fromGeneric(s))
          .where((s) => s.id == widget.initialValue)
          .firstOrNull;
      if (match != null) {
        _selectedOption = match;
        _textController.text = match.displayName;
      }
    }

    _loadInitialDefaultStores();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _showOverlay();
      } else {
        _hideOverlay();
        if (_selectedOption != null) {
          _textController.text = _selectedOption!.displayName;
        } else if (_selectedStoreId == null) {
          _textController.clear();
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant StoreDropdownSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      _selectedStoreId = widget.initialValue;
      if (widget.initialLabel != null) {
        _textController.text = widget.initialLabel!;
      } else if (_selectedStoreId == null) {
        _selectedOption = null;
        _textController.clear();
      } else if (widget.initialStores != null) {
        final match = widget.initialStores!
            .map((s) => StoreSelectOption.fromGeneric(s))
            .where((s) => s.id == _selectedStoreId)
            .firstOrNull;
        if (match != null) {
          _selectedOption = match;
          _textController.text = match.displayName;
        }
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _hideOverlay();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _loadInitialDefaultStores() {
    if (widget.initialStores != null && widget.initialStores!.isNotEmpty) {
      _dropdownStores = widget.initialStores!
          .map((s) => StoreSelectOption.fromGeneric(s))
          .take(5)
          .toList();
    }
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
                      // 1. List Item Dropdown (Maksimal 5)
                      Flexible(
                        child: _buildDropdownItems(),
                      ),

                      // 2. Tombol "Tampilkan semua mitra toko"
                      const Divider(
                        height: 1,
                        thickness: 0.8,
                        color: AppColors.brandBorder,
                      ),
                      InkWell(
                        onTap: _openFullSearchDialog,
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
                            children: const [
                              Icon(
                                TablerIcons.list_search,
                                size: 16,
                                color: AppColors.brandPrimary,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Tampilkan semua mitra toko',
                                style: TextStyle(
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

    // UX Rule: User ketik minimal 3 huruf dulu, baru fungsi pencarian jalan
    if (trimmed.length < 3) {
      setState(() {
        _isSearching = false;
        if (trimmed.isEmpty) {
          _loadInitialDefaultStores();
        } else {
          _dropdownStores = [];
        }
      });
      _overlayEntry?.markNeedsBuild();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(trimmed);
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() {
      _isSearching = true;
    });
    _overlayEntry?.markNeedsBuild();

    try {
      final repository = ref.read(storeRepositoryProvider);
      // Batasi hanya 5 data pada select dropdown
      final result = await repository.getStores(
        search: query,
        isActive: true,
        page: 1,
        perPage: 5,
      );

      if (!mounted) return;

      setState(() {
        _isSearching = false;
        _dropdownStores = result.stores
            .map((s) => StoreSelectOption.fromStore(s))
            .take(5)
            .toList();
      });
      _overlayEntry?.markNeedsBuild();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _dropdownStores = [];
      });
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _selectStore(StoreSelectOption store) {
    setState(() {
      _selectedStoreId = store.id;
      _selectedOption = store;
      _textController.text = store.displayName;
    });

    if (_currentFormFieldState != null) {
      _currentFormFieldState!.didChange(store.id);
      _currentFormFieldState!.validate();
    }
    widget.onSelected?.call(store);

    _focusNode.unfocus();
    _hideOverlay();
  }

  void _clearSelection() {
    setState(() {
      _selectedStoreId = null;
      _selectedOption = null;
      _textController.clear();
      _loadInitialDefaultStores();
    });

    if (_currentFormFieldState != null) {
      _currentFormFieldState!.didChange(null);
      _currentFormFieldState!.validate();
    }
    widget.onSelected?.call(null);
  }

  Future<void> _openFullSearchDialog() async {
    _hideOverlay();
    _focusNode.unfocus();

    final currentQuery = _textController.text.trim();
    final selectedStore = await StoreSearchSelectionDialog.show(
      context,
      selectedStoreId: _selectedStoreId,
      initialSearch: currentQuery.length >= 3 ? currentQuery : null,
    );

    if (selectedStore != null && mounted) {
      final option = StoreSelectOption.fromStore(selectedStore);
      _selectStore(option);
    }
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
                'Mencari mitra toko...',
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

    // UX Rule: Jika ketik < 3 huruf (1 atau 2 huruf)
    if (query.isNotEmpty && query.length < 3) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: const [
            Icon(
              TablerIcons.info_circle,
              size: 16,
              color: AppColors.brandWarmGray,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ketik minimal 3 huruf untuk mencari toko mitra.',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 12,
                  color: AppColors.brandWarmGray,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_dropdownStores.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(
          query.length >= 3
              ? 'Tidak ada toko mitra ditemukan dengan kata kunci "$query".'
              : 'Pilih mitra toko dari daftar di bawah atau klik tombol di bawah.',
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
      itemCount: _dropdownStores.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        thickness: 0.6,
        color: AppColors.brandBorder,
      ),
      itemBuilder: (context, index) {
        final store = _dropdownStores[index];
        final isSelected = _selectedStoreId == store.id;

        return InkWell(
          onTap: () => _selectStore(store),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: AppColors.brandEspresso,
                        ),
                      ),
                      if (store.route != null && store.route!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Rute: ${store.route}',
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
                    size: 16,
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
    return FormField<int>(
      initialValue: _selectedStoreId,
      validator: widget.validator,
      builder: (FormFieldState<int> field) {
        _currentFormFieldState = field;
        final hasError = field.hasError;
        final errorText = field.errorText;

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
                    _showOverlay();
                  }
                },
                onChanged: (text) {
                  _onTextChanged(text);
                  _showOverlay();
                },
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  color: AppColors.brandEspresso,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText ?? 'Pilih atau cari toko mitra...',
                  hintStyle: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13.5,
                    color: AppColors.brandPlaceholder,
                  ),
                  filled: true,
                  fillColor: Colors.white,
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
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: hasError ? AppColors.error : AppColors.brandPrimary,
                      width: 1.5,
                    ),
                  ),
                  prefixIcon: const Icon(
                    TablerIcons.building_store,
                    size: 18,
                    color: AppColors.brandWarmGray,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectedStoreId != null ||
                          _textController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(
                            TablerIcons.x,
                            size: 16,
                            color: AppColors.brandWarmGray,
                          ),
                          splashRadius: 16,
                          onPressed: () {
                            _clearSelection();
                            _showOverlay();
                          },
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
                        onPressed: () {
                          if (_focusNode.hasFocus) {
                            _focusNode.unfocus();
                          } else {
                            _focusNode.requestFocus();
                          }
                        },
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
