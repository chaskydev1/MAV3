import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Agregar esta línea
import 'package:country_code_picker/country_code_picker.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/controller/global_setting_conroller.dart';
import 'package:driver/firebase_options.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/ui/splash_screen.dart';
import 'package:driver/utils/DarkThemeProvider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'services/localization_service.dart';
import 'themes/Styles.dart';
import 'utils/Preferences.dart';
//here

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Agregar esta línea para inicializar el locale español
  await initializeDateFormatting('es');
  
  await Firebase.initializeApp(
    name: 'driver_app',
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Preferences.initPref();
  EasyLoading.instance
    ..displayDuration = const Duration(seconds: 2)
    ..indicatorType = EasyLoadingIndicatorType.fadingCircle
    ..loadingStyle = EasyLoadingStyle.custom
    ..backgroundColor = AppColors.darkModePrimary
    ..textColor = Colors.black
    ..indicatorColor = Colors.black
    ..maskColor = Colors.blue.withOpacity(0.5)
    ..userInteractions = false
    ..dismissOnTap = false;
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  // This widget is the root of your application. DarkThemeProvider themeChangeProvider = DarkThemeProvider();
  //

  DarkThemeProvider themeChangeProvider = DarkThemeProvider();

  @override
  void initState() {
    getCurrentAppTheme();
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    getCurrentAppTheme();
  }

  void getCurrentAppTheme() async {
    themeChangeProvider.darkTheme = await themeChangeProvider.darkThemePreference.getTheme();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        return themeChangeProvider;
      },
      child: Consumer<DarkThemeProvider>(builder: (context, value, child) {
        return GetMaterialApp(
          title: 'Mujeres al Volante'.tr,
          debugShowCheckedModeBanner: false,
          theme: Styles.themeData(
              themeChangeProvider.darkTheme == 0
                  ? true
                  : themeChangeProvider.darkTheme == 1
                      ? false
                      : themeChangeProvider.getSystemThem(),
              context),
          localizationsDelegates: const [
            CountryLocalizations.delegate,
          ],
          locale: LocalizationService.locale,
          fallbackLocale: LocalizationService.locale,
          translations: LocalizationService(),
          builder: EasyLoading.init(),
          home: GetX<GlobalSettingController>(
            init: GlobalSettingController(),
            builder: (controller) {
              return controller.isLoading.value ? Constant.loader(context) : const SplashScreen();
            },
          ),
        );
      }),
    );
  }
}
