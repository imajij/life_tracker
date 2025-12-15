import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class GeminiService {
  final Dio _dio = Dio();

  // Google Gemini API endpoint
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  // Rate limiting: max calls per day
  static const int maxCallsPerDay = 600;

  // Models
  static const String _visionModel = 'gemini-2.0-flash-exp';
  static const String _textModel = 'gemini-2.0-flash-exp';

  GeminiService() {
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  /// Calculate SHA256 hash of a file
  Future<String> calculateFileHash(File file) async {
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Compress image before sending to API
  Future<File> compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath = p.join(
      dir.path,
      '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg',
    );

    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 85,
      minWidth: 1024,
      minHeight: 1024,
    );

    return compressedFile != null ? File(compressedFile.path) : file;
  }

  /// Analyze food image and return calorie/macro estimation
  Future<Map<String, dynamic>> analyzeFoodImage({
    required File imageFile,
    required String apiKey,
  }) async {
    try {
      // Compress image first
      final compressedImage = await compressImage(imageFile);

      // Convert image to base64
      final bytes = await compressedImage.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Prepare prompt
      final prompt =
          '''Analyze this food image and return ONLY a valid JSON object with the following schema:
{
  "calories": number,
  "serving_size_g": number,
  "protein_g": number,
  "carbs_g": number,
  "fat_g": number,
  "confidence": number (0.0 to 1.0),
  "notes": "string describing the food items and estimation methodology"
}

Use conservative estimates when uncertain. Set confidence lower if the image quality is poor or food items are hard to identify.
Return ONLY the JSON object, no additional text.''';

      // Make API call
      final response = await _dio.post(
        '$_baseUrl/models/$_visionModel:generateContent?key=$apiKey',
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
            'temperature': 0.4,
            'topK': 32,
            'topP': 1,
            'maxOutputTokens': 2048,
          },
        },
      );

      // Parse response
      final text =
          response.data['candidates'][0]['content']['parts'][0]['text']
              as String;

      // Extract JSON from response (handle markdown code blocks)
      String jsonStr = text.trim();
      if (jsonStr.startsWith('```json')) {
        jsonStr = jsonStr.substring(7);
      } else if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.substring(3);
      }
      if (jsonStr.endsWith('```')) {
        jsonStr = jsonStr.substring(0, jsonStr.length - 3);
      }
      jsonStr = jsonStr.trim();

      final result = json.decode(jsonStr) as Map<String, dynamic>;

      return {'success': true, 'data': result};
    } on DioException catch (e) {
      return {'success': false, 'error': _handleDioError(e)};
    } catch (e) {
      return {'success': false, 'error': 'Failed to parse response: $e'};
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

      final response = await _dio.post(
        '$_baseUrl/models/$_textModel:generateContent?key=$apiKey',
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

      final text =
          response.data['candidates'][0]['content']['parts'][0]['text']
              as String;

      // Extract JSON
      String jsonStr = text.trim();
      if (jsonStr.startsWith('```json')) {
        jsonStr = jsonStr.substring(7);
      } else if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.substring(3);
      }
      if (jsonStr.endsWith('```')) {
        jsonStr = jsonStr.substring(0, jsonStr.length - 3);
      }
      jsonStr = jsonStr.trim();

      final result = json.decode(jsonStr) as Map<String, dynamic>;

      return {'success': true, 'data': result};
    } on DioException catch (e) {
      return {'success': false, 'error': _handleDioError(e)};
    } catch (e) {
      return {'success': false, 'error': 'Failed to generate workout plan: $e'};
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

      final response = await _dio.post(
        '$_baseUrl/models/$_textModel:generateContent?key=$apiKey',
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

      final text =
          response.data['candidates'][0]['content']['parts'][0]['text']
              as String;

      // Extract JSON
      String jsonStr = text.trim();
      if (jsonStr.startsWith('```json')) {
        jsonStr = jsonStr.substring(7);
      } else if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.substring(3);
      }
      if (jsonStr.endsWith('```')) {
        jsonStr = jsonStr.substring(0, jsonStr.length - 3);
      }
      jsonStr = jsonStr.trim();

      final result = json.decode(jsonStr) as Map<String, dynamic>;

      return {'success': true, 'data': result};
    } on DioException catch (e) {
      return {'success': false, 'error': _handleDioError(e)};
    } catch (e) {
      return {'success': false, 'error': 'Failed to get quote: $e'};
    }
  }

  String _handleDioError(DioException e) {
    if (e.response != null) {
      final statusCode = e.response!.statusCode;
      if (statusCode == 429) {
        return 'API quota exceeded. Free tier: 15 requests/minute, 1500/day. Please wait a few minutes or upgrade your API key at https://ai.google.dev/pricing';
      } else if (statusCode == 401) {
        return 'Invalid API key. Please check your Gemini API key in settings.';
      } else if (statusCode == 404) {
        return 'API endpoint not found. Please verify your API key is valid for Gemini 1.5 models.';
      } else if (statusCode == 400) {
        return 'Bad request. The image may be invalid or too large.';
      }
      return 'API error ($statusCode): ${e.response!.data}';
    } else if (e.type == DioExceptionType.connectionTimeout) {
      return 'Connection timeout. Please check your internet connection.';
    } else if (e.type == DioExceptionType.receiveTimeout) {
      return 'Request timeout. Please try again.';
    }
    return 'Network error: ${e.message}';
  }
}
