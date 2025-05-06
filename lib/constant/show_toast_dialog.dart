import 'package:flutter_easyloading/flutter_easyloading.dart';

class ShowToastDialog {
  static showToast(String? message) {
    EasyLoading.showToast(message!);
  }

  static showLoader(String message) {
    EasyLoading.show(status: message);
  }

  static closeLoader() {
    EasyLoading.dismiss();
  }
}
