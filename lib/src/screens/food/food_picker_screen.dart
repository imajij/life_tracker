import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../db/database.dart';
import '../../providers/app_providers.dart';
import '../../models/food_item.dart';

class FoodPickerScreen extends ConsumerStatefulWidget {
  final Function(FoodDatabaseData food, double amount)? onFoodSelected;

  const FoodPickerScreen({super.key, this.onFoodSelected});

  @override
  ConsumerState<FoodPickerScreen> createState() => _FoodPickerScreenState();
}

class _FoodPickerScreenState extends ConsumerState<FoodPickerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedCategory;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeFoods();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeFoods() async {
    final db = ref.read(databaseProvider);
    final count = await db.getFoodCount();

    if (count == 0) {
      setState(() => _isLoading = true);
      await _loadFoodsFromJson();
      ref.invalidate(foodDatabaseProvider);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFoodsFromJson() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/food_database.json',
      );
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      final List<dynamic> foods = jsonData['foods'];

      final db = ref.read(databaseProvider);
      final foodCompanions = foods.map((f) {
        return FoodDatabaseCompanion.insert(
          name: f['name'] as String,
          category: f['category'] as String,
          servingUnit: f['serving_unit'] as String,
          servingSize: (f['serving_size'] as num).toDouble(),
          caloriesPer100g: (f['calories_per_100g'] as num).toDouble(),
          proteinPer100g: (f['protein_per_100g'] as num).toDouble(),
          carbsPer100g: (f['carbs_per_100g'] as num).toDouble(),
          fatPer100g: (f['fat_per_100g'] as num).toDouble(),
          fiberPer100g: drift.Value(
            (f['fiber_per_100g'] as num?)?.toDouble() ?? 0.0,
          ),
        );
      }).toList();

