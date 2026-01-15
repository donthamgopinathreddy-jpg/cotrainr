import 'package:flutter/material.dart';

class GradientIconBlob extends StatelessWidget {
  final IconData icon;
  final LinearGradient gradient;
  final double size;
  final double iconSize;

  const GradientIconBlob({
    super.key,
    required this.icon,
    required this.gradient,
    this.size = 48.0,
    this.iconSize = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: iconSize,
      ),
    );
  }
}

