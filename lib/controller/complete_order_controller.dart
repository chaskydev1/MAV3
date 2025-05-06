import 'package:driver/constant/constant.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:get/get.dart';

class CompleteOrderController extends GetxController {
  RxBool isLoading = true.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getArgument();
    super.onInit();
  }

  Rx<OrderModel> orderModel = OrderModel().obs;

  RxString couponAmount = "0.0".obs;

  RxDouble amount = 0.0.obs;
  RxDouble subTotal = 0.0.obs;
  RxDouble total = 0.0.obs;
  RxDouble taxAmount = 0.0.obs;
  RxString startNightTime = "".obs;
  RxString endNightTime = "".obs;
  RxDouble totalNightFare = 0.0.obs;
  RxDouble totalChargeOfMinute = 0.0.obs;
  RxDouble basicFareCharge = 0.0.obs;
  RxDouble holdingCharge = 0.0.obs;
  DateTime currentTime = DateTime.now();
  DateTime currentDate = DateTime.now();
  DateTime startNightTimeString = DateTime.now();
  DateTime endNightTimeString = DateTime.now();

  calculateAmount() async {
    String formatTime(String? time) {
      if (time == null || !time.contains(":")) {
        return "00:00";
      }
      List<String> parts = time.split(':');
      if (parts.length != 2) return "00:00";
      return "${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}";
    }

    startNightTime.value = formatTime(orderModel.value.service!.startNightTime);
    endNightTime.value = formatTime(orderModel.value.service!.endNightTime);

    List<String> startParts = startNightTime.split(':');
    List<String> endParts = endNightTime.split(':');

    startNightTimeString = DateTime(currentDate.year, currentDate.month, currentDate.day, int.parse(startParts[0]), int.parse(startParts[1]));
    endNightTimeString = DateTime(currentDate.year, currentDate.month, currentDate.day, int.parse(endParts[0]), int.parse(endParts[1]));

    double durationValueInMinutos = convertToMinutos(orderModel.value.duration.toString());
    double distance = double.tryParse(orderModel.value.distance.toString()) ?? 0.0;
    double nonAcChargeValue = 0.0;
    double acChargeValue = 0.0;
    double kmCharge = 0.0;

    if (orderModel.value.driverId != null && orderModel.value.driverId!.isNotEmpty) {
      nonAcChargeValue = double.tryParse(driverModel.value.vehicleInformation!.nonAcPerKmRate.toString()) ?? 0.0;
      acChargeValue = double.tryParse(driverModel.value.vehicleInformation!.nonAcPerKmRate.toString()) ?? 0.0;
      kmCharge = double.tryParse(driverModel.value.vehicleInformation!.perKmRate ?? '0.0') ?? 0.0;
    } else {
      nonAcChargeValue = double.tryParse(orderModel.value.service!.nonAcCharge.toString()) ?? 0.0;
      acChargeValue = double.tryParse(orderModel.value.service!.acCharge.toString()) ?? 0.0;
      kmCharge = double.tryParse(orderModel.value.service!.kmCharge ?? '0.0') ?? 0.0;
    }

    totalChargeOfMinute.value = double.parse(durationValueInMinutos.toString()) * double.parse(orderModel.value.service!.perMinuteCharge.toString());
    basicFareCharge.value = double.parse(orderModel.value.service!.basicFareCharge.toString());
    holdingCharge.value = double.parse(orderModel.value.totalHoldingCharges.toString());
    if (distance <= double.parse(orderModel.value.service!.basicFare.toString())) {
      if (currentTime.isAfter(startNightTimeString) && currentTime.isBefore(endNightTimeString)) {
        amount.value = amount.value * double.parse(orderModel.value.service!.nightCharge.toString());
      } else {
        amount.value = double.parse(orderModel.value.service!.basicFareCharge.toString());
      }
    } else {
      double distanceValue = double.tryParse(orderModel.value.distance.toString()) ?? 0.0;
      double basicFareValue = double.tryParse(orderModel.value.service!.basicFare.toString()) ?? 0.0;
      double extraDist = distanceValue - basicFareValue;

      double perKmCharge = orderModel.value.service!.isAcNonAc == true
          ? orderModel.value.isAcSelected == false
              ? nonAcChargeValue
              : acChargeValue
          : kmCharge;
      amount.value = (perKmCharge * extraDist);

      if (currentTime.isAfter(startNightTimeString) && currentTime.isBefore(endNightTimeString)) {
        totalChargeOfMinute.value = totalChargeOfMinute.value * double.parse(orderModel.value.service!.nightCharge.toString());
        basicFareCharge.value = basicFareCharge.value * double.parse(orderModel.value.service!.nightCharge.toString());
        holdingCharge.value = holdingCharge.value * double.parse(orderModel.value.service!.nightCharge.toString());
      }
    }

    if (orderModel.value.finalRate != null && orderModel.value.finalRate != '0.0') {
      amount.value = double.parse(orderModel.value.finalRate.toString()) - basicFareCharge.value - totalChargeOfMinute.value - holdingCharge.value;
    } else {
      amount.value = amount.value * double.parse(orderModel.value.service!.nightCharge.toString());
    }

    subTotal.value = amount.value + basicFareCharge.value + totalChargeOfMinute.value + holdingCharge.value;

    if (orderModel.value.taxList != null) {
      for (var element in orderModel.value.taxList!) {
        taxAmount.value = taxAmount.value +
            Constant().calculateTax(amount: (double.parse(subTotal.value.toString()) - double.parse(couponAmount.value.toString())).toString(), taxModel: element);
      }
    }
    total.value = subTotal.value + taxAmount.value;
  }

  double convertToMinutos(String duration) {
    double durationValue = 0.0;

    try {
      final RegExp hoursRegex = RegExp(r"(\d+)\s*hour");
      final RegExp MinutosRegex = RegExp(r"(\d+)\s*min");

      final Match? hoursMatch = hoursRegex.firstMatch(duration);
      if (hoursMatch != null) {
        int hours = int.parse(hoursMatch.group(1)!.trim());
        durationValue += hours * 60;
      }

      final Match? MinutosMatch = MinutosRegex.firstMatch(duration);
      if (MinutosMatch != null) {
        int Minutos = int.parse(MinutosMatch.group(1)!.trim());
        durationValue += Minutos;
      }
    } catch (e) {
      print("Exception: $e");
      throw FormatException("Invalid duration format: $duration");
    }

    return durationValue;
  }

  getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      orderModel.value = argumentData['orderModel'];
      await getDriver();
      if (orderModel.value.coupon != null) {
        if (orderModel.value.coupon?.code != null) {
          if (orderModel.value.coupon!.type == "fix") {
            couponAmount.value = orderModel.value.coupon!.amount.toString();
          } else {
            couponAmount.value = ((double.parse(orderModel.value.finalRate.toString()) * double.parse(orderModel.value.coupon!.amount.toString())) / 100).toString();
          }
        }
      }
      calculateAmount();
    }
    isLoading.value = false;
    update();
  }

  Rx<DriverUserModel> driverModel = DriverUserModel().obs;

  getDriver() async {
    await FireStoreUtils.getDriverProfile(orderModel.value.driverId.toString()).then(
      (value) {
        if (value != null) {
          driverModel.value = value;
        }
      },
    );
  }
}
