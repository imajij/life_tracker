import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/screens/onboarding/onboarding_screen.dart';
import 'src/screens/home/home_screen.dart';
import 'src/providers/app_providers.dart';

// App gradient colors for dark theme
class AppGradients {
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6C63FF), Color(0xFF5A52D5)],
  );

  static const secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6584), Color(0xFFFF4E7A)],
  );

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1E), Color(0xFF121218)],
  );

  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF252538), Color(0xFF1E1E2E)],
  );

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4ECDC4), Color(0xFF3DBDB5)],
  );
}

void main() {
  runApp(const ProviderScope(child: LifeTrackerApp()));
}

class LifeTrackerApp extends StatelessWidget {
  const LifeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeTracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
          primary: const Color(0xFF6C63FF),
          secondary: const Color(0xFFFF6584),
          tertiary: const Color(0xFF4ECDC4),
          surface: const Color(0xFF1E1E2E),
          background: const Color(0xFF121218),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121218),
        cardTheme: CardThemeData(
          elevation: 8,
          shadowColor: Colors.black45,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: const Color(0xFF1E1E2E),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Color(0xFF1E1E2E),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 4,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A3E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
          titleLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  String _quote = 'Loading...';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Load motivational quote
    await _loadQuote();

    // Small delay to show splash
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Check if user exists
    final user = await ref.read(currentUserProvider.future);

    if (!mounted) return;

    if (user == null) {
      // No user, go to onboarding
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    } else {
      // User exists, go to home
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  Future<void> _loadQuote() async {
    try {
      final db = ref.read(databaseProvider);
      final cached = await db.getRandomQuote();

      if (cached != null) {
        setState(() {
          _quote = '${cached.quoteText}\n- ${cached.author ?? 'Unknown'}';
        });
        return;
      }

      // Try to fetch from Gemini if API key available
      final storage = ref.read(secureStorageProvider);
      final apiKey = await storage.getGeminiApiKey();

      if (apiKey != null && apiKey.isNotEmpty) {
        // TODO: Implement Gemini quote fetch
        // For now, use fallback
      }

      // Fallback quotes
      setState(() {
        _quote = _getFallbackQuote();
      });
    } catch (e) {
      setState(() {
        _quote = 'Your journey begins today!';
      });
    }
  }

  String _getFallbackQuote() {
    final quotes = [
      'The only way to do great work is to love what you do. - Steve Jobs',
      'Success is not final, failure is not fatal. - Winston Churchill',
      'Believe you can and you\'re halfway there. - Theodore Roosevelt',
      'The future depends on what you do today. - Mahatma Gandhi',
      'Every accomplishment starts with the decision to try. - Unknown',
      'Your health is an investment, not an expense. - Unknown',
      'Take care of your body. It\'s the only place you have to live. - Jim Rohn',
    ];
    quotes.shuffle();
    return quotes.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.backgroundGradient,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.fitness_center,
                  size: 100,
                  color: Colors.white,
                ),
                const SizedBox(height: 24),
                const Text(
                  'LifeTracker',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Track. Improve. Thrive.',
                  style: TextStyle(fontSize: 18, color: Colors.white70),
                ),
                const SizedBox(height: 48),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                const SizedBox(height: 48),
                Text(
                  _quote,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
