import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database.dart';
import '../services/secure_storage_service.dart';
import '../services/gemini_service.dart';

// Database provider
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

// Secure storage provider
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

// Gemini service provider
final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

// Current user provider
final currentUserProvider = FutureProvider<User?>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getUser();
});

// Gemini API key provider
final geminiApiKeyProvider = FutureProvider<String?>((ref) async {
  final storage = ref.watch(secureStorageProvider);
  return await storage.getGeminiApiKey();
});

// Has API key provider
final hasApiKeyProvider = FutureProvider<bool>((ref) async {
  final storage = ref.watch(secureStorageProvider);
  return await storage.hasGeminiApiKey();
});

// AI remaining calls provider
final aiRemainingCallsProvider = FutureProvider<int>((ref) async {
  final geminiService = ref.watch(geminiServiceProvider);
  return await geminiService.getRemainingCalls();
});

// Food entries for today
final todayFoodEntriesProvider = FutureProvider<List<FoodEntry>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getFoodEntries(date: DateTime.now());
});

// Total calories for today
final todayCaloriesProvider = FutureProvider<double>((ref) async {
  final entries = await ref.watch(todayFoodEntriesProvider.future);
  return entries.fold<double>(
    0.0,
    (sum, entry) => sum + entry.caloriesEstimated,
  );
});

// Water logs for today
final todayWaterLogsProvider = FutureProvider<List<WaterLog>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getWaterLogs(date: DateTime.now());
});

// Total water intake for today (in ml)
final todayWaterIntakeProvider = FutureProvider<int>((ref) async {
  final logs = await ref.watch(todayWaterLogsProvider.future);
  return logs.fold<int>(0, (sum, log) => sum + log.amountMl);
});

// Habits provider
final habitsProvider = FutureProvider<List<Habit>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getHabits();
});

// Study tasks provider
final studyTasksProvider = FutureProvider<List<StudyTask>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getStudyTasks();
});

// Incomplete study tasks
final incompleteTasksProvider = FutureProvider<List<StudyTask>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getStudyTasks(completed: false);
});

// Workout plans provider
final workoutPlansProvider = FutureProvider<List<WorkoutPlan>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getWorkoutPlans();
});

// Sleep logs provider
final sleepLogsProvider = FutureProvider<List<SleepLog>>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final weekAgo = now.subtract(const Duration(days: 7));
  return await db.getSleepLogs(startDate: weekAgo, endDate: now);
});

// Diet plans provider
final dietPlansProvider = FutureProvider<List<DietPlan>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getDietPlans();
});

// Active diet plan provider
final activeDietPlanProvider = FutureProvider<DietPlan?>((ref) async {
  final db = ref.watch(databaseProvider);
  final storage = ref.watch(secureStorageProvider);
  final userId = await storage.getUserId();
  if (userId == null) return null;
  return await db.getActiveDietPlan(userId);
});
