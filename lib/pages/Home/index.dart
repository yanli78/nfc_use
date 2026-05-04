import 'package:flutter/material.dart';
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

  // 示例卡片数据
  final List<Map<String, dynamic>> _cardData = [
    {
      'title': '探索宇宙',
      'subtitle': '仰望星空，探索未知的奥秘',
      'color': const Color(0xFF667eea),
      'image':
          'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=800&q=80',
    },
    {
      'title': '城市夜景',
      'subtitle': '霓虹灯下的都市生活',
      'color': const Color(0xFFf093fb),
      'image':
          'https://images.unsplash.com/photo-1514565131-fce0801e5785?w=800&q=80',
    },
    {
      'title': '自然风光',
      'subtitle': '远离喧嚣，回归自然',
      'color': const Color(0xFF4facfe),
      'image':
          'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800&q=80',
    },
    {
      'title': '科技未来',
      'subtitle': '创新科技，引领未来',
      'color': const Color(0xFF43e97b),
      'image':
          'https://images.unsplash.com/photo-1485827404703-89b55fcc595e?w=800&q=80',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 核心：卡片滑动触发的功能
  void _onCardTriggered(int index) {
    final item = _cardData[index];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('已触发：${item['title']}'),
        content: Text('这里可以打开详情页、跳转页面或执行其他操作。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
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
          children: [
            // 1. 顶部标题区域
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
                    '左右滑动切换 · 上滑当前卡片触发功能',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // 2. 中间核心卡片区域
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _cardData.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final item = _cardData[index];

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
                              380, // 稍微加高一点给滑动留空间
                          child: child,
                        ),
                      );
                    },
                    // 核心：使用 GalleryCard
                    child: GalleryCard(
                      title: item['title'],
                      subtitle: item['subtitle'],
                      color: item['color'],
                      imageUrl: item['image'],
                      isActive: _currentPage == index, // 只有当前页的卡片是活跃的
                      onTrigger: () => _onCardTriggered(index),
                    ),
                  );
                },
              ),
            ),

            // 3. 指示器
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_cardData.length, (index) {
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
          ],
        ),
      ),
    );
  }
}
