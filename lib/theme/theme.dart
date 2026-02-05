import "package:flutter/material.dart";

class MaterialTheme {
  final TextTheme textTheme;

  const MaterialTheme(this.textTheme);

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff69548d),
      surfaceTint: Color(0xff69548d),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xffebdcff),
      onPrimaryContainer: Color(0xff503c74),
      secondary: Color(0xff635b70),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xffeadef7),
      onSecondaryContainer: Color(0xff4b4358),
      tertiary: Color(0xff7f525d),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xffffd9e0),
      onTertiaryContainer: Color(0xff643b45),
      error: Color(0xffba1a1a),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffffdad6),
      onErrorContainer: Color(0xff93000a),
      surface: Color(0xfffef7ff),
      onSurface: Color(0xff1d1b20),
      onSurfaceVariant: Color(0xff49454e),
      outline: Color(0xff7a757f),
      outlineVariant: Color(0xffcbc4cf),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff322f35),
      inversePrimary: Color(0xffd4bbfc),
      primaryFixed: Color(0xffebdcff),
      onPrimaryFixed: Color(0xff230e45),
      primaryFixedDim: Color(0xffd4bbfc),
      onPrimaryFixedVariant: Color(0xff503c74),
      secondaryFixed: Color(0xffeadef7),
      onSecondaryFixed: Color(0xff1f182a),
      secondaryFixedDim: Color(0xffcdc2db),
      onSecondaryFixedVariant: Color(0xff4b4358),
      tertiaryFixed: Color(0xffffd9e0),
      onTertiaryFixed: Color(0xff32101b),
      tertiaryFixedDim: Color(0xfff1b7c4),
      onTertiaryFixedVariant: Color(0xff643b45),
      surfaceDim: Color(0xffded8e0),
      surfaceBright: Color(0xfffef7ff),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff8f1fa),
      surfaceContainer: Color(0xfff2ecf4),
      surfaceContainerHigh: Color(0xffede6ee),
      surfaceContainerHighest: Color(0xffe7e0e8),
    );
  }

  ThemeData light() {
    return theme(lightScheme());
  }

  static ColorScheme lightMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff3f2b62),
      surfaceTint: Color(0xff69548d),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff78639d),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff3a3346),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff72697f),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff512a35),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff8f606b),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff740006),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffcf2c27),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfffef7ff),
      onSurface: Color(0xff121016),
      onSurfaceVariant: Color(0xff38353d),
      outline: Color(0xff55515a),
      outlineVariant: Color(0xff706b75),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff322f35),
      inversePrimary: Color(0xffd4bbfc),
      primaryFixed: Color(0xff78639d),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff5f4a83),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff72697f),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff595166),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff8f606b),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff744853),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffcac4cc),
      surfaceBright: Color(0xfffef7ff),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff8f1fa),
      surfaceContainer: Color(0xffede6ee),
      surfaceContainerHigh: Color(0xffe1dbe3),
      surfaceContainerHighest: Color(0xffd6d0d7),
    );
  }

  ThemeData lightMediumContrast() {
    return theme(lightMediumContrastScheme());
  }

  static ColorScheme lightHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff352157),
      surfaceTint: Color(0xff69548d),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xff533f76),
      onPrimaryContainer: Color(0xffffffff),
      secondary: Color(0xff30293c),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xff4e465a),
      onSecondaryContainer: Color(0xffffffff),
      tertiary: Color(0xff45212b),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xff673d48),
      onTertiaryContainer: Color(0xffffffff),
      error: Color(0xff600004),
      onError: Color(0xffffffff),
      errorContainer: Color(0xff98000a),
      onErrorContainer: Color(0xffffffff),
      surface: Color(0xfffef7ff),
      onSurface: Color(0xff000000),
      onSurfaceVariant: Color(0xff000000),
      outline: Color(0xff2e2b33),
      outlineVariant: Color(0xff4c4750),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff322f35),
      inversePrimary: Color(0xffd4bbfc),
      primaryFixed: Color(0xff533f76),
      onPrimaryFixed: Color(0xffffffff),
      primaryFixedDim: Color(0xff3b285e),
      onPrimaryFixedVariant: Color(0xffffffff),
      secondaryFixed: Color(0xff4e465a),
      onSecondaryFixed: Color(0xffffffff),
      secondaryFixedDim: Color(0xff372f43),
      onSecondaryFixedVariant: Color(0xffffffff),
      tertiaryFixed: Color(0xff673d48),
      onTertiaryFixed: Color(0xffffffff),
      tertiaryFixedDim: Color(0xff4d2731),
      onTertiaryFixedVariant: Color(0xffffffff),
      surfaceDim: Color(0xffbdb7be),
      surfaceBright: Color(0xfffef7ff),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfff5eff7),
      surfaceContainer: Color(0xffe7e0e8),
      surfaceContainerHigh: Color(0xffd9d2da),
      surfaceContainerHighest: Color(0xffcac4cc),
    );
  }

  ThemeData lightHighContrast() {
    return theme(lightHighContrastScheme());
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffd4bbfc),
      surfaceTint: Color(0xffd4bbfc),
      onPrimary: Color(0xff39255c),
      primaryContainer: Color(0xff503c74),
      onPrimaryContainer: Color(0xffebdcff),
      secondary: Color(0xffcdc2db),
      onSecondary: Color(0xff342d40),
      secondaryContainer: Color(0xff4b4358),
      onSecondaryContainer: Color(0xffeadef7),
      tertiary: Color(0xfff1b7c4),
      onTertiary: Color(0xff4a252f),
      tertiaryContainer: Color(0xff643b45),
      onTertiaryContainer: Color(0xffffd9e0),
      error: Color(0xffffb4ab),
      onError: Color(0xff690005),
      errorContainer: Color(0xff93000a),
      onErrorContainer: Color(0xffffdad6),
      surface: Color(0xff151218),
      onSurface: Color(0xffe7e0e8),
      onSurfaceVariant: Color(0xffcbc4cf),
      outline: Color(0xff948f99),
      outlineVariant: Color(0xff49454e),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe7e0e8),
      inversePrimary: Color(0xff69548d),
      primaryFixed: Color(0xffebdcff),
      onPrimaryFixed: Color(0xff230e45),
      primaryFixedDim: Color(0xffd4bbfc),
      onPrimaryFixedVariant: Color(0xff503c74),
      secondaryFixed: Color(0xffeadef7),
      onSecondaryFixed: Color(0xff1f182a),
      secondaryFixedDim: Color(0xffcdc2db),
      onSecondaryFixedVariant: Color(0xff4b4358),
      tertiaryFixed: Color(0xffffd9e0),
      onTertiaryFixed: Color(0xff32101b),
      tertiaryFixedDim: Color(0xfff1b7c4),
      onTertiaryFixedVariant: Color(0xff643b45),
      surfaceDim: Color(0xff151218),
      surfaceBright: Color(0xff3b383e),
      surfaceContainerLowest: Color(0xff0f0d13),
      surfaceContainerLow: Color(0xff1d1b20),
      surfaceContainer: Color(0xff211f24),
      surfaceContainerHigh: Color(0xff2c292f),
      surfaceContainerHighest: Color(0xff37343a),
    );
  }

  ThemeData dark() {
    return theme(darkScheme());
  }

  static ColorScheme darkMediumContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xffe6d5ff),
      surfaceTint: Color(0xffd4bbfc),
      onPrimary: Color(0xff2e1a50),
      primaryContainer: Color(0xff9c86c3),
      onPrimaryContainer: Color(0xff000000),
      secondary: Color(0xffe4d8f1),
      onSecondary: Color(0xff292235),
      secondaryContainer: Color(0xff968da4),
      onSecondaryContainer: Color(0xff000000),
      tertiary: Color(0xffffd1da),
      onTertiary: Color(0xff3e1a25),
      tertiaryContainer: Color(0xffb6838f),
      onTertiaryContainer: Color(0xff000000),
      error: Color(0xffffd2cc),
      onError: Color(0xff540003),
      errorContainer: Color(0xffff5449),
      onErrorContainer: Color(0xff000000),
      surface: Color(0xff151218),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffe1dae5),
      outline: Color(0xffb6b0ba),
      outlineVariant: Color(0xff948e98),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe7e0e8),
      inversePrimary: Color(0xff513e75),
      primaryFixed: Color(0xffebdcff),
      onPrimaryFixed: Color(0xff19023b),
      primaryFixedDim: Color(0xffd4bbfc),
      onPrimaryFixedVariant: Color(0xff3f2b62),
      secondaryFixed: Color(0xffeadef7),
      onSecondaryFixed: Color(0xff140e1f),
      secondaryFixedDim: Color(0xffcdc2db),
      onSecondaryFixedVariant: Color(0xff3a3346),
      tertiaryFixed: Color(0xffffd9e0),
      onTertiaryFixed: Color(0xff250610),
      tertiaryFixedDim: Color(0xfff1b7c4),
      onTertiaryFixedVariant: Color(0xff512a35),
      surfaceDim: Color(0xff151218),
      surfaceBright: Color(0xff47434a),
      surfaceContainerLowest: Color(0xff08070b),
      surfaceContainerLow: Color(0xff1f1d22),
      surfaceContainer: Color(0xff29272d),
      surfaceContainerHigh: Color(0xff343137),
      surfaceContainerHighest: Color(0xff403c43),
    );
  }

  ThemeData darkMediumContrast() {
    return theme(darkMediumContrastScheme());
  }

  static ColorScheme darkHighContrastScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xfff6ecff),
      surfaceTint: Color(0xffd4bbfc),
      onPrimary: Color(0xff000000),
      primaryContainer: Color(0xffd0b8f8),
      onPrimaryContainer: Color(0xff120030),
      secondary: Color(0xfff6ecff),
      onSecondary: Color(0xff000000),
      secondaryContainer: Color(0xffc9bed7),
      onSecondaryContainer: Color(0xff0e0819),
      tertiary: Color(0xffffebee),
      onTertiary: Color(0xff000000),
      tertiaryContainer: Color(0xffedb4c0),
      onTertiaryContainer: Color(0xff1d020a),
      error: Color(0xffffece9),
      onError: Color(0xff000000),
      errorContainer: Color(0xffffaea4),
      onErrorContainer: Color(0xff220001),
      surface: Color(0xff151218),
      onSurface: Color(0xffffffff),
      onSurfaceVariant: Color(0xffffffff),
      outline: Color(0xfff5edf9),
      outlineVariant: Color(0xffc7c0cb),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe7e0e8),
      inversePrimary: Color(0xff513e75),
      primaryFixed: Color(0xffebdcff),
      onPrimaryFixed: Color(0xff000000),
      primaryFixedDim: Color(0xffd4bbfc),
      onPrimaryFixedVariant: Color(0xff19023b),
      secondaryFixed: Color(0xffeadef7),
      onSecondaryFixed: Color(0xff000000),
      secondaryFixedDim: Color(0xffcdc2db),
      onSecondaryFixedVariant: Color(0xff140e1f),
      tertiaryFixed: Color(0xffffd9e0),
      onTertiaryFixed: Color(0xff000000),
      tertiaryFixedDim: Color(0xfff1b7c4),
      onTertiaryFixedVariant: Color(0xff250610),
      surfaceDim: Color(0xff151218),
      surfaceBright: Color(0xff524f55),
      surfaceContainerLowest: Color(0xff000000),
      surfaceContainerLow: Color(0xff211f24),
      surfaceContainer: Color(0xff322f35),
      surfaceContainerHigh: Color(0xff3d3a40),
      surfaceContainerHighest: Color(0xff49454c),
    );
  }

  ThemeData darkHighContrast() {
    return theme(darkHighContrastScheme());
  }

  ThemeData theme(ColorScheme colorScheme) => ThemeData(
        useMaterial3: true,
        brightness: colorScheme.brightness,
        colorScheme: colorScheme,
        textTheme: textTheme.apply(
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
        ),
        scaffoldBackgroundColor: colorScheme.surface,
        canvasColor: colorScheme.surface,
      );

  List<ExtendedColor> get extendedColors => [];
}

class ExtendedColor {
  final Color seed, value;
  final ColorFamily light;
  final ColorFamily lightHighContrast;
  final ColorFamily lightMediumContrast;
  final ColorFamily dark;
  final ColorFamily darkHighContrast;
  final ColorFamily darkMediumContrast;

  const ExtendedColor({
    required this.seed,
    required this.value,
    required this.light,
    required this.lightHighContrast,
    required this.lightMediumContrast,
    required this.dark,
    required this.darkHighContrast,
    required this.darkMediumContrast,
  });
}

class ColorFamily {
  const ColorFamily({
    required this.color,
    required this.onColor,
    required this.colorContainer,
    required this.onColorContainer,
  });

  final Color color;
  final Color onColor;
  final Color colorContainer;
  final Color onColorContainer;
}
