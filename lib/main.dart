import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_login.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const DairyGoCustomerApp());
}

class DairyGoCustomerApp extends StatelessWidget {
  const DairyGoCustomerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DairyGo Customer',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Poppins',
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
      scaffoldBackgroundColor: const Color(0xFFEEF3FA),
    ),
    home: const SplashScreen(),
  );
}
