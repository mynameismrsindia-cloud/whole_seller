import 'package:flutter_test/flutter_test.dart';
import 'package:owner_desktop/models/product.dart';
import 'package:owner_desktop/services/sale_invoice_pdf.dart';

void main() {
  test('builds a PDF invoice for a sale', () async {
    final bytes = await buildSaleInvoicePdf(
      Sale(
        id: 'sale-1',
        salesman: 'Seller',
        userId: 'private-user-id',
        store: 'Store',
        contact: '1234567890',
        location: 'Kolkata',
        productId: 'rice',
        productName: 'Rice',
        quantity: 2,
        rate: 50,
        createdAt: DateTime.utc(2026, 1, 1, 21),
      ),
    );

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(500));
  });

  test('builds one order invoice containing all product lines', () async {
    final first = Sale(
      id: 'sale-rice',
      requestId: 'order-123',
      salesman: 'Seller',
      userId: 'seller-id',
      store: 'Store',
      contact: '1234567890',
      location: 'Kolkata',
      productId: 'rice',
      productName: 'Rice',
      quantity: 2,
      rate: 50,
      createdAt: DateTime.utc(2026, 1, 1, 21),
    );
    final second = Sale(
      id: 'sale-lentils',
      requestId: 'order-123',
      salesman: 'Seller',
      userId: 'seller-id',
      store: 'Store',
      contact: '1234567890',
      location: 'Kolkata',
      productId: 'lentils',
      productName: 'Lentils',
      quantity: 3,
      rate: 40,
      createdAt: DateTime.utc(2026, 1, 1, 21),
    );

    final invoiceBytes = await buildSaleInvoicePdf(
      first,
      orderItems: [first, second],
    );
    final singleLineBytes = await buildSaleInvoicePdf(first);

    expect(String.fromCharCodes(invoiceBytes.take(5)), '%PDF-');
    expect(invoiceBytes.length, greaterThan(singleLineBytes.length));
  });
}
