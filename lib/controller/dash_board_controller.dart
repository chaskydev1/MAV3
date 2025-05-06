import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/ui/auth_screen/login_screen.dart';
import 'package:driver/ui/bank_details/bank_details_screen.dart';
import 'package:driver/ui/chat_screen/inbox_screen.dart';
import 'package:driver/ui/freight/freight_screen.dart';
import 'package:driver/ui/home_screens/home_screen.dart';
import 'package:driver/ui/intercity_screen/home_intercity_screen.dart';
import 'package:driver/ui/online_registration/online_registartion_screen.dart';
import 'package:driver/ui/profile_screen/profile_screen.dart';
import 'package:driver/ui/settings_screen/setting_screen.dart';
import 'package:driver/ui/subscription_plan_screen/subscription_history.dart';
import 'package:driver/ui/subscription_plan_screen/subscription_list_screen.dart';
import 'package:driver/ui/vehicle_information/vehicle_information_screen.dart';
import 'package:driver/ui/wallet/wallet_screen.dart';
import 'package:driver/utils/utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DashBoardController extends GetxController {
  RxList<DrawerItem> drawerItems = <DrawerItem>[].obs;

  getDrawerItemWidget(int pos) {
    switch (pos) {
      case 0:
        return const HomeScreen();
      case 1:
        return const WalletScreen();
      case 2:
        return const InboxScreen();
      case 3:
        return const ProfileScreen();
      case 4:
        return const OnlineRegistrationScreen();
      case 5:
        return const VehicleInformationScreen();
      case 6:
        return const SettingScreen();
      case 7:
        return const Text("Error");
      default:
        return const Text("Error");
    }
  }

  RxInt selectedDrawerIndex = 0.obs;

  onSelectItem(int index) async {
    if (index == 7) { // Log out
      await FirebaseAuth.instance.signOut();
      Get.offAll(const LoginScreen());
    } else {
      selectedDrawerIndex.value = index;
    }

    Get.back();
  }

  @override
  void onInit() {
    // TODO: implement onInit
    setDrawerList();
    getLocation();
    super.onInit();
  }

  setDrawerList() {
    drawerItems.value = [
      DrawerItem('City'.tr, "assets/icons/ic_city.svg"),
      DrawerItem('My Wallet'.tr, "assets/icons/ic_wallet.svg"),
      DrawerItem('Inbox'.tr, "assets/icons/ic_inbox.svg"),
      DrawerItem('Profile'.tr, "assets/icons/ic_profile.svg"),
      DrawerItem('Online Registration'.tr, "assets/icons/ic_document.svg"),
      DrawerItem('Vehicle Information'.tr, "assets/icons/ic_city.svg"),
      DrawerItem('Settings'.tr, "assets/icons/ic_settings.svg"),
      DrawerItem('Log out'.tr, "assets/icons/ic_logout.svg"),
    ];
  }

  getLocation() async {
    await Utils.determinePosition();
  }

  Rx<DateTime> currentBackPressTime = DateTime.now().obs;

  Future<bool> onWillPop() {
    DateTime now = DateTime.now();
    if (now.difference(currentBackPressTime.value) > const Duration(seconds: 2)) {
      currentBackPressTime.value = now;
      ShowToastDialog.showToast(
        "Double press to exit".tr,
      );
      return Future.value(false);
    }
    return Future.value(true);
  }

  String getCurrentTitle() {
    if (selectedDrawerIndex.value >= 0 && selectedDrawerIndex.value < drawerItems.length) {
      return drawerItems[selectedDrawerIndex.value].title;
    }
    return '';
  }
}

class DrawerItem {
  String title;
  String icon;

  DrawerItem(this.title, this.icon);
}
