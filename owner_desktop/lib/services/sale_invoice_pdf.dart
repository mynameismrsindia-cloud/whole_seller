import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/product.dart';

Future<Uint8List> buildSaleInvoicePdf(Sale sale) async {
  final document = pw.Document();
  final indiaTime = sale.createdAt.toUtc().add(const Duration(hours: 5, minutes: 30));
  final saleDate =
      '${indiaTime.day.toString().padLeft(2, '0')} '
      '${_month(indiaTime.month)} ${indiaTime.year}';
  final saleTime =
      '${indiaTime.hour.toString().padLeft(2, '0')}:'
      '${indiaTime.minute.toString().padLeft(2, '0')}';
  final details = <(String, String)>[
    ('Invoice number', sale.id),
    ('Date & time', '$saleDate, $saleTime IST'),
    ('Salesman', sale.salesman),
    ('Store', sale.store),
    ('Contact', sale.contact),
    ('Location', sale.location),
    ('Product', '${sale.productName} (${sale.productId})'),
    ('Quantity', '${sale.quantity}'),
    ('Rate per unit', 'INR ${sale.rate}'),
  ];

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'BONZAR',
            style: pw.TextStyle(
              color: PdfColors.teal800,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'SALES INVOICE',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 24),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: const {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(2),
            },
            children: [
              for (final (label, value) in details)
                pw.TableRow(
                  children: [
                    _cell(label, bold: true),
                    _cell(value),
                  ],
                ),
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                children: [
                  _cell('Total amount', bold: true),
                  _cell('INR ${sale.totalAmount}', bold: true),
                ],
              ),
              pw.TableRow(
                children: [
                  _cell('Order status', bold: true),
                  _cell(
                    sale.orderStatus == OrderStatus.pending
                        ? 'Pending'
                        : 'Approved',
                  ),
                ],
              ),
            ],
          ),
          pw.Spacer(),
          pw.Divider(color: PdfColors.grey400),
          pw.Text(
            'Generated from the Owner desktop application.',
            style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9),
          ),
        ],
      ),
    ),
  );

  return document.save();
}

Future<void> saveSaleInvoicePdf(Sale sale) async {
  final safeId = sale.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  await FileSaver.instance.saveFile(
    name: safeId.isEmpty ? 'sale_invoice' : 'sale_invoice_$safeId',
    bytes: await buildSaleInvoicePdf(sale),
    fileExtension: 'pdf',
    mimeType: MimeType.pdf,
  );
}

pw.Widget _cell(String value, {bool bold = false}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
  child: pw.Text(
    value,
    style: pw.TextStyle(
      fontSize: 11,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    ),
  ),
);

String _month(int value) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][value - 1];
