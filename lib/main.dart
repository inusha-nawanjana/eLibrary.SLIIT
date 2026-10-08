import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'library_state.dart';
import 'models.dart';
import 'ui/common.dart';
import 'ui/catalogue.dart';
import 'ui/reservations.dart';
import 'ui/personal.dart';
import 'ui/auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: orange,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const Bootstrap());
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  LibraryState? state;
  Object? error;
  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    setState(() => error = null);
    try {
      const url = String.fromEnvironment('SUPABASE_URL'),
          key = String.fromEnvironment('SUPABASE_ANON_KEY');
      if (url.isEmpty != key.isEmpty) {
        throw const LibraryException(
          'Set both SUPABASE_URL and SUPABASE_ANON_KEY, or leave both empty for demo mode.',
        );
      }
      SupabaseClient? client;
      if (url.isNotEmpty) {
        await Supabase.initialize(url: url, publishableKey: key);
        client = Supabase.instance.client;
      }
      final loaded = LibraryState(client: client);
      await loaded.initialize();
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (mounted) setState(() => state = loaded);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext c) {
    if (state != null) return LibraryApp(state: state!);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      builder: previewFrame,
      home: error == null
          ? const SplashScreen()
          : Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Brand(center: true),
                      const SizedBox(height: 32),
                      Text(
                        friendlyError(error!),
                        textAlign: TextAlign.center,
                        style: txt(14, color: muted),
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton('Retry', onTap: initialize),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Inter',
  scaffoldBackgroundColor: Colors.white,
  colorScheme: ColorScheme.fromSeed(
    seedColor: navy,
    primary: orange,
    secondary: navy,
    surface: Colors.white,
  ),
  textTheme: ThemeData.light().textTheme.apply(
    fontFamily: 'Inter',
    bodyColor: navy,
    displayColor: navy,
  ),
  dividerColor: line,
  splashFactory: InkRipple.splashFactory,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: navy,
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
);
Widget previewFrame(BuildContext c, Widget? child) {
  if (!previewChrome) return child ?? const SizedBox.shrink();
  return ColoredBox(
    color: surface,
    child: LayoutBuilder(
      builder: (c, s) {
        final w = math.min(390.0, s.maxWidth), h = math.min(844.0, s.maxHeight);
        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: MediaQuery(
              data: MediaQuery.of(c).copyWith(size: Size(w, h)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(s.maxWidth > 420 ? 32 : 0),
                child: child,
              ),
            ),
          ),
        );
      },
    ),
  );
}

class LibraryApp extends StatefulWidget {
  const LibraryApp({super.key, required this.state});
  final LibraryState state;
  @override
  State<LibraryApp> createState() => _LibraryAppState();
}

class _LibraryAppState extends State<LibraryApp> {
  final navigator = GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? auth;
  @override
  void initState() {
    super.initState();
    auth = widget.state.client?.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.passwordRecovery) {
        navigator.currentState?.push(
          MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    auth?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => LibraryScope(
    state: widget.state,
    child: MaterialApp(
      title: 'eLibrary.SLIIT',
      navigatorKey: navigator,
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      builder: previewFrame,
      home: const RootScreen(),
    ),
  );
}

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});
  @override
  Widget build(BuildContext c) {
    final state = LibraryScope.of(c);
    return switch (state.tab) {
      1 => const HomeScreen(key: ValueKey('ebooks'), ebooks: true),
      2 => const StudyScreen(),
      3 => state.signedIn ? const ActivityScreen() : const HomeScreen(),
      4 => state.signedIn ? const ProfileScreen() : const HomeScreen(),
      _ => const HomeScreen(key: ValueKey('home')),
    };
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
    body: SafeArea(
      top: !previewChrome,
      bottom: false,
      child: LayoutBuilder(
        builder: (c, s) => Stack(
          children: [
            Positioned(
              top: s.maxHeight * 22.7915 / 844,
              height: s.maxHeight * 798.4165 / 844,
              left: 0,
              right: 0,
              child: Art(asset('splash.png'), fit: BoxFit.fill),
            ),
            Positioned(
              left: 32,
              right: 32,
              top: s.maxHeight * 545 / 844,
              child: const Brand(size: 36, center: true),
            ),
            if (previewChrome)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: DeviceStatus(),
              ),
            if (previewChrome)
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: HomeIndicator(),
              ),
          ],
        ),
      ),
    ),
  );
}
