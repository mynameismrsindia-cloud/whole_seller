import 'package:flutter/material.dart';

import '../models/product.dart';
import '../utils/india_date_time.dart';

class SalesListScreen extends StatefulWidget {
  const SalesListScreen({
    super.key,
    required this.sales,
    required this.onStatusChanged,
    required this.onDownloadInvoice,
    this.initialRange,
    this.hasMore = false,
    this.onRangeChanged,
    this.onLoadMore,
    this.onRefresh,
  });

  final List<Sale> sales;
  final void Function(List<Sale>, OrderStatus) onStatusChanged;
  final Future<void> Function(Sale) onDownloadInvoice;
  final DateTimeRange? initialRange;
  final bool hasMore;
  final Future<void> Function(DateTimeRange?)? onRangeChanged;
  final Future<void> Function()? onLoadMore;
  final Future<void> Function()? onRefresh;

  @override
  State<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends State<SalesListScreen> {
  late DateTimeRange? range = widget.initialRange;
  final _tableScrollController = ScrollController();

  @override
  void dispose() {
    _tableScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedRange = range;
    final visible = widget.sales.where((sale) {
      final selected = selectedRange;
      if (selected == null) return true;
      final indiaTime = toIndiaDateTime(sale.createdAt);
      final saleDate = DateTime.utc(
        indiaTime.year,
        indiaTime.month,
        indiaTime.day,
      );
      final start = DateTime.utc(
        selected.start.year,
        selected.start.month,
        selected.start.day,
      );
      final end = DateTime.utc(
        selected.end.year,
        selected.end.month,
        selected.end.day + 1,
      );
      return !saleDate.isBefore(start) && saleDate.isBefore(end);
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final grouped = <String, List<Sale>>{};
    for (final sale in visible) {
      final orderKey = sale.requestId.isNotEmpty ? sale.requestId : sale.id;
      (grouped[orderKey] ??= []).add(sale);
    }
    final orders = grouped.values.map(_SalesOrder.new).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Sales Entries',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                if (widget.onRefresh != null)
                  IconButton(
                    tooltip: 'Refresh sales',
                    onPressed: () async {
                      try {
                        await widget.onRefresh!.call();
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.refresh),
                  ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await showDateRangePicker(
                      context: context,
                      initialDateRange: range,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (selected != null) {
                      setState(() => range = selected);
                      await widget.onRangeChanged?.call(selected);
                    }
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    selectedRange == null
                        ? 'All dates'
                        : '${_rangeDate(selectedRange.start)} – '
                              '${_rangeDate(selectedRange.end)}',
                  ),
                ),
                if (selectedRange != null)
                  IconButton(
                    tooltip: 'Clear filter',
                    onPressed: () {
                      setState(() => range = null);
                      widget.onRangeChanged?.call(null);
                    },
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Text(
                  'No sales entries for the selected date.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              Scrollbar(
                controller: _tableScrollController,
                thumbVisibility: true,
                trackVisibility: true,
                thickness: 12,
                interactive: true,
                child: SingleChildScrollView(
                  controller: _tableScrollController,
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Date & time')),
                      DataColumn(label: Text('Invoice #')),
                      DataColumn(label: Text('Salesman')),
                      DataColumn(label: Text('Store')),
                      DataColumn(label: Text('Contact')),
                      DataColumn(label: Text('Location')),
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('Qty')),
                      DataColumn(label: Text('Rate')),
                      DataColumn(label: Text('Order status')),
                      DataColumn(label: Text('Action')),
                    ],
                    rows: orders.map((order) {
                      final sale = order.primary;
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              '${_date(sale.createdAt)}\n${_time(sale.createdAt)}',
                            ),
                          ),
                          DataCell(
                            Tooltip(
                              message: sale.requestId,
                              child: Text(sale.displayInvoiceNumber),
                            ),
                          ),
                          DataCell(Text(sale.salesman)),
                          DataCell(Text(sale.store)),
                          DataCell(Text(sale.contact)),
                          DataCell(Text(sale.location)),
                          DataCell(
                            Text(
                              order.items
                                  .map((item) => item.productName)
                                  .join('\n'),
                            ),
                          ),
                          DataCell(
                            Text(
                              order.items
                                  .map((item) => '${item.quantity}')
                                  .join('\n'),
                            ),
                          ),
                          DataCell(
                            Text(
                              order.items
                                  .map((item) => '₹${item.rate}')
                                  .join('\n'),
                            ),
                          ),
                          DataCell(
                            Chip(
                              label: Text(
                                order.isPending ? 'Pending' : 'Approved',
                              ),
                              backgroundColor: order.isPending
                                  ? Colors.orange.shade100
                                  : Colors.green.shade100,
                              labelStyle: TextStyle(
                                color: order.isPending
                                    ? Colors.orange.shade900
                                    : Colors.green.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FilledButton(
                                  key: ValueKey('approve-order-${sale.id}'),
                                  onPressed: order.isPending
                                      ? () => widget.onStatusChanged(
                                          order.items,
                                          OrderStatus.approved,
                                        )
                                      : null,
                                  child: Text(
                                    order.isPending ? 'Approve' : 'Approved',
                                  ),
                                ),
                                IconButton(
                                  key: ValueKey('download-invoice-${sale.id}'),
                                  tooltip: 'Download invoice PDF',
                                  onPressed: () =>
                                      widget.onDownloadInvoice(sale),
                                  icon: const Icon(
                                    Icons.picture_as_pdf_outlined,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            if (widget.hasMore && widget.onLoadMore != null)
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: () async {
                    try {
                      await widget.onLoadMore!.call();
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    }
                  },
                  child: const Text('Load more sales'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SalesOrder {
  _SalesOrder(this.items);

  final List<Sale> items;
  Sale get primary => items.first;
  bool get isPending =>
      items.any((sale) => sale.orderStatus == OrderStatus.pending);
}

String _date(DateTime value) {
  final indiaTime = toIndiaDateTime(value);
  return '${indiaTime.day.toString().padLeft(2, '0')} '
      '${_month(indiaTime.month)} ${indiaTime.year}';
}

String _time(DateTime value) {
  final indiaTime = toIndiaDateTime(value);
  final hour = indiaTime.hour % 12 == 0 ? 12 : indiaTime.hour % 12;
  return '$hour:${indiaTime.minute.toString().padLeft(2, '0')} '
      '${indiaTime.hour >= 12 ? 'PM' : 'AM'}';
}

String _rangeDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')} '
    '${_month(value.month)} ${value.year}';

String _month(int n) => const [
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
][n - 1];
