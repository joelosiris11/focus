import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'auth_services.dart'; // Importa el archivo de servicios de autenticación
import 'pages/main_dashboard.dart'; // Importa el archivo de MainDashboard
import 'create_project_page.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyBrjDd6QXOkF_yfN_NQstx_sHyWQaq-Lbw',
        appId: '1:788312826114:android:2de0fa01efac1ccec0221b',
        messagingSenderId: '788312826114',
        projectId: 'focus-35f20',
        storageBucket: 'focus-35f20.appspot.com',
      ),
    );
  } else {
    await Firebase.initializeApp();
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        // Disable swipe gesture on PageRoute transitions
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.android: NoAnimationTransitionBuilder(),
            TargetPlatform.iOS: NoAnimationTransitionBuilder(),
          },
        ),
      ),
      // Disable iOS swipe back gesture
      home: WillPopScope(
        onWillPop: () async {
          // Return false to prevent the default back button behavior
          return false;
        },
        child: const SplashScreen(),
      ),
    );
  }
}

// Custom transition builder that disables swipe gestures
class NoAnimationTransitionBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // No animation, just return the child directly
    return child;
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    final authService = AuthService();
    
    // Esperar 1 segundo para mostrar el splash
    await Future.delayed(const Duration(seconds: 1));
    
    // Verificar si hay una sesión activa
    final currentUser = await authService.getCurrentUser();
    
    if (!mounted) return;

    if (currentUser != null) {
      // Usuario ya está autenticado, ir directamente a MainDashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const MainDashboard(),
          // Disable swipe to go back
          fullscreenDialog: true,
        ),
      );
    } else {
      // No hay sesión activa, ir a la página de login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
          // Disable swipe to go back
          fullscreenDialog: true,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Focus.',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'una app de ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                  Image.asset(
                    'assets/ltm.png',
                    height: 34,
                    width: 34,
                  ),
                  Text(
                    ' T-ecogroup',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return WillPopScope(
      onWillPop: () async {
        // Prevent back navigation
        return false;
      },
      child: Scaffold(
        body: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Focus.',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'una app de ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                      Image.asset(
                        'assets/ltm.png',
                        height: 34,
                        width: 34,
                      ),
                      Text(
                        ' T-ecogroup',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: SignInButton(
                  Buttons.Google,
                  onPressed: () async {
                    setState(() {
                      _isLoading = true;
                    });
                    print('Iniciando el proceso de inicio de sesión con Google...');
                    try {
                      final user = await authService.signInWithGoogle();
                      if (user != null) {
                        print('Inicio de sesión exitoso: ${user.email}');
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MainDashboard(),
                            // Disable swipe to go back
                            fullscreenDialog: true,
                          ),
                        );
                      } else {
                        print('No se pudo iniciar sesión, el usuario es nulo.');
                      }
                    } catch (e) {
                      print('Error durante el inicio de sesión: $e');
                    } finally {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Page'),
      ),
      body: const Center(
        child: Text('Bienvenido a la página de inicio'),
      ),
    );
  }
}
