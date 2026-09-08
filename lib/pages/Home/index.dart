import 'package:flutter/material.dart';
import 'package:nfc_use/core/constants/card_item.dart';
import 'package:nfc_use/core/services/sqlite_service.dart';
import 'package:nfc_use/pages/Home/card_use.dart';
import 'package:nfc_use/pages/Home/card.dart';

/// 主页组件
///
/// 展示卡片画廊列表，支持左右滑动切换卡片、上滑查看详情等交互。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

/// 主页状态类
///
/// 管理页面控制器、当前页面索引、卡片重置回调等内部状态。
class _HomePageState extends State<HomePage> {
  /// 页面控制器，用于卡片横向滑动
  final PageController _pageController = PageController(
    viewportFraction: kCardListViewportFraction,
    initialPage: 0,
  );

  /// 当前显示的页面索引
  int _currentPage = 0;

  /// 当前卡片的重置函数引用，用于页面返回后恢复卡片状态
  Function? _currentResetCard;

  /// 保存每个卡片的GlobalKey，用于触发卡片动画
  final List<GlobalKey> _cardKeys = [];

  bool _isLoadingCards = true;

  /// 当前展示卡片数据列表
  List<CardItem> _cardItems = [];

  /// 示例卡片数据列表
  static final List<CardItem> _sampleCardItems = [
    CardItem(
      id: 'NONE',
      title: 'NONE',
      color: kCardDefaultColors['explore']!,
      imageUrl:
          'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=800&q=80',
    ),
  ];

  @override
  void initState() {
    super.initState();
    CardDatabaseHelper.instance.cardsRevision.addListener(_loadCards);
    _loadCards();
  }

  @override
  void dispose() {
    CardDatabaseHelper.instance.cardsRevision.removeListener(_loadCards);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadCards() async {
    final cards = await CardDatabaseHelper.instance.getAllCards();
    if (!mounted) return;
    setState(() {
      _cardItems = cards.isEmpty ? _sampleCardItems : cards;
      _isLoadingCards = false;
      _currentPage = _cardItems.isEmpty
          ? 0
          : _currentPage.clamp(0, _cardItems.length - 1).toInt();
      _syncCardKeys();
    });
  }

  void _syncCardKeys() {
    while (_cardKeys.length < _cardItems.length) {
      _cardKeys.add(GlobalKey());
    }
    if (_cardKeys.length > _cardItems.length) {
      _cardKeys.removeRange(_cardItems.length, _cardKeys.length);
    }
  }

  /// 触发当前卡片的上滑动画
  void _triggerCurrentCard() {
    if (_currentPage >= 0 && _currentPage < _cardKeys.length) {
      InteractiveGalleryCard.triggerAnimation(_cardKeys[_currentPage]);
    }
  }

  /// 打开详情页，等页面过渡完成后再重置卡片状态
  ///
  /// [item] 要展示的卡片数据
  /// [resetCard] 卡片重置回调函数
  void _openDetailPage(CardItem item, Function resetCard) {
    _currentResetCard = resetCard;
    Navigator.of(context)
        .push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                CardDetailScreen(item: item),
            reverseTransitionDuration: const Duration(milliseconds: 340),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  const begin = Offset(0.0, 1.0);
                  const end = Offset.zero;

                  var tween = Tween(
                    begin: begin,
                    end: end,
                  ).chain(CurveTween(curve: Curves.easeOutCubic));
                  var offsetAnimation = animation.drive(tween);
                  var opacityAnimation = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutQuad,
                  );

                  return SlideTransition(
                    position: offsetAnimation,
                    child: FadeTransition(
                      opacity: opacityAnimation,
                      child: child,
                    ),
                  );
                },
            transitionDuration: kCardExitDuration,
          ),
        )
        .then((_) {
          _resetCurrentCard();
        });

    Future.delayed(const Duration(milliseconds: 420), () {
      _resetCurrentCard();
    });
  }

  /// 执行当前卡片的重置操作
  void _resetCurrentCard() {
    final resetCard = _currentResetCard;
    _currentResetCard = null;
    resetCard?.call();
  }

  /// 构建顶部标题区域
  Widget _buildHeader() {
    return _SimpleSwipeDetector(
      onSwipeUp: _triggerCurrentCard,
      child: const Padding(
        padding: EdgeInsets.only(left: 24, top: 40, bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '精选画廊',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '左右滑动切换 · 上滑任意位置查看详情',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建卡片列表区域
  Widget _buildCardList() {
    if (_isLoadingCards) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }

    return Expanded(
      child: Stack(
        children: [
          Positioned.fill(
            child: _SimpleSwipeDetector(
              onSwipeUp: _triggerCurrentCard,
              child: Container(color: Colors.transparent),
            ),
          ),
          PageView.builder(
            controller: _pageController,
            itemCount: _cardItems.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final item = _cardItems[index];

              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_pageController.position.haveDimensions) {
                    value = (_pageController.page! - index);
                    value = (1 - (value.abs() * 0.1)).clamp(0.8, 1.0);
                  }
                  return Center(
                    child: SizedBox(
                      height:
                          Curves.easeInOut.transform(value) *
                          kCardDefaultHeight,
                      child: child,
                    ),
                  );
                },
                child: InteractiveGalleryCard(
                  key: _cardKeys[index],
                  item: item,
                  isActive: _currentPage == index,
                  onTriggerWithReset: (resetCard) =>
                      _openDetailPage(item, resetCard),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 构建底部指示器区域
  Widget _buildEnd() {
    return _SimpleSwipeDetector(
      onSwipeUp: _triggerCurrentCard,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_cardItems.length, (index) {
                return Container(
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _currentPage == index
                        ? const Color(0xFF00966A)
                        : Colors.grey[300],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_buildHeader(), _buildCardList(), _buildEnd()],
        ),
      ),
    );
  }
}

/// 简单的上滑手势检测组件
///
/// 检测用户的上滑操作，并触发回调。
class _SimpleSwipeDetector extends StatefulWidget {
  /// 上滑回调
  final VoidCallback? onSwipeUp;

  /// 子组件
  final Widget child;

  const _SimpleSwipeDetector({required this.child, this.onSwipeUp});

  @override
  State<_SimpleSwipeDetector> createState() => __SimpleSwipeDetectorState();
}

class __SimpleSwipeDetectorState extends State<_SimpleSwipeDetector> {
  /// 拖动起始位置
  Offset? _dragStartPosition;

  /// 当前拖动距离
  double _dragDistance = 0;

  /// 最小滑动距离阈值
  static const double _minSwipeDistance = 48;

  /// 最小滑动速度阈值
  static const double _minSwipeVelocity = 360;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (details) {
        _dragStartPosition = details.localPosition;
        _dragDistance = 0;
      },
      onVerticalDragUpdate: (details) {
        if (details.delta.dy < 0) {
          _dragDistance -= details.delta.dy;
        }
      },
      onVerticalDragEnd: (details) {
        if (_dragStartPosition == null) return;

        final bool hasEnoughDistance = _dragDistance >= _minSwipeDistance;
        final bool hasEnoughVelocity =
            details.primaryVelocity != null &&
            details.primaryVelocity! < -_minSwipeVelocity;

        if (hasEnoughDistance || hasEnoughVelocity) {
          widget.onSwipeUp?.call();
        }
        _dragStartPosition = null;
        _dragDistance = 0;
      },
      child: widget.child,
    );
  }
}
