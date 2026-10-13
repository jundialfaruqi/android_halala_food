import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../../core/constants/app_colors.dart';
import 'store_dropdown_search_field.dart';
import 'store_multi_search_selection_dialog.dart';

/// Form Field untuk memilih SATU ATAU LEBIH Mitra Toko (Multi-Select)
///
/// Karakteristik UI & UX:
/// - Terintegrasi dengan FormField untuk validasi form.
/// - Menampilkan toko yang terpilih dalam bentuk chips yang dapat dihapus individual.
/// - Terdapat tombol cepat "+ Tambah Toko Mitra" untuk menambah pilihan via dialog pencarian multi-select.
/// - Menampilkan pesan error validasi secara inline.
class StoreMultiSelectField extends StatefulWidget {
  final String? labelText;
  final String? hintText;
  final List<StoreSelectOption> initialStores;
  final List<dynamic>? initialAvailableStores;
  final ValueChanged<List<StoreSelectOption>>? onChanged;
  final FormFieldValidator<List<StoreSelectOption>>? validator;
  final bool enabled;

  const StoreMultiSelectField({
    super.key,
    this.labelText,
    this.hintText,
    this.initialStores = const [],
    this.initialAvailableStores,
    this.onChanged,
    this.validator,
    this.enabled = true,
  });

  @override
  State<StoreMultiSelectField> createState() => _StoreMultiSelectFieldState();
}

class _StoreMultiSelectFieldState extends State<StoreMultiSelectField> {
  late List<StoreSelectOption> _selectedStores;
  FormFieldState<List<StoreSelectOption>>? _currentFormFieldState;

  @override
  void initState() {
    super.initState();
    _selectedStores = List<StoreSelectOption>.from(widget.initialStores);
  }

  bool _areStoresEqual(List<StoreSelectOption> a, List<StoreSelectOption> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  @override
  void didUpdateWidget(covariant StoreMultiSelectField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_areStoresEqual(widget.initialStores, _selectedStores)) {
      _selectedStores = List<StoreSelectOption>.from(widget.initialStores);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentFormFieldState != null) {
          _currentFormFieldState!.didChange(_selectedStores);
        }
      });
    }
  }

  Future<void> _openSelectionDialog(FormFieldState<List<StoreSelectOption>> state) async {
    if (!widget.enabled) return;

    final result = await StoreMultiSearchSelectionDialog.show(
      context,
      initialSelectedStores: _selectedStores,
      initialAvailableStores: widget.initialAvailableStores,
    );

    if (result != null) {
      setState(() {
        _selectedStores = result;
      });
      state.didChange(_selectedStores);
      widget.onChanged?.call(_selectedStores);
    }
  }

  void _removeStore(StoreSelectOption store, FormFieldState<List<StoreSelectOption>> state) {
    if (!widget.enabled) return;
    setState(() {
      _selectedStores.removeWhere((s) => s.id == store.id);
    });
    state.didChange(_selectedStores);
    widget.onChanged?.call(_selectedStores);
  }

  @override
  Widget build(BuildContext context) {
    return FormField<List<StoreSelectOption>>(
      initialValue: _selectedStores,
      validator: widget.validator,
      builder: (state) {
        _currentFormFieldState = state;
        final hasError = state.hasError;
        final count = _selectedStores.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label
            if (widget.labelText != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  if (count > 0)
                    Text(
                      '$count toko terpilih',
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
            ],

            // Kontainer Utama Input
            InkWell(
              onTap: () => _openSelectionDialog(state),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: widget.enabled
                      ? AppColors.background
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasError
                        ? AppColors.error
                        : (_selectedStores.isNotEmpty
                            ? AppColors.brandBorder
                            : AppColors.brandBorder),
                    width: hasError ? 1.5 : 1.0,
                  ),
                ),
                child: _selectedStores.isEmpty
                    ? Row(
                        children: [
                          const Icon(
                            TablerIcons.building_store,
                            size: 18,
                            color: AppColors.brandWarmGray,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.hintText ?? 'Pilih satu atau lebih toko mitra...',
                              style: const TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                color: AppColors.brandWarmGray,
                              ),
                            ),
                          ),
                          const Icon(
                            TablerIcons.chevron_down,
                            size: 16,
                            color: AppColors.brandWarmGray,
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _selectedStores.map((store) {
                              return Container(
                                padding: const EdgeInsets.only(
                                  left: 10,
                                  top: 5,
                                  bottom: 5,
                                  right: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.brandBorder,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      TablerIcons.building_store,
                                      size: 14,
                                      color: AppColors.brandPrimary,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        store.displayName,
                                        style: const TextStyle(
                                          fontFamily: 'PlusJakartaSans',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.brandEspresso,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () => _removeStore(store, state),
                                      child: const Padding(
                                        padding: EdgeInsets.all(2.0),
                                        child: Icon(
                                          TablerIcons.x,
                                          size: 14,
                                          color: AppColors.brandWarmGray,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.brandPrimary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      TablerIcons.plus,
                                      size: 13,
                                      color: AppColors.brandPrimary,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Tambah / Ubah Pilihan Toko',
                                      style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.brandPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),

            // Pesan Error Validasi
            if (hasError) ...[
              const SizedBox(height: 5),
              Text(
                state.errorText!,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.error,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
