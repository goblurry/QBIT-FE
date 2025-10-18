import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:app_links/app_links.dart';
import 'package:kakao_flutter_sdk_common/kakao_flutter_sdk_common.dart';
import 'package:qbit_core/config/app_config.dart';
import 'package:qbit_core/config/env_config.dart';
import 'package:qbit_shared/theme/app_theme.dart';
import 'package:qbit_services/auth/auth_service.dart';
import 'package:qbit_services/api/api_client.dart';
import 'package:qbit_services/auth/kakao_auth_service.dart';
import 'package:qbit_shared/router/app_router.dart';

void runQbitApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 환경 변수 초기화
  try {
    await EnvConfig.initialize();
  } catch (e, stackTrace) {
    if (kDebugMode) {
      debugPrint('EnvConfig.initialize failed: $e');
      debugPrint('Stack trace: $stackTrace');
    } else {
      debugPrint('EnvConfig.initialize failed: $e');
      // 프로덕션에서는 앱을 계속 실행하되 로그만 남김
    }
  }
  
  // 카카오 SDK 초기화
  try {
    KakaoSdk.init(nativeAppKey: AppConfig.kakaoNativeAppKey);
  } catch (e, stackTrace) {
    if (kDebugMode) {
      debugPrint('KakaoSdk.init failed: $e');
      debugPrint('Stack trace: $stackTrace');
    } else {
      debugPrint('KakaoSdk.init failed: $e');
      // 프로덕션에서는 앱을 계속 실행하되 로그만 남김
    }
  }
  
  // API 클라이언트 초기화
  try {
    ApiClient.initialize();
  } catch (e, stackTrace) {
    if (kDebugMode) {
      debugPrint('ApiClient.initialize failed: $e');
      debugPrint('Stack trace: $stackTrace');
    } else {
      debugPrint('ApiClient.initialize failed: $e');
      // 프로덕션에서는 앱을 계속 실행하되 로그만 남김
    }
  }

  // 카카오 토큰 정보 출력 (앱 시작 시)
  try {
    await KakaoAuthService.printTokenInfo();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('카카오 토큰 정보 출력 실패: $e');
    }
  }
  
  // 개발자 모드 에러 로그 활성화
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };
  
  // Dart 에러 처리
  PlatformDispatcher.instance.onError = (error, stack) {
    // 에러 정보 수집
    final errorDetails = FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'PlatformDispatcher',
      context: ErrorDescription('Uncaught Dart error'),
    );

    if (kDebugMode) {
      // 개발 환경: 에러를 콘솔에 출력하고 Flutter 에러 시스템에 보고
      debugPrint('Uncaught Dart error: $error');
      debugPrint('Stack trace: $stack');
      FlutterError.reportError(errorDetails);
    } else {
      // 프로덕션 환경: 크래시 리포팅 서비스에 전달
      // TODO: 실제 크래시 리포팅 서비스(Firebase Crashlytics, Sentry 등) 연동
      // 예시: FirebaseCrashlytics.instance.recordError(error, stack);
      debugPrint('Production error occurred: $error');
    }

    return true; // 에러가 처리되었음을 시스템에 알림
  };
  
  runApp(const QbitApp());
}

void main() => runQbitApp();

class QbitApp extends StatefulWidget {
  const QbitApp({super.key});

  @override
  State<QbitApp> createState() => _QbitAppState();
}

class _QbitAppState extends State<QbitApp> {
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    // 앱이 이미 실행 중일 때 URL 처리
    _appLinks.uriLinkStream.listen(
      (Uri uri) {
        // 카카오 SDK가 자동으로 Deep Link 처리
      },
      onError: (err) {
        if (kDebugMode) {
          debugPrint('Deep Link 처리 에러: $err');
        }
      },
    );

    // 앱이 종료된 상태에서 URL로 실행될 때 처리
    _appLinks.getInitialLink().then((Uri? uri) {
      if (uri != null) {
        // 카카오 SDK가 자동으로 Deep Link 처리
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConfig.appName,
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
    );
  }
}
