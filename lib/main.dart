import 'package:flutter/material.dart';
// 1. Importamos las librerías de Firebase
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:login_bear_animation/screens/login_screen.dart';

// 2. Convertimos el main en asíncrono (async)
void main() async {
  // 3. Requisito obligatorio de Flutter antes de usar código nativo (Firebase)
  WidgetsFlutterBinding.ensureInitialized();

  // 4. Inicializar Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("🔥 Firebase inicializado correctamente");
  } catch (e) {
    print("❌ Error al inicializar Firebase: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        // Nota: Corregí un pequeño detalle aquí, le faltaba la palabra "ColorScheme" antes del .fromSeed
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const LoginScreen(),
    );
  }
}