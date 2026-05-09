import 'package:flutter/material.dart';
import 'package:nfc_use/core/constants/CardItem.dart';

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

  Future<void> _closePage() async {
    setState(() => _isClosing = true);

    _slideAnimation =
        Tween<Offset>(begin: _dragOffset, end: const Offset(0, 1000)).animate(
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
      Navigator.of(context).pop();
    }
  }

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

  Widget _nfcPage() {
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white70,
                  size: 40,
                ),
                SizedBox(height: 10),
                Text(
                  '下滑返回',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEffect(double currentOpacity, double currentScale) {
    return Scaffold(
      backgroundColor: widget.item.color,
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
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (details) {
            if (_isClosing) return;
            _animationController.stop();
          },
          onVerticalDragUpdate: (details) {
            if (_isClosing) return;
            if (details.delta.dy > 0) {
              setState(() => _dragOffset += details.delta);
            }
          },
          onVerticalDragEnd: (details) async {
            if (_isClosing) return;
            final double dragDistance = _dragOffset.dy;
            if (dragDistance > _closeThreshold) {
              await _closePage();
            } else {
              _animateBackToStart();
            }
          },
          child: _nfcPage(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double progress = (_dragOffset.dy / _closeThreshold).clamp(0.0, 1.0);
    final double currentScale = 1.0 - (progress * 0.1);
    final double currentOpacity = 1.0 - (progress * 0.3);

    return _buildEffect(currentOpacity, currentScale);
  }
}
