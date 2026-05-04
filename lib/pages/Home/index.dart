import 'package:flutter/material.dart';
import 'package:nfc_use/core/constants/CardItem.dart';
import 'package:nfc_use/pages/Cards/card_use.dart';
import 'package:nfc_use/shared/card/index.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _pageController = PageController(
    viewportFraction: 0.8,
    initialPage: 0,
  );
  int _currentPage = 0;

  // 示例数据
  final List<CardItem> _cardItems = [
    CardItem(
      title: '探索宇宙',
      subtitle: '仰望星空，探索未知的奥秘',
      description:
          '宇宙是一个充满神秘和未知的地方。从最小的原子到最大的星系，宇宙中的一切都遵循着物理定律运行。人类对宇宙的探索从未停止，从伽利略的望远镜到现代的太空探测器，我们正在一步步揭开宇宙的神秘面纱。',
      color: const Color(0xFF667eea),
      imageUrl:
          'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=800&q=80',
    ),
    CardItem(
      title: '城市夜景',
      subtitle: '霓虹灯下的都市生活',
      description:
          '当夜幕降临，城市便换上了另一副面孔。霓虹灯闪烁，车水马龙，高楼大厦的灯光构成了一幅美丽的画卷。城市的夜晚充满了活力和机遇，每一盏灯背后都有一个故事。',
      color: const Color(0xFFf093fb),
      imageUrl:
          'https://images.unsplash.com/photo-1514565131-fce0801e5785?w=800&q=80',
    ),
    CardItem(
      title: '自然风光',
      subtitle: '远离喧嚣，回归自然',
      description:
          '大自然是最伟大的艺术家。从雄伟的山川到宁静的湖泊，从茂密的森林到广阔的草原，自然的美景总是让人心旷神怡。走进大自然，感受生命的力量，让心灵得到净化。',
      color: const Color(0xFF4facfe),
      imageUrl:
          'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800&q=80',
    ),
    CardItem(
      title: '科技未来',
      subtitle: '创新科技，引领未来',
      description:
          '科技正在改变我们的生活。人工智能、量子计算、太空探索、生物技术...每一项创新都在推动人类社会向前发展。未来已来，让我们一起见证科技带来的无限可能。',
      color: const Color(0xFF43e97b),
      imageUrl:
          'https://images.unsplash.com/photo-1485827404703-89b55fcc595e?w=800&q=80',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 核心：打开详情页
  void _openDetailPage(CardItem item) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CardDetailScreen(item: item),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // 自定义页面切换动画：从下方淡入
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
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
          children: [
            const Padding(
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
                    '左右滑动切换 · 上滑当前卡片查看详情',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),

            Expanded(
              child: PageView.builder(
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
                          height: Curves.easeInOut.transform(value) * 380,
                          child: child,
                        ),
                      );
                    },
                    child: InteractiveGalleryCard(
                      title: item.title,
                      subtitle: item.subtitle,
                      color: item.color,
                      imageUrl: item.imageUrl,
                      isActive: _currentPage == index,
                      onTrigger: () => _openDetailPage(item),
                    ),
                  );
                },
              ),
            ),

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
      ),
    );
  }
}
