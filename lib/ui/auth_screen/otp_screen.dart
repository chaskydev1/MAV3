import 'dart:developer';

import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/otp_controller.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/ui/auth_screen/information_screen.dart';
import 'package:driver/ui/dashboard_screen.dart';
import 'package:driver/ui/subscription_plan_screen/subscription_list_screen.dart';
import 'package:driver/utils/DarkThemeProvider.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';

import '../../themes/responsive.dart';

class OtpScreen extends StatelessWidget {
  const OtpScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);

    return GetX<OtpController>(
        init: OtpController(),
        builder: (controller) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.background,
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Image.asset(
                      "assets/images/login_image.png",
                      width: Responsive.width(50, context)
                    ),
                  ),
                  const SizedBox(height: 30),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Center(  // Añadido Center
                            child: Text(
                              "Verify Phone Number".tr,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                color: Colors.black  // Cambiado a negro como en login
                              )
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Center( // Añadido widget Center
                            child: Text(
                              "Enviaremos un codigo de verificacion a \n${controller.countryCode.value + controller.phoneNumber.value}".tr,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w400,
                                color: Colors.black,
                              )
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 50),
                          child: PinCodeTextField(
                            length: 6,
                            appContext: context,
                            keyboardType: TextInputType.phone,
                            textStyle: GoogleFonts.poppins(
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            pinTheme: PinTheme(
                              fieldHeight: 50,
                              fieldWidth: 50,
                              activeColor: themeChange.getThem() ? AppColors.darkTextFieldBorder : AppColors.textFieldBorder,
                              selectedColor: themeChange.getThem() ? AppColors.darkTextFieldBorder : AppColors.textFieldBorder,
                              inactiveColor: themeChange.getThem() ? AppColors.darkTextFieldBorder : const Color.fromARGB(255, 218, 183, 216),
                              activeFillColor: themeChange.getThem() ? AppColors.textField : AppColors.textField,
                              inactiveFillColor: themeChange.getThem() ? AppColors.textField : AppColors.textField,
                              selectedFillColor: themeChange.getThem() ? AppColors.textField : AppColors.textField,
                              shape: PinCodeFieldShape.box,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            enableActiveFill: true,
                            cursorColor: AppColors.primary,
                            controller: controller.otpController.value,
                            onCompleted: (v) async {},
                            onChanged: (value) {},
                          ),
                        ),
                        const SizedBox(
                          height: 30,
                        ),
                        ButtonThem.buildButton(
                          context,
                          title: "Verify".tr,
                          onPress: () async {
                            if (controller.otpController.value.text.length == 6) {
                              ShowToastDialog.showLoader("Verify OTP".tr);

                              PhoneAuthCredential credential =
                                  PhoneAuthProvider.credential(verificationId: controller.verificationId.value, smsCode: controller.otpController.value.text);
                              await FirebaseAuth.instance.signInWithCredential(credential).then((value) async {
                                if (value.additionalUserInfo!.isNewUser) {
                                  log("----->new user");
                                  DriverUserModel userModel = DriverUserModel();
                                  userModel.id = value.user!.uid;
                                  userModel.countryCode = controller.countryCode.value;
                                  userModel.phoneNumber = controller.phoneNumber.value;
                                  userModel.loginType = Constant.phoneLoginType;

                                  ShowToastDialog.closeLoader();
                                  Get.off(const InformationScreen(), arguments: {
                                    "userModel": userModel,
                                  });
                                } else {
                                  log("----->old user");
                                  FireStoreUtils.userExitOrNot(value.user!.uid).then((userExit) async {
                                    ShowToastDialog.closeLoader();
                                    if (userExit == true) {
                                      await FireStoreUtils.getDriverProfile(value.user!.uid).then(
                                        (value) {
                                          if (value != null) {
                                            DriverUserModel userModel = value;
                                            bool isPlanExpire = false;
                                            if (userModel.subscriptionPlan?.id != null) {
                                              if (userModel.subscriptionExpiryDate == null) {
                                                if (userModel.subscriptionPlan?.expiryDay == '-1') {
                                                  isPlanExpire = false;
                                                } else {
                                                  isPlanExpire = true;
                                                }
                                              } else {
                                                DateTime expiryDate = userModel.subscriptionExpiryDate!.toDate();
                                                isPlanExpire = expiryDate.isBefore(DateTime.now());
                                              }
                                            } else {
                                              isPlanExpire = true;
                                            }
                                            if (userModel.subscriptionPlanId == null || isPlanExpire == true) {
                                              if (Constant.adminCommission?.isEnabled == false && Constant.isSubscriptionModelApplied == false) {
                                                Get.offAll(const DashBoardScreen());
                                              } else {
                                                Get.offAll(const SubscriptionListScreen(), arguments: {"isShow": true});
                                              }
                                            }else{
                                              Get.offAll(const DashBoardScreen());
                                            }
                                          }
                                        },
                                      );
                                    } else {
                                      DriverUserModel userModel = DriverUserModel();
                                      userModel.id = value.user!.uid;
                                      userModel.countryCode = controller.countryCode.value;
                                      userModel.phoneNumber = controller.phoneNumber.value;
                                      userModel.loginType = Constant.phoneLoginType;

                                      Get.off(const InformationScreen(), arguments: {
                                        "userModel": userModel,
                                      });
                                    }
                                  });
                                }
                              }).catchError((error) {
                                ShowToastDialog.closeLoader();
                                ShowToastDialog.showToast("Code is Invalid".tr);
                              });
                            } else {
                              ShowToastDialog.showToast("Please Enter Valid OTP".tr);
                            }

                            // print(controller.countryCode.value);
                            // print(controller.phoneNumberController.value.text);
                          },
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        });
  }
}
