DateTime toIndiaDateTime(DateTime value) =>
    value.toUtc().add(const Duration(hours: 5, minutes: 30));

String formatIndiaDateTime(DateTime value) {
  final indiaTime = toIndiaDateTime(value);
  final date =
      '${indiaTime.day.toString().padLeft(2, '0')} '
      '${_month(indiaTime.month)} ${indiaTime.year}';
  final time =
      '${indiaTime.hour.toString().padLeft(2, '0')}:'
      '${indiaTime.minute.toString().padLeft(2, '0')}';
  return '$date, $time IST';
}

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
