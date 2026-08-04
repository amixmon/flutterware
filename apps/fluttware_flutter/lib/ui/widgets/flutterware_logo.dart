import 'package:flutter/material.dart';

class FlutterwareLogo extends StatelessWidget {
  const FlutterwareLogo({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/branding/flutterware-mark.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
    semanticLabel: 'Flutterware logo',
  );
}
