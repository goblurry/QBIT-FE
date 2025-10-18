import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 3,
    lineLength: 50,
    colors: true,
    printEmojis: true,
    printTime: false,
  ),
);

class KakaoAuthService {
  /// 카카오 토큰 정보 출력 (디버깅용)
  static Future<void> printTokenInfo() async {
    try {
      if (await AuthApi.instance.hasToken()) {
        OAuthToken? token = await TokenManagerProvider.instance.manager.getToken();
        
        logger.i('🔑 카카오 액세스 토큰: ${token?.accessToken}');
      } else {
        logger.w('카카오 토큰이 없습니다');
      }
    } catch (e) {
      logger.e('토큰 정보 조회 실패: $e');
    }
  }

  /// 카카오 로그인 실행

  /// 카카오톡 설치 여부에 따라 카카오톡 로그인 또는 카카오계정 로그인 시도
  static Future<Map<String, dynamic>?> login() async {
    try {
      logger.i('카카오 로그인 시작');
      
      // 기존 토큰 확인
      if (await AuthApi.instance.hasToken()) {
        try {
          AccessTokenInfo tokenInfo = await UserApi.instance.accessTokenInfo();
          OAuthToken? token = await TokenManagerProvider.instance.manager.getToken();
          
          logger.i('기존 토큰 유효: userId=${tokenInfo.id}');
          
          User user = await UserApi.instance.me();
          logger.i('자동 로그인 성공: 닉네임=${user.kakaoAccount?.profile?.nickname}');
          
          return {
            'success': true,
            'userId': user.id.toString(),
            'accessToken': token?.accessToken,
            'nickname': user.kakaoAccount?.profile?.nickname,
            'email': user.kakaoAccount?.email,
          };
        } catch (error) {
          if (error is KakaoException && error.isInvalidTokenError()) {
            logger.w('토큰 만료됨, 재로그인 필요');
          } else {
            logger.e('토큰 유효성 체크 실패: $error');
          }
        }
      } else {
        logger.w('저장된 토큰 없음, 로그인 필요');
      }

      // 카카오톡 설치 여부 확인
      bool isInstalled = await isKakaoTalkInstalled();
      logger.i('카카오톡 설치 여부: $isInstalled');

      if (isInstalled) {
        try {
          // 카카오톡으로 로그인 시도
          OAuthToken token = await UserApi.instance.loginWithKakaoTalk();
          logger.i('카카오톡 로그인 성공');
          
          User user = await UserApi.instance.me();
          logger.i('사용자 정보: userId=${user.id}, 닉네임=${user.kakaoAccount?.profile?.nickname}');
          
          return {
            'success': true,
            'userId': user.id.toString(),
            'accessToken': token.accessToken,
            'nickname': user.kakaoAccount?.profile?.nickname,
            'email': user.kakaoAccount?.email,
          };
        } catch (error) {
          logger.w('카카오톡 로그인 실패: $error');
          if (error is PlatformException && error.code == 'CANCELED') {
            return {'success': false, 'error': '사용자 취소'};
          }

          // 카카오톡 로그인 실패 시 카카오계정 로그인으로
          try {
            OAuthToken token = await UserApi.instance.loginWithKakaoAccount();
            logger.i('카카오계정 로그인 성공');
            
            User user = await UserApi.instance.me();
            logger.i('사용자 정보: userId=${user.id}, 닉네임=${user.kakaoAccount?.profile?.nickname}');
            
            return {
              'success': true,
              'userId': user.id.toString(),
              'accessToken': token.accessToken,
              'nickname': user.kakaoAccount?.profile?.nickname,
              'email': user.kakaoAccount?.email,
            };
          } catch (error) {
            logger.e('카카오계정 로그인 실패: $error');
            return {'success': false, 'error': error.toString()};
          }
        }
      } else {
        // 카카오톡이 설치되지 않은 경우 카카오계정으로 로그인
        try {
          OAuthToken token = await UserApi.instance.loginWithKakaoAccount();
          logger.i('카카오계정 로그인 성공');
          
          User user = await UserApi.instance.me();
          logger.i('사용자 정보: userId=${user.id}, 닉네임=${user.kakaoAccount?.profile?.nickname}');
          
          return {
            'success': true,
            'userId': user.id.toString(),
            'accessToken': token.accessToken,
            'nickname': user.kakaoAccount?.profile?.nickname,
            'email': user.kakaoAccount?.email,
          };
        } catch (error) {
          logger.e('카카오계정 로그인 실패: $error');
          return {'success': false, 'error': error.toString()};
        }
      }
    } catch (e, stack) {
      logger.e("로그인 중 예외 발생: $e\n$stack");
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 로그아웃
  static Future<bool> logout() async {
    try {
      await UserApi.instance.logout();
      logger.i('카카오 로그아웃 성공');
      return true;
    } catch (error) {
      logger.e('카카오 로그아웃 실패: $error');
      return false;
    }
  }

  /// 연결 해제 
  static Future<bool> unlink() async {
    try {
      await UserApi.instance.unlink();
      logger.i('카카오 연결 해제 성공');
      return true;
    } catch (error) {
      logger.e('카카오 연결 해제 실패: $error');
      return false;
    }
  }

  /// 토큰 존재 여부 조회 
  static Future<bool> hasToken() async {
    try {
      bool hasToken = await AuthApi.instance.hasToken();
      logger.i('토큰 존재 여부: $hasToken');
      return hasToken;
    } catch (error) {
      logger.e('토큰 존재 여부 조회 실패: $error');
      return false;
    }
  }

  /// 액세스 토큰 정보 조회 
  static Future<Map<String, dynamic>?> getTokenInfo() async {
    try {
      AccessTokenInfo tokenInfo = await UserApi.instance.accessTokenInfo();
      // 토큰 만료 시간 계산
      final now = DateTime.now();
      final expiresAt = now.add(Duration(seconds: tokenInfo.expiresIn));
      final remainingMinutes = expiresAt.difference(now).inMinutes;
      
      logger.i('카카오 토큰: ${expiresAt.isBefore(now) ? '만료' : '유효'} (${remainingMinutes}분 남음)');
      
      // 토큰 만료 상태 상세 확인
      if (expiresAt.isBefore(now)) {
        logger.e('카카오 토큰이 만료되었습니다!');
        logger.e('토큰 만료 시간: ${expiresAt.toIso8601String()}');
        logger.e('현재 시간: ${now.toIso8601String()}');
        logger.e('만료된 지: ${now.difference(expiresAt).inMinutes}분');
      } else {
        logger.i('카카오 토큰이 유효합니다');
        logger.i('토큰 만료 시간: ${expiresAt.toIso8601String()}');
        logger.i('현재 시간: ${now.toIso8601String()}');
        logger.i('만료까지: ${remainingMinutes}분');
      }
      
      return {
        'userId': tokenInfo.id,
        'expiresIn': tokenInfo.expiresIn,
        'appId': tokenInfo.appId,
        'expiresAt': expiresAt.toIso8601String(),
        'isExpired': expiresAt.isBefore(now),
      };
    } catch (error) {
      logger.e('토큰 정보 조회 실패: $error');
      return null;
    }
  }

  /// 사용자 정보 조회 
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      User user = await UserApi.instance.me();
      logger.i('사용자 정보 조회 성공: userId=${user.id}, 닉네임=${user.kakaoAccount?.profile?.nickname}');
      
      return {
        'id': user.id,
        'hasSignedUp': user.hasSignedUp,
        'connectedAt': user.connectedAt?.toIso8601String(),
        'synchedAt': user.synchedAt?.toIso8601String(),
        'properties': user.properties,
        'kakaoAccount': {
          'profileNeedsAgreement': user.kakaoAccount?.profileNeedsAgreement,
          'profileNicknameNeedsAgreement': user.kakaoAccount?.profileNicknameNeedsAgreement,
          'profileImageNeedsAgreement': user.kakaoAccount?.profileImageNeedsAgreement,
          'nameNeedsAgreement': user.kakaoAccount?.nameNeedsAgreement,
          'name': user.kakaoAccount?.name,
          'emailNeedsAgreement': user.kakaoAccount?.emailNeedsAgreement,
          'isEmailValid': user.kakaoAccount?.isEmailValid,
          'isEmailVerified': user.kakaoAccount?.isEmailVerified,
          'email': user.kakaoAccount?.email,
          'ageRangeNeedsAgreement': user.kakaoAccount?.ageRangeNeedsAgreement,
          'ageRange': user.kakaoAccount?.ageRange?.toString(),
          'birthdayNeedsAgreement': user.kakaoAccount?.birthdayNeedsAgreement,
          'birthday': user.kakaoAccount?.birthday,
          'birthdayType': user.kakaoAccount?.birthdayType?.toString(),
          'birthyearNeedsAgreement': user.kakaoAccount?.birthyearNeedsAgreement,
          'birthyear': user.kakaoAccount?.birthyear,
          'genderNeedsAgreement': user.kakaoAccount?.genderNeedsAgreement,
          'gender': user.kakaoAccount?.gender?.toString(),
          'phoneNumberNeedsAgreement': user.kakaoAccount?.phoneNumberNeedsAgreement,
          'phoneNumber': user.kakaoAccount?.phoneNumber,
          'profile': {
            'nickname': user.kakaoAccount?.profile?.nickname,
            'thumbnailImageUrl': user.kakaoAccount?.profile?.thumbnailImageUrl,
            'profileImageUrl': user.kakaoAccount?.profile?.profileImageUrl,
            'isDefaultImage': user.kakaoAccount?.profile?.isDefaultImage,
          },
        },
      };
    } catch (error) {
      logger.e('사용자 정보 조회 실패: $error');
      return null;
    }
  }

