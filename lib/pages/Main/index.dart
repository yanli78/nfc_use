import 'package:flutter/material.dart';
import 'package:nfc_use/pages/Home/index.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  // 核心：创建 PageController
  final PageController _pageController = PageController();

  final List<Widget> _pages = [
    HomePage(),
    Container(
      color: Colors.yellow,
      child: const Center(child: Text("设置")),
    ),
  ];

  @override
  void dispose() {
    // 销毁 Controller，防止内存泄漏
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        // 核心：用 PageView 替换 IndexedStack
        child: PageView(
          controller: _pageController,
          // 禁止左右滑动（如果想保留滑动，删掉这行）
          physics: const NeverScrollableScrollPhysics(),
          // 页面切换时更新底部栏索引
          onPageChanged: (index) => setState(() => _currentIndex = index),
          children: _pages,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        showUnselectedLabels: true,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          // 核心：点击底部栏时平滑跳转页面
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        selectedItemColor: const Color(0xFF00966A),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
