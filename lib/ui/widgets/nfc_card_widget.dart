import 'package:flutter/material.dart';
import 'package:nfc_use/models/nfc_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 模拟的本地卡片数据
  final List<NfcCardInfo> _cards = [
    NfcCardInfo(
      id: '04:A1:B2:C3',
      title: '门禁卡 (宿舍)',
      description: '用于开启前端大门',
      cardColor: Colors.blueAccent,
    ),
    NfcCardInfo(
      id: '04:D4:E5:F6',
      title: '启动卡 (电脑)',
      description: '碰一碰唤醒工作站',
      cardColor: Colors.orangeAccent,
    ),
    NfcCardInfo(
      id: '04:G7:H8:I9',
      title: '快捷指令卡',
      description: '触发特定场景模式',
      cardColor: Colors.purpleAccent,
    ),
  ];

  late PageController _pageController;
  int _currentIndex = 0;
  bool _isSyncing = false; // 同步状态标志位

  @override
  void initState() {
    super.initState();
    // viewportFraction 设为 0.8 可以让旁边未选中的卡片露出一点边缘
    _pageController = PageController(viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 模拟同步操作
  Future<void> _handleSync() async {
    setState(() {
      _isSyncing = true;
    });

    // TODO: 在这里调用你的单片机同步接口 (ESP32 网络请求或蓝牙通信)
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isSyncing = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('数据同步完成！')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC 卡包'),
        actions: [
          // 同步按钮
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            tooltip: '与设备同步',
            onPressed: _isSyncing ? null : _handleSync,
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 卡片滑动区域
          SizedBox(
            height: 220,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _cards.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return _buildCardWidget(_cards[index], index == _currentIndex);
              },
            ),
          ),
          const SizedBox(height: 40),
          // 底部操作区指示
          Text(
            '当前选中: ${_cards[_currentIndex].title}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'UID: ${_cards[_currentIndex].id}',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 40),
          // 预留的操作按钮（例如：写入此卡、分享等）
          ElevatedButton.icon(
            onPressed: () {
              // TODO: 处理当前卡片的具体逻辑
            },
            icon: const Icon(Icons.nfc),
            label: const Text('激活此卡片'),
          ),
        ],
      ),
    );
  }

  // 单个卡片的 UI 构建
  Widget _buildCardWidget(NfcCardInfo card, bool isActive) {
    // 简单的缩放动画效果，选中的卡片更大一点
    final double margin = isActive ? 10.0 : 20.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutQuint,
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: margin),
      decoration: BoxDecoration(
        color: card.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: isActive ? 15 : 5,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.contactless, color: Colors.white, size: 32),
            const Spacer(),
            Text(
              card.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              card.description,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