      await db.insertFoods(foodCompanions);
    } catch (e) {
      debugPrint('Error loading foods: $e');
    }
  }

  void _showFoodDetails(FoodDatabaseData food) {
    final amountController = TextEditingController(
      text: food.servingSize.toStringAsFixed(0),
    );
    double currentAmount = food.servingSize;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          double calcCalories = (food.caloriesPer100g * currentAmount) / 100;
          double calcProtein = (food.proteinPer100g * currentAmount) / 100;
          double calcCarbs = (food.carbsPer100g * currentAmount) / 100;
          double calcFat = (food.fatPer100g * currentAmount) / 100;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.green.shade100,
                        child: Text(
                          FoodItem.getCategoryIcon(food.category),
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              food.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              food.category,
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Amount Selector
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Amount',
                            suffixText: food.servingUnit,
                          ),
                          onChanged: (value) {
                            setModalState(() {
                              currentAmount =
                                  double.tryParse(value) ?? food.servingSize;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        children: [
                          Text(
                            '1 serving = ${food.servingSize.toStringAsFixed(0)} ${food.servingUnit}',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _quickAmountButton(
                                label: '½',
                                onTap: () {
                                  setModalState(() {
                                    currentAmount = food.servingSize / 2;
                                    amountController.text = currentAmount
                                        .toStringAsFixed(0);
                                  });
                                },
                              ),
                              _quickAmountButton(
                                label: '1x',
                                onTap: () {
                                  setModalState(() {
                                    currentAmount = food.servingSize;
                                    amountController.text = currentAmount
                                        .toStringAsFixed(0);
                                  });
                                },
                              ),
                              _quickAmountButton(
                                label: '2x',
                                onTap: () {
                                  setModalState(() {
                                    currentAmount = food.servingSize * 2;
                                    amountController.text = currentAmount
                                        .toStringAsFixed(0);
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Nutrition Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _nutritionRow(
                          'Calories',
                          '${calcCalories.toStringAsFixed(0)} kcal',
                          Colors.orange,
                        ),
                        const Divider(),
                        _nutritionRow(
                          'Protein',
                          '${calcProtein.toStringAsFixed(1)} g',
                          Colors.red,
                        ),
                        _nutritionRow(
                          'Carbs',
                          '${calcCarbs.toStringAsFixed(1)} g',
                          Colors.blue,
                        ),
                        _nutritionRow(
                          'Fat',
                          '${calcFat.toStringAsFixed(1)} g',
                          Colors.yellow,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Per 100g Info
                  Text(
                    'Per 100g: ${food.caloriesPer100g.toStringAsFixed(0)} kcal | '
                    'P: ${food.proteinPer100g.toStringAsFixed(1)}g | '
                    'C: ${food.carbsPer100g.toStringAsFixed(1)}g | '
                    'F: ${food.fatPer100g.toStringAsFixed(1)}g',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        if (widget.onFoodSelected != null) {
                          widget.onFoodSelected!(food, currentAmount);
                        } else {
                          _addFoodEntry(food, currentAmount);
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: Text(
                        'Add ${calcCalories.toStringAsFixed(0)} kcal',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _quickAmountButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade600),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }

  Widget _nutritionRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _addFoodEntry(FoodDatabaseData food, double amount) async {
    final db = ref.read(databaseProvider);
    final user = await db.getUser();
    if (user == null) return;

    final calories = (food.caloriesPer100g * amount) / 100;
    final macros = {
      'protein_g': (food.proteinPer100g * amount) / 100,
      'carbs_g': (food.carbsPer100g * amount) / 100,
      'fat_g': (food.fatPer100g * amount) / 100,
      'serving_size_g': amount,
    };

    await db.insertFoodEntry(
      FoodEntriesCompanion.insert(
        userId: user.id,
        caloriesEstimated: calories,
        macrosJson: drift.Value(jsonEncode(macros)),
        source: 'manual',
        notes: drift.Value(food.name),
      ),
    );

    ref.invalidate(todayFoodEntriesProvider);
    ref.invalidate(todayCaloriesProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${food.name} - ${calories.toStringAsFixed(0)} kcal',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _showAddCustomFood() {
    final nameController = TextEditingController();
    final caloriesController = TextEditingController();
    final proteinController = TextEditingController(text: '0');
    final carbsController = TextEditingController(text: '0');
    final fatController = TextEditingController(text: '0');
    final servingSizeController = TextEditingController(text: '100');
    String selectedCategory = 'Snacks';
    String selectedUnit = 'g';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Custom Food',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Food Name',
                    prefixIcon: Icon(Icons.fastfood),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: FoodCategories.all.map((cat) {
                    return DropdownMenuItem(value: cat, child: Text(cat));
                  }).toList(),
                  onChanged: (val) {
                    setModalState(() => selectedCategory = val!);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: servingSizeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Serving Size',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 100,
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedUnit,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: ['g', 'ml', 'piece', 'cup', 'tbsp'].map((u) {
                          return DropdownMenuItem(value: u, child: Text(u));
                        }).toList(),
                        onChanged: (val) {
                          setModalState(() => selectedUnit = val!);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Nutrition per 100g',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: caloriesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Calories (kcal)',
                    prefixIcon: Icon(Icons.local_fire_department),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: proteinController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Protein (g)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: carbsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Carbs (g)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: fatController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Fat (g)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (nameController.text.isEmpty ||
                          caloriesController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill required fields'),
                          ),
                        );
                        return;
                      }

                      final db = ref.read(databaseProvider);
                      await db.insertFood(
                        FoodDatabaseCompanion.insert(
                          name: nameController.text,
                          category: selectedCategory,
                          servingUnit: selectedUnit,
                          servingSize:
                              double.tryParse(servingSizeController.text) ??
                              100,
                          caloriesPer100g:
                              double.tryParse(caloriesController.text) ?? 0,
                          proteinPer100g:
                              double.tryParse(proteinController.text) ?? 0,
                          carbsPer100g:
                              double.tryParse(carbsController.text) ?? 0,
                          fatPer100g: double.tryParse(fatController.text) ?? 0,
                          isCustom: const drift.Value(true),
                        ),
                      );

                      ref.invalidate(foodDatabaseProvider);

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Food added to database!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Food'),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Database'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddCustomFood,
            tooltip: 'Add Custom Food',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.history), text: 'Recent'),
            Tab(icon: Icon(Icons.restaurant_menu), text: 'All Foods'),
            Tab(icon: Icon(Icons.star), text: 'Custom'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading food database...'),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRecentTab(),
                _buildAllFoodsTab(),
                _buildCustomFoodsTab(),
              ],
            ),
    );
  }

  Widget _buildRecentTab() {
    final recentEntriesAsync = ref.watch(recentFoodEntriesProvider);

    return recentEntriesAsync.when(
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
                const Text('No recent foods'),
                const SizedBox(height: 8),
                Text(
                  'Foods you log will appear here',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        // Group by food name and count frequency
        final foodCounts = <String, int>{};
        final foodEntries = <String, FoodEntry>{};
        for (final entry in entries) {
          final name = entry.notes ?? 'Unknown';
          foodCounts[name] = (foodCounts[name] ?? 0) + 1;
          foodEntries[name] = entry;
        }

        // Sort by frequency (most eaten first)
        final sortedFoods = foodCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Frequent section
            if (sortedFoods.length > 3) ...[
              const Text(
                'Frequent',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: sortedFoods.take(5).length,
                  itemBuilder: (context, index) {
                    final item = sortedFoods[index];
                    final entry = foodEntries[item.key]!;
                    return _FrequentFoodCard(
                      name: item.key,
                      count: item.value,
                      calories: entry.caloriesEstimated,
                      onTap: () => _addRecentEntry(entry),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Recent entries
            const Text(
              'Recent',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...entries
                .take(20)
                .map(
                  (entry) => _RecentEntryTile(
                    entry: entry,
                    onTap: () => _addRecentEntry(entry),
                  ),
                ),
          ],
        );
      },
    );
  }

  Future<void> _addRecentEntry(FoodEntry entry) async {
    final db = ref.read(databaseProvider);
    final user = await db.getUser();
    if (user == null) return;

    await db.insertFoodEntry(
      FoodEntriesCompanion.insert(
        userId: user.id,
        caloriesEstimated: entry.caloriesEstimated,
        macrosJson: drift.Value(entry.macrosJson),
        source: 'recent',
        notes: drift.Value(entry.notes),
      ),
    );

    ref.invalidate(todayFoodEntriesProvider);
    ref.invalidate(todayCaloriesProvider);
    ref.invalidate(recentFoodEntriesProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${entry.notes ?? "food"} - ${entry.caloriesEstimated.toInt()} kcal',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  Widget _buildAllFoodsTab() {
    final foodsAsync = _selectedCategory != null
        ? ref.watch(foodsByCategoryProvider(_selectedCategory))
        : ref.watch(foodDatabaseProvider);

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search foods...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value.toLowerCase());
            },
          ),
        ),

        // Category Filter
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: const Text('All'),
                  selected: _selectedCategory == null,
                  onSelected: (_) {
                    setState(() => _selectedCategory = null);
                  },
                ),
              ),
              ...FoodCategories.all.map((category) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(FoodItem.getCategoryIcon(category)),
                        const SizedBox(width: 4),
                        Text(category),
                      ],
                    ),
                    selected: _selectedCategory == category,
                    onSelected: (_) {
                      setState(() => _selectedCategory = category);
                    },
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Food List
        Expanded(
          child: foodsAsync.when(
            data: (foods) {
              // Filter by search
              final filteredFoods = foods.where((f) {
                if (_searchQuery.isEmpty) return true;
                return f.name.toLowerCase().contains(_searchQuery);
              }).toList();

              if (filteredFoods.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.fastfood,
                        size: 64,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(height: 16),
                      const Text('No foods found'),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _showAddCustomFood,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Custom Food'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredFoods.length,
                itemBuilder: (context, index) {
                  final food = filteredFoods[index];
                  return _FoodListTile(
                    food: food,
                    onTap: () => _showFoodDetails(food),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Error: $error')),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomFoodsTab() {
    final foodsAsync = ref.watch(foodDatabaseProvider);

    return foodsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (foods) {
        final customFoods = foods.where((f) => f.isCustom).toList();

        if (customFoods.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_border, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text('No custom foods yet'),
                const SizedBox(height: 8),
                Text(
                  'Create your own foods for quick access',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _showAddCustomFood,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Custom Food'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: customFoods.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ElevatedButton.icon(
                  onPressed: _showAddCustomFood,
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Custom Food'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              );
            }
            final food = customFoods[index - 1];
            return _FoodListTile(
              food: food,
              onTap: () => _showFoodDetails(food),
              onDelete: () => _deleteCustomFood(food),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteCustomFood(FoodDatabaseData food) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Custom Food'),
        content: Text('Delete "${food.name}"?'),
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
      await db.deleteFood(food.id);
      ref.invalidate(foodDatabaseProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Deleted ${food.name}')));
      }
    }
  }
}

// Helper Widgets

class _FrequentFoodCard extends StatelessWidget {
  final String name;
  final int count;
  final double calories;
  final VoidCallback onTap;

  const _FrequentFoodCard({
    required this.name,
    required this.count,
    required this.calories,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.repeat, size: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    '${count}x',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                '${calories.toInt()} kcal',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentEntryTile extends StatelessWidget {
  final FoodEntry entry;
  final VoidCallback onTap;

  const _RecentEntryTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: const Icon(Icons.restaurant, color: Colors.green),
        ),
        title: Text(
          entry.notes ?? 'Food entry',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          DateFormat('MMM d, h:mm a').format(entry.createdAt),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${entry.caloriesEstimated.toInt()} kcal',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Icon(Icons.add_circle, color: Colors.green, size: 20),
          ],
        ),
      ),
    );
  }
}

class _FoodListTile extends StatelessWidget {
  final FoodDatabaseData food;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _FoodListTile({required this.food, required this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        onLongPress: onDelete,
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: Text(
            FoodItem.getCategoryIcon(food.category),
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                food.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (food.isCustom)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Custom',
                  style: TextStyle(fontSize: 10, color: Colors.orange.shade900),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${food.caloriesPer100g.toStringAsFixed(0)} kcal/100g • '
          'P: ${food.proteinPer100g.toStringAsFixed(1)}g • '
          'C: ${food.carbsPer100g.toStringAsFixed(1)}g • '
          'F: ${food.fatPer100g.toStringAsFixed(1)}g',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        ),
        trailing: const Icon(Icons.add_circle, color: Colors.green),
      ),
    );
  }
}
