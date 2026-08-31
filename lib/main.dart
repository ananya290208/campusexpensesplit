import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/landing_screen.dart';
import 'provider.dart'; // Imports ExpenseProvider
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for offline-first caching
  await Hive.initFlutter();
  await Hive.openBox('expenses_cache');
  await Hive.openBox('pending_sync');
  final settingsBox = await Hive.openBox('settings_box');
  final bool savedDarkMode = settingsBox.get('isDarkMode', defaultValue: false);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    ChangeNotifierProvider(
      create: (context) => ExpenseProvider(initialDarkMode: savedDarkMode, settingsBox: settingsBox),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, expenseProvider, child) {
        return MaterialApp(
          title: 'Campus Expense Split',
          debugShowCheckedModeBanner: false,
          themeMode: expenseProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          
          // Light Theme Definition
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.light,
            ),
            textTheme: GoogleFonts.notoSansTextTheme(ThemeData.light().textTheme),
            fontFamily: 'NotoSans',
            cardTheme: const CardThemeData(
              elevation: 2,
            ),
            scrollbarTheme: ScrollbarThemeData(
              thumbColor: WidgetStateProperty.all(Colors.deepPurple.shade400),
              thickness: WidgetStateProperty.all(6.0),
              radius: const Radius.circular(8.0),
              thumbVisibility: WidgetStateProperty.all(true),
            ),
          ),

          // Dark Theme Definition
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardTheme: const CardThemeData(
              color: Color(0xFF1E1E1E),
              elevation: 2,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E1E1E),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF1E1E1E),
            ),
            bottomSheetTheme: const BottomSheetThemeData(
              backgroundColor: Color(0xFF1E1E1E),
            ),
            textTheme: GoogleFonts.notoSansTextTheme(ThemeData.dark().textTheme),
            fontFamily: 'NotoSans',
            scrollbarTheme: ScrollbarThemeData(
              thumbColor: WidgetStateProperty.all(Colors.deepPurple.shade300),
              thickness: WidgetStateProperty.all(6.0),
              radius: const Radius.circular(8.0),
              thumbVisibility: WidgetStateProperty.all(true),
            ),
          ),

          home: FirebaseAuth.instance.currentUser != null 
              ? const LandingScreen() 
              : const LoginScreen(),
        );
      },
    );
  }
}