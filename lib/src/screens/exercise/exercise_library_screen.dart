import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'dart:convert';
import 'package:flutter/services.dart';
import '../../db/database.dart';
import '../../providers/app_providers.dart';
import '../../models/exercise_item.dart';

class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  final bool selectionMode;
  final Function(ExerciseLibraryData)? onExerciseSelected;

  const ExerciseLibraryScreen({
    super.key,
    this.selectionMode = false,
    this.onExerciseSelected,
  });

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  String? _selectedCategory;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeExercises();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeExercises() async {
    final db = ref.read(databaseProvider);
    final count = await db.getExerciseCount();

    if (count == 0) {
      setState(() => _isLoading = true);
      await _loadExercisesFromJson();
      ref.invalidate(exerciseLibraryProvider);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadExercisesFromJson() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/exercise_library.json',
      );
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      final List<dynamic> exercises = jsonData['exercises'];

      final db = ref.read(databaseProvider);
      final exerciseCompanions = exercises.map((e) {
        return ExerciseLibraryCompanion.insert(
          name: e['name'] as String,
          category: e['category'] as String,
          muscleGroup: e['muscle_group'] as String,
          equipment: e['equipment'] as String,
          description: drift.Value(e['description'] as String?),
          instructions: drift.Value(e['instructions'] as String?),
        );
      }).toList();

      await db.insertExercises(exerciseCompanions);
    } catch (e) {
      debugPrint('Error loading exercises: $e');
    }
  }

  void _showExerciseDetails(ExerciseLibraryData exercise) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    ExerciseItem.getCategoryIcon(exercise.category),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        exercise.category,
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoRow('Muscle Group', exercise.muscleGroup),
            _buildInfoRow('Equipment', exercise.equipment),
            if (exercise.description != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(exercise.description!),
            ],
            if (exercise.instructions != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Instructions',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(exercise.instructions!),
            ],
            const SizedBox(height: 24),
            if (widget.selectionMode)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onExerciseSelected?.call(exercise);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add to Plan'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  void _showAddCustomExercise() {
    final nameController = TextEditingController();
    final muscleGroupController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedCategory = 'Chest';
    String selectedEquipment = 'Bodyweight';

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
                  'Add Custom Exercise',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Exercise Name',
                    prefixIcon: Icon(Icons.fitness_center),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: ExerciseCategories.all.map((cat) {
                    return DropdownMenuItem(value: cat, child: Text(cat));
                  }).toList(),
                  onChanged: (val) {
                    setModalState(() => selectedCategory = val!);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: muscleGroupController,
                  decoration: const InputDecoration(
                    labelText: 'Primary Muscle Group',
                    prefixIcon: Icon(Icons.accessibility_new),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedEquipment,
                  decoration: const InputDecoration(
                    labelText: 'Equipment',
                    prefixIcon: Icon(Icons.build),
                  ),
                  items: EquipmentTypes.all.map((eq) {
                    return DropdownMenuItem(value: eq, child: Text(eq));
                  }).toList(),
                  onChanged: (val) {
                    setModalState(() => selectedEquipment = val!);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (nameController.text.isEmpty ||
                          muscleGroupController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill required fields'),
                          ),
                        );
                        return;
                      }

                      final db = ref.read(databaseProvider);
                      await db.insertExercise(
                        ExerciseLibraryCompanion.insert(
                          name: nameController.text,
                          category: selectedCategory,
                          muscleGroup: muscleGroupController.text,
                          equipment: selectedEquipment,
                          description: drift.Value(
                            descriptionController.text.isNotEmpty
                                ? descriptionController.text
                                : null,
                          ),
                          isCustom: const drift.Value(true),
                        ),
                      );

                      ref.invalidate(exerciseLibraryProvider);

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Exercise added!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Exercise'),
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
    final exercisesAsync = _selectedCategory != null
        ? ref.watch(exercisesByCategoryProvider(_selectedCategory))
        : ref.watch(exerciseLibraryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.selectionMode ? 'Select Exercise' : 'Exercise Library',
        ),
        actions: [
          if (!widget.selectionMode)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddCustomExercise,
              tooltip: 'Add Custom Exercise',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading exercise library...'),
                ],
              ),
            )
          : Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search exercises...',
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
                      ...ExerciseCategories.all.map((category) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(ExerciseItem.getCategoryIcon(category)),
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

                // Exercise List
                Expanded(
                  child: exercisesAsync.when(
                    data: (exercises) {
                      // Filter by search
                      final filteredExercises = exercises.where((e) {
                        if (_searchQuery.isEmpty) return true;
                        return e.name.toLowerCase().contains(_searchQuery) ||
                            e.muscleGroup.toLowerCase().contains(
                              _searchQuery,
                            ) ||
                            e.equipment.toLowerCase().contains(_searchQuery);
                      }).toList();

                      if (filteredExercises.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.fitness_center,
                                size: 64,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(height: 16),
                              const Text('No exercises found'),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredExercises.length,
                        itemBuilder: (context, index) {
                          final exercise = filteredExercises[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                child: Text(
                                  ExerciseItem.getCategoryIcon(
                                    exercise.category,
                                  ),
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      exercise.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (exercise.isCustom)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Custom',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.orange.shade900,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                '${exercise.muscleGroup} • ${exercise.equipment}',
                                style: TextStyle(color: Colors.grey.shade400),
                              ),
                              trailing: widget.selectionMode
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.add_circle,
                                        color: Colors.green,
                                      ),
                                      onPressed: () {
                                        widget.onExerciseSelected?.call(
                                          exercise,
                                        );
                                        Navigator.pop(context);
                                      },
                                    )
                                  : const Icon(Icons.chevron_right),
                              onTap: () => _showExerciseDetails(exercise),
                            ),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(child: Text('Error: $error')),
                  ),
                ),
              ],
            ),
    );
  }
}
