import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/product.dart';

Future<Uint8List> buildSaleInvoicePdf(
  Sale sale, {
  List<Sale>? orderItems,
}) async {
  final document = pw.Document();
  final items = orderItems == null || orderItems.isEmpty ? [sale] : orderItems;
  final indiaTime = sale.createdAt.toUtc().add(
    const Duration(hours: 5, minutes: 30),
  );
  final saleDate =
      '${indiaTime.day.toString().padLeft(2, '0')} '
      '${_month(indiaTime.month)} ${indiaTime.year}';
  final saleTime =
      '${indiaTime.hour.toString().padLeft(2, '0')}:'
      '${indiaTime.minute.toString().padLeft(2, '0')}';
  final details = <(String, String)>[
    (
      'Invoice / order number',
      sale.requestId.isEmpty ? sale.id : sale.requestId,
    ),
    ('Date & time', '$saleDate, $saleTime IST'),
    ('Salesman', sale.salesman),
    ('Store', sale.store),
    ('Contact', sale.contact),
    ('Location', sale.location),
  ];
  final totalAmount = items.fold<int>(
    0,
    (total, item) => total + item.totalAmount,
  );
  final orderStatus =
      items.any((item) => item.orderStatus == OrderStatus.pending)
      ? OrderStatus.pending
      : OrderStatus.approved;

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
                pw.TableRow(children: [_cell(label, bold: true), _cell(value)]),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: const <int, pw.TableColumnWidth>{
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(0.7),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1),
              4: pw.FlexColumnWidth(1.3),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cell('Product', bold: true),
                  _cell('Qty', bold: true),
                  _cell('Rate', bold: true),
                  _cell('Amount', bold: true),
                  _cell('Product ID', bold: true),
                ],
              ),
              for (final item in items)
                pw.TableRow(
                  children: [
                    _cell(item.productName),
                    _cell('${item.quantity}'),
                    _cell('INR ${item.rate}'),
                    _cell('INR ${item.totalAmount}'),
                    _cell(item.productId),
                  ],
                ),
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                children: [
                  _cell('Total amount', bold: true),
                  _cell(''),
                  _cell(''),
                  _cell('INR $totalAmount', bold: true),
                  _cell(''),
                ],
              ),
              pw.TableRow(
                children: [
                  _cell(
                    'Order status: ${orderStatus == OrderStatus.pending ? 'Pending' : 'Approved'}',
                    bold: true,
                  ),
                  _cell(''),
                  _cell(''),
                  _cell(''),
                  _cell(''),
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

Future<void> saveSaleInvoicePdf(Sale sale, {List<Sale>? orderItems}) async {
  final invoiceId = sale.requestId.isEmpty ? sale.id : sale.requestId;
  final safeId = invoiceId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  await FileSaver.instance.saveFile(
    name: safeId.isEmpty ? 'sale_invoice' : 'sale_invoice_$safeId',
    bytes: await buildSaleInvoicePdf(sale, orderItems: orderItems),
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
