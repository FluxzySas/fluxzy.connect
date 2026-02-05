import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

TextTheme createTextTheme(
    BuildContext context, String bodyFontString, String displayFontString) {
  TextTheme baseTextTheme = Theme.of(context).textTheme;
  TextTheme bodyTextTheme =
      GoogleFonts.getTextTheme(bodyFontString, baseTextTheme);
  TextTheme displayTextTheme =
      GoogleFonts.getTextTheme(displayFontString, baseTextTheme);
  TextTheme textTheme = displayTextTheme.copyWith(
    bodyLarge: bodyTextTheme.bodyLarge,
    bodyMedium: bodyTextTheme.bodyMedium,
    bodySmall: bodyTextTheme.bodySmall,
    labelLarge: bodyTextTheme.labelLarge,
    labelMedium: bodyTextTheme.labelMedium,
    labelSmall: bodyTextTheme.labelSmall,
  );
  // Scale up all font sizes slightly
  return _scaleTextTheme(textTheme, 1.1);
}

TextTheme _scaleTextTheme(TextTheme textTheme, double scale) {
  return TextTheme(
    displayLarge: _scaleTextStyle(textTheme.displayLarge, scale),
    displayMedium: _scaleTextStyle(textTheme.displayMedium, scale),
    displaySmall: _scaleTextStyle(textTheme.displaySmall, scale),
    headlineLarge: _scaleTextStyle(textTheme.headlineLarge, scale),
    headlineMedium: _scaleTextStyle(textTheme.headlineMedium, scale),
    headlineSmall: _scaleTextStyle(textTheme.headlineSmall, scale),
    titleLarge: _scaleTextStyle(textTheme.titleLarge, scale),
    titleMedium: _scaleTextStyle(textTheme.titleMedium, scale),
    titleSmall: _scaleTextStyle(textTheme.titleSmall, scale),
    bodyLarge: _scaleTextStyle(textTheme.bodyLarge, scale),
    bodyMedium: _scaleTextStyle(textTheme.bodyMedium, scale),
    bodySmall: _scaleTextStyle(textTheme.bodySmall, scale),
    labelLarge: _scaleTextStyle(textTheme.labelLarge, scale),
    labelMedium: _scaleTextStyle(textTheme.labelMedium, scale),
    labelSmall: _scaleTextStyle(textTheme.labelSmall, scale),
  );
}

TextStyle? _scaleTextStyle(TextStyle? style, double scale) {
  if (style == null) return null;
  return style.copyWith(
    fontSize: style.fontSize != null ? style.fontSize! * scale : null,
  );
}
