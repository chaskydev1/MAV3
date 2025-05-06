import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/utils/DarkThemeProvider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ButtonThem {
  static Widget buildButton(
    BuildContext context, {
    required String title,
    required Function() onPress,
    bool isEnabled = true, //habilitado boton (aceptar tarifa)
    double? btnHeight,
    double? btnWidthRatio,
    double btnRadius = 10,
    double txtSize = 16, // Agregar este parámetro
    final Color? textColor,
    final Color? bgColors,
    bool isVisible = true,
  }) {
    final themeChange = Provider.of<DarkThemeProvider>(context);

    return Visibility(
      visible: isVisible,
      child: InkWell(
        onTap: isEnabled ? onPress : null,
        child: Container(
          height: btnHeight ?? Responsive.height(5, context),
          width: btnWidthRatio == null ? Responsive.width(90, context) : Responsive.width(btnWidthRatio, context),
          decoration: BoxDecoration(
            color: isEnabled ? AppColors.primary : AppColors.darkGray,
            borderRadius: BorderRadius.all(Radius.circular(btnRadius)),
          ),
          child: Center(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                color: textColor ?? Colors.white, 
                fontSize: txtSize // Usar el parámetro aquí
              ),
            ),
          ),
        ),
      ),
    );
  }

  static buildBorderButton(
    BuildContext context, {
    required String title,
    double btnHeight = 50,
    double txtSize = 14,
    double btnWidthRatio = 0.9,
    double borderRadius = 10,
    required Function() onPress,
    bool isVisible = true,
    bool iconVisibility = false,
    String iconAssetImage = '',
    Color? iconColor,
  }) {
    final themeChange = Provider.of<DarkThemeProvider>(context);

    return Visibility(
      visible: isVisible,
      child: SizedBox(
        width: Responsive.width(100, context) * btnWidthRatio,
        height: btnHeight,
        child: ElevatedButton(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all<Color>(Colors.white),
            foregroundColor: MaterialStateProperty.all<Color>(themeChange.getThem() ? AppColors.darkModePrimary : AppColors.primary),
            shape: MaterialStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
                side: BorderSide(
                  color: themeChange.getThem() ? AppColors.darkModePrimary : AppColors.primary,
                ),
              ),
            ),
          ),
          onPressed: onPress,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Visibility(
                visible: iconVisibility,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Image.asset(iconAssetImage, fit: BoxFit.cover, width: 32, color: iconColor),
                ),
              ),
              Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.black, fontSize: txtSize, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static roundButton(
    BuildContext context, {
    required String title,
    double btnHeight = 48,
    double txtSize = 14,
    double btnWidthRatio = 0.9,
    required Function() onPress,
    bool isVisible = true,
  }) {
    final themeChange = Provider.of<DarkThemeProvider>(context);

    return Visibility(
      visible: isVisible,
      child: SizedBox(
        width: Responsive.width(100, context) * btnWidthRatio,
        child: MaterialButton(
          onPressed: onPress,
          height: btnHeight,
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          color: themeChange.getThem() ? AppColors.darkModePrimary : AppColors.primary,
          child: Text(
            title.toUpperCase(),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: txtSize, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
