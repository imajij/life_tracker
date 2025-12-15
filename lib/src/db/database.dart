import 'package:drift/drift.dart';
import 'connection/connection.dart';

part 'database.g.dart';

// User table
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get dob => dateTime()();
  TextColumn get gender => text()(); // 'male', 'female', 'other'
  IntColumn get heightCm => integer()();
  RealColumn get weightKg => real()();
  TextColumn get activityLevel =>
      text()(); // 'sedentary', 'light', 'moderate', 'very_active', 'extra_active'
  TextColumn get goal => text()(); // 'lose', 'gain', 'maintain'
  IntColumn get dailyWaterGoalMl =>
      integer().withDefault(const Constant(2500))();
  IntColumn get dailyCalorieGoal =>
      integer().withDefault(const Constant(2000))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// Food entry table
class FoodEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get photoPath => text().nullable()();
  TextColumn get hash => text().nullable()(); // SHA256 hash of image
  RealColumn get caloriesEstimated => real()();
  TextColumn get macrosJson =>
      text().nullable()(); // JSON: {protein_g, carbs_g, fat_g, serving_size_g}
  TextColumn get prompt => text().nullable()();
  TextColumn get source => text()(); // 'gemini', 'fallback', 'manual'
  RealColumn get confidence => real().withDefault(const Constant(1.0))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Workout plan table
class WorkoutPlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get goal => text()(); // 'lose', 'gain', 'maintain', 'endurance'
  TextColumn get planJson => text()(); // Full JSON plan from Gemini or manual
  TextColumn get source => text()(); // 'gemini', 'manual'
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Workout session table
class WorkoutSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId => integer().references(WorkoutPlans, #id)();
  DateTimeColumn get date => dateTime()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  IntColumn get durationMinutes => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Water log table
class WaterLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  IntColumn get amountMl => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Sleep log table
class SleepLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime()();
  RealColumn get durationHours => real()();
  TextColumn get quality =>
      text().nullable()(); // 'poor', 'fair', 'good', 'excellent'
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Study task table
class StudyTasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get title => text()();
  TextColumn get subject => text()();
  IntColumn get durationGoalMinutes => integer().nullable()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Habit table
class Habits extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get title => text()();
  TextColumn get periodicity => text()(); // 'daily', 'weekly'
  IntColumn get streakCount => integer().withDefault(const Constant(0))();
  IntColumn get bestStreak => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastDoneDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// Habit log table (to track daily completions)
class HabitLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get habitId => integer().references(Habits, #id)();
  DateTimeColumn get completedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

// Quote cache table
class QuoteCaches extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get quoteText => text()();
  TextColumn get author => text().nullable()();
  DateTimeColumn get fetchedAt => dateTime().withDefault(currentDateAndTime)();
}

// API call tracking for rate limiting
class ApiCallLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get endpoint =>
      text()(); // 'gemini_food', 'gemini_workout', 'gemini_quote'
  DateTimeColumn get calledAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get success => boolean()();
  TextColumn get errorMessage => text().nullable()();
}

