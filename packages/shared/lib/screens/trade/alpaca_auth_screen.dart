import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:qbit_shared/widgets/common/common_widgets.dart';
import 'package:qbit_shared/widgets/common/header_back.dart';
import 'package:qbit_shared/widgets/common/button/big_black_button.dart';
import 'package:qbit_shared/theme/app_colors.dart';
import 'package:qbit_shared/theme/app_fonts.dart';
import 'package:qbit_services/auth/alpaca_auth_service.dart';

class AlpacaAuthScreen extends StatelessWidget {
  const AlpacaAuthScreen({super.key});

  // 연동 성공 시 모의거래 화면 상태 업데이트를 위한 콜백
  static Function()? onSuccess;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader( // Changed widget
        title: 'Alpaca 연동', // Changed title
        onBack: () => context.pop(), // Added onBack callback
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
        ),
        child: Stack(
          children: [
            // 제목
            Positioned(
              left: 22,
              top: 120,
              child: Text(
                '계좌 연결 후 모의투자 바로 시작',
                style: AppFonts.t2Bold.copyWith(color: AppColors.gray900),
              ),
            ),
            
            // 설명 텍스트
            Positioned(
              left: 22,
              top: 160,
              child: SizedBox(
                width: 342,
                height: 67,
                child: Text(
                  '모의투자를 위해서는 Alpaca 계좌가 필요해요.\n회원가입 후 \'Allow\'를 눌러 연동을 마쳐주세요.',
                  style: AppFonts.b1Regular.copyWith(
                    color: AppColors.gray900,
                    height: 1.6, // lineheight 조정
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
            ),
            
            // 올빼미 캐릭터
            Positioned(
              left: 91,
              top: 330,
              child: SvgPicture.asset(
                'assets/images/characters/owl-sleeping.svg',
                width: 240,
                height: 240,
              ),
            ),
            
            // Alpaca 계좌 연결 버튼
            Positioned(
              left: 16,
              right: 16,
              top: 580,
              child: BigBlackButton(
                text: 'Alpaca 계좌 연결',
                onPressed: () {
                  _handleAlpacaAuth(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Alpaca 인증 처리
  void _handleAlpacaAuth(BuildContext context) async {
    try {
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // 실제 Alpaca 인증 로직 호출
      final result = await AlpacaAuthService.startAlpacaAuth();
      
      // 로딩 닫기
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      if (context.mounted) {
        if (result != null && result['success'] == true) {
          // 연동 성공 콜백 실행
          onSuccess?.call();
          
          // 성공 시 투자 화면으로 이동
          context.go('/trade');
          
          // 성공 메시지 표시
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Alpaca 계좌 연결이 완료되었습니다!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // 실패 메시지 표시 (더 명확한 에러 메시지)
          String errorMessage = '계좌 연결에 실패했습니다.';
          
          if (result?['error'] != null) {
            final error = result!['error'].toString();
            if (error.contains('인증 URL')) {
              errorMessage = '인증 서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요.';
            } else if (error.contains('토큰')) {
              errorMessage = '로그인이 만료되었습니다. 다시 로그인해주세요.';
            } else {
              errorMessage = '계좌 연결 실패: $error';
            }
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (error) {
      // 로딩 닫기
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      if (context.mounted) {
        String errorMessage = '계좌 연결 중 오류가 발생했습니다.';
        
        if (error.toString().contains('SocketException') || 
            error.toString().contains('HandshakeException')) {
          errorMessage = '네트워크 연결을 확인해주세요.';
        } else if (error.toString().contains('401')) {
          errorMessage = '로그인이 만료되었습니다. 앱을 재시작해주세요.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