  /// 간단한 사용자 정보 조회 (기본 정보만)
  static Future<Map<String, dynamic>?> getSimpleUserInfo() async {
    try {
      User user = await UserApi.instance.me();
      logger.i('간단한 사용자 정보 조회 성공: userId=${user.id}, 닉네임=${user.kakaoAccount?.profile?.nickname}');
      
      return {
        'userId': user.id.toString(),
        'nickname': user.kakaoAccount?.profile?.nickname,
        'email': user.kakaoAccount?.email,
        'profileImageUrl': user.kakaoAccount?.profile?.profileImageUrl,
        'thumbnailImageUrl': user.kakaoAccount?.profile?.thumbnailImageUrl,
        'hasSignedUp': user.hasSignedUp,
      };
    } catch (error) {
      logger.e('간단한 사용자 정보 조회 실패: $error');
      return null;
    }
  }

  /// 카카오 액세스 토큰 갱신 (SDK 자동 갱신 활용)
  static Future<Map<String, dynamic>?> refreshAccessToken() async {
    try {
      logger.i('카카오 액세스 토큰 갱신 시작 (SDK 자동 갱신)');
      
      // 기존 토큰 확인
      if (!await AuthApi.instance.hasToken()) {
        logger.e('갱신할 토큰이 없습니다');
        return {'success': false, 'error': '갱신할 토큰이 없습니다'};
      }

      // SDK의 자동 토큰 갱신 기능 활용
      // getToken()을 호출하면 SDK가 내부적으로 토큰 만료 여부를 확인하고 자동 갱신
      try {
        OAuthToken? token = await TokenManagerProvider.instance.manager.getToken();
        if (token == null) {
          logger.e('SDK에서 토큰을 가져올 수 없습니다');
          return {'success': false, 'error': 'SDK에서 토큰을 가져올 수 없습니다'};
        }

        // 토큰 정보 확인
        AccessTokenInfo tokenInfo = await UserApi.instance.accessTokenInfo();
        
        logger.i('SDK 자동 토큰 갱신 성공: userId=${tokenInfo.id}');
        return {
          'success': true,
          'accessToken': token.accessToken,
          'userId': tokenInfo.id.toString(),
          'refreshed': true, // SDK가 자동으로 갱신했을 가능성
        };
      } on KakaoException catch (e) {
        if (e.isInvalidTokenError()) {
          logger.w('토큰이 완전히 만료되어 재로그인 필요');
          return {'success': false, 'error': '토큰이 완전히 만료되어 재로그인이 필요합니다'};
        }
        rethrow;
      }
    } catch (error) {
      logger.e('카카오 토큰 갱신 중 예외 발생: $error');
      return {'success': false, 'error': error.toString()};
    }
  }
  /// 재로그인을 통한 토큰 갱신 헬퍼 메서드
  static Future<Map<String, dynamic>> _reloginAndBuildResult() async {
    final isInstalled = await isKakaoTalkInstalled();
    final newToken = isInstalled
        ? await UserApi.instance.loginWithKakaoTalk()
        : await UserApi.instance.loginWithKakaoAccount();

    logger.i('카카오 토큰 갱신 성공');
    
    final user = await UserApi.instance.me();
    return {
      'success': true,
      'accessToken': newToken.accessToken,
      'userId': user.id.toString(),
      'nickname': user.kakaoAccount?.profile?.nickname,
      'email': user.kakaoAccount?.email,
      'refreshed': true,
    };
  }
}
