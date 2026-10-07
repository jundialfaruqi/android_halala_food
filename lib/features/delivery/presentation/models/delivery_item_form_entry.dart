import '../../data/models/delivery_model.dart';

/// Model representasi baris muatan produk jadi di form Create & Edit Surat Jalan.
class DeliveryItemFormEntry {
  final int productId;
  final ProductOptionModel product;
  int quantity;
  double unitPrice;
  final int previouslyReservedQty;

  DeliveryItemFormEntry({
    required this.productId,
    required this.product,
    required this.quantity,
    required this.unitPrice,
    this.previouslyReservedQty = 0,
  });

  /// Total subtotal per baris muatan
  double get subtotal => quantity * unitPrice;

  /// Total stok yang tersedia untuk item ini (termasuk stok yang sebelumnya sudah dialokasikan pada edit surat jalan)
  int get totalAvailableStock => product.stockReady + previouslyReservedQty;

  /// Konversi ke payload API surat jalan
  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
    };
  }
}
