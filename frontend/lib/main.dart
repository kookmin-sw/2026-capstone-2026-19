// ============================================================
// lib/main.dart
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/tabs/home_tab.dart';
import 'screens/tabs/matching_tab.dart';
import 'screens/tabs/active_tab.dart';
import 'screens/tabs/message_tab.dart';
import 'screens/tabs/myPage_tab.dart';
import 'utils/colors.dart';
import 'utils/routes.dart';
import 'service/notification_service.dart';
import 'service/auth_session.dart';
import 'service/notification_service.dart';

void main() async {
  // 1. Flutter 엔진 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 서비스 초기화
  await NotificationService.init();
  await AuthSession.load();

  // 3. 카카오맵 SDK 초기화 (웹에서는 제외)
  if (!kIsWeb) {
    AuthRepository.initialize(
      appKey: '2c89ba1eee07b01fbfb0d1ca3220eff2',
      baseUrl: 'https://localhost',
    );
  }

  // 4. 앱 실행 (TaxiMateApp 하나만 남깁니다)
  runApp(const TaxiMateApp());
}

// 앱 최상위 위젯
class TaxiMateApp extends StatelessWidget {
  const TaxiMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaxiMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: Colors.white,
          onPrimary: Colors.white,
          onSurface: AppColors.secondary,
        ),
        scaffoldBackgroundColor: AppColors.bg,
      ),
      initialRoute: AppRoutes.splash, // 스플래시 화면부터 시작
      routes: {
        AppRoutes.splash: (_) => const SplashScreen(),
        AppRoutes.login:  (_) => const LoginScreen(),
        AppRoutes.signup: (_) => const SignupScreen(),
        AppRoutes.main:   (_) => const MainScreen(),
      },
    );
  }
}

// 메인 화면 (탭 관리)
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  List<Widget> get _screens => [
    HomeTab(
      onTabChange: (i) => setState(() => _selectedIndex = i),
      onGoToCreate: () => setState(() => _selectedIndex = 1),
    ),
    MatchingTab(onGoHome: () => setState(() => _selectedIndex = 0)),
    const ActiveTab(),
    const MessageTab(),
    const MyPageTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.gray,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.location_on_outlined), activeIcon: Icon(Icons.location_on), label: '매칭'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_car_outlined), activeIcon: Icon(Icons.directions_car), label: '이용 중'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: '채팅'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: '내정보'),
        ],
      ),
    );
  }
}