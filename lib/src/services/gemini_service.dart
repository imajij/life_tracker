import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class GeminiService {
  final Dio _dio = Dio();

  // Google Gemini API endpoints (use v1beta by default for model availability)
  static const String _baseUrlPrimary =
      'https://generativelanguage.googleapis.com/v1beta';
  static const String _baseUrlFallback =
      'https://generativelanguage.googleapis.com/v1';

  // Rate limiting: max calls per day (user-facing limit for free tier warning)
  static const int maxCallsPerDay = 15;
  static const String _dailyCountKey = 'ai_daily_call_count';
  static const String _dailyCountDateKey = 'ai_daily_call_date';

  // Models - use stable model names that work with v1beta
  static const String _visionModel = 'gemini-pro-vision';
  static const String _textModel = 'gemini-pro';

  GeminiService() {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
  }

  /// Reset the daily AI call counter (for debugging/testing)
  Future<void> resetDailyCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyCountKey, 0);
    final today = DateTime.now().toIso8601String().split('T')[0];
    await prefs.setString(_dailyCountDateKey, today);
  }

  /// Ensure daily AI counter is initialized (prevents false limit hit)
  Future<void> _ensureDailyCounterInitialized() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];

    final hasDate = prefs.containsKey(_dailyCountDateKey);
    final hasCount = prefs.containsKey(_dailyCountKey);

    if (!hasDate || !hasCount) {
      await prefs.setString(_dailyCountDateKey, today);
      await prefs.setInt(_dailyCountKey, 0);
      print('DEBUG GeminiService: Daily counter initialized');
      return;
    }

    final storedDate = prefs.getString(_dailyCountDateKey);
    if (storedDate != today) {
      await prefs.setString(_dailyCountDateKey, today);
      await prefs.setInt(_dailyCountKey, 0);
      print('DEBUG GeminiService: New day detected, counter reset');
    }
  }

  /// Get current count for debugging
  Future<int> getCurrentCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_dailyCountKey) ?? 0;
  }

  /// Check if daily AI call limit is reached
  Future<bool> isDailyLimitReached() async {
    await _ensureDailyCounterInitialized();

    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_dailyCountKey) ?? 0;

    return count >= maxCallsPerDay;
  }

  /// Get remaining AI calls for today
  Future<int> getRemainingCalls() async {
    await _ensureDailyCounterInitialized();

    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_dailyCountKey) ?? 0;

    return (maxCallsPerDay - count).clamp(0, maxCallsPerDay);
  }

  /// Increment the daily AI call counter
  Future<void> _incrementDailyCount() async {
    await _ensureDailyCounterInitialized();

    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_dailyCountKey) ?? 0;

    await prefs.setInt(_dailyCountKey, count + 1);
    print('DEBUG GeminiService: Daily count incremented to ${count + 1}');
  }

  /// Test if the API key is valid by making a simple text request
  Future<Map<String, dynamic>> testApiKey(String apiKey) async {
    try {
      print('DEBUG: Testing API key...');
      print('DEBUG: Using model: $_textModel');
      final path = '/models/$_textModel:generateContent';
      final response = await _postWithFallback(
        path: path,
        apiKey: apiKey,
        data: {
          'contents': [
            {
              'parts': [
                {'text': 'Say "Hello" in one word.'},
              ],
            },
          ],
          'generationConfig': {'maxOutputTokens': 10},
        },
      );

      print('DEBUG: API test response status: ${response.statusCode}');
      print('DEBUG: API test response: ${response.data}');

      final candidates = response.data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        return {'success': true, 'message': 'API key is valid'};
      }
      return {'success': false, 'error': 'Unexpected response format'};
    } on DioException catch (e) {
      print(
        'DEBUG: API test DioException: ${e.response?.statusCode} - ${e.response?.data}',
      );
      return {'success': false, 'error': _handleDioError(e)};
    } catch (e) {
      print('DEBUG: API test error: $e');
      return {'success': false, 'error': 'Test failed: $e'};
    }
  }

  /// Safely extract JSON from AI response text
  /// Handles markdown code blocks, extra text, and various formats
  String? _extractJsonFromText(String text) {
    if (text.isEmpty) return null;

    String cleaned = text.trim();

    // Try to find JSON in markdown code blocks first
    final jsonBlockRegex = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final blockMatch = jsonBlockRegex.firstMatch(cleaned);
    if (blockMatch != null) {
      cleaned = blockMatch.group(1)?.trim() ?? cleaned;
    }

    // Try to find JSON object pattern
    final jsonObjectRegex = RegExp(r'\{[\s\S]*\}');
    final objectMatch = jsonObjectRegex.firstMatch(cleaned);
    if (objectMatch != null) {
      return objectMatch.group(0);
    }

    // Try to find JSON array pattern
    final jsonArrayRegex = RegExp(r'\[[\s\S]*\]');
    final arrayMatch = jsonArrayRegex.firstMatch(cleaned);
    if (arrayMatch != null) {
      return arrayMatch.group(0);
    }

    return null;
  }

  /// Safely parse JSON with validation and defaults
  Map<String, dynamic>? _safeParseJson(
    String? jsonStr, {
    List<String>? requiredFields,
    Map<String, dynamic>? defaults,
  }) {
    if (jsonStr == null || jsonStr.isEmpty) return null;

    try {
      final decoded = json.decode(jsonStr);
      if (decoded is! Map<String, dynamic>) return null;

      final result = Map<String, dynamic>.from(decoded);

      // Apply defaults for missing fields
      if (defaults != null) {
        for (final entry in defaults.entries) {
          result[entry.key] ??= entry.value;
        }
      }

      // Check required fields
      if (requiredFields != null) {
        for (final field in requiredFields) {
          if (!result.containsKey(field) || result[field] == null) {
            return null;
          }
        }
      }

      return result;
    } catch (e) {
      return null;
    }
  }

  /// Parse food analysis response with validation
  Map<String, dynamic>? _parseFoodAnalysisResponse(String responseText) {
    final jsonStr = _extractJsonFromText(responseText);
    return _safeParseJson(
      jsonStr,
      requiredFields: ['calories'],
      defaults: {
        'protein_g': 0.0,
        'carbs_g': 0.0,
        'fat_g': 0.0,
        'serving_size_g': 100.0,
        'confidence': 0.7,
        'notes': 'AI estimation',
        'food_name': 'Unknown food',
      },
    );
  }

  /// Parse diet plan response with validation
  Map<String, dynamic>? _parseDietPlanResponse(String responseText) {
    final jsonStr = _extractJsonFromText(responseText);
    return _safeParseJson(
      jsonStr,
      requiredFields: ['daily_calorie_target', 'plan'],
      defaults: {
        'macros': {'protein_g': 0, 'carbs_g': 0, 'fat_g': 0},
        'notes': '',
      },
    );
  }

  /// Calculate SHA256 hash of a file
  Future<String> calculateFileHash(File file) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Compress image before sending to API (optimized for calorie scanning)
  Future<File> compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath = p.join(
      dir.path,
      '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg',
    );

    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70,
      minWidth: 512,
      minHeight: 512,
    );

    return compressedFile != null ? File(compressedFile.path) : file;
  }

  /// Analyze food image and return calorie/macro estimation
  Future<Map<String, dynamic>> analyzeFoodImage({
    required File imageFile,
    required String apiKey,
  }) async {
    await _ensureDailyCounterInitialized();
    print('DEBUG GeminiService: analyzeFoodImage called');

    // Check daily limit first
    if (await isDailyLimitReached()) {
      print('DEBUG GeminiService: Daily limit reached');
      return {
        'success': false,
        'error':
            'Daily AI limit reached ($maxCallsPerDay calls/day). Try manual entry or wait until tomorrow.',
        'limitReached': true,
      };
    }

    try {
      print('DEBUG GeminiService: Compressing image...');
      // Compress image first
      final compressedImage = await compressImage(imageFile);
      print('DEBUG GeminiService: Image compressed');

      // Convert image to base64
      final bytes = await compressedImage.readAsBytes();
      final base64Image = base64Encode(bytes);
      print(
        'DEBUG GeminiService: Image encoded to base64 (${base64Image.length} chars)',
      );
      print('DEBUG GeminiService: Using model: $_visionModel');
      print(
        'DEBUG GeminiService: Full path: /models/$_visionModel:generateContent',
      );
      print(
        'DEBUG GeminiService: API Key (first 10 chars): ${apiKey.substring(0, apiKey.length > 10 ? 10 : apiKey.length)}...',
      );

      // Prepare strict JSON prompt
      final prompt =
          '''You are a nutrition estimation system. Analyze the provided food image.
Return ONLY a valid JSON object and no extra text.

JSON schema:
{
  "food_name": string (name of the food item),
  "calories": number (estimated calories),
  "serving_size_g": number (estimated serving size in grams),
  "protein_g": number (protein in grams),
  "carbs_g": number (carbohydrates in grams),
  "fat_g": number (fat in grams),
  "confidence": number (0.0 to 1.0, how confident you are),
  "notes": string (brief description of the food and methodology)
}

If uncertain, estimate conservatively and reduce confidence.
Return ONLY the JSON object, no markdown, no explanation.''';

      // Make API call
      final response = await _postWithFallback(
        path: '/models/$_visionModel:generateContent',
        apiKey: apiKey,
        data: {
          'contents': [
            {
              'parts': [
                {'text': prompt},
                {
                  'inline_data': {
                    'mime_type': 'image/jpeg',
                    'data': base64Image,
                  },
                },
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.3,
            'topK': 32,
            'topP': 1,
            'maxOutputTokens': 1024,
          },
        },
      );

      print(
        'DEBUG GeminiService: API call successful, status: ${response.statusCode}',
      );

      // Increment daily counter on successful API call
      await _incrementDailyCount();

      // Parse response safely
      final candidates = response.data['candidates'] as List?;
      print('DEBUG GeminiService: Candidates: ${candidates?.length ?? 0}');

      if (candidates == null || candidates.isEmpty) {
        print('DEBUG GeminiService: No candidates in response');
        return {
          'success': false,
          'error': 'No response from AI. Please try manual entry.',
        };
      }

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        print('DEBUG GeminiService: No parts in response');
        return {
          'success': false,
          'error': 'Empty AI response. Please try manual entry.',
        };
      }

      final text = parts[0]['text'] as String? ?? '';
      print(
        'DEBUG GeminiService: Response text: ${text.length > 200 ? text.substring(0, 200) : text}...',
      );

      // Use robust JSON parsing
      final result = _parseFoodAnalysisResponse(text);
      print('DEBUG GeminiService: Parsed result: $result');

      if (result == null) {
        return {
          'success': false,
          'error': 'Could not parse AI response. Please try manual entry.',
          'rawResponse': text.length > 200
              ? '${text.substring(0, 200)}...'
              : text,
        };
      }

      return {'success': true, 'data': result};
    } on DioException catch (e) {
      print('DEBUG GeminiService: DioException: ${e.type}, ${e.message}');
      print('DEBUG GeminiService: Response: ${e.response?.data}');
      return {'success': false, 'error': _handleDioError(e)};
    } catch (e) {
      print('DEBUG GeminiService: Unexpected error: $e');
      return {'success': false, 'error': 'Unexpected error: ${e.toString()}'};
    }
  }

  /// Generate workout plan using Gemini
  Future<Map<String, dynamic>> generateWorkoutPlan({
    required String apiKey,
    required Map<String, dynamic> userProfile,
  }) async {
    try {
      final prompt =
          '''Based on the following user profile, create a 4-week workout plan.

User Profile:
- Age: ${userProfile['age']}
- Weight: ${userProfile['weight_kg']} kg
- Height: ${userProfile['height_cm']} cm
- Goal: ${userProfile['goal']} (lose/gain/maintain weight)
- Activity Level: ${userProfile['activity_level']}
- Available Days per Week: ${userProfile['available_days'] ?? 4}
- Equipment: ${userProfile['equipment']?.join(', ') ?? 'bodyweight, dumbbells'}

Return ONLY a valid JSON object with this schema:
{
  "goal": "lose|gain|maintain",
  "weeks": 4,
  "sessions_per_week": number,
  "plan": [
    {
      "week": 1,
      "days": [
        {
          "day_of_week": "Monday",
          "focus": "Upper body strength",
          "exercises": [
            {
              "name": "Push-ups",
              "sets": 3,
              "reps": "8-12",
              "rest_seconds": 60,
              "notes": "Keep core tight"
            }
          ]
        }
      ]
    }
  ],
  "notes": "General recommendations and safety tips"
}

Keep exercises safe for the user's fitness level. Include warm-up and cool-down recommendations.
Return ONLY the JSON object, no additional text.''';

      final response = await _postWithFallback(
        path: '/models/$_textModel:generateContent',
        apiKey: apiKey,
        data: {
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 4096,
          },
        },
      );

      // Parse response safely
      final candidates = response.data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        return {'success': false, 'error': 'No response from AI.'};
      }

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        return {'success': false, 'error': 'Empty AI response.'};
      }

      final text = parts[0]['text'] as String? ?? '';
      final jsonStr = _extractJsonFromText(text);
      final result = _safeParseJson(jsonStr, requiredFields: ['plan']);

      if (result == null) {
        return {
          'success': false,
          'error': 'Could not parse workout plan response.',
        };
      }

      return {'success': true, 'data': result};
    } on DioException catch (e) {
      return {'success': false, 'error': _handleDioError(e)};
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to generate workout plan. Please try again.',
      };
    }
  }

  /// Generate 7-day diet plan based on user profile
  Future<Map<String, dynamic>> generateDietPlan({
    required String apiKey,
    required Map<String, dynamic> userProfile,
  }) async {
    await _ensureDailyCounterInitialized();

    // Check daily limit first
    if (await isDailyLimitReached()) {
      return {
        'success': false,
        'error':
            'Daily AI limit reached ($maxCallsPerDay calls/day). Please try again tomorrow.',
        'limitReached': true,
      };
    }

    try {
      final prompt =
          '''You are a certified nutrition planner. Create a 7-day diet plan based on the user profile provided.
Return ONLY valid JSON and no extra text.

User Profile:
- Age: ${userProfile['age']} years
- Gender: ${userProfile['gender']}
- Height: ${userProfile['height_cm']} cm
- Weight: ${userProfile['weight_kg']} kg
- Goal: ${userProfile['goal']} (lose/gain/maintain weight)
- Activity Level: ${userProfile['activity_level']} (low/medium/high)
- Diet Type: ${userProfile['diet_type']} (veg/non-veg/mixed)
- Meals per Day: ${userProfile['meals_per_day']}

JSON schema:
{
  "daily_calorie_target": number,
  "macros": {
    "protein_g": number,
    "carbs_g": number,
    "fat_g": number
  },
  "plan": [
    {
      "day": "Monday",
      "meals": [
        {
          "meal": "Breakfast",
          "items": ["string item 1", "string item 2"],
          "calories": number
        }
      ]
    }
  ],
  "notes": "string with general recommendations"
}

Keep recommendations realistic, safe, and culturally appropriate.
Return ONLY the JSON object, no markdown, no explanation.''';

      final response = await _postWithFallback(
        path: '/models/$_textModel:generateContent',
        apiKey: apiKey,
        data: {
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.6,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 8192,
          },
        },
      );

      // Increment daily counter on successful API call
      await _incrementDailyCount();

      // Parse response safely
      final candidates = response.data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        return {
          'success': false,
          'error': 'No response from AI. Please try again.',
        };
      }

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        return {
          'success': false,
          'error': 'Empty AI response. Please try again.',
        };
      }

      final text = parts[0]['text'] as String? ?? '';
      final result = _parseDietPlanResponse(text);

      if (result == null) {
        return {
          'success': false,
          'error': 'Could not parse diet plan. Please try again.',
          'rawResponse': text.length > 200
              ? '${text.substring(0, 200)}...'
              : text,
        };
      }

      return {'success': true, 'data': result};
    } on DioException catch (e) {
      return {'success': false, 'error': _handleDioError(e)};
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to generate diet plan. Please try again.',
      };
    }
  }

  /// Get motivational quote from Gemini
  Future<Map<String, dynamic>> getMotivationalQuote({
    required String apiKey,
  }) async {
    try {
      final prompt =
          '''Generate a single motivational quote about health, fitness, productivity, or personal growth.

Return ONLY a valid JSON object with this schema:
{
  "text": "the quote text",
  "author": "author name or 'Unknown' if it's an original quote"
}

Return ONLY the JSON object, no additional text.''';

      final response = await _postWithFallback(
        path: '/models/$_textModel:generateContent',
        apiKey: apiKey,
        data: {
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.9,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 256,
          },
        },
      );

      // Parse response safely
      final candidates = response.data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        return {'success': false, 'error': 'No response from AI.'};
      }

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        return {'success': false, 'error': 'Empty AI response.'};
      }

      final text = parts[0]['text'] as String? ?? '';
      final jsonStr = _extractJsonFromText(text);
      final result = _safeParseJson(jsonStr, requiredFields: ['text']);

      if (result == null) {
        return {'success': false, 'error': 'Could not parse quote response.'};
      }

      return {'success': true, 'data': result};
    } on DioException catch (e) {
      return {'success': false, 'error': _handleDioError(e)};
    } catch (e) {
      return {'success': false, 'error': 'Failed to get quote.'};
    }
  }

  String _handleDioError(DioException e) {
    // Debug: Print full error details
    print('DEBUG DioError: ${e.type}');
    print('DEBUG Response status: ${e.response?.statusCode}');
    print('DEBUG Response data: ${e.response?.data}');
    print('DEBUG Error message: ${e.message}');

    if (e.response != null) {
      final statusCode = e.response!.statusCode;
      final responseBody = e.response?.data?.toString() ?? '';

      if (statusCode == 429) {
        // Check if it's a rate limit or quota issue
        if (responseBody.contains('RESOURCE_EXHAUSTED') ||
            responseBody.contains('quota')) {
          return 'Google API quota exhausted. The free tier has limited requests. Please wait 1-2 minutes and try again, or upgrade your API key at console.cloud.google.com';
        }
        return 'Too many requests. Please wait a minute and try again.';
      } else if (statusCode == 401) {
        return 'Invalid API key. Please check your Gemini API key in settings.';
      } else if (statusCode == 403) {
        return 'API access denied. Please verify your API key has Gemini API enabled.';
      } else if (statusCode == 404) {
        return 'API endpoint not found. Please verify your API key.';
      } else if (statusCode == 400) {
        if (responseBody.contains('API_KEY_INVALID')) {
          return 'Invalid API key format. Please check your Gemini API key.';
        }
        return 'Bad request. The image may be invalid or too large.';
      } else if (statusCode == 503) {
        return 'AI service temporarily unavailable. Please try again later.';
      }
      return 'API error ($statusCode). Please try again.';
    } else if (e.type == DioExceptionType.connectionTimeout) {
      return 'Connection timeout. Please check your internet connection.';
    } else if (e.type == DioExceptionType.receiveTimeout) {
      return 'Request timeout. Please try again.';
    } else if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection. Please check your network.';
    }
    return 'Network error. Please check your connection and try again.';
  }

  /// Post with automatic fallback: try v1 first (current), then v1beta on 404
  Future<Response<dynamic>> _postWithFallback({
    required String path,
    required String apiKey,
    required Map<String, dynamic> data,
  }) async {
    final headers = {'x-goog-api-key': apiKey};
    final redactedKey = apiKey.length > 6
        ? '${apiKey.substring(0, 3)}***${apiKey.substring(apiKey.length - 3)}'
        : '***';
    final urlPrimary = '$_baseUrlPrimary$path?key=$apiKey';
    try {
      print('DEBUG GeminiService: POST $urlPrimary (key: $redactedKey)');
      return await _dio.post(
        urlPrimary,
        data: data,
        options: Options(headers: headers),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        print('DEBUG GeminiService: 404 body on primary: ${e.response?.data}');
        final urlFallback = '$_baseUrlFallback$path?key=$apiKey';
        print(
          'DEBUG GeminiService: 404 on primary, retrying $urlFallback (key: $redactedKey)',
        );
        return await _dio.post(
          urlFallback,
          data: data,
          options: Options(headers: headers),
        );
      }
      rethrow;
    }
  }
}
