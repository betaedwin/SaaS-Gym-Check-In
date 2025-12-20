String formatLocalDate(DateTime date) {
  const months = <String>[
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
  ];
  final monthName =
      (date.month >= 1 && date.month <= 12) ? months[date.month - 1] : '';
  return '$monthName ${date.day}, ${date.year}';
}
