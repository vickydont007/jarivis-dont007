import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class VoiceWaveform extends StatefulWidget {
  final bool isActive;
  final int barCount;
  final double height;
  final double barWidth;
  final Color? color;

  const VoiceWaveform({
    super.key,
    this.isActive = false,
    this.barCount = 5,
    this.height = 40,
    this.barWidth = 2.0,
    this.color,
  });

  @override
  State<VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<VoiceWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _heights = [];

  @override
  void initState() {
    super.initState();
    _heights.addAll(List.filled(widget.barCount, 0.3));

    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(VoiceWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
      setState(() {
        _heights.clear();
        _heights.addAll(List.filled(widget.barCount, 0.3));
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final random = Random(42);
        for (int i = 0; i < widget.barCount; i++) {
          final normalizedI = i / (widget.barCount - 1);
          final baseHeight = 0.3 + (sin(_controller.value * pi * 2 + normalizedI * pi) * 0.3 + 0.3);
          _heights[i] = baseHeight * (0.6 + random.nextDouble() * 0.4);
        }

        return SizedBox(
          height: widget.height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(widget.barCount, (index) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.barWidth),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: widget.barWidth,
                  height: widget.height * _heights[index],
                  decoration: BoxDecoration(
                    color: widget.color ?? AppColors.accent,
                    borderRadius: BorderRadius.circular(widget.barWidth / 2),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
