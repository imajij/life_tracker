class CalorieEstimator {
  /// Provides a conservative fallback estimate for food calories
  /// This is a simple heuristic-based estimator when Gemini is unavailable
  static Map<String, dynamic> estimateFromImage({
    String? detectedFood,
    int? estimatedServingGrams,
  }) {
    // Default conservative estimates
    final servingSize = estimatedServingGrams ?? 250; // Default 250g

    // Simple heuristic: assume mixed meal
    // Average: 1.5 calories per gram (between high carb ~1.2 and high fat ~2.0)
    final calories = (servingSize * 1.5).round();

    // Conservative macro split (40% carbs, 30% protein, 30% fat)
    final carbCalories = calories * 0.4;
    final proteinCalories = calories * 0.3;
    final fatCalories = calories * 0.3;

    final carbsG = (carbCalories / 4).round(); // 4 cal per gram
    final proteinG = (proteinCalories / 4).round(); // 4 cal per gram
    final fatG = (fatCalories / 9).round(); // 9 cal per gram

    return {
      'calories': calories.toDouble(),
      'serving_size_g': servingSize.toDouble(),
      'protein_g': proteinG.toDouble(),
      'carbs_g': carbsG.toDouble(),
      'fat_g': fatG.toDouble(),
      'confidence': 0.3, // Low confidence for fallback
      'notes':
          'Estimated using local fallback. Actual values may vary significantly. Consider adding Gemini API key for accurate estimation.',
    };
  }

  /// Estimate calories for common food categories
  static Map<String, dynamic> estimateByCategory({
    required String category,
    required int servingGrams,
  }) {
    double caloriesPerGram;
    double proteinRatio;
    double carbsRatio;
    double fatRatio;

    switch (category.toLowerCase()) {
      case 'vegetables':
        caloriesPerGram = 0.3;
        proteinRatio = 0.15;
        carbsRatio = 0.70;
        fatRatio = 0.15;
        break;
      case 'fruits':
        caloriesPerGram = 0.5;
        proteinRatio = 0.05;
        carbsRatio = 0.90;
        fatRatio = 0.05;
        break;
      case 'grains':
      case 'rice':
      case 'pasta':
        caloriesPerGram = 1.3;
        proteinRatio = 0.15;
        carbsRatio = 0.75;
        fatRatio = 0.10;
        break;
      case 'meat':
      case 'chicken':
      case 'beef':
        caloriesPerGram = 1.8;
        proteinRatio = 0.50;
        carbsRatio = 0.05;
        fatRatio = 0.45;
        break;
      case 'fish':
        caloriesPerGram = 1.2;
        proteinRatio = 0.60;
        carbsRatio = 0.05;
        fatRatio = 0.35;
        break;
      case 'dairy':
        caloriesPerGram = 0.9;
        proteinRatio = 0.30;
        carbsRatio = 0.40;
        fatRatio = 0.30;
        break;
      case 'nuts':
        caloriesPerGram = 6.0;
        proteinRatio = 0.15;
        carbsRatio = 0.20;
        fatRatio = 0.65;
        break;
      case 'oils':
      case 'butter':
        caloriesPerGram = 9.0;
        proteinRatio = 0.0;
        carbsRatio = 0.0;
        fatRatio = 1.0;
        break;
      default: // mixed meal
        caloriesPerGram = 1.5;
        proteinRatio = 0.30;
        carbsRatio = 0.40;
        fatRatio = 0.30;
    }

    final totalCalories = (servingGrams * caloriesPerGram).round();
    final proteinCalories = totalCalories * proteinRatio;
    final carbsCalories = totalCalories * carbsRatio;
    final fatCalories = totalCalories * fatRatio;

    return {
      'calories': totalCalories.toDouble(),
      'serving_size_g': servingGrams.toDouble(),
      'protein_g': (proteinCalories / 4).round().toDouble(),
      'carbs_g': (carbsCalories / 4).round().toDouble(),
      'fat_g': (fatCalories / 9).round().toDouble(),
      'confidence': 0.5,
      'notes':
          'Estimated based on $category category. For accurate values, use Gemini API.',
    };
  }

  /// Calculate recommended daily calorie intake based on user profile
  static double calculateDailyCalories({
    required int age,
    required String gender, // 'male', 'female'
    required double weightKg,
    required int heightCm,
    required String
    activityLevel, // 'sedentary', 'light', 'moderate', 'very_active', 'extra_active'
    required String goal, // 'lose', 'gain', 'maintain'
  }) {
    // Calculate BMR using Mifflin-St Jeor Equation
    double bmr;
    if (gender.toLowerCase() == 'male') {
      bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
    } else {
      bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
    }

    // Apply activity multiplier
    double activityMultiplier;
    switch (activityLevel.toLowerCase()) {
      case 'sedentary':
        activityMultiplier = 1.2;
        break;
      case 'light':
        activityMultiplier = 1.375;
        break;
      case 'moderate':
        activityMultiplier = 1.55;
        break;
      case 'very_active':
        activityMultiplier = 1.725;
        break;
      case 'extra_active':
        activityMultiplier = 1.9;
        break;
      default:
        activityMultiplier = 1.2;
    }

    double tdee = bmr * activityMultiplier;

    // Adjust for goal
    switch (goal.toLowerCase()) {
      case 'lose':
        tdee -= 500; // 500 calorie deficit for ~0.5kg/week loss
        break;
      case 'gain':
        tdee += 300; // 300 calorie surplus for lean muscle gain
        break;
      case 'maintain':
        // No adjustment
        break;
    }

    return tdee;
  }

  /// Calculate BMI
  static double calculateBMI(double weightKg, int heightCm) {
    final heightM = heightCm / 100;
    return weightKg / (heightM * heightM);
  }

  /// Get BMI category
  static String getBMICategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }
}
