import 'package:flutter/material.dart';
import 'dart:ui';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final Color? color;
  final double opacity;
  final double borderRadius;
  
  const GlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.color,
    this.opacity = 0.85,
    this.borderRadius = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (color ?? Colors.black).withOpacity(opacity),
            (color ?? Colors.black).withOpacity(opacity - 0.1),
          ],
        ),
        border: Border.all(
          width: 1.0,
          color: Colors.purple.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.1),
            blurRadius: 20.0,
            spreadRadius: 2.0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: child,
        ),
      ),
    );
  }
}