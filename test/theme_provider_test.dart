import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshflag/theme/theme_provider.dart';

void main() {
  test('FreshFlag exposes distinct light and dark themes', () {
    expect(ThemeProvider.lightTheme.brightness, Brightness.light);
    expect(ThemeProvider.darkTheme.brightness, Brightness.dark);
    expect(
      ThemeProvider.lightTheme.scaffoldBackgroundColor,
      isNot(ThemeProvider.darkTheme.scaffoldBackgroundColor),
    );
  });

  test('dark theme keeps a usable Material color scheme', () {
    final scheme = ThemeProvider.darkTheme.colorScheme;
    expect(scheme.brightness, Brightness.dark);
    expect(scheme.primary, isNot(scheme.surface));
  });
}
