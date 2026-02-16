import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 90});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/school_logo.png',
      height: height,
      errorBuilder: (context, error, stackTrace) {
        return Icon(Icons.school, size: height);
      },
    );
  }
}
