import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/widgets.dart';
import '../../data/models/invoice_model.dart';

class InvoiceShareHelper {
  static String formatInvoiceReceiptText(InvoiceModel invoice) {
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final store = invoice.store;
    final lines = <String>[];

    final recipientGreeting = store != null && store.ownerName != null && store.ownerName!.isNotEmpty
        ? '${store.name} (Bpk/Ibu ${store.ownerName})'
        : (store?.name ?? 'Mitra Toko');

    lines.add('Halo *$recipientGreeting*,');
    lines.add('');
    lines.add('Berikut kami sampaikan rincian tagihan faktur konsinyasi dari *Halala Food*:');
    lines.add('• No. Faktur: *${invoice.invoiceNumber}*');
    lines.add('• Tanggal: ${invoice.formattedInvoiceDate}');
    lines.add('• Jatuh Tempo: ${invoice.formattedDueDate}');
    if (invoice.deliveryNumber != null && invoice.deliveryNumber!.isNotEmpty) {
      lines.add('• Terkait SJ: ${invoice.deliveryNumber}');
    }
    lines.add('');
    lines.add('*Rincian Produk:*');

    for (final item in invoice.items) {
      lines.add(
        '- ${item.productName} (${item.quantity} ${item.productUnit}) = ${item.formattedSubtotal}',
      );
    }

    lines.add('');
    lines.add('Total Tagihan: *${currency.format(invoice.totalAmount)}*');
    if (invoice.discount > 0) {
      lines.add('Diskon: - ${currency.format(invoice.discount)}');
    }
    if (invoice.paidAmount > 0) {
      lines.add('Sudah Dibayar: ${currency.format(invoice.paidAmount)}');
    }
    lines.add('*Sisa Tagihan: ${currency.format(invoice.remainingBalance)}*');
    lines.add('');
    lines.add('Terima kasih atas kerja samanya.');

    return lines.join('\n');
  }

  static Future<void> shareToWhatsApp(
    BuildContext context,
    InvoiceModel invoice,
  ) async {
    final message = formatInvoiceReceiptText(invoice);

    String phone = (invoice.store?.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.startsWith('0')) {
      phone = '62${phone.substring(1)}';
    }

    final encodedMessage = Uri.encodeComponent(message);
    final urlString = phone.isNotEmpty
        ? 'https://api.whatsapp.com/send?phone=$phone&text=$encodedMessage'
        : 'https://api.whatsapp.com/send?text=$encodedMessage';

    final uri = Uri.parse(urlString);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        await _fallbackCopy(context, message);
      }
    } catch (_) {
      if (context.mounted) {
        await _fallbackCopy(context, message);
      }
    }
  }

  static Future<void> _fallbackCopy(BuildContext context, String message) async {
    await Clipboard.setData(ClipboardData(text: message));
    if (context.mounted) {
      AppSnackBar.showSuccess(
        context,
        message: 'Teks faktur telah disalin ke clipboard.',
      );
    }
  }
}
