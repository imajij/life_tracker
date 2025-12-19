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
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.today), text: 'Today'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildDailyTab(theme, userAsync), _buildHistoryTab(theme)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddFoodOptions,
        icon: const Icon(Icons.add),
        label: const Text('Add Food'),
      ),
    );
  }

  Widget _buildDailyTab(ThemeData theme, AsyncValue<User?> userAsync) {
    final entriesAsync = ref.watch(foodEntriesByDateProvider(_selectedDate));

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (entries) {
        final groupedEntries = _groupEntriesByMeal(entries);
        final totalCalories = _calculateTotalCalories(entries);
        final totalMacros = _calculateTotalMacros(entries);
        final user = userAsync.valueOrNull;
        final calorieGoal = user?.dailyCalorieGoal ?? 2000;

        return CustomScrollView(
          slivers: [
            // Date selector
            SliverToBoxAdapter(child: _buildDateSelector(theme)),

            // Daily summary card
            SliverToBoxAdapter(
              child: _buildSummaryCard(
                theme,
                totalCalories,
                calorieGoal,
                totalMacros,
              ),
            ),

            // Meal sections
            ...MealType.values.map((mealType) {
              final mealEntries = groupedEntries[mealType] ?? [];
              return SliverToBoxAdapter(
                child: _buildMealSection(theme, mealType, mealEntries),
              );
            }),

            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }

  Widget _buildDateSelector(ThemeData theme) {
    final dateFormat = DateFormat('EEE, MMM d');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => _changeDate(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          GestureDetector(
            onTap: () async {
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isToday ? 'Today' : dateFormat.format(_selectedDate),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: _isToday ? null : () => _changeDate(1),
            icon: Icon(
              Icons.chevron_right,
              color: _isToday ? Colors.grey : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    ThemeData theme,
    double totalCalories,
    int calorieGoal,
    Map<String, double> macros,
  ) {
    final progress = (totalCalories / calorieGoal).clamp(0.0, 1.0);
    final remaining = calorieGoal - totalCalories;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Calorie ring
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 12,
                    backgroundColor: theme.colorScheme.surface.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation(
                      progress > 1.0 ? Colors.red : theme.colorScheme.primary,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      totalCalories.toInt().toString(),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      'of $calorieGoal kcal',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onPrimaryContainer.withOpacity(
                          0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            remaining >= 0
                ? '${remaining.toInt()} kcal remaining'
                : '${(-remaining).toInt()} kcal over',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: remaining >= 0 ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(height: 20),

          // Macro bars
          Row(
            children: [
              Expanded(
                child: _MacroProgress(
                  label: 'Protein',
                  value: macros['protein'] ?? 0,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MacroProgress(
                  label: 'Carbs',
                  value: macros['carbs'] ?? 0,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MacroProgress(
                  label: 'Fat',
                  value: macros['fat'] ?? 0,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealSection(
    ThemeData theme,
    MealType mealType,
    List<FoodEntry> entries,
  ) {
    final mealCalories = _calculateTotalCalories(entries);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: entries.isNotEmpty,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: mealType.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(mealType.icon, color: mealType.color),
          ),
          title: Text(
            mealType.displayName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            entries.isEmpty
                ? 'No entries'
                : '${entries.length} item${entries.length == 1 ? '' : 's'} • ${mealCalories.toInt()} kcal',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (mealCalories > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: mealType.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${mealCalories.toInt()}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: mealType.color,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.expand_more),
            ],
          ),
          children: [
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Tap + to add ${mealType.displayName.toLowerCase()}',
                  style: TextStyle(color: Colors.grey.shade500),
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
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await _deleteEntry(entry);
        return false;
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: _getSourceColor(entry.source).withOpacity(0.1),
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
        ),
        subtitle: macros != null
            ? Text(
                'P: ${(macros['protein_g'] as num?)?.toStringAsFixed(0) ?? 0}g • '
                'C: ${(macros['carbs_g'] as num?)?.toStringAsFixed(0) ?? 0}g • '
                'F: ${(macros['fat_g'] as num?)?.toStringAsFixed(0) ?? 0}g',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              )
            : Text(
                DateFormat('h:mm a').format(entry.createdAt),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
        trailing: Text(
          '${entry.caloriesEstimated.toInt()} kcal',
          style: const TextStyle(fontWeight: FontWeight.bold),
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

        // Group entries by date
        final groupedByDate = <String, List<FoodEntry>>{};
        for (final entry in entries) {
          final dateKey = DateFormat('yyyy-MM-dd').format(entry.createdAt);
          groupedByDate.putIfAbsent(dateKey, () => []).add(entry);
        }

        final sortedDates = groupedByDate.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
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

class _MacroProgress extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MacroProgress({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${value.toInt()}g',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(
              context,
            ).colorScheme.onPrimaryContainer.withOpacity(0.7),
          ),
        ),
      ],
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
                    value: macros['protein']?.toInt() ?? 0,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 8),
                  _MacroChip(
                    label: 'C',
                    value: macros['carbs']?.toInt() ?? 0,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _MacroChip(
                    label: 'F',
                    value: macros['fat']?.toInt() ?? 0,
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

class _MacroChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MacroChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: ${value}g',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
