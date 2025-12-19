import 'package:home_widget/home_widget.dart';
import '../db/database.dart';

class WidgetService {
  static const String appGroupId = 'group.com.example.life_tracker';
  static const String androidWidgetName = 'LifeTrackerWidgetProvider';

  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId(appGroupId);
  }

  /// Updates the home screen widget with current data
  static Future<void> updateWidget({
    required int streak,
    required String weight,
    required int calories,
  }) async {
    try {
      await HomeWidget.saveWidgetData<int>('streak', streak);
      await HomeWidget.saveWidgetData<String>('weight', weight);
      await HomeWidget.saveWidgetData<int>('calories', calories);

      await HomeWidget.updateWidget(
        androidName: androidWidgetName,
        iOSName: 'LifeTrackerWidget',
      );
    } catch (e) {
      print('Error updating widget: $e');
    }
  }

  /// Fetches all data and updates the widget
  static Future<void> refreshWidgetData(AppDatabase database) async {
    try {
      // Get streak data (longest current streak from habits)
      int maxStreak = 0;
      final habits = await database.getHabits();
      for (final habit in habits) {
        if (habit.streakCount > maxStreak) {
          maxStreak = habit.streakCount;
        }
      }

      // Get latest weight
      String weightStr = '--';
      final weights = await database.getWeightLogs(limit: 1);
      if (weights.isNotEmpty) {
        weightStr = weights.first.weightKg.toStringAsFixed(1);
      }

      // Get today's calories
      final today = DateTime.now();
      final foodEntries = await database.getFoodEntries(date: today);
      double totalCalories = 0;
      for (final entry in foodEntries) {
        totalCalories += entry.caloriesEstimated;
      }

      await updateWidget(
        streak: maxStreak,
        weight: weightStr,
        calories: totalCalories.toInt(),
      );
    } catch (e) {
      print('Error refreshing widget data: $e');
    }
  }
}
