import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/raw_material_model.dart';
import '../../data/repositories/raw_material_repository_impl.dart';
import 'raw_material_search_selection_dialog.dart';

/// Widget Select Dropdown Bahan Baku dengan UX Halala Food:
/// 1. Dropdown overlay interaktif dengan input pencarian realtime
/// 2. Hasil di select dropdown cepat dibatasi maksimal 5 data
/// 3. Tombol "Tampilkan semua bahan baku" untuk membuka dialog modal lengkap
/// 4. Terintegrasi penuh dengan [FormField] validasi
class RawMaterialDropdownSearchField extends ConsumerStatefulWidget {
  final String? labelText;
  final String? hintText;
  final int? initialValue;
  final RawMaterialModel? initialMaterial;
  final List<RawMaterialModel>? initialMaterials;
  final ValueChanged<RawMaterialModel?>? onSelected;
  final FormFieldValidator<int>? validator;
  final bool enabled;

  const RawMaterialDropdownSearchField({
    super.key,
    this.labelText,
    this.hintText,
    this.initialValue,
    this.initialMaterial,
    this.initialMaterials,
    this.onSelected,
    this.validator,
    this.enabled = true,
  });

  @override
  ConsumerState<RawMaterialDropdownSearchField> createState() =>
      _RawMaterialDropdownSearchFieldState();
}

