import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:drift/drift.dart' as drift;
import '../../db/database.dart';
import '../../providers/app_providers.dart';
import '../../utils/calorie_estimator.dart';

class AddFoodScreen extends ConsumerStatefulWidget {
  const AddFoodScreen({super.key});

  @override
  ConsumerState<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends ConsumerState<AddFoodScreen> {
  File? _selectedImage;
  bool _isProcessing = false;
  Map<String, dynamic>? _result;
  String? _error;

  final _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _result = null;
          _error = null;
        });
      }
    } catch (e) {
      setState(() => _error = 'Failed to pick image: $e');
    }
  }

  Future<void> _estimateCalories() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final geminiService = ref.read(geminiServiceProvider);
      final storage = ref.read(secureStorageProvider);
      final db = ref.read(databaseProvider);

      // Calculate hash
      final hash = await geminiService.calculateFileHash(_selectedImage!);

      // Check cache
      final cached = await db.getFoodEntryByHash(hash);
      if (cached != null) {
        setState(() {
          _result = {
            'calories': cached.caloriesEstimated,
            'protein_g': 0.0,
            'carbs_g': 0.0,
            'fat_g': 0.0,
            'confidence': cached.confidence,
            'notes': 'From cache: ${cached.notes ?? ""}',
            'source': 'cache',
          };
          _isProcessing = false;
        });
        return;
      }

      // Try Gemini API
      final apiKey = await storage.getGeminiApiKey();
      if (apiKey != null && apiKey.isNotEmpty) {
        try {
          final geminiResult = await geminiService.analyzeFoodImage(
            imageFile: _selectedImage!,
            apiKey: apiKey,
          );

          if (geminiResult['success'] == true) {
            final data = geminiResult['data'] as Map<String, dynamic>;
            setState(() {
              _result = {
                'calories': data['calories'],
                'protein_g': data['protein_g'],
                'carbs_g': data['carbs_g'],
                'fat_g': data['fat_g'],
                'serving_size_g': data['serving_size_g'],
                'confidence': data['confidence'],
                'notes': data['notes'],
                'source': 'gemini',
              };
              _isProcessing = false;
            });
            return; // Success, don't fall through to local estimate
          } else {
            // API returned error
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Gemini API error: ${geminiResult['error']}. Using local estimate.',
                  ),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        } catch (e) {
          // Gemini failed, fall back to local
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Gemini API failed: $e. Using local estimate.'),
              ),
            );
          }
        }
      }

      // Fallback to local estimate
      final localEstimate = CalorieEstimator.estimateFromImage();
      setState(() {
        _result = {
          'calories': localEstimate['calories'],
          'protein_g': localEstimate['protein_g'],
          'carbs_g': localEstimate['carbs_g'],
          'fat_g': localEstimate['fat_g'],
          'serving_size_g': localEstimate['serving_size_g'],
          'confidence': 0.5,
          'notes': 'Local heuristic estimate',
          'source': 'fallback',
        };
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Estimation failed: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _saveEntry() async {
    if (_result == null || _selectedImage == null) return;

    try {
      final db = ref.read(databaseProvider);
      final storage = ref.read(secureStorageProvider);
      final geminiService = ref.read(geminiServiceProvider);

      final userId = await storage.getUserId();
      if (userId == null) {
        throw Exception('No user ID found');
      }

      final hash = await geminiService.calculateFileHash(_selectedImage!);

      final macrosJson = {
        'protein_g': _result!['protein_g'] ?? 0.0,
        'carbs_g': _result!['carbs_g'] ?? 0.0,
        'fat_g': _result!['fat_g'] ?? 0.0,
        'serving_size_g': _result!['serving_size_g'] ?? 0.0,
      };

      await db.insertFoodEntry(
        FoodEntriesCompanion(
          userId: drift.Value(userId),
          photoPath: drift.Value(_selectedImage!.path),
          hash: drift.Value(hash),
          caloriesEstimated: drift.Value(_result!['calories'].toDouble()),
          macrosJson: drift.Value(macrosJson.toString()),
          source: drift.Value(_result!['source'] ?? 'unknown'),
          confidence: drift.Value(_result!['confidence']?.toDouble() ?? 0.5),
          notes: drift.Value(_result!['notes']),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Food entry saved!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Food')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selectedImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _selectedImage!,
                  height: 300,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_selectedImage == null) ...[
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.image, size: 64, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_selectedImage != null && _result == null)
              ElevatedButton(
                onPressed: _isProcessing ? null : _estimateCalories,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: _isProcessing
                    ? const CircularProgressIndicator()
                    : const Text('Estimate Calories'),
              ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estimation Result',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      Text(
                        '${_result!['calories'].toStringAsFixed(0)} kcal',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _MacroRow(
                        label: 'Protein',
                        value: _result!['protein_g']?.toStringAsFixed(1) ?? '0',
                      ),
                      _MacroRow(
                        label: 'Carbs',
                        value: _result!['carbs_g']?.toStringAsFixed(1) ?? '0',
                      ),
                      _MacroRow(
                        label: 'Fat',
                        value: _result!['fat_g']?.toStringAsFixed(1) ?? '0',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Confidence: ${((_result!['confidence'] ?? 0.5) * 100).toStringAsFixed(0)}%',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      if (_result!['notes'] != null)
                        Text(
                          _result!['notes'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      Text(
                        'Source: ${_result!['source']}',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveEntry,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save Entry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  final String label;
  final String value;

  const _MacroRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            '$value g',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
