// ============================================================
// lib/main.dart
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'package:geolocator/geolocator.dart';
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

void main() async {
  // Flutter 엔진 초기화 (async main 사용 시 필수)
  WidgetsFlutterBinding.ensureInitialized();

  // 카카오맵 SDK 초기화 (웹에서는 제외)
  if (!kIsWeb) {
    AuthRepository.initialize(
      appKey: 'ab5f9937336b573d4e68ad90b988bd9c',
      baseUrl: '',
    );
  }

  runApp(const TaxiMateApp());
}

// 앱 최상위 위젯 (앱 전체를 감싸고 있는 위젯)
class TaxiMateApp extends StatelessWidget {
  const TaxiMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaxiMate',  // 나중에 앱 이름 바꾸기?
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
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.secondary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        scaffoldBackgroundColor: AppColors.bg,
        cardTheme: CardThemeData(
          color: Colors.white, elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
      initialRoute: AppRoutes.splash, // 앱 시작 시 기본적으로 스플래시 화면으로 이동
      routes: {
        AppRoutes.splash: (_) => const SplashScreen(),
        AppRoutes.login:  (_) => const LoginScreen(),
        AppRoutes.signup: (_) => const SignupScreen(),
        AppRoutes.main:   (_) => const MainScreen(),
      },
    );
  }
}

// 메인 화면 (StatefulWidget으로 탭 구조 관리)
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

// 메인 화면 상태 관리 클래스
class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0; // 현재 선택된 탭 인덱스

  // 각 탭 화면 리스트
  List<Widget> get _screens => [
    HomeTab(
      onTabChange: (i) => setState(() => _selectedIndex = i),
      onGoToCreate: () => setState(() {
        _selectedIndex = 1; // 매칭 탭 인덱스
        // 매칭 탭의 핀 생성 탭(인덱스 1)으로 바로 이동하려면 아래처럼
      }),
    ),
    MatchingTab(onGoHome: () => setState(() => _selectedIndex = 0)),
    const ActiveTab(),
    const MessageTab(),
    const MyPageTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens), // 여러 탭 화면 유지하면서 현재 탭만 출력
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // 탭 네비게이션 바
        currentIndex: _selectedIndex, // 현재 선택된 탭 인덱스
        onTap: (i) => setState(() => _selectedIndex = i),
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.gray,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        elevation: 12,
        items: const [ // 탭바 아이콘 설정
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined),        activeIcon: Icon(Icons.home),        label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.location_on_outlined), activeIcon: Icon(Icons.location_on), label: '매칭'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_car_outlined), activeIcon: Icon(Icons.directions_car), label: '이용 중'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline),  activeIcon: Icon(Icons.chat_bubble), label: '채팅'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline),       activeIcon: Icon(Icons.person),      label: '내정보'),
        ],
      ),
    );
  }
}