import 'package:driver/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Styles {
  static ThemeData themeData(bool isDarkTheme, BuildContext context) {
    return ThemeData(
      primarySwatch: Colors.red,
      useMaterial3: false,
      colorScheme: ColorScheme(
          brightness: isDarkTheme ? Brightness.dark : Brightness.light,
          primary: isDarkTheme ? AppColors.darkModePrimary : AppColors.greenA,
          onPrimary: isDarkTheme ? AppColors.greenA : AppColors.darkModePrimary,
          secondary: isDarkTheme ? AppColors.whiteA : AppColors.background,
          onSecondary: isDarkTheme ? AppColors.whiteA : AppColors.background,
          error: isDarkTheme ? AppColors.whiteA : AppColors.background,
          onError: isDarkTheme ? AppColors.whiteA : AppColors.background,
          background: isDarkTheme ? AppColors.whiteA : AppColors.background,
          onBackground: isDarkTheme ? AppColors.whiteA : AppColors.background,
          surface: isDarkTheme ? AppColors.whiteA : AppColors.background,
          onSurface: isDarkTheme ? AppColors.whiteA : AppColors.background),
      primaryColor: isDarkTheme ? AppColors.greenA : AppColors.darkModePrimary,
      hintColor: isDarkTheme ? Colors.white38 : Colors.black38,
      brightness: isDarkTheme ? Brightness.dark : Brightness.light,
      buttonTheme: ButtonThemeData(
        textTheme: ButtonTextTheme.primary, //  <-- dark text for light background
        colorScheme: Theme.of(context).colorScheme.copyWith(primary: isDarkTheme ? AppColors.darkModePrimary : AppColors.greenA),
      ),
      appBarTheme: AppBarTheme(centerTitle: true, iconTheme: const IconThemeData(color: Colors.white), titleTextStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 16)),
    );
  }
}
