import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:drift/drift.dart' as drift;
import '../../db/database.dart';
import '../../providers/app_providers.dart';
import '../../utils/calorie_estimator.dart';

enum FoodEntryMode { aiScan, manual }

class AddFoodScreen extends ConsumerStatefulWidget {
  const AddFoodScreen({super.key});

  @override
  ConsumerState<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends ConsumerState<AddFoodScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // AI Scan state
  File? _selectedImage;
  bool _isProcessing = false;
  Map<String, dynamic>? _result;
  String? _error;
  int _remainingCalls = 5;

  // Manual entry state
  final _formKey = GlobalKey<FormState>();
  final _foodNameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _notesController = TextEditingController();

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRemainingCalls();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _foodNameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadRemainingCalls() async {
    final geminiService = ref.read(geminiServiceProvider);
    final remaining = await geminiService.getRemainingCalls();
    if (mounted) {
      setState(() => _remainingCalls = remaining);
    }
  }

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
        Map<String, dynamic>? macros;
        if (cached.macrosJson != null) {
          try {
            macros = jsonDecode(cached.macrosJson!) as Map<String, dynamic>?;
          } catch (_) {}
        }
        setState(() {
          _result = {
            'food_name': cached.notes ?? 'Cached food',
            'calories': cached.caloriesEstimated,
            'protein_g': macros?['protein_g'] ?? 0.0,
            'carbs_g': macros?['carbs_g'] ?? 0.0,
            'fat_g': macros?['fat_g'] ?? 0.0,
            'confidence': cached.confidence,
            'notes': 'Retrieved from cache',
            'source': 'cache',
          };
          _isProcessing = false;
        });
        return;
      }

      // Try Gemini API
      final apiKey = await storage.getGeminiApiKey();
      if (apiKey != null && apiKey.isNotEmpty) {
        final geminiResult = await geminiService.analyzeFoodImage(
          imageFile: _selectedImage!,
          apiKey: apiKey,
        );

        // Refresh remaining calls
        await _loadRemainingCalls();

        if (geminiResult['success'] == true) {
          final data = geminiResult['data'] as Map<String, dynamic>;
          setState(() {
            _result = {
              'food_name': data['food_name'] ?? 'Unknown food',
              'calories': data['calories'] ?? 0,
              'protein_g': data['protein_g'] ?? 0.0,
              'carbs_g': data['carbs_g'] ?? 0.0,
              'fat_g': data['fat_g'] ?? 0.0,
              'serving_size_g': data['serving_size_g'] ?? 100.0,
              'confidence': data['confidence'] ?? 0.7,
              'notes': data['notes'] ?? '',
              'source': 'gemini',
            };
            _isProcessing = false;
          });
          return;
        } else {
          // API returned error - show friendly message and offer manual entry
          final errorMsg = geminiResult['error'] as String? ?? 'Unknown error';
          final limitReached = geminiResult['limitReached'] == true;

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  limitReached
                      ? 'Daily AI limit reached. Try manual entry!'
                      : 'AI estimation failed. Using local estimate.',
                ),
                action: SnackBarAction(
                  label: 'Manual Entry',
                  onPressed: () => _tabController.animateTo(1),
                ),
                duration: const Duration(seconds: 4),
              ),
            );
          }

          if (limitReached) {
            setState(() {
              _error = errorMsg;
              _isProcessing = false;
            });
            return;
          }
        }
      }

      // Fallback to local estimate
      final localEstimate = CalorieEstimator.estimateFromImage();
      setState(() {
        _result = {
          'food_name': 'Estimated food',
          'calories': localEstimate['calories'],
          'protein_g': localEstimate['protein_g'],
          'carbs_g': localEstimate['carbs_g'],
          'fat_g': localEstimate['fat_g'],
          'serving_size_g': localEstimate['serving_size_g'],
          'confidence': 0.4,
          'notes': 'Local estimate - consider manual entry for accuracy',
          'source': 'fallback',
        };
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Estimation failed. Please try manual entry.';
        _isProcessing = false;
      });
    }
  }

  Future<void> _saveAIEntry() async {
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

      final macrosJson = jsonEncode({
        'protein_g': _result!['protein_g'] ?? 0.0,
        'carbs_g': _result!['carbs_g'] ?? 0.0,
        'fat_g': _result!['fat_g'] ?? 0.0,
        'serving_size_g': _result!['serving_size_g'] ?? 0.0,
      });

      await db.insertFoodEntry(
        FoodEntriesCompanion(
          userId: drift.Value(userId),
          photoPath: drift.Value(_selectedImage!.path),
          hash: drift.Value(hash),
          caloriesEstimated: drift.Value(
            (_result!['calories'] as num).toDouble(),
          ),
          macrosJson: drift.Value(macrosJson),
          source: drift.Value(_result!['source'] ?? 'unknown'),
          confidence: drift.Value(
            (_result!['confidence'] as num?)?.toDouble() ?? 0.5,
          ),
          notes: drift.Value(_result!['food_name'] ?? _result!['notes']),
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

  Future<void> _saveManualEntry() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final db = ref.read(databaseProvider);
      final storage = ref.read(secureStorageProvider);

      final userId = await storage.getUserId();
      if (userId == null) {
        throw Exception('No user ID found');
      }

      final macrosJson = jsonEncode({
        'protein_g': double.tryParse(_proteinController.text) ?? 0.0,
        'carbs_g': double.tryParse(_carbsController.text) ?? 0.0,
        'fat_g': double.tryParse(_fatController.text) ?? 0.0,
        'serving_size_g': 100.0,
      });

      await db.insertFoodEntry(
        FoodEntriesCompanion(
          userId: drift.Value(userId),
          photoPath: const drift.Value(null),
          hash: const drift.Value(null),
          caloriesEstimated: drift.Value(
            double.parse(_caloriesController.text),
          ),
          macrosJson: drift.Value(macrosJson),
          source: const drift.Value('manual'),
          confidence: const drift.Value(1.0),
          notes: drift.Value(
            _foodNameController.text +
                (_notesController.text.isNotEmpty
                    ? ' - ${_notesController.text}'
                    : ''),
          ),
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Food'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.camera_alt), text: 'AI Scan'),
            Tab(icon: Icon(Icons.edit), text: 'Manual Entry'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildAIScanTab(theme), _buildManualEntryTab(theme)],
      ),
    );
  }

  Widget _buildAIScanTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // AI calls remaining indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _remainingCalls > 2
                  ? Colors.green.withOpacity(0.1)
                  : _remainingCalls > 0
                  ? Colors.orange.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _remainingCalls > 0 ? Icons.auto_awesome : Icons.warning,
                  size: 18,
                  color: _remainingCalls > 2
                      ? Colors.green
                      : _remainingCalls > 0
                      ? Colors.orange
                      : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  _remainingCalls > 0
                      ? '$_remainingCalls AI scans remaining today'
                      : 'Daily limit reached - use manual entry',
                  style: TextStyle(
                    color: _remainingCalls > 2
                        ? Colors.green
                        : _remainingCalls > 0
                        ? Colors.orange
                        : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Image preview
          if (_selectedImage != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _selectedImage!,
                height: 250,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.restaurant,
                    size: 48,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Take or select a food photo',
                    style: TextStyle(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Camera/Gallery buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Estimate button
          if (_selectedImage != null && _result == null)
            ElevatedButton.icon(
              onPressed: _isProcessing || _remainingCalls <= 0
                  ? null
                  : _estimateCalories,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _isProcessing
                    ? 'Analyzing...'
                    : _remainingCalls <= 0
                    ? 'Limit Reached'
                    : 'Scan with AI',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),

          // Error display
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.edit),
              label: const Text('Try Manual Entry Instead'),
            ),
          ],

          // Result display
          if (_result != null) ...[
            const SizedBox(height: 20),
            _buildResultCard(theme),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _saveAIEntry,
              icon: const Icon(Icons.save),
              label: const Text('Save Entry'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard(ThemeData theme) {
    final confidence = (_result!['confidence'] as num?)?.toDouble() ?? 0.5;
    final confidenceColor = confidence >= 0.7
        ? Colors.green
        : confidence >= 0.4
        ? Colors.orange
        : Colors.red;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Estimation Result',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: confidenceColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 14, color: confidenceColor),
                      const SizedBox(width: 4),
                      Text(
                        '${(confidence * 100).toInt()}%',
                        style: TextStyle(
                          color: confidenceColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_result!['food_name'] != null) ...[
              const SizedBox(height: 4),
              Text(
                _result!['food_name'],
                style: TextStyle(
                  color: theme.colorScheme.outline,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const Divider(height: 24),
            Text(
              '${(_result!['calories'] as num).toStringAsFixed(0)} kcal',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MacroChip(
                    label: 'Protein',
                    value:
                        '${(_result!['protein_g'] as num?)?.toStringAsFixed(1) ?? '0'}g',
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MacroChip(
                    label: 'Carbs',
                    value:
                        '${(_result!['carbs_g'] as num?)?.toStringAsFixed(1) ?? '0'}g',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MacroChip(
                    label: 'Fat',
                    value:
                        '${(_result!['fat_g'] as num?)?.toStringAsFixed(1) ?? '0'}g',
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            if (_result!['notes'] != null &&
                (_result!['notes'] as String).isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _result!['notes'],
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.source, size: 14, color: theme.colorScheme.outline),
                const SizedBox(width: 4),
                Text(
                  'Source: ${_result!['source']}',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualEntryTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Manual entries work 100% offline',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Food name
            TextFormField(
              controller: _foodNameController,
              decoration: const InputDecoration(
                labelText: 'Food Name *',
                hintText: 'e.g., Grilled chicken breast',
                prefixIcon: Icon(Icons.restaurant_menu),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a food name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Calories
            TextFormField(
              controller: _caloriesController,
              decoration: const InputDecoration(
                labelText: 'Calories *',
                hintText: 'e.g., 250',
                prefixIcon: Icon(Icons.local_fire_department),
                suffixText: 'kcal',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter calories';
                }
                final calories = double.tryParse(value);
                if (calories == null || calories < 0) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Macros section
            Text(
              'Macronutrients (optional)',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _proteinController,
                    decoration: const InputDecoration(
                      labelText: 'Protein',
                      suffixText: 'g',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _carbsController,
                    decoration: const InputDecoration(
                      labelText: 'Carbs',
                      suffixText: 'g',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _fatController,
                    decoration: const InputDecoration(
                      labelText: 'Fat',
                      suffixText: 'g',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Any additional details...',
                prefixIcon: Icon(Icons.notes),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Save button
            ElevatedButton.icon(
              onPressed: _saveManualEntry,
              icon: const Icon(Icons.save),
              label: const Text('Save Food Entry'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }
}
