import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../../db/database.dart';
import '../../providers/app_providers.dart';
import 'add_food_screen.dart';
import 'food_picker_screen.dart';

// Meal type enum
enum MealType { breakfast, lunch, dinner, snacks }

extension MealTypeExtension on MealType {
  String get displayName {
    switch (this) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
      case MealType.snacks:
        return 'Snacks';
    }
  }

  IconData get icon {
    switch (this) {
      case MealType.breakfast:
        return Icons.wb_sunny_outlined;
      case MealType.lunch:
        return Icons.wb_cloudy_outlined;
      case MealType.dinner:
        return Icons.nightlight_outlined;
      case MealType.snacks:
        return Icons.cookie_outlined;
    }
  }

  Color get color {
    switch (this) {
      case MealType.breakfast:
        return Colors.orange;
      case MealType.lunch:
        return Colors.green;
      case MealType.dinner:
        return Colors.indigo;
      case MealType.snacks:
        return Colors.pink;
    }
  }

  // Time ranges for auto-categorization
  bool isInTimeRange(DateTime time) {
    final hour = time.hour;
    switch (this) {
      case MealType.breakfast:
        return hour >= 5 && hour < 11;
      case MealType.lunch:
        return hour >= 11 && hour < 15;
      case MealType.dinner:
        return hour >= 17 && hour < 22;
      case MealType.snacks:
        return (hour >= 15 && hour < 17) || (hour >= 22 || hour < 5);
    }
  }
}

// Provider for food entries by date
final foodEntriesByDateProvider =
    FutureProvider.family<List<FoodEntry>, DateTime>((ref, date) async {
      final db = ref.watch(databaseProvider);
      return await db.getFoodEntries(date: date);
    });

// Provider for food entries in date range (for history)
final foodHistoryProvider = FutureProvider.family<List<FoodEntry>, int>((
  ref,
  daysBack,
) async {
  final db = ref.watch(databaseProvider);
  final entries = <FoodEntry>[];
  for (int i = 0; i < daysBack; i++) {
    final date = DateTime.now().subtract(Duration(days: i));
    final dayEntries = await db.getFoodEntries(date: date);
    entries.addAll(dayEntries);
  }
  return entries;
});

