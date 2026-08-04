import 'package:flutter/widgets.dart';

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
}

abstract final class AppRadii {
  static const double input = 16;
  static const double button = 16;
  static const double card = 20;
  static const double sheet = 28;
  static const double dialog = 28;

  static BorderRadius get inputBorder => BorderRadius.circular(input);
  static BorderRadius get buttonBorder => BorderRadius.circular(button);
  static BorderRadius get cardBorder => BorderRadius.circular(card);
}

abstract final class AppSizes {
  static const double buttonHeight = 52;
  static const double touchTarget = 48;
  static const double fieldGap = 14;
  static const double pageHorizontal = 20;
}
