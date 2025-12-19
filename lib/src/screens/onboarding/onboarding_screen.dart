import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../db/database.dart';
import '../../providers/app_providers.dart';
import '../root/main_shell.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  DateTime? _selectedDob;
  String _selectedGender = 'male';
  String _selectedActivityLevel = 'moderate';
  String _selectedGoal = 'maintain';

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDob = picked);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _selectedDob == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    final db = ref.read(databaseProvider);
    final storage = ref.read(secureStorageProvider);

    final userId = await db.insertUser(
      UsersCompanion(
        name: drift.Value(_nameController.text),
        dob: drift.Value(_selectedDob!),
        gender: drift.Value(_selectedGender),
        heightCm: drift.Value(int.parse(_heightController.text)),
        weightKg: drift.Value(double.parse(_weightController.text)),
        activityLevel: drift.Value(_selectedActivityLevel),
        goal: drift.Value(_selectedGoal),
      ),
    );

    await storage.saveUserId(userId);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ApiKeySetupScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to LifeTracker')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Let\'s set up your profile',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Date of Birth'),
              subtitle: Text(
                _selectedDob == null
                    ? 'Not selected'
                    : '${_selectedDob!.day}/${_selectedDob!.month}/${_selectedDob!.year}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectDate(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: Colors.grey.shade400),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedGender,
              decoration: const InputDecoration(
                labelText: 'Gender',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedGender = value);
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _heightController,
              decoration: const InputDecoration(
                labelText: 'Height (cm)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Required';
                if (int.tryParse(value!) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _weightController,
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Required';
                if (double.tryParse(value!) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedActivityLevel,
              decoration: const InputDecoration(
                labelText: 'Activity Level',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'sedentary', child: Text('Sedentary')),
                DropdownMenuItem(value: 'light', child: Text('Lightly Active')),
                DropdownMenuItem(
                  value: 'moderate',
                  child: Text('Moderately Active'),
                ),
                DropdownMenuItem(
                  value: 'very_active',
                  child: Text('Very Active'),
                ),
                DropdownMenuItem(
                  value: 'extra_active',
                  child: Text('Extra Active'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedActivityLevel = value);
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedGoal,
              decoration: const InputDecoration(
                labelText: 'Fitness Goal',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'lose', child: Text('Lose Weight')),
                DropdownMenuItem(
                  value: 'maintain',
                  child: Text('Maintain Weight'),
                ),
                DropdownMenuItem(value: 'gain', child: Text('Gain Weight')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedGoal = value);
                }
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

class ApiKeySetupScreen extends ConsumerStatefulWidget {
  const ApiKeySetupScreen({super.key});

  @override
  ConsumerState<ApiKeySetupScreen> createState() => _ApiKeySetupScreenState();
}

class _ApiKeySetupScreenState extends ConsumerState<ApiKeySetupScreen> {
  final _apiKeyController = TextEditingController();

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      // Skip API key setup
      _navigateToHome();
      return;
    }

    final storage = ref.read(secureStorageProvider);
    await storage.saveGeminiApiKey(key);

    _navigateToHome();
  }

  void _navigateToHome() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
  }

  void _showConsentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Notice'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'By providing your Gemini API key, you agree to the following:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '• Food images will be sent to Google Gemini API using YOUR API key',
              ),
              Text('• You are responsible for your API usage and costs'),
              Text('• Images are sent securely over HTTPS'),
              Text(
                '• LifeTracker does not store or access your images on any server',
              ),
              Text('• Your API key is stored securely on your device only'),
              Text('• You can delete your API key anytime from Settings'),
              SizedBox(height: 16),
              Text(
                'Your privacy is important. All data stays on your device.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API Key Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Gemini API Key (Optional)',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'To use AI-powered food calorie estimation and workout plan generation, provide your own Google Gemini API key. This uses YOUR free quota.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _showConsentDialog,
              child: const Text(
                'Read Privacy Notice →',
                style: TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'Gemini API Key',
                hintText: 'Paste your API key here',
                border: OutlineInputBorder(),
                helperText:
                    'Get your free key from https://makersuite.google.com/app/apikey',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveApiKey,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: Text(
                _apiKeyController.text.isEmpty
                    ? 'Skip for Now'
                    : 'Save and Continue',
              ),
            ),
            const SizedBox(height: 8),
            if (_apiKeyController.text.isEmpty)
              TextButton(
                onPressed: _navigateToHome,
                child: const Text('Skip and use local estimates'),
              ),
          ],
        ),
      ),
    );
  }
}
