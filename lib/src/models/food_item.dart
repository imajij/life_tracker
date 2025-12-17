/// Model representing a food item from the food database
class FoodItem {
  final int? id;
  final String name;
  final String category;
  final String servingUnit;
  final double servingSize;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double fiberPer100g;
  final bool isCustom;

  FoodItem({
    this.id,
    required this.name,
    required this.category,
    required this.servingUnit,
    required this.servingSize,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.fiberPer100g = 0.0,
    this.isCustom = false,
  });

  /// Calculate calories for a given amount in grams
  double caloriesForAmount(double grams) => (caloriesPer100g * grams) / 100;

  /// Calculate protein for a given amount in grams
  double proteinForAmount(double grams) => (proteinPer100g * grams) / 100;

  /// Calculate carbs for a given amount in grams
  double carbsForAmount(double grams) => (carbsPer100g * grams) / 100;

  /// Calculate fat for a given amount in grams
  double fatForAmount(double grams) => (fatPer100g * grams) / 100;

  /// Calculate fiber for a given amount in grams
  double fiberForAmount(double grams) => (fiberPer100g * grams) / 100;

  /// Get calories for one serving
  double get caloriesPerServing => caloriesForAmount(servingSize);

  /// Get protein for one serving
  double get proteinPerServing => proteinForAmount(servingSize);

  /// Get carbs for one serving
  double get carbsPerServing => carbsForAmount(servingSize);

  /// Get fat for one serving
  double get fatPerServing => fatForAmount(servingSize);

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'category': category,
      'serving_unit': servingUnit,
      'serving_size': servingSize,
      'calories_per_100g': caloriesPer100g,
      'protein_per_100g': proteinPer100g,
      'carbs_per_100g': carbsPer100g,
      'fat_per_100g': fatPer100g,
      'fiber_per_100g': fiberPer100g,
      'is_custom': isCustom,
    };
  }

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'] as int?,
      name: json['name'] as String,
      category: json['category'] as String,
      servingUnit: json['serving_unit'] as String,
      servingSize: (json['serving_size'] as num).toDouble(),
      caloriesPer100g: (json['calories_per_100g'] as num).toDouble(),
      proteinPer100g: (json['protein_per_100g'] as num).toDouble(),
      carbsPer100g: (json['carbs_per_100g'] as num).toDouble(),
      fatPer100g: (json['fat_per_100g'] as num).toDouble(),
      fiberPer100g: (json['fiber_per_100g'] as num?)?.toDouble() ?? 0.0,
      isCustom: json['is_custom'] as bool? ?? false,
    );
  }

  /// Get icon for food category
  static String getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'grains':
        return '🌾';
      case 'proteins':
        return '🥩';
      case 'dairy':
        return '🥛';
      case 'fruits':
        return '🍎';
      case 'vegetables':
        return '🥬';
      case 'snacks':
        return '🍿';
      case 'beverages':
        return '🥤';
      case 'indian':
        return '🍛';
      case 'fast food':
        return '🍔';
      case 'desserts':
        return '🍰';
      case 'nuts & seeds':
        return '🥜';
      case 'oils & fats':
        return '🫒';
      default:
        return '🍽️';
    }
  }
}

/// Categories for food items
class FoodCategories {
  static const List<String> all = [
    'Grains',
    'Proteins',
    'Dairy',
    'Fruits',
    'Vegetables',
    'Snacks',
    'Beverages',
    'Indian',
    'Fast Food',
    'Desserts',
    'Nuts & Seeds',
    'Oils & Fats',
  ];
}