class _RawMaterialDropdownSearchFieldState
    extends ConsumerState<RawMaterialDropdownSearchField> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  OverlayEntry? _overlayEntry;
  Timer? _debounceTimer;

  int? _selectedMaterialId;
  RawMaterialModel? _selectedMaterial;

  List<RawMaterialModel> _dropdownMaterials = [];
  bool _isSearching = false;
  FormFieldState<int>? _currentFormFieldState;

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  String _formatMaterialLabel(RawMaterialModel m) {
    return '${m.name} (${_currencyFormat.format(m.costPerUnit)} / ${m.unitShort})';
  }

  @override
  void initState() {
    super.initState();
    _selectedMaterialId = widget.initialValue;

    if (widget.initialMaterial != null) {
      _selectedMaterial = widget.initialMaterial;
      _textController.text = _formatMaterialLabel(widget.initialMaterial!);
    } else if (widget.initialValue != null && widget.initialMaterials != null) {
      final match = widget.initialMaterials!
          .where((m) => m.id == widget.initialValue)
          .firstOrNull;
      if (match != null) {
        _selectedMaterial = match;
        _textController.text = _formatMaterialLabel(match);
      }
    }

    _loadInitialDefaultMaterials();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _showOverlay();
      } else {
        _hideOverlay();
        if (_selectedMaterial != null) {
          _textController.text = _formatMaterialLabel(_selectedMaterial!);
        } else if (_selectedMaterialId == null) {
          _textController.clear();
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant RawMaterialDropdownSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue ||
        widget.initialMaterial != oldWidget.initialMaterial) {
      _selectedMaterialId = widget.initialValue;
      if (widget.initialMaterial != null) {
        _selectedMaterial = widget.initialMaterial;
        _textController.text = _formatMaterialLabel(widget.initialMaterial!);
      } else if (_selectedMaterialId == null) {
        _selectedMaterial = null;
        _textController.clear();
      } else if (widget.initialMaterials != null) {
        final match = widget.initialMaterials!
            .where((m) => m.id == _selectedMaterialId)
            .firstOrNull;
        if (match != null) {
          _selectedMaterial = match;
          _textController.text = _formatMaterialLabel(match);
        }
      }
    }

    if (widget.initialMaterials != oldWidget.initialMaterials) {
      _loadInitialDefaultMaterials();
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

  void _loadInitialDefaultMaterials() {
    if (widget.initialMaterials != null && widget.initialMaterials!.isNotEmpty) {
      _dropdownMaterials = widget.initialMaterials!.take(5).toList();
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

                      // 2. Tombol "Tampilkan semua bahan baku"
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
                            color: Color(0xFFF9FAFB),
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
                                color: Colors.black,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Tampilkan semua bahan baku',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandEspresso,
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

    if (trimmed.isEmpty) {
      setState(() {
        _isSearching = false;
        _loadInitialDefaultMaterials();
      });
      _overlayEntry?.markNeedsBuild();
      return;
    }

    // Filter lokal terlebih dahulu untuk feedback instan jika data tersedia
    if (widget.initialMaterials != null && widget.initialMaterials!.isNotEmpty) {
      final localMatches = widget.initialMaterials!
          .where((m) => m.name.toLowerCase().contains(trimmed.toLowerCase()))
          .take(5)
          .toList();
      setState(() {
        _dropdownMaterials = localMatches;
      });
      _overlayEntry?.markNeedsBuild();
    }

    // Jalankan debounce pencarian remote jika teks >= 2 huruf
    if (trimmed.length >= 2) {
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        _performSearch(trimmed);
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() {
      _isSearching = true;
    });
    _overlayEntry?.markNeedsBuild();

    try {
      final repository = ref.read(rawMaterialRepositoryProvider);
      final result = await repository.getRawMaterials(
        search: query,
        perPage: 5,
      );

      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _dropdownMaterials = result.materials.take(5).toList();
      });
      _overlayEntry?.markNeedsBuild();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
      });
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _selectMaterial(RawMaterialModel material) {
    setState(() {
      _selectedMaterialId = material.id;
      _selectedMaterial = material;
      _textController.text = _formatMaterialLabel(material);
    });

    if (_currentFormFieldState != null) {
      _currentFormFieldState!.didChange(material.id);
      _currentFormFieldState!.validate();
    }
    widget.onSelected?.call(material);

    _focusNode.unfocus();
    _hideOverlay();
  }

  void _clearSelection() {
    setState(() {
      _selectedMaterialId = null;
      _selectedMaterial = null;
      _textController.clear();
      _loadInitialDefaultMaterials();
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
    final selected = await RawMaterialSearchSelectionDialog.show(
      context,
      selectedMaterialId: _selectedMaterialId,
      initialSearch: currentQuery.isNotEmpty ? currentQuery : null,
      fallbackMaterials: widget.initialMaterials,
    );

    if (selected != null && mounted) {
      _selectMaterial(selected);
    }
  }

  Widget _buildDropdownItems() {
    if (_isSearching && _dropdownMaterials.isEmpty) {
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
                'Mencari bahan baku...',
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

    if (_dropdownMaterials.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(
          query.isNotEmpty
              ? 'Tidak ada bahan baku ditemukan dengan kata kunci "$query".'
              : 'Pilih bahan baku dari daftar atau klik tombol di bawah.',
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
      itemCount: _dropdownMaterials.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        thickness: 0.6,
        color: AppColors.brandBorder,
      ),
      itemBuilder: (context, index) {
        final mat = _dropdownMaterials[index];
        final isSelected = _selectedMaterialId == mat.id;

        return InkWell(
          onTap: () => _selectMaterial(mat),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              mat.name,
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                fontWeight:
                                    isSelected ? FontWeight.w700 : FontWeight.w600,
                                color: AppColors.brandEspresso,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${mat.unitShort})',
                            style: const TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11.5,
                              color: AppColors.brandWarmGray,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_currencyFormat.format(mat.costPerUnit)} / ${mat.unitShort}',
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandEspresso,
                        ),
                      ),
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
      initialValue: _selectedMaterialId,
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
                  fontSize: 12.5,
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
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandEspresso,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText ?? 'Pilih Bahan Baku...',
                  hintStyle: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.brandWarmGray,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: hasError ? const Color(0xFFDC2626) : AppColors.brandBorder,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: hasError ? const Color(0xFFDC2626) : AppColors.brandBorder,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: hasError ? const Color(0xFFDC2626) : AppColors.brandPrimary,
                      width: 1.5,
                    ),
                  ),
                  prefixIcon: const Icon(
                    TablerIcons.package,
                    size: 18,
                    color: AppColors.brandWarmGray,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectedMaterialId != null ||
                          _textController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(
                            TablerIcons.x,
                            size: 16,
                            color: Colors.black,
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
                padding: const EdgeInsets.only(left: 4, top: 4),
                child: Text(
                  errorText,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFDC2626),
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
