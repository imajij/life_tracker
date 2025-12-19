import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/screens/onboarding/onboarding_screen.dart';
import 'src/providers/app_providers.dart';
import 'src/services/widget_service.dart';
import 'src/screens/root/main_shell.dart';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WidgetService.initialize();
  runApp(const ProviderScope(child: LifeTrackerApp()));
}

class LifeTrackerApp extends StatelessWidget {
  const LifeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeTracker',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const SplashScreen(),
    );
  }

  ThemeData _buildTheme() {
    const seed = Color(0xFF7C6CF6);
    const surface = Color(0xFF151A24);
    const surfaceVariant = Color(0xFF1E2531);
    const background = Color(0xFF0F131A);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      primary: seed,
      secondary: const Color(0xFFFF6584),
      tertiary: const Color(0xFF4ECDC4),
      background: background,
      surface: surface,
      surfaceTint: seed,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        shadowColor: Colors.black.withOpacity(0.35),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface.withOpacity(0.96),
        indicatorColor: seed.withOpacity(0.16),
        height: 70,
        elevation: 12,
        labelTextStyle: MaterialStateProperty.resolveWith(
          (states) => TextStyle(
            fontWeight: states.contains(MaterialState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: seed.withOpacity(0.6), width: 1.8),
        ),
        labelStyle: const TextStyle(fontWeight: FontWeight.w500),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        tileColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      dividerTheme: DividerThemeData(color: Colors.white.withOpacity(0.08)),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceVariant,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontWeight: FontWeight.w800),
        headlineMedium: TextStyle(fontWeight: FontWeight.w800),
        titleLarge: TextStyle(fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(fontWeight: FontWeight.w500),
      ),
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
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
