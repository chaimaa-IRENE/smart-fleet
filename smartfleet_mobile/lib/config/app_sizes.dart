import 'package:flutter/material.dart';

class AppSizes {
  static const double paddingXS = 4;
  static const double paddingS = 8;
  static const double paddingM = 12;
  static const double paddingL = 16;
  static const double paddingXL = 24;
  static const double paddingXXL = 32;

  static const double radiusS = 4;
  static const double radiusM = 8;
  static const double radiusL = 12;
  static const double radiusXL = 20;
  static const double radiusXXL = 28;

  static const double iconS = 16;
  static const double iconM = 24;
  static const double iconL = 32;
  static const double iconXL = 48;

  static const double fontS = 12;
  static const double fontM = 14;
  static const double fontL = 16;
  static const double fontXL = 18;
  static const double fontXXL = 24;
  static const double fontTitle = 28;

  static const double buttonHeight = 50;
  static const double cardElevation = 2;
  static const double appBarElevation = 2;

  static const EdgeInsets pagePadding = EdgeInsets.all(paddingL);
  static const EdgeInsets cardPadding = EdgeInsets.all(paddingL);
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: paddingL,
    vertical: paddingS,
  );

  static const SizedBox gapS = SizedBox(height: paddingS);
  static const SizedBox gapM = SizedBox(height: paddingM);
  static const SizedBox gapL = SizedBox(height: paddingL);
  static const SizedBox gapXL = SizedBox(height: paddingXL);
}