@DriftDatabase(
  tables: [
    Users,
    FoodEntries,
    WorkoutPlans,
    WorkoutSessions,
    WaterLogs,
    SleepLogs,
    StudyTasks,
    Habits,
    HabitLogs,
    QuoteCaches,
    ApiCallLogs,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from == 1) {
        // Add new columns to users table
        await m.addColumn(users, users.dailyWaterGoalMl);
        await m.addColumn(users, users.dailyCalorieGoal);
      }
    },
  );

  // User queries
  Future<User?> getUser() => (select(users)..limit(1)).getSingleOrNull();
  Future<int> insertUser(UsersCompanion user) => into(users).insert(user);
  Future<bool> updateUser(User user) => update(users).replace(user);

  // Food entry queries
  Future<List<FoodEntry>> getFoodEntries({DateTime? date}) {
    final query = select(foodEntries);
    if (date != null) {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      query.where(
        (t) =>
            t.createdAt.isBiggerOrEqualValue(startOfDay) &
            t.createdAt.isSmallerThanValue(endOfDay),
      );
    }
    query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.get();
  }

  Future<FoodEntry?> getFoodEntryByHash(String hash) => (select(
    foodEntries,
  )..where((t) => t.hash.equals(hash))).getSingleOrNull();

  Future<int> insertFoodEntry(FoodEntriesCompanion entry) =>
      into(foodEntries).insert(entry);

  // Workout queries
  Future<List<WorkoutPlan>> getWorkoutPlans() => (select(
    workoutPlans,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

  Future<int> insertWorkoutPlan(WorkoutPlansCompanion plan) =>
      into(workoutPlans).insert(plan);

  Future<List<WorkoutSession>> getWorkoutSessions({int? planId}) {
    final query = select(workoutSessions);
    if (planId != null) {
      query.where((t) => t.planId.equals(planId));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.date)]);
    return query.get();
  }

  Future<int> insertWorkoutSession(WorkoutSessionsCompanion session) =>
      into(workoutSessions).insert(session);

  Future<bool> updateWorkoutSession(WorkoutSession session) =>
      update(workoutSessions).replace(session);

  // Water log queries
  Future<List<WaterLog>> getWaterLogs({DateTime? date}) {
    final query = select(waterLogs);
    if (date != null) {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      query.where(
        (t) =>
            t.createdAt.isBiggerOrEqualValue(startOfDay) &
            t.createdAt.isSmallerThanValue(endOfDay),
      );
    }
    query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.get();
  }

  Future<int> insertWaterLog(WaterLogsCompanion log) =>
      into(waterLogs).insert(log);

  // Sleep log queries
  Future<List<SleepLog>> getSleepLogs({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final query = select(sleepLogs);
    if (startDate != null) {
      query.where((t) => t.startTime.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where((t) => t.startTime.isSmallerThanValue(endDate));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.startTime)]);
    return query.get();
  }

  Future<int> insertSleepLog(SleepLogsCompanion log) =>
      into(sleepLogs).insert(log);

  // Study task queries
  Future<List<StudyTask>> getStudyTasks({bool? completed}) {
    final query = select(studyTasks);
    if (completed != null) {
      query.where((t) => t.completed.equals(completed));
    }
    query.orderBy([(t) => OrderingTerm.asc(t.dueDate)]);
    return query.get();
  }

  Future<int> insertStudyTask(StudyTasksCompanion task) =>
      into(studyTasks).insert(task);
  Future<bool> updateStudyTask(StudyTask task) =>
      update(studyTasks).replace(task);
  Future<int> deleteStudyTask(int id) =>
      (delete(studyTasks)..where((t) => t.id.equals(id))).go();

  // Habit queries
  Future<List<Habit>> getHabits() =>
      (select(habits)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();

  Future<int> insertHabit(HabitsCompanion habit) => into(habits).insert(habit);
  Future<bool> updateHabit(Habit habit) => update(habits).replace(habit);
  Future<int> deleteHabit(int id) =>
      (delete(habits)..where((t) => t.id.equals(id))).go();

  Future<int> insertHabitLog(HabitLogsCompanion log) =>
      into(habitLogs).insert(log);

  Future<List<HabitLog>> getHabitLogs(int habitId) =>
      (select(habitLogs)
            ..where((t) => t.habitId.equals(habitId))
            ..orderBy([(t) => OrderingTerm.desc(t.completedAt)]))
          .get();

  // Quote cache queries
  Future<QuoteCache?> getRandomQuote() async {
    final allQuotes = await select(quoteCaches).get();
    if (allQuotes.isEmpty) return null;
    allQuotes.shuffle();
    return allQuotes.first;
  }

  Future<int> insertQuote(QuoteCachesCompanion quote) =>
      into(quoteCaches).insert(quote);

  // API call log queries
  Future<int> getApiCallCount({
    required String endpoint,
    required DateTime since,
  }) async {
    final count =
        await (select(apiCallLogs)..where(
              (t) =>
                  t.endpoint.equals(endpoint) &
                  t.calledAt.isBiggerOrEqualValue(since),
            ))
            .get();
    return count.length;
  }

  Future<int> insertApiCallLog(ApiCallLogsCompanion log) =>
      into(apiCallLogs).insert(log);
}
