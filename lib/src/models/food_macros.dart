import 'dart:convert';

class FoodMacros {
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double servingSizeG;

  FoodMacros({
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.servingSizeG,
  });

  Map<String, dynamic> toJson() {
    return {
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'serving_size_g': servingSizeG,
    };
  }

  factory FoodMacros.fromJson(Map<String, dynamic> json) {
    return FoodMacros(
      proteinG: (json['protein_g'] as num).toDouble(),
      carbsG: (json['carbs_g'] as num).toDouble(),
      fatG: (json['fat_g'] as num).toDouble(),
      servingSizeG: (json['serving_size_g'] as num).toDouble(),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory FoodMacros.fromJsonString(String jsonString) {
    return FoodMacros.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }
}
