import 'package:flutter/material.dart';

class AnKiFadeIn extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const AnKiFadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  @override
  State<AnKiFadeIn> createState() => _AnKiFadeInState();
}

class _AnKiFadeInState extends State<AnKiFadeIn>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 600);
  static const _offset = Offset(0, 0.05);
  static const _curve = Curves.easeOutCubic;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: _curve),
      ),
    );

    _slideAnimation = Tween<Offset>(begin: _offset, end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: _curve),
      ),
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}
