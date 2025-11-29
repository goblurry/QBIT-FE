import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qbit_shared/widgets/common/header_back.dart';
import 'package:qbit_shared/theme/app_colors.dart';
import 'package:qbit_shared/theme/app_fonts.dart';
import 'package:qbit_shared/utils/responsive_utils.dart';
import 'package:qbit_services/api/order_api_service.dart';
import 'package:qbit_services/api/exchange_rate_api_service.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

/// 주문 상세 화면
class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _orderDetail;
  double? _exchangeRate;
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    _fetchOrderDetail();
    _fetchExchangeRate();
  }

  Future<void> _fetchOrderDetail() async {
    setState(() => _isLoading = true);

    try {
      final response = await OrderApiService.getOrder(widget.orderId.toString());

      if (mounted) {
        setState(() {
          _orderDetail = response;
          _isLoading = false;
        });
      }
    } catch (error) {
      _logger.e('주문 상세 조회 실패: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchExchangeRate() async {
    try {
      // 환율 API 호출 (ExchangeRateApiService 사용)
      final rate = await ExchangeRateApiService.getUsdToKrwRate();
      if (mounted) {
        setState(() {
          _exchangeRate = rate;
        });
      }
    } catch (error) {
      _logger.e('환율 조회 실패: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppHeader(
        title: '주문 상세',
        onBack: () => context.pop(),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : _orderDetail == null
              ? _buildErrorView()
              : _buildContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: context.w(64),
            color: AppColors.gray400,
          ),
          SizedBox(height: context.h(16)),
          Text(
            '주문 정보를 불러올 수 없습니다',
            style: AppFonts.b1Semibold.copyWith(color: AppColors.gray600),
          ),
          SizedBox(height: context.h(24)),
          ElevatedButton(
            onPressed: () => context.pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(
                horizontal: context.w(24),
                vertical: context.h(12),
              ),
            ),
            child: Text(
              '돌아가기',
              style: AppFonts.b2Semibold.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final order = _orderDetail!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 진행 단계 표시
          _buildProgressIndicator(order),

          SizedBox(height: context.h(32)),

          // 주문 정보 섹션
          _buildInfoSection(order),
        ],
      ),
    );
  }

  /// 상단 진행 단계 표시 (주문 → 매수완료 → 출금/입금)
  Widget _buildProgressIndicator(Map<String, dynamic> order) {
    final status = order['status'] as String?;
    final side = order['side'] as String?;
    final filledAt = order['filledAt'] as String?;
    final canceledAt = order['canceledAt'] as String?;

    // 상태에 따른 단계 결정
    int currentStep = 0;
    String step1Label = '주문';
    String step2Label = side == 'buy' ? '매수완료' : '매도완료';
    String step3Label = side == 'buy' ? '출금예정' : '입금예정';
    String step1Sub = '취소 가능';
    String step2Sub = '취소 불가능';
    String step3Sub = '';

    switch (status) {
      case 'pending_new':
      case 'accepted':
      case 'new':
        // 주문 접수됨
        currentStep = 1;
        step1Sub = '취소 가능';
        break;
        
      case 'partially_filled':
        // 부분 체결
        currentStep = 2;
        step2Label = side == 'buy' ? '부분 매수' : '부분 매도';
        step1Sub = '';
        step2Sub = '취소 불가능';
        break;
        
      case 'filled':
        // 체결 완료 - 출금/입금까지 완료로 표시
        currentStep = 3;
        step1Sub = '';
        step2Sub = '';
        if (filledAt != null && filledAt.isNotEmpty) {
          try {
            final filledDate = DateTime.parse(filledAt);
            step3Sub = DateFormat('M월 d일').format(filledDate);
          } catch (e) {
            step3Sub = '';
          }
        }
        break;
        
      case 'canceled':
        // 취소됨
        currentStep = 2;
        step2Label = '주문 취소';
        step3Label = '';
        step1Sub = '';
        if (canceledAt != null && canceledAt.isNotEmpty) {
          try {
            final cancelDate = DateTime.parse(canceledAt);
            step2Sub = DateFormat('M월 d일').format(cancelDate);
          } catch (e) {
            step2Sub = '';
          }
        }
        break;
        
      case 'expired':
        // 만료됨
        currentStep = 2;
        step2Label = '주문 만료';
        step3Label = '';
        step1Sub = '';
        step2Sub = '';
        break;
        
      case 'rejected':
        // 거부됨
        currentStep = 2;
        step2Label = '주문 거부';
        step3Label = '';
        step1Sub = '';
        step2Sub = '';
        break;
        
      case 'replaced':
        // 대체됨
        currentStep = 2;
        step2Label = '주문 변경';
        step3Label = '';
        step1Sub = '';
        step2Sub = '';
        break;
        
      case 'done_for_day':
        // 당일 종료
        currentStep = 2;
        step2Label = '당일 종료';
        step1Sub = '';
        step2Sub = '';
        break;
        
      default:
        currentStep = 0;
        step1Sub = '';
    }

    final symbol = order['symbol'] as String? ?? '';
    final isBuy = side == 'buy';
    final stepColor = isBuy ? AppColors.profit : AppColors.loss;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.w(24),
        vertical: context.h(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isBuy ? '$symbol 매수' : '$symbol 매도',
            style: AppFonts.t2Bold.copyWith(
              color: AppColors.gray900,
              fontSize: 24,
            ),
          ),
          SizedBox(height: context.h(40)),
          Row(
            children: [
              _buildStep(
                label: step1Label,
                subLabel: step1Sub,
                isActive: currentStep >= 1,
                showCheck: currentStep >= 2,
                color: stepColor,
              ),
              _buildStepConnector(isActive: currentStep >= 2, color: stepColor),
              _buildStep(
                label: step2Label,
                subLabel: step2Sub,
                isActive: currentStep >= 2,
                showCheck: currentStep >= 2 && (status == 'canceled' || status == 'expired' || status == 'rejected' || currentStep >= 3),
                color: stepColor,
              ),
              if (step3Label.isNotEmpty) ...[
                _buildStepConnector(isActive: currentStep >= 3, color: stepColor),
                _buildStep(
                  label: step3Label,
                  subLabel: step3Sub,
                  isActive: currentStep >= 3,
                  showCheck: currentStep >= 3 && status == 'filled',
                  color: stepColor,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required String label,
    required String subLabel,
    required bool isActive,
    required bool showCheck,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: context.w(40),
            height: context.w(40),
            decoration: BoxDecoration(
              color: isActive ? color : AppColors.gray200,
              shape: BoxShape.circle,
            ),
            child: showCheck
                ? Icon(
                    Icons.check,
                    color: Colors.white,
                    size: context.w(24),
                  )
                : null,
          ),
          SizedBox(height: context.h(8)),
          Text(
            label,
            style: AppFonts.c1.copyWith(
              color: isActive ? AppColors.gray900 : AppColors.gray400,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          // 항상 높이를 확보
          SizedBox(height: context.h(4)),
          SizedBox(
            height: context.h(15), // 고정 높이
            child: subLabel.isNotEmpty
                ? Text(
                    subLabel,
                    style: AppFonts.c2.copyWith(
                      color: AppColors.gray400,
                      fontSize: 11,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector({required bool isActive, required Color color}) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.h(50)), // 텍스트 높이만큼 아래 패딩
      child: Align(
        alignment: Alignment.center,
        child: Container(
          width: context.w(60),
          height: 2,
          color: isActive ? color : AppColors.gray200,
        ),
      ),
    );
  }

  /// 주문 정보 섹션
  Widget _buildInfoSection(Map<String, dynamic> order) {
    final status = order['status'] as String?;
    final side = order['side'] as String?;
    final canCancel = status == 'new' || status == 'accepted' || status == 'pending_new';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.w(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 대기중인 주문이면 "대기중인 내역" 헤더와 주문 취소 버튼
          if (canCancel) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '대기중인 내역',
                  style: AppFonts.b1Semibold.copyWith(
                    color: AppColors.gray900,
                    fontSize: 18,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showCancelDialog(order),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.w(12),
                      vertical: context.h(6),
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '주문 취소',
                      style: AppFonts.c1.copyWith(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.h(24)),
          ],
          
          _buildInfoRow(
            '주문 시각',
            _formatDateTime(order['createdAt']),
          ),
          SizedBox(height: context.h(16)),
          _buildInfoRow(
            '주문 단가',
            _formatPriceWithKrw(_getPrice(order)),
          ),
          SizedBox(height: context.h(16)),
          _buildInfoRow(
            '적용 환율',
            _formatExchangeRate(),
          ),
          SizedBox(height: context.h(16)),
          _buildInfoRow(
            '수량',
            '${_formatQuantity(order['quantity'] ?? order['filledQuantity'])}주',
          ),
          
          // 취소된 경우 취소 시각 표시
          if (status == 'canceled' && order['canceledAt'] != null) ...[
            SizedBox(height: context.h(24)),
            Divider(color: AppColors.gray200, thickness: 1),
            SizedBox(height: context.h(16)),
            _buildInfoRow(
              '취소 시각',
              _formatDateTime(order['canceledAt']),
            ),
          ],
          
          // 체결 완료된 경우 완료 시각 표시
          if (status == 'filled' && order['filledAt'] != null) ...[
            SizedBox(height: context.h(24)),
            Divider(color: AppColors.gray200, thickness: 1),
            SizedBox(height: context.h(16)),
            _buildInfoRow(
              side == 'buy' ? '매수완료' : '매도완료',
              _formatDateTime(order['filledAt']),
            ),
          ],
          
          SizedBox(height: context.h(32)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppFonts.b2Regular.copyWith(
            color: AppColors.gray600,
            fontSize: isTotal ? 16 : 14,
          ),
        ),
        Text(
          value,
          style: AppFonts.b2Semibold.copyWith(
            color: AppColors.gray900,
            fontSize: isTotal ? 18 : 14,
          ),
        ),
      ],
    );
  }

  // ========== 다이얼로그 ==========

  void _showCancelDialog(Map<String, dynamic> order) {
    final side = order['side'] as String?;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          side == 'buy' ? '매수를 취소할까요?' : '판매를 취소할까요?',
          style: AppFonts.b1Semibold.copyWith(color: AppColors.gray900),
        ),
        content: Text(
          '언제든 다시 주문할 수 있어요.',
          style: AppFonts.b2Regular.copyWith(color: AppColors.gray600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '아니요',
              style: AppFonts.b2Semibold.copyWith(color: AppColors.gray600),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _cancelOrder(order['orderId']);
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.1),
            ),
            child: Text(
              '취소합니다',
              style: AppFonts.b2Semibold.copyWith(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOrder(int orderId) async {
    try {
      final success = await OrderApiService.cancelOrder(orderId.toString());
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('주문이 취소되었습니다'),
              backgroundColor: AppColors.primary,
            ),
          );
          // 화면 새로고침
          _fetchOrderDetail();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('주문 취소에 실패했습니다'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      _logger.e('주문 취소 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('주문 취소 중 오류가 발생했습니다'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ========== 포맷 헬퍼 함수 ==========

  double? _getPrice(Map<String, dynamic> order) {
    // filledAvgPrice가 0이 아니면 사용
    final filledPrice = order['filledAvgPrice'];
    if (filledPrice != null) {
      final price = filledPrice is String ? double.tryParse(filledPrice) : (filledPrice as num).toDouble();
      if (price != null && price > 0) {
        return price;
      }
    }
    
    // 없으면 limitPrice 사용
    final limitPrice = order['limitPrice'];
    if (limitPrice != null) {
      return limitPrice is String ? double.tryParse(limitPrice) : (limitPrice as num).toDouble();
    }
    
    return null;
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return '--';
    try {
      final dt = dateTime is DateTime ? dateTime : DateTime.parse(dateTime as String);
      return DateFormat('yyyy.M.d HH:mm').format(dt);
    } catch (e) {
      return '--';
    }
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat('M월 d일').format(dateTime);
  }

  String _formatQuantity(dynamic quantity) {
    if (quantity == null) return '0';
    try {
      final quantityValue = quantity is String ? double.parse(quantity) : (quantity as num).toDouble();
      // 소수점이 있으면 그대로, 없으면 정수로
      if (quantityValue % 1 == 0) {
        return quantityValue.toInt().toString();
      } else {
        return quantityValue.toStringAsFixed(2);
      }
    } catch (e) {
      return '0';
    }
  }

  String _formatPriceWithKrw(dynamic price) {
    if (price == null) return '\$0.00';
    try {
      final priceValue = price is String ? double.parse(price) : (price as num).toDouble();
      final dollarFormatted = NumberFormat('#,##0.00').format(priceValue);
      
      if (_exchangeRate != null) {
        final krwValue = priceValue * _exchangeRate!;
        final krwFormatted = NumberFormat('#,###').format(krwValue.round());
        return '\$$dollarFormatted (${krwFormatted}원)';
      }
      
      return '\$$dollarFormatted';
    } catch (e) {
      return '\$0.00';
    }
  }

  String _formatExchangeRate() {
    if (_exchangeRate == null) return '조회 중...';
    final formatted = NumberFormat('#,##0.00').format(_exchangeRate!);
    return '${formatted}원';
  }
}

