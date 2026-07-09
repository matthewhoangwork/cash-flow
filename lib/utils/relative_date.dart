import 'package:intl/intl.dart';

/// "Today" / "Yesterday" / weekday name (within the last week) / "MMM d" otherwise.
String relativeDayLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final difference = today.difference(day).inDays;

  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  if (difference > 1 && difference < 7) return DateFormat.EEEE().format(day);
  return DateFormat.yMMMd().format(day);
}