class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});

  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    ref.invalidate(foodEntriesByDateProvider(_selectedDate));
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  MealType _getMealTypeForEntry(FoodEntry entry) {
    final hour = entry.createdAt.hour;
    if (hour >= 5 && hour < 11) return MealType.breakfast;
    if (hour >= 11 && hour < 15) return MealType.lunch;
    if (hour >= 17 && hour < 22) return MealType.dinner;
    return MealType.snacks;
  }

  Map<MealType, List<FoodEntry>> _groupEntriesByMeal(List<FoodEntry> entries) {
    final grouped = <MealType, List<FoodEntry>>{};
    for (final meal in MealType.values) {
      grouped[meal] = [];
    }
    for (final entry in entries) {
      final mealType = _getMealTypeForEntry(entry);
      grouped[mealType]!.add(entry);
    }
    return grouped;
  }

  double _calculateTotalCalories(List<FoodEntry> entries) {
    return entries.fold(0.0, (sum, e) => sum + e.caloriesEstimated);
  }

  Map<String, double> _calculateTotalMacros(List<FoodEntry> entries) {
    double protein = 0;
    double carbs = 0;
    double fat = 0;
    for (final entry in entries) {
      if (entry.macrosJson != null) {
        try {
          final macros = jsonDecode(entry.macrosJson!) as Map<String, dynamic>;
          protein += (macros['protein_g'] as num?)?.toDouble() ?? 0;
          carbs += (macros['carbs_g'] as num?)?.toDouble() ?? 0;
          fat += (macros['fat_g'] as num?)?.toDouble() ?? 0;
        } catch (_) {}
      }
    }
    return {'protein': protein, 'carbs': carbs, 'fat': fat};
  }

  void _showAddFoodOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Add Food',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _AddOptionTile(
              icon: Icons.camera_alt,
              title: 'AI Food Scan',
              subtitle: 'Take a photo to analyze',
              color: Colors.purple,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddFoodScreen()),
                ).then((_) => _refreshData());
              },
            ),
            const SizedBox(height: 12),
            _AddOptionTile(
              icon: Icons.restaurant_menu,
              title: 'Food Database',
              subtitle: 'Search from 1000+ foods',
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FoodPickerScreen()),
                ).then((_) => _refreshData());
              },
            ),
            const SizedBox(height: 12),
            _AddOptionTile(
              icon: Icons.edit_note,
              title: 'Quick Add',
              subtitle: 'Enter calories manually',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _showQuickAddDialog();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showQuickAddDialog() {
    final caloriesController = TextEditingController();
    final nameController = TextEditingController();
    MealType selectedMeal = _getCurrentMealType();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Quick Add Calories'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Food name (optional)',
                  hintText: 'e.g., Snack',
                  prefixIcon: Icon(Icons.fastfood),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: caloriesController,
                decoration: const InputDecoration(
                  labelText: 'Calories',
                  hintText: 'e.g., 200',
                  prefixIcon: Icon(Icons.local_fire_department),
                  suffixText: 'kcal',
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MealType>(
                value: selectedMeal,
                decoration: const InputDecoration(
                  labelText: 'Meal',
                  prefixIcon: Icon(Icons.schedule),
                ),
                items: MealType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Row(
                      children: [
                        Icon(type.icon, size: 20, color: type.color),
                        const SizedBox(width: 8),
                        Text(type.displayName),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedMeal = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final calories = double.tryParse(caloriesController.text);
                if (calories == null || calories <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter valid calories'),
                    ),
                  );
                  return;
                }
                await _quickAddCalories(
                  calories,
                  nameController.text.isEmpty
                      ? 'Quick add'
                      : nameController.text,
                  selectedMeal,
                );
                if (mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  MealType _getCurrentMealType() {
    final now = DateTime.now();
    for (final meal in MealType.values) {
      if (meal.isInTimeRange(now)) return meal;
    }
    return MealType.snacks;
  }

  Future<void> _quickAddCalories(
    double calories,
    String name,
    MealType mealType,
  ) async {
    final db = ref.read(databaseProvider);
    final user = await db.getUser();
    if (user == null) return;

    // Entry will use current time from database default

    await db.insertFoodEntry(
      FoodEntriesCompanion.insert(
        userId: user.id,
        caloriesEstimated: calories,
        source: 'quick_add',
        notes: drift.Value('$name (${mealType.displayName})'),
      ),
    );

    _refreshData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${calories.toInt()} kcal to ${mealType.displayName}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _refreshData() {
    ref.invalidate(foodEntriesByDateProvider(_selectedDate));
    ref.invalidate(todayFoodEntriesProvider);
    ref.invalidate(todayCaloriesProvider);
    ref.invalidate(foodHistoryProvider(30));
  }

  Future<void> _deleteEntry(FoodEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: Text('Delete "${entry.notes ?? "this food entry"}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      await (db.delete(
        db.foodEntries,
      )..where((t) => t.id.equals(entry.id))).go();
      _refreshData();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Entry deleted')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entriesAsync = ref.watch(foodEntriesByDateProvider(_selectedDate));
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      floatingActionButton: _buildFab(),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme, entriesAsync, userAsync),
            _buildTabBar(theme),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDailyTab(theme, userAsync, entriesAsync),
                  _buildHistoryTab(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: _showAddFoodOptions,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Add food'),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    AsyncValue<List<FoodEntry>> entriesAsync,
    AsyncValue<User?> userAsync,
  ) {
    final dateLabel = _isToday
        ? 'Today'
        : DateFormat('EEE, MMM d').format(_selectedDate);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.15),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nutrition',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track macros, calories, and history',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer.withOpacity(
                          0.75,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _showQuickAddDialog,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.onPrimaryContainer
                      .withOpacity(0.08),
                ),
                icon: Icon(
                  Icons.bolt,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                    ref.invalidate(foodEntriesByDateProvider(_selectedDate));
                  }
                },
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.onPrimaryContainer
                      .withOpacity(0.08),
                ),
                icon: Icon(
                  Icons.calendar_today_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _DatePill(
                onTap: () => _changeDate(-1),
                icon: Icons.chevron_left,
                enabled: true,
              ),
              Expanded(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      dateLabel,
                      key: ValueKey(dateLabel),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
              _DatePill(
                onTap: _isToday ? null : () => _changeDate(1),
                icon: Icons.chevron_right,
                enabled: !_isToday,
              ),
            ],
          ),
          const SizedBox(height: 14),
          entriesAsync.when(
            loading: () => const _HeaderSkeleton(),
            error: (e, _) => Text(
              'Error: $e',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            data: (entries) {
              final grouped = _groupEntriesByMeal(entries);
              final totalCalories = _calculateTotalCalories(entries);
              final totalMacros = _calculateTotalMacros(entries);
              final user = userAsync.valueOrNull;
              final calorieGoal = user?.dailyCalorieGoal ?? 2000;

              return _HeaderSummary(
                calorieGoal: calorieGoal,
                totalCalories: totalCalories,
                macros: totalMacros,
                entries: grouped,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        labelColor: theme.colorScheme.onSurface,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant.withOpacity(
          0.7,
        ),
        tabs: const [
          Tab(text: 'Today', icon: Icon(Icons.today_rounded)),
          Tab(text: 'History', icon: Icon(Icons.timeline_rounded)),
        ],
      ),
    );
  }

  Widget _buildDailyTab(
    ThemeData theme,
    AsyncValue<User?> userAsync,
    AsyncValue<List<FoodEntry>> entriesAsync,
  ) {
    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (entries) {
        final groupedEntries = _groupEntriesByMeal(entries);
        final totalCalories = _calculateTotalCalories(entries);
        final totalMacros = _calculateTotalMacros(entries);
        final user = userAsync.valueOrNull;
        final calorieGoal = user?.dailyCalorieGoal ?? 2000;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          children: [
            _QuickActions(
              onQuickAdd: _showQuickAddDialog,
              onAdd: _showAddFoodOptions,
            ),
            const SizedBox(height: 12),
            _MiniSummary(
              calorieGoal: calorieGoal,
              totalCalories: totalCalories,
              macros: totalMacros,
              theme: theme,
            ),
            const SizedBox(height: 8),
            ...MealType.values.map((mealType) {
              final mealEntries = groupedEntries[mealType] ?? [];
              return _buildMealSection(theme, mealType, mealEntries);
            }),
          ],
        );
      },
    );
  }

  Widget _buildMealSection(
    ThemeData theme,
    MealType mealType,
    List<FoodEntry> entries,
  ) {
    final mealCalories = _calculateTotalCalories(entries);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: entries.isNotEmpty,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: mealType.color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(mealType.icon, color: mealType.color),
          ),
          title: Text(
            mealType.displayName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            entries.isEmpty
                ? 'No entries'
                : '${entries.length} items • ${mealCalories.toInt()} kcal',
          ),
          trailing: mealCalories > 0
              ? Chip(
                  label: Text('${mealCalories.toInt()} kcal'),
                  backgroundColor: mealType.color.withOpacity(0.12),
                  labelStyle: TextStyle(
                    color: mealType.color,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : const Icon(Icons.expand_more),
          children: [
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Text(
                  'Tap Add to log ${mealType.displayName.toLowerCase()}',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            else
              ...entries.map((entry) => _buildFoodEntryTile(theme, entry)),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodEntryTile(ThemeData theme, FoodEntry entry) {
    Map<String, dynamic>? macros;
    if (entry.macrosJson != null) {
      try {
        macros = jsonDecode(entry.macrosJson!) as Map<String, dynamic>;
      } catch (_) {}
    }

    return Dismissible(
      key: Key('entry_${entry.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.red,
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await _deleteEntry(entry);
        return false;
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: _getSourceColor(entry.source).withOpacity(0.14),
          child: Icon(
            _getSourceIcon(entry.source),
            color: _getSourceColor(entry.source),
            size: 20,
          ),
        ),
        title: Text(
          entry.notes ?? 'Food entry',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: macros != null
            ? Text(
                'P ${(macros['protein_g'] as num?)?.toStringAsFixed(0) ?? 0}g • '
                'C ${(macros['carbs_g'] as num?)?.toStringAsFixed(0) ?? 0}g • '
                'F ${(macros['fat_g'] as num?)?.toStringAsFixed(0) ?? 0}g',
              )
            : Text(DateFormat('h:mm a').format(entry.createdAt)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${entry.caloriesEstimated.toInt()} kcal',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              entry.source,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getSourceIcon(String source) {
    switch (source) {
      case 'gemini':
        return Icons.auto_awesome;
      case 'manual':
        return Icons.restaurant_menu;
      case 'quick_add':
        return Icons.bolt;
      case 'cache':
        return Icons.cached;
      default:
        return Icons.fastfood;
    }
  }

  Color _getSourceColor(String source) {
    switch (source) {
      case 'gemini':
        return Colors.purple;
      case 'manual':
        return Colors.green;
      case 'quick_add':
        return Colors.orange;
      case 'cache':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildHistoryTab(ThemeData theme) {
    final historyAsync = ref.watch(foodHistoryProvider(30));

    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No food history yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start tracking your meals!',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        final groupedByDate = <String, List<FoodEntry>>{};
        for (final entry in entries) {
          final dateKey = DateFormat('yyyy-MM-dd').format(entry.createdAt);
          groupedByDate.putIfAbsent(dateKey, () => []).add(entry);
        }

        final sortedDates = groupedByDate.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          itemCount: sortedDates.length,
          itemBuilder: (context, index) {
            final dateKey = sortedDates[index];
            final dayEntries = groupedByDate[dateKey]!;
            final date = DateTime.parse(dateKey);
            final dayCalories = _calculateTotalCalories(dayEntries);
            final dayMacros = _calculateTotalMacros(dayEntries);

            return _HistoryDayCard(
              date: date,
              entries: dayEntries,
              totalCalories: dayCalories,
              macros: dayMacros,
              onTap: () {
                setState(() => _selectedDate = date);
                _tabController.animateTo(0);
              },
            );
          },
        );
      },
    );
  }
}

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: const [
            Expanded(child: _SkeletonBox(height: 80)),
            SizedBox(width: 12),
            Expanded(child: _SkeletonBox(height: 80)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: const [
            Expanded(child: _SkeletonBox(height: 12)),
            SizedBox(width: 8),
            _SkeletonBox(width: 60, height: 12),
          ],
        ),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double height;
  final double? width;

  const _SkeletonBox({this.height = 16, this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final bool enabled;

  const _DatePill({
    required this.onTap,
    required this.icon,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withOpacity(0.2)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _HeaderSummary extends StatelessWidget {
  final int calorieGoal;
  final double totalCalories;
  final Map<String, double> macros;
  final Map<MealType, List<FoodEntry>> entries;

  const _HeaderSummary({
    required this.calorieGoal,
    required this.totalCalories,
    required this.macros,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (totalCalories / calorieGoal).clamp(0.0, 1.0);
    final remaining = calorieGoal - totalCalories;

    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor: Colors.white.withOpacity(0.22),
                    valueColor: AlwaysStoppedAnimation(
                      progress > 1.0 ? Colors.red : Colors.white,
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        totalCalories.toInt().toString(),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'of $calorieGoal kcal',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    remaining >= 0
                        ? '${remaining.toInt()} kcal remaining'
                        : '${(-remaining).toInt()} kcal over',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MacroChip(
                        label: 'Protein',
                        value: macros['protein'],
                        color: Colors.red,
                      ),
                      _MacroChip(
                        label: 'Carbs',
                        value: macros['carbs'],
                        color: Colors.blue,
                      ),
                      _MacroChip(
                        label: 'Fat',
                        value: macros['fat'],
                        color: Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: MealType.values.map((meal) {
                      final hasEntries = (entries[meal]?.isNotEmpty ?? false);
                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 6,
                          decoration: BoxDecoration(
                            color: hasEntries
                                ? meal.color.withOpacity(0.9)
                                : Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onQuickAdd;
  final VoidCallback onAdd;

  const _QuickActions({required this.onQuickAdd, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onQuickAdd,
            icon: const Icon(Icons.bolt_rounded),
            label: const Text('Quick add'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Add food'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniSummary extends StatelessWidget {
  final int calorieGoal;
  final double totalCalories;
  final Map<String, double> macros;
  final ThemeData theme;

  const _MiniSummary({
    required this.calorieGoal,
    required this.totalCalories,
    required this.macros,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (calorieGoal - totalCalories).toInt();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${totalCalories.toInt()} kcal',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                remaining >= 0
                    ? '$remaining kcal left of $calorieGoal'
                    : '${remaining.abs()} kcal over',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const Spacer(),
          Wrap(
            spacing: 8,
            children: [
              _MacroChip(
                label: 'P',
                value: macros['protein'],
                color: Colors.red,
              ),
              _MacroChip(
                label: 'C',
                value: macros['carbs'],
                color: Colors.blue,
              ),
              _MacroChip(
                label: 'F',
                value: macros['fat'],
                color: Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final double? value;
  final Color color;

  const _MacroChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 4, backgroundColor: color),
          const SizedBox(width: 6),
          Text(
            '$label ${value?.toInt() ?? 0}g',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _AddOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AddOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade700),
      ),
    );
  }
}

class _HistoryDayCard extends StatelessWidget {
  final DateTime date;
  final List<FoodEntry> entries;
  final double totalCalories;
  final Map<String, double> macros;
  final VoidCallback onTap;

  const _HistoryDayCard({
    required this.date,
    required this.entries,
    required this.totalCalories,
    required this.macros,
    required this.onTap,
  });

  String get _dateLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final entryDate = DateTime(date.year, date.month, date.day);

    if (entryDate == today) return 'Today';
    if (entryDate == yesterday) return 'Yesterday';
    return DateFormat('EEEE, MMM d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _dateLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${totalCalories.toInt()} kcal',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _MacroChip(
                    label: 'P',
                    value: macros['protein'],
                    color: Colors.red,
                  ),
                  const SizedBox(width: 8),
                  _MacroChip(
                    label: 'C',
                    value: macros['carbs'],
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _MacroChip(
                    label: 'F',
                    value: macros['fat'],
                    color: Colors.orange,
                  ),
                  const Spacer(),
                  Text(
                    '${entries.length} items',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
