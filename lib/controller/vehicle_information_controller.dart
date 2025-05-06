import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/model/driver_rules_model.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/service_model.dart';
import 'package:driver/model/vehicle_type_model.dart';
import 'package:driver/model/zone_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class VehicleInformationController extends GetxController {
  Rx<TextEditingController> vehicleNumberController = TextEditingController().obs;
  Rx<TextEditingController> seatsController = TextEditingController().obs;
  Rx<TextEditingController> registrationDateController = TextEditingController().obs;
  Rx<TextEditingController> driverRulesController = TextEditingController().obs;
  Rx<TextEditingController> zoneNameController = TextEditingController().obs;
  Rx<TextEditingController> acPerKmRate = TextEditingController().obs;
  Rx<TextEditingController> nonAcPerKmRate = TextEditingController().obs;
  Rx<TextEditingController> acNonAcWithoutPerKmRate = TextEditingController().obs;
  Rx<DateTime?> selectedDate = DateTime.now().obs;

  RxBool isLoading = true.obs;

  Rx<String> selectedColor = "".obs;
  List<String> carColorList = <String>['Rojo', 'Negro', 'Blanco', 'Azul', 'Verde', 'Naranja', 'Plateado', 'Gris', 'Amarillo', 'Marrón', 'Dorado', 'Beige', 'Morado'].obs;
  List<String> sheetList = <String>['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15'].obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getVehicleTye();
    super.onInit();
  }

  List<VehicleTypeModel> vehicleList = <VehicleTypeModel>[].obs;
  Rx<VehicleTypeModel> selectedVehicle = VehicleTypeModel().obs;
  var colors = [
    AppColors.serviceColor1,
    AppColors.serviceColor2,
    AppColors.serviceColor3,
  ];
  Rx<DriverUserModel> driverModel = DriverUserModel().obs;
  RxList<DriverRulesModel> driverRulesList = <DriverRulesModel>[].obs;
  RxList<DriverRulesModel> selectedDriverRulesList = <DriverRulesModel>[].obs;

  RxList<ServiceModel> serviceList = <ServiceModel>[].obs;
  Rx<ServiceModel> selectedServiceType = ServiceModel().obs;
  RxList<ZoneModel> zoneList = <ZoneModel>[].obs;
  RxList selectedZone = <String>[].obs;
  RxString zoneString = "".obs;

  getVehicleTye() async {
    await FireStoreUtils.getService().then((value) {
      serviceList.value = value;
    });

    await FireStoreUtils.getZone().then((value) {
      if (value != null) {
        zoneList.value = value;
      }
    });

    await FireStoreUtils.getDriverProfile(FireStoreUtils.getCurrentUid()).then((value) {
      if (value != null) {
        driverModel.value = value;
        if (driverModel.value.vehicleInformation != null) {
          vehicleNumberController.value.text = driverModel.value.vehicleInformation!.vehicleNumber.toString();
          selectedDate.value = driverModel.value.vehicleInformation!.registrationDate!.toDate();
          registrationDateController.value.text = DateFormat("dd-MM-yyyy").format(selectedDate.value!);
          selectedColor.value = driverModel.value.vehicleInformation!.vehicleColor.toString();
          seatsController.value.text = driverModel.value.vehicleInformation!.seats ?? "2";
          if(driverModel.value.vehicleInformation!.acPerKmRate != null){
            acPerKmRate.value.text = driverModel.value.vehicleInformation!.acPerKmRate ?? '';
          }else{
            nonAcPerKmRate.value.text = driverModel.value.vehicleInformation!.nonAcPerKmRate ?? '';
            acNonAcWithoutPerKmRate.value.text = driverModel.value.vehicleInformation!.perKmRate ?? '';
          }
        }

        if (driverModel.value.zoneIds != null) {
          for (var element in driverModel.value.zoneIds!) {
            List<ZoneModel> list = zoneList.where((p0) => p0.id == element).toList();
            if (list.isNotEmpty) {
              selectedZone.add(element);
              zoneString.value = "$zoneString${zoneString.isEmpty ? "" : ","} ${Constant.localizationName(list.first.name)}";
            }
          }
          zoneNameController.value.text = zoneString.value;
        }
        for (var element in serviceList) {
          if (element.id == driverModel.value.serviceId) {
            print("====>");
            selectedServiceType.value = element;
          }
        }
      }
    });

    await FireStoreUtils.getVehicleType().then((value) {
      vehicleList = value!;
      if (driverModel.value.vehicleInformation != null) {
        for (var element in vehicleList) {
          if (element.id == driverModel.value.vehicleInformation!.vehicleTypeId) {
            selectedVehicle.value = element;
          }
        }
      }
    });

    await FireStoreUtils.getDriverRules().then((value) {
      if (value != null) {
        driverRulesList.value = value;
        if (driverModel.value.vehicleInformation != null) {
          if (driverModel.value.vehicleInformation!.driverRules != null) {
            for (var element in driverModel.value.vehicleInformation!.driverRules!) {
              selectedDriverRulesList.add(element);
            }
          }
        }
      }
    });
    isLoading.value = false;
    update();
  }

  saveDetails() async {
    if (driverModel.value.serviceId == null) {
      driverModel.value.serviceId = selectedServiceType.value.id;
    }
    driverModel.value.zoneIds = selectedZone;

    driverModel.value.vehicleInformation = VehicleInformation(
        registrationDate: Timestamp.fromDate(selectedDate.value!),
        vehicleColor: selectedColor.value,
        vehicleNumber: vehicleNumberController.value.text,
        vehicleType: selectedVehicle.value.name,
        acPerKmRate: acPerKmRate.value.text,
        nonAcPerKmRate: nonAcPerKmRate.value.text,
        vehicleTypeId: selectedVehicle.value.id,
        seats: seatsController.value.text,
        perKmRate: acNonAcWithoutPerKmRate.value.text,
        driverRules: selectedDriverRulesList);

    await FireStoreUtils.updateDriverUser(driverModel.value).then((value) {
      ShowToastDialog.closeLoader();
      if (value == true) {
        ShowToastDialog.showToast(
          "Actualización de información exitosa".tr,
        );
      }
    });
  }
}
