import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'models/car_state.dart';
import 'pages/login_page.dart';
import 'theme/app_theme.dart';
import 'widgets/floating_status_ball.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Default to portrait mode on startup
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CarState()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();
    return MaterialApp(
      title: 'RoboCar-A',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],
      theme: AppTheme.darkTheme,
      locale: state.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LoginPage(),
      builder: (context, child) {
        return Stack(
          children: [
            // ignore: use_null_aware_elements
            if (child != null) child,
            const GlobalFloatingBall(),
          ],
        );
      },
    );
  }
}

class GlobalFloatingBall extends StatefulWidget {
  const GlobalFloatingBall({super.key});

  @override
  State<GlobalFloatingBall> createState() => _GlobalFloatingBallState();
}

class _GlobalFloatingBallState extends State<GlobalFloatingBall> {

  @override
  Widget build(BuildContext context) {
    // Determine visibility based on navigator state
    final hasHistory = MyApp.navigatorKey.currentState?.canPop() ?? false;
    return hasHistory ? const FloatingStatusBall() : const SizedBox.shrink();
  }
}
