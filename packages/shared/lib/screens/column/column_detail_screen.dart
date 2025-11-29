import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qbit_shared/widgets/common/header_back.dart';
import 'package:qbit_shared/theme/app_colors.dart';
import 'package:qbit_shared/theme/app_fonts.dart';
import 'package:qbit_shared/utils/responsive_utils.dart';
import 'package:qbit_services/api/ai_api_service.dart';
import 'package:qbit_services/models/column.dart' as models;
import 'package:qbit_services/models/recommend_column_response.dart';
import 'package:qbit_services/models/api_error_response.dart';

class ColumnDetailScreen extends StatefulWidget {
  final String ticker;

  const ColumnDetailScreen({
    super.key,
    required this.ticker,
  });

  @override
  State<ColumnDetailScreen> createState() => _ColumnDetailScreenState();
}

class _ColumnDetailScreenState extends State<ColumnDetailScreen> {
  models.Column? _column;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadColumn();
  }

  Future<void> _loadColumn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final column = await AiApiService.getColumnByTicker(widget.ticker);
      
      if (mounted) {
        if (column != null) {
          setState(() {
            _column = column;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = '칼럼을 찾을 수 없습니다.';
            _isLoading = false;
          });
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '칼럼을 불러오는 중 오류가 발생했습니다.';
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      // 날짜가 없으면 현재 날짜 사용
      final now = DateTime.now();
      return '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';
    }
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      // 파싱 실패 시 현재 날짜 사용
      final now = DateTime.now();
      return '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';
    }
  }

  String _formatSourceDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      // "2025년 11월 14일" 형식으로 포맷팅
      return '${date.year}년 ${date.month}월 ${date.day}일';
    } catch (e) {
      return '';
    }
  }

  String _formatSectionBody(String body) {
    // "📚 함께 보면 좋은 키워드:" 앞에 줄바꿈 추가
    if (body.contains('📚 함께 보면 좋은 키워드:')) {
      return body.replaceAll('📚 함께 보면 좋은 키워드:', '\n📚 함께 보면 좋은 키워드:');
    }
    return body;
  }

  bool _hasSourceInfo() {
    return (_column!.sourceTitle != null && _column!.sourceTitle!.isNotEmpty) ||
           (_column!.sourcePublisher != null && _column!.sourcePublisher!.isNotEmpty) ||
           (_column!.sourcePublishedAt != null && _column!.sourcePublishedAt!.isNotEmpty) ||
           (_column!.sourceUrl != null && _column!.sourceUrl!.isNotEmpty);
  }

  Future<void> _launchSourceUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // URL 실행 실패 시 무시
    }
  }

  Widget _buildPublisherLogo(String? logoUrl, String? publisherName) {
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return Image.network(
        logoUrl,
        width: 24,
        height: 24,
        errorBuilder: (context, error, stackTrace) {
          // 로고 로드 실패 시 publisher name 표시
          if (publisherName != null && publisherName.isNotEmpty) {
            return Text(
              publisherName,
              style: AppFonts.c2.copyWith(color: AppColors.gray600),
            );
          }
          return const SizedBox.shrink();
        },
      );
    } else if (publisherName != null && publisherName.isNotEmpty) {
      return Text(
        publisherName,
        style: AppFonts.c2.copyWith(color: AppColors.gray600),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: const AppHeader(title: '칼럼'),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: AppFonts.b1Regular.copyWith(
                          color: AppColors.gray600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadColumn,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                )
              : _column == null
                  ? Center(
                      child: Text(
                        '칼럼이 없습니다.',
                        style: AppFonts.b1Regular.copyWith(
                          color: AppColors.gray600,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 상단 이미지 (가로 꽉 차고 높이 짧게)
                          if (_column!.imageUrl != null && _column!.imageUrl!.isNotEmpty)
                            Image.network(
                              _column!.imageUrl!,
                              width: double.infinity,
                              height: context.h(137),
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  width: double.infinity,
                                  height: context.h(137),
                                  color: AppColors.gray100,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: double.infinity,
                                height: context.h(137),
                                color: AppColors.gray100,
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: AppColors.gray400,
                                  size: context.w(40),
                                ),
                              ),
                            ),
                          
                          // 내용 영역
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: context.w(20)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: context.h(16)),
                                
                                // 제목
                                Text(
                                  _column!.title,
                                  style: TextStyle(
                                    color: AppColors.gray900,
                                    fontSize: 18,
                                    fontFamily: 'Pretendard',
                                    fontWeight: FontWeight.w700,
                                    height: 1.17,
                                  ),
                                ),
                                SizedBox(height: context.h(8)),
                                
                                // 부제목
                                if (_column!.subtitle != null && _column!.subtitle!.isNotEmpty)
                                  Text(
                                    _column!.subtitle!,
                                    style: TextStyle(
                                      color: AppColors.gray600,
                                      fontSize: 14,
                                      fontFamily: 'Pretendard',
                                      fontWeight: FontWeight.w600,
                                      height: 1.50,
                                    ),
                                  ),
                                SizedBox(height: context.h(4)),
                                
                                // 날짜 ∙ 심볼명
                                Text(
                                  '${_formatDate(_column!.generatedAt ?? _column!.sourcePublishedAt)} ∙ ${_column!.ticker}',
                                  style: TextStyle(
                                    color: AppColors.gray400,
                                    fontSize: 10,
                                    fontFamily: 'Pretendard',
                                    fontWeight: FontWeight.w500,
                                    height: 2.10,
                                  ),
                                ),
                                SizedBox(height: context.h(16)),
                                
                                // 구분선
                                Container(
                                  width: double.infinity,
                                  height: 0.5,
                                  color: AppColors.gray150,
                                ),
                                SizedBox(height: context.h(24)),
                                
                                // 섹션들
                                ..._column!.sections.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final section = entry.value;
                                  
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: index < _column!.sections.length - 1
                                          ? context.h(32)
                                          : 0,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // 섹션 헤더
                                        if (section.header != null && section.header!.isNotEmpty)
                                          Padding(
                                            padding: EdgeInsets.only(bottom: context.h(8)),
                                            child: Text(
                                              section.header!,
                                              style: TextStyle(
                                                color: AppColors.gray900,
                                                fontSize: 15,
                                                fontFamily: 'Pretendard',
                                                fontWeight: FontWeight.w600,
                                                height: 1.40,
                                              ),
                                            ),
                                          ),
                                        
                                        // 섹션 본문 (body)
                                        if (section.body != null && section.body!.isNotEmpty)
                                          Padding(
                                            padding: EdgeInsets.only(bottom: context.h(8)),
                                            child: Text(
                                              _formatSectionBody(section.body!),
                                              style: TextStyle(
                                                color: AppColors.gray600,
                                                fontSize: 14,
                                                fontFamily: 'Pretendard',
                                                fontWeight: FontWeight.w500,
                                                height: 1.50,
                                              ),
                                            ),
                                          ),
                                        
                                        // 섹션 본문 (list)
                                        if (section.list != null && section.list!.isNotEmpty)
                                          ...section.list!.map((item) => Padding(
                                                padding: EdgeInsets.only(bottom: context.h(4)),
                                                child: Text(
                                                  item,
                                                  style: TextStyle(
                                                    color: AppColors.gray600,
                                                    fontSize: 14,
                                                    fontFamily: 'Pretendard',
                                                    fontWeight: FontWeight.w500,
                                                    height: 1.43,
                                                  ),
                                                ),
                                              )),
                                      ],
                                    ),
                                  );
                                }),
                                
                                SizedBox(height: context.h(32)),
                                
                                // 구분선
                                Container(
                                  width: double.infinity,
                                  height: 0.5,
                                  color: AppColors.gray150,
                                ),
                                SizedBox(height: context.h(16)),
                                
                                // 원본이 궁금하다면?
                                if (_hasSourceInfo())
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '원본이 궁금하다면?',
                                        style: AppFonts.c2.copyWith(
                                          color: AppColors.gray600,
                                        ),
                                      ),
                                      SizedBox(height: context.h(8)),
                                      
                                      // 원문 제목
                                      if (_column!.sourceTitle != null && _column!.sourceTitle!.isNotEmpty)
                                        Padding(
                                          padding: EdgeInsets.only(bottom: context.h(4)),
                                          child: Text(
                                            '원문: ${_column!.sourceTitle!}',
                                            style: AppFonts.c2.copyWith(
                                              color: AppColors.gray600,
                                            ),
                                          ),
                                        ),
                                      
                                      // 발행일
                                      if (_column!.sourcePublishedAt != null && _column!.sourcePublishedAt!.isNotEmpty)
                                        Padding(
                                          padding: EdgeInsets.only(bottom: context.h(4)),
                                          child: Builder(
                                            builder: (context) {
                                              final dateStr = _formatSourceDate(_column!.sourcePublishedAt);
                                              if (dateStr.isNotEmpty) {
                                                return Text(
                                                  '발행일: $dateStr',
                                                  style: AppFonts.c2.copyWith(
                                                    color: AppColors.gray600,
                                                  ),
                                                );
                                              }
                                              return const SizedBox.shrink();
                                            },
                                          ),
                                        ),
                                      
                                      // Publisher 정보 (로고 또는 이름)
                                      if (_column!.sourcePublisher != null && _column!.sourcePublisher!.isNotEmpty)
                                        Padding(
                                          padding: EdgeInsets.only(bottom: context.h(8)),
                                          child: Row(
                                            children: [
                                              _buildPublisherLogo(
                                                null, // TODO: publisherLogo 필드가 추가되면 여기에 전달
                                                _column!.sourcePublisher,
                                              ),
                                            ],
                                          ),
                                        ),
                                      
                                      // 원문 보기 버튼
                                      if (_column!.sourceUrl != null && _column!.sourceUrl!.isNotEmpty)
                                        TextButton(
                                          onPressed: () => _launchSourceUrl(_column!.sourceUrl),
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: Text(
                                            '원문 보기',
                                            style: AppFonts.c2.copyWith(
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                SizedBox(height: context.h(32)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}
