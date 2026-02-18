/// Format DateTime to human-readable string
String formatDateTime(DateTime? dateTime) {
  if (dateTime == null) {
    return 'Unknown';
  }

  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inDays > 0) {
    if (difference.inDays == 1) {
      return 'Yesterday at ${_formatTime(dateTime)}';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    }
  } else if (difference.inHours > 0) {
    return '${difference.inHours}h ago';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes}m ago';
  }

  return _formatDate(dateTime);
}

String _formatTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatDate(DateTime dateTime) {
  final year = dateTime.year;
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  final time = _formatTime(dateTime);
  return '$year-$month-$day $time';
}
