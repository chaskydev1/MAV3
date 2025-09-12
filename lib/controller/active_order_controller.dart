import 'package:driver/controller/home_controller.dart';
import 'package:driver/model/payment_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ActiveOrderController extends GetxController {
  HomeController homeController = Get.put(HomeController());
  
  final Rx<TextEditingController> otpController = TextEditingController().obs;

  Rx<PaymentModel> paymentModel = PaymentModel().obs;

  @override
  void onInit() {
    super.onInit();
    getPayment();
  }

  getPayment() async {
    await FireStoreUtils().getPayment().then((value) {
      if (value != null) {
        paymentModel.value = value;
      }
    });
  }

  void resetOTPController() {
    otpController.value = TextEditingController();
  }
}
