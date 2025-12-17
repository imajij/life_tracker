/// Model representing an exercise from the exercise library
class ExerciseItem {
  final int? id;
  final String name;
  final String category;
  final String muscleGroup;
  final String equipment;
  final String? description;
  final String? instructions;
  final bool isCustom;

  ExerciseItem({
    this.id,
    required this.name,
    required this.category,
    required this.muscleGroup,
    required this.equipment,
    this.description,
    this.instructions,
    this.isCustom = false,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'category': category,
      'muscle_group': muscleGroup,
      'equipment': equipment,
      if (description != null) 'description': description,
      if (instructions != null) 'instructions': instructions,
      'is_custom': isCustom,
    };
  }

  factory ExerciseItem.fromJson(Map<String, dynamic> json) {
    return ExerciseItem(
      id: json['id'] as int?,
      name: json['name'] as String,
      category: json['category'] as String,
      muscleGroup: json['muscle_group'] as String,
      equipment: json['equipment'] as String,
      description: json['description'] as String?,
      instructions: json['instructions'] as String?,
      isCustom: json['is_custom'] as bool? ?? false,
    );
  }

  /// Get icon for exercise category
  static String getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'chest':
        return '💪';
      case 'back':
        return '🔙';
      case 'shoulders':
        return '🎯';
      case 'arms':
        return '💪';
      case 'legs':
        return '🦵';
      case 'core':
        return '🎯';
      case 'cardio':
        return '❤️';
      default:
        return '🏋️';
    }
  }

  /// Get icon for equipment type
  static String getEquipmentIcon(String equipment) {
    switch (equipment.toLowerCase()) {
      case 'barbell':
        return '🏋️';
      case 'dumbbell':
        return '🏋️‍♂️';
      case 'machine':
        return '⚙️';
      case 'cable':
        return '🔗';
      case 'bodyweight':
        return '🧍';
      case 'kettlebell':
        return '🔔';
      case 'resistance band':
        return '➰';
      default:
        return '🏋️';
    }
  }
}

/// Categories for exercises
class ExerciseCategories {
  static const List<String> all = [
    'Chest',
    'Back',
    'Shoulders',
    'Arms',
    'Legs',
    'Core',
    'Cardio',
  ];
}

/// Equipment types
class EquipmentTypes {
  static const List<String> all = [
    'Barbell',
    'Dumbbell',
    'Machine',
    'Cable',
    'Bodyweight',
    'Kettlebell',
    'Resistance Band',
  ];
}
