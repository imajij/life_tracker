import 'package:intl/intl.dart';

class DateUtils {
  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('MMM dd, yyyy hh:mm a').format(date);
  }

  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  static DateTime startOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  static DateTime endOfWeek(DateTime date) {
    return startOfWeek(
      date,
    ).add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return isSameDay(date, now);
  }

  static int daysBetween(DateTime from, DateTime to) {
    from = DateTime(from.year, from.month, from.day);
    to = DateTime(to.year, to.month, to.day);
    return (to.difference(from).inHours / 24).round();
  }
}

class HabitStreakCalculator {
  /// Calculate current streak for a habit
  /// Returns 0 if habit was not done yesterday (for daily) or this week (for weekly)
  static int calculateStreak({
    required DateTime? lastDoneDate,
    required String periodicity, // 'daily' or 'weekly'
  }) {
    if (lastDoneDate == null) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDone = DateTime(
      lastDoneDate.year,
      lastDoneDate.month,
      lastDoneDate.day,
    );

    if (periodicity == 'daily') {
      final daysSince = today.difference(lastDone).inDays;

      // If done today or yesterday, streak continues
      if (daysSince <= 1) {
        return 1; // This will be incremented by the calling code
      } else {
        return 0; // Streak broken
      }
    } else if (periodicity == 'weekly') {
      final weeksSince = (today.difference(lastDone).inDays / 7).floor();

      if (weeksSince <= 1) {
        return 1;
      } else {
        return 0;
      }
    }

    return 0;
  }

  /// Check if habit should reset streak (was not completed in required timeframe)
  static bool shouldResetStreak({
    required DateTime? lastDoneDate,
    required String periodicity,
  }) {
    if (lastDoneDate == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDone = DateTime(
      lastDoneDate.year,
      lastDoneDate.month,
      lastDoneDate.day,
    );

    if (periodicity == 'daily') {
      final daysSince = today.difference(lastDone).inDays;
      return daysSince > 1; // Missed a day
    } else if (periodicity == 'weekly') {
      final daysSince = today.difference(lastDone).inDays;
      return daysSince > 7; // Missed a week
    }

    return false;
  }

  /// Check if habit can be marked as done today
  static bool canMarkDoneToday({
    required DateTime? lastDoneDate,
    required String periodicity,
  }) {
    if (lastDoneDate == null) return true;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDone = DateTime(
      lastDoneDate.year,
      lastDoneDate.month,
      lastDoneDate.day,
    );

    if (periodicity == 'daily') {
      return !DateUtils.isSameDay(lastDone, today);
    } else if (periodicity == 'weekly') {
      final lastDoneWeekStart = DateUtils.startOfWeek(lastDone);
      final currentWeekStart = DateUtils.startOfWeek(today);
      return lastDoneWeekStart != currentWeekStart;
    }

    return true;
  }
}
