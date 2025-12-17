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

// Habit completions by date (last 7 days) for consistency graph
final habitCompletionsByDateProvider = FutureProvider<Map<DateTime, int>>((
  ref,
) async {
  final db = ref.watch(databaseProvider);
  return await db.getHabitCompletionsByDate(days: 7);
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

// Weight logs provider
final weightLogsProvider = FutureProvider<List<WeightLog>>((ref) async {
  final db = ref.watch(databaseProvider);
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  return await db.getWeightLogs(userId: user.id);
});

// Latest weight provider
final latestWeightProvider = FutureProvider<WeightLog?>((ref) async {
  final db = ref.watch(databaseProvider);
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return null;
  return await db.getLatestWeightLog(user.id);
});

// Exercise library provider
final exerciseLibraryProvider = FutureProvider<List<ExerciseLibraryData>>((
  ref,
) async {
  final db = ref.watch(databaseProvider);
  return await db.getExercises();
});

// Exercise library by category provider
final exercisesByCategoryProvider =
    FutureProvider.family<List<ExerciseLibraryData>, String?>((
      ref,
      category,
    ) async {
      final db = ref.watch(databaseProvider);
      return await db.getExercises(category: category);
    });

// Manual exercise plans provider
final manualExercisePlansProvider = FutureProvider<List<ManualExercisePlan>>((
  ref,
) async {
  final db = ref.watch(databaseProvider);
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  return await db.getManualExercisePlans(userId: user.id);
});

// Active manual plan provider
final activeManualPlanProvider = FutureProvider<ManualExercisePlan?>((
  ref,
) async {
  final db = ref.watch(databaseProvider);
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return null;
  return await db.getActiveManualPlan(user.id);
});

// Food database provider
final foodDatabaseProvider = FutureProvider<List<FoodDatabaseData>>((
  ref,
) async {
  final db = ref.watch(databaseProvider);
  return await db.getFoods();
});

// Food by category provider
final foodsByCategoryProvider =
    FutureProvider.family<List<FoodDatabaseData>, String?>((
      ref,
      category,
    ) async {
      final db = ref.watch(databaseProvider);
      return await db.getFoods(category: category);
    });
