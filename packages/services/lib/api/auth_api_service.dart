import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'api_client.dart';

final logger = Logger();

class AuthApiService {
  static final Dio _dio = ApiClient.instance;
  
  // 토큰 재발급 전용 Dio 인스턴스 (토큰 인터셉터 없음)
  static final Dio _refreshDio = Dio(BaseOptions(
    baseUrl: ApiClient.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    sendTimeout: const Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json; charset=utf-8',
    },
  ));

  /// 카카오 로그인
  /// POST /auth/kakao/login
  static Future<Map<String, dynamic>?> kakaoLogin({
    required String kakaoAccessToken,
    required String userId,
    String? nickname,
    String? email,
  }) async {
    try {
      logger.i('카카오 로그인 API 호출 시작');
      
      final response = await _refreshDio.post(
        '/auth/kakao/login',
        data: {
          'kakaoAccessToken': kakaoAccessToken,
          'userId': userId,
          'nickname': nickname,
          'email': email,
        },
      );

      if (response.statusCode == 200) {
        logger.i('카카오 로그인 API 성공');
        return response.data;
      } else {
        logger.e('카카오 로그인 API 실패: ${response.statusCode}');
        return null;
      }
    } catch (error) {
      logger.e('카카오 로그인 API 에러: $error');
      if (error is DioException) {
        logger.e('Dio 에러 상세: ${error.response?.data}');
        logger.e('에러 타입: ${error.type}');
        logger.e('에러 메시지: ${error.message}');
        logger.e('요청 URL: ${error.requestOptions.uri}');
        logger.e('응답 상태: ${error.response?.statusCode}');
      }
      return null;
    }
  }

  /// 로그아웃
  /// POST /auth/logout
  static Future<bool> logout() async {
    try {
      logger.i('로그아웃 API 호출 시작');
      
      final response = await _dio.post('/auth/logout');

      if (response.statusCode == 200 || response.statusCode == 204) {
        logger.i('로그아웃 API 성공 (상태코드: ${response.statusCode})');
        return true;
      } else {
        logger.e('로그아웃 API 실패: ${response.statusCode}');
        return false;
      }
    } catch (error) {
      logger.e('로그아웃 API 에러: $error');
      if (error is DioException) {
        logger.e('Dio 에러 상세: ${error.response?.data}');
      }
      return false;
    }
  }

  /// 토큰 갱신
  /// POST /auth/refresh
  static Future<Map<String, dynamic>?> refreshToken({
    required String refreshToken,
  }) async {
    try {
      logger.i('토큰 갱신 API 호출 시작');
      
      final response = await _refreshDio.post(
        '/auth/refresh',
        data: {
          'refreshToken': refreshToken,
        },
      );

      if (response.statusCode == 200) {
        logger.i('토큰 갱신 API 성공');
        return response.data;
      } else {
        logger.e('토큰 갱신 API 실패: ${response.statusCode}');
        return null;
      }
    } catch (error) {
      logger.e('토큰 갱신 API 에러: $error');
      if (error is DioException) {
        logger.e('Dio 에러 상세: ${error.response?.data}');
      }
      return null;
    }
  }

  /// Alpaca OAuth 인증 시작
  /// GET /auth/alpaca/authorize
  static Future<String?> getAlpacaAuthorizeUrl() async {
    try {
      logger.i('Alpaca 인증 URL 요청 시작');
      
      final response = await _dio.get('/auth/alpaca/authorize', 
        options: Options(
          followRedirects: true, // 리다이렉트를 따라가서 최종 URL 획득
          responseType: ResponseType.plain, // HTML 응답 처리
        ),
      );

      if (response.statusCode == 200) {
        logger.i('Alpaca 인증 URL 요청 성공');
        logger.i('최종 URL: ${response.realUri}');
        
        // 리다이렉트를 따라간 최종 URL 반환
        return response.realUri.toString();
      } else {
        logger.e('Alpaca 인증 URL 요청 실패: ${response.statusCode}');
        return null;
      }
    } catch (error) {
      logger.e('Alpaca 인증 URL 요청 에러: $error');
      if (error is DioException) {
        logger.e('Dio 에러 상세: ${error.response?.data}');
      }
      return null;
    }
  }

  /// Alpaca 연결 상태 확인
  /// GET /auth/alpaca/status
  static Future<Map<String, dynamic>?> getAlpacaStatus() async {
    try {
      logger.i('Alpaca 연결 상태 확인 시작');
      
      // 현재 시간 기록
      final requestTime = DateTime.now();
      logger.i('API 요청 시간: ${requestTime.toIso8601String()}');
      logger.i('API 요청 시간 (UTC): ${requestTime.toUtc().toIso8601String()}');
      
      final response = await _dio.get('/auth/alpaca/status');
      if (response.statusCode == 200) {
        logger.i('Alpaca 연결 상태 확인 성공');
        logger.i('응답 데이터: ${response.data}');
        logger.i('응답 데이터 타입: ${response.data.runtimeType}');
        
        if (response.data is Map<String, dynamic>) {
          final data = response.data as Map<String, dynamic>;
          logger.i('connected: ${data['connected']}');
          logger.i('paperTrading: ${data['paperTrading']}');
          logger.i('connectionStatus: ${data['connectionStatus']}');
          logger.i('tokenExpired: ${data['tokenExpired']}');
          logger.i('전체 키 목록: ${data.keys.toList()}');
          return data;
        } else {
          logger.e('응답 데이터 타입이 예상과 다름: ${response.data.runtimeType}');
          return null;
        }
      } else {
        logger.e('Alpaca 연결 상태 확인 실패: ${response.statusCode}');
        logger.e('응답 데이터: ${response.data}');
        return null;
      }
    } catch (error) {
      logger.e('Alpaca 연결 상태 확인 에러: $error');
      if (error is DioException) {
        logger.e('Dio 에러 상세: ${error.response?.data}');
        logger.e('Dio 에러 상태코드: ${error.response?.statusCode}');
      
      }
      return null;
    }
  }

  /// Alpaca 토큰 갱신
  /// POST /auth/alpaca/refresh
  static Future<bool> refreshAlpacaToken() async {
    try {
      logger.i('Alpaca 토큰 갱신 시작');
      final response = await _dio.post('/auth/alpaca/refresh');
      if (response.statusCode == 200) {
        logger.i('Alpaca 토큰 갱신 성공');
        return true;
      } else {
        logger.e('Alpaca 토큰 갱신 실패: ${response.statusCode}');
        return false;
      }
    } catch (error) {
      logger.e('Alpaca 토큰 갱신 에러: $error');
      if (error is DioException) {
        logger.e('Dio 에러 상세: ${error.response?.data}');
      }
      return false;
    }
  }

  /// Alpaca 연결 해제
  /// POST /auth/alpaca/disconnect
  static Future<bool> disconnectAlpaca() async {
    try {
      logger.i('Alpaca 연결 해제 시작');
      final response = await _dio.post('/auth/alpaca/disconnect');
      if (response.statusCode == 200) {
        logger.i('Alpaca 연결 해제 성공');
        return true;
      } else {
        logger.e('Alpaca 연결 해제 실패: ${response.statusCode}');
        return false;
      }
    } catch (error) {
      logger.e('Alpaca 연결 해제 에러: $error');
      if (error is DioException) {
        logger.e('Dio 에러 상세: ${error.response?.data}');
      }
      return false;
    }
  }

  /// 현재 사용자 정보 조회
  /// GET /users/me
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      logger.i('현재 사용자 정보 조회 시작');
      
      final response = await _dio.get('/users/me');
      
      if (response.statusCode == 200) {
        logger.i('현재 사용자 정보 조회 성공');
        logger.i('응답 데이터: ${response.data}');
        return response.data;
      } else {
        logger.e('현재 사용자 정보 조회 실패: ${response.statusCode}');
        logger.e('응답 데이터: ${response.data}');
        return null;
      }
    } catch (error) {
      logger.e('현재 사용자 정보 조회 에러: $error');
      if (error is DioException) {
        logger.e('Dio 에러 상세: ${error.response?.data}');
        logger.e('Dio 에러 상태코드: ${error.response?.statusCode}');
        
        if (error.response?.statusCode == 401) {
          logger.e('401 에러: 인증되지 않은 요청');
        }
      }
      return null;
    }
  }
}
