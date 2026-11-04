import 'package:flutter/material.dart';

import '../models/product.dart';

class SalesListScreen extends StatefulWidget {
  const SalesListScreen({
    super.key,
    required this.sales,
    required this.onStatusChanged,
  });

  final List<Sale> sales;
  final void Function(Sale, OrderStatus) onStatusChanged;

  @override
  State<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends State<SalesListScreen> {
  DateTimeRange? range;

  @override
  Widget build(BuildContext context) {
    final selectedRange = range;
    final visible = widget.sales.where((sale) {
      final selected = selectedRange;
      if (selected == null) return true;
      final start = DateTime(
        selected.start.year,
        selected.start.month,
        selected.start.day,
      );
      final end = DateTime(
        selected.end.year,
        selected.end.month,
        selected.end.day + 1,
      );
      return !sale.createdAt.isBefore(start) && sale.createdAt.isBefore(end);
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
                OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await showDateRangePicker(
                      context: context,
                      initialDateRange: range,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (selected != null) setState(() => range = selected);
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    selectedRange == null
                        ? 'All dates'
                        : '${_date(selectedRange.start)} – '
                              '${_date(selectedRange.end)}',
                  ),
                ),
                if (selectedRange != null)
                  IconButton(
                    tooltip: 'Clear filter',
                    onPressed: () => setState(() => range = null),
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
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Date & time')),
                    DataColumn(label: Text('Salesman')),
                    DataColumn(label: Text('User ID')),
                    DataColumn(label: Text('Store')),
                    DataColumn(label: Text('Contact')),
                    DataColumn(label: Text('Location')),
                    DataColumn(label: Text('Product')),
                    DataColumn(label: Text('Qty')),
                    DataColumn(label: Text('Rate')),
                    DataColumn(label: Text('Order status')),
                  ],
                  rows: visible.map((sale) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            '${_date(sale.createdAt)}\n${_time(sale.createdAt)}',
                          ),
                        ),
                        DataCell(Text(sale.salesman)),
                        DataCell(Text(sale.userId)),
                        DataCell(Text(sale.store)),
                        DataCell(Text(sale.contact)),
                        DataCell(Text(sale.location)),
                        DataCell(
                          Text('${sale.productName}\n${sale.productId}'),
                        ),
                        DataCell(Text('${sale.quantity}')),
                        DataCell(Text('₹${sale.rate}')),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                sale.orderStatus == OrderStatus.pending
                                    ? 'Pending'
                                    : 'Approved',
                                style: TextStyle(
                                  color: sale.orderStatus == OrderStatus.pending
                                      ? Colors.orange.shade800
                                      : Colors.green.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                key: ValueKey(
                                  'approve-order-${sale.id.isEmpty ? sale.userId : sale.id}',
                                ),
                                onPressed:
                                    sale.orderStatus == OrderStatus.pending
                                    ? () => widget.onStatusChanged(
                                        sale,
                                        OrderStatus.approved,
                                      )
                                    : null,
                                child: Text(
                                  sale.orderStatus == OrderStatus.pending
                                      ? 'Approve'
                                      : 'Approved',
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
          ],
        ),
      ),
    );
  }
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')} ${_month(value.month)} ${value.year}';

String _time(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  return '$hour:${value.minute.toString().padLeft(2, '0')} '
      '${value.hour >= 12 ? 'PM' : 'AM'}';
}

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
