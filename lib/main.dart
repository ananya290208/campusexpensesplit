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

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    ChangeNotifierProvider(
      create: (context) => ExpenseProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to theme changes from ExpenseProvider
    final expenseProvider = Provider.of<ExpenseProvider>(context);

    return MaterialApp(
      title: 'Campus Expense Split',
      debugShowCheckedModeBanner: false,
      
      // Connect theme mode dynamically via ExpenseProvider
      themeMode: expenseProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      
      // Light Theme Definition
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.light,
        textTheme: GoogleFonts.notoSansTextTheme(ThemeData.light().textTheme),
        fontFamily: 'NotoSans',
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
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
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
  }
}