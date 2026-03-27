import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:space_time_plan_app/home_page.dart';
import 'package:space_time_plan_app/providers/habit_provider.dart';
import 'package:space_time_plan_app/services/notification_service.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await initializeDateFormatting('zh_CN', null);
  
  // Initialize Notification Service
  final notificationService = NotificationService();
  await notificationService.init();
  await notificationService.requestPermissions();
  
  final habitProvider = HabitProvider();
  await habitProvider.loadData();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: habitProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '时间管理与习惯打卡',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        fontFamily: 'System', // Uses system font
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
