import 'package:flutter/material.dart';
import 'package:nfc_use/core/constants/CardItem.dart';
import 'package:nfc_use/shared/card/index.dart';

class CardDetailScreen extends StatefulWidget {
  final CardItem item;

  const CardDetailScreen({super.key, required this.item});

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;

  Offset _dragOffset = Offset.zero;
  bool _isClosing = false;
  static const double _closeThreshold = 150;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOutBack,
          ),
        );
    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 1.0,
    ).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // 详情页手势：只允许向下滑动
  void _handleVerticalDragStart(DragStartDetails details) {
    if (_isClosing) return;
    _animationController.stop();
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_isClosing) return;
    // 只允许向下滑动（dy > 0）
    if (details.delta.dy > 0) {
      setState(() => _dragOffset += details.delta);
    }
  }

  void _handleVerticalDragEnd(DragEndDetails details) async {
    if (_isClosing) return;

    final double dragDistance = _dragOffset.dy; // 向下滑动的距离
    if (dragDistance > _closeThreshold) {
      await _closePage();
    } else {
      _animateBackToStart();
    }
  }

  // 关闭页面的动画
  Future<void> _closePage() async {
    setState(() => _isClosing = true);

    _slideAnimation =
        Tween<Offset>(
          begin: _dragOffset,
          end: const Offset(0, 1000), // 向下飞出屏幕
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInBack,
          ),
        );

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(_animationController);

    await _animationController.forward(from: 0);

    if (mounted) {
      Navigator.of(context).pop(); // 返回上一页
    }
  }

  // 回弹动画
  void _animateBackToStart() {
    _slideAnimation = Tween<Offset>(begin: _dragOffset, end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOutBack,
          ),
        );

    _animationController.forward(from: 0);
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _dragOffset = Offset.zero);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double progress = (_dragOffset.dy / _closeThreshold).clamp(0.0, 1.0);
    final double currentScale = 1.0 - (progress * 0.1);
    final double currentOpacity = 1.0 - (progress * 0.3);

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final Offset totalOffset = _isClosing
              ? _slideAnimation.value
              : (_dragOffset + (_slideAnimation.value - Offset.zero));

          return Opacity(
            opacity: _isClosing ? _opacityAnimation.value : currentOpacity,
            child: Transform.translate(
              offset: totalOffset,
              child: Transform.scale(scale: currentScale, child: child),
            ),
          );
        },
        child: GestureDetector(
          onVerticalDragStart: _handleVerticalDragStart,
          onVerticalDragUpdate: _handleVerticalDragUpdate,
          onVerticalDragEnd: _handleVerticalDragEnd,
          child: CustomScrollView(
            slivers: [
              // 顶部图片区域
              SliverAppBar(
                expandedHeight: 400,
                pinned: true,
                backgroundColor: widget.item.color,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    widget.item.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(widget.item.imageUrl, fit: BoxFit.cover),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.8),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              // 详情内容区域
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 下滑提示
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.grey[400],
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '下滑返回画廊',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.grey[400],
                            size: 24,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      Text(
                        widget.item.title,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.item.subtitle,
                        style: TextStyle(fontSize: 18, color: Colors.grey[300]),
                      ),
                      const SizedBox(height: 32),

                      // 功能按钮区域
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('已收藏：${widget.item.title}'),
                                    backgroundColor: widget.item.color,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.favorite_border),
                              label: const Text('收藏'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.item.color,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('已分享')),
                                );
                              },
                              icon: const Icon(Icons.share),
                              label: const Text('分享'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(color: Colors.grey[700]!),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // 详细描述
                      const Text(
                        '详细介绍',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.item.description,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[400],
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
