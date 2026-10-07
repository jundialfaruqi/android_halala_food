import 'package:android_halala_food/core/constants/app_colors.dart';
import 'package:android_halala_food/core/widgets/app_empty_card.dart';
import 'package:android_halala_food/core/widgets/app_menu_select.dart';
import 'package:android_halala_food/features/delivery/data/models/delivery_model.dart';
import 'package:android_halala_food/features/delivery/presentation/models/delivery_item_form_entry.dart';
import 'package:android_halala_food/features/delivery/presentation/widgets/delivery_item_card.dart';
import 'package:android_halala_food/features/delivery/presentation/widgets/delivery_item_edit_dialog.dart';
import 'package:android_halala_food/features/delivery/presentation/widgets/delivery_product_selection_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const sampleProduct1 = ProductOptionModel(
    id: 1,
    name: 'Ting Ting Susu 200gr',
    unit: 'bungkus',
    stockReady: 50,
    consignmentPrice: 50000,
    depositPrice: 60000,
  );

  const sampleProduct2 = ProductOptionModel(
    id: 2,
    name: 'Keripik Tempe Renyah',
    unit: 'bungkus',
    stockReady: 30,
    consignmentPrice: 15000,
    depositPrice: 20000,
  );

  group('DeliveryProductSelectionDialog Widget Tests', () {
    testWidgets('renders 2-column products and stepper increments quantity',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeliveryProductSelectionDialog(
              products: [sampleProduct1, sampleProduct2],
              alreadyAddedProductIds: {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Product names are rendered
      expect(find.text('Ting Ting Susu 200gr'), findsOneWidget);
      expect(find.text('Keripik Tempe Renyah'), findsOneWidget);

      // Button Tambahkan exists
      expect(find.text('Tambahkan'), findsOneWidget);

      // Tap + on first product to increment count
      final plusIcons = find.byIcon(TablerIcons.plus);
      expect(plusIcons, findsWidgets);

      await tester.tap(plusIcons.first);
      await tester.pumpAndSettle();

      // Quantity should become 2 and button text updates to 1 Produk
      expect(find.text('2'), findsWidgets);
      expect(find.text('Tambahkan (1 Produk)'), findsOneWidget);
    });

    testWidgets(
        'validates empty/0 quantity and price when product selected (Point 8)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeliveryProductSelectionDialog(
              products: [sampleProduct1],
              alreadyAddedProductIds: {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap checkbox to select product
      await tester.tap(find.byKey(const Key('product_checkbox_1')));
      await tester.pumpAndSettle();

      // Button updates to 1 Produk
      expect(find.text('Tambahkan (1 Produk)'), findsOneWidget);

      // Clear quantity field to simulate empty quantity
      final qtyTextField = find.byKey(const Key('qty_field_1'));
      await tester.enterText(qtyTextField, '');
      await tester.pumpAndSettle();

      // Validation error message should appear under the card
      expect(find.text('Jumlah wajib diisi (min. 1)'), findsOneWidget);
    });
  });

  group('DeliveryItemEditDialog Widget Tests', () {
    testWidgets('renders single item edit dialog and edits quantity',
        (tester) async {
      final entry = DeliveryItemFormEntry(
        productId: 1,
        product: sampleProduct1,
        quantity: 3,
        unitPrice: 50000,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeliveryItemEditDialog(item: entry),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Displays title and product name
      expect(find.text('Edit Muatan Produk'), findsOneWidget);
      expect(find.text('Ting Ting Susu 200gr'), findsOneWidget);

      // Initial quantity 3 is present
      expect(find.text('3'), findsOneWidget);

      // Tap minus to decrease to 2
      await tester.tap(find.byIcon(TablerIcons.minus));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);

      // Tap Simpan
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      // Entry quantity should be updated to 2
      expect(entry.quantity, 2);
    });
  });

  group('DeliveryItemCard Widget Tests', () {
    testWidgets('renders item details, and edit/delete callbacks trigger',
        (tester) async {
      final entry = DeliveryItemFormEntry(
        productId: 1,
        product: sampleProduct1,
        quantity: 5,
        unitPrice: 50000,
      );

      bool editTapped = false;
      bool deleteTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeliveryItemCard(
              index: 0,
              item: entry,
              onEdit: () => editTapped = true,
              onDelete: () => deleteTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Content checks
      expect(find.text('Ting Ting Susu 200gr'), findsOneWidget);
      expect(find.text('5 bungkus'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Hapus'), findsOneWidget);

      // Tap Edit
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(editTapped, isTrue);

      // Tap Hapus
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
      expect(deleteTapped, isTrue);
    });
  });

  group('Delivery Form Inline Validations', () {
    testWidgets(
        'AppMenuSelect validates courier required inline and clears upon selection',
        (tester) async {
      final formKey = GlobalKey<FormState>();
      int? selectedCourierId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: Column(
                children: [
                  AppMenuSelect<int>(
                    labelText: 'Kurir Bertugas',
                    hintText: 'Pilih Kurir Bertugas...',
                    initialSelection: selectedCourierId,
                    entries: const [
                      AppMenuSelectEntry<int>(value: 1, label: 'Budi Santoso'),
                      AppMenuSelectEntry<int>(value: 2, label: 'Ahmad Dahlan'),
                    ],
                    validator: (val) {
                      if (val == null || val == 0) {
                        return 'Kurir yang bertugas wajib dipilih.';
                      }
                      return null;
                    },
                    onSelected: (val) {
                      selectedCourierId = val;
                    },
                  ),
                  ElevatedButton(
                    onPressed: () {
                      formKey.currentState!.validate();
                    },
                    child: const Text('Validate'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger validation
      await tester.tap(find.text('Validate'));
      await tester.pumpAndSettle();

      // Inline error text is shown
      expect(find.text('Kurir yang bertugas wajib dipilih.'), findsOneWidget);

      // Select courier from dropdown
      await tester.tap(find.byType(DropdownMenu<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Budi Santoso').last);
      await tester.pumpAndSettle();

      // Inline error text is cleared dynamically
      expect(find.text('Kurir yang bertugas wajib dipilih.'), findsNothing);
    });

    testWidgets(
        'Empty product items shows inline error card and red border below AppEmptyCard',
        (tester) async {
      String? itemsErrorMessage;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    AppEmptyCard(
                      icon: TablerIcons.package,
                      title: 'Belum Ada Muatan Barang Jadi',
                      message:
                          'Pilih produk barang jadi yang akan dimuat ke dalam pengantaran ini.',
                      actionText: 'Tambahkan Produk Jadi',
                      actionIcon: TablerIcons.plus,
                      hasBorder: true,
                      borderColor: itemsErrorMessage != null
                          ? AppColors.error
                          : AppColors.brandBorder,
                      backgroundColor: Colors.white,
                      onAction: () {},
                    ),
                    if (itemsErrorMessage != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              TablerIcons.alert_circle,
                              size: 16,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                itemsErrorMessage!,
                                style: const TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          itemsErrorMessage =
                              'Muatan barang jadi wajib diisi minimal 1 jenis produk.';
                        });
                      },
                      child: const Text('Simpan Surat Jalan'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(
          find.text('Muatan barang jadi wajib diisi minimal 1 jenis produk.'),
          findsNothing);

      // Tap Simpan Surat Jalan with empty products
      await tester.tap(find.text('Simpan Surat Jalan'));
      await tester.pumpAndSettle();

      // Inline error message and icon appear directly below the card
      expect(
          find.text('Muatan barang jadi wajib diisi minimal 1 jenis produk.'),
          findsOneWidget);
      expect(find.byIcon(TablerIcons.alert_circle), findsOneWidget);
    });
  });
}
