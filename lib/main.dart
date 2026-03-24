import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/main_home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState()..init(),
      child: const AttendMarkApp(),
    ),
  );
}

class AttendMarkApp extends StatelessWidget {
  const AttendMarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        if (!appState.isInitialized) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return MaterialApp(
          title: 'AttendMark',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: appState.themeMode,
          home: const RootScreenRouter(),
        );
      },
    );
  }
}

class RootScreenRouter extends StatefulWidget {
  const RootScreenRouter({super.key});

  @override
  State<RootScreenRouter> createState() => _RootScreenRouterState();
}

class _RootScreenRouterState extends State<RootScreenRouter> {
  late final Widget _initialScreen;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    if (appState.currentSession == null) {
      _initialScreen = const WelcomeScreen();
    } else {
      _initialScreen = const MainHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _initialScreen;
  }
}
