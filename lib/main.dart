
import 'package:becall2/add_questions.dart';
import 'package:becall2/admin_dashboard.dart';
import 'package:becall2/homepage.dart';
import 'package:becall2/login_page.dart';
import 'package:becall2/product_report_view.dart';
import 'package:becall2/survay_report.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Future<String?> _getStartPage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? role = prefs.getString('role');

    if (token != null && token.isNotEmpty) {
      // Check role and decide which dashboard to show
      if (role != null &&
          (role.toLowerCase() == 'admin' ||
              role.toLowerCase() == 'ceo' ||
              role.toLowerCase() == 'coo'|| role.toLowerCase() == 'asd')) {
        return 'admin';
      } else {
        return 'home';
      }
    } else {
      return 'login';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getStartPage(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Splash/loading screen
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final startPage = snapshot.data;

        Widget initialScreen;
        if (startPage == 'admin') {
          initialScreen = const AdminDashboard();
        } else if (startPage == 'home') {
          initialScreen = const Homepage();
        } else {
          initialScreen = const LoginPage();
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: initialScreen,
          routes: {
            '/login': (context) => const LoginPage(),
            '/dialer': (context) => const Homepage(),
            '/admin': (context) => const AdminDashboard(),
            '/add_questions': (context) => const AddQuestions(),
            '/survay_report': (context) => const SurveyReportPage(),
            '/product_report_view': (context) => const ProductReportView(),
          },
        );
      },
    );
  }
}
