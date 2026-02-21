import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class CustomLoader extends StatelessWidget {
  final double? width;
  final double? height;

  const CustomLoader({super.key, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Lottie.asset(
        'assets/animations/loader.json',
        width: width ?? 100,
        height: height ?? 100,
        fit: BoxFit.contain,
      ),
    );
  }
}
