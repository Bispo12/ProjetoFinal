import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'global.dart';
import 'user_provider.dart';
import 'register_screen.dart';
import 'ForgotPasswordScreen.dart';
import 'Homescreen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Easy‑Localization precisa disto antes de runApp
  await EasyLocalization.ensureInitialized();

  // Firebase
  try {
    await Firebase.initializeApp();
    // ignore: avoid_print
    print('Firebase inicializado com sucesso');
  } catch (e) {
    // ignore: avoid_print
    print('Erro ao inicializar o Firebase: $e');
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('pt'), Locale('es'), Locale('en')],
      path: 'i18n',
      fallbackLocale: const Locale('pt'),
      child: ChangeNotifierProvider(
        create:
            (_) => UserProvider(
              nome: 'Amelinha',
              email: 'amelinha@exemplo.com',
              idioma: 'pt',
            ),
        child: const MyApp(),
      ),
    ),
  );
}

// ──────────────────────────────────────────────────────────────────────────────
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Litecs Login',
      theme: ThemeData(primarySwatch: Colors.green),
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _login() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Preencha todos os campos.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      // ignore: avoid_print
      print('FCM Token: $fcmToken');

      final response = await http.post(
        Uri.parse('$baseUrl/api/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _usernameController.text,
          'password': _passwordController.text,
          'fcm_token': fcmToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.containsKey('access')) {
          final String accessToken = data['access'];

          // Opcional: guardar token no provider
          try {
            context.read<UserProvider>().update(
              idioma: context.locale.languageCode,
            );
          } catch (_) {}

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => HomeScreen(accessToken: accessToken),
            ),
          );
        } else {
          _showError('Token de acesso não encontrado.');
        }
      } else {
        _showError('Falha no login: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Erro: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[100],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const CircleAvatar(
                radius: 50,
                backgroundImage: AssetImage('imagens/logo.jpg'),
              ),
              const SizedBox(height: 10),
              Text(
                'Litecs Login',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                    ),
                    child: const Text(
                      'Login',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
              const SizedBox(height: 15),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ForgotPasswordScreen()),
                  );
                },
                child: Text(
                  'Esqueceu-se da password?',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RegisterScreen()),
                  );
                },
                child: Text(
                  'Criar uma conta',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
