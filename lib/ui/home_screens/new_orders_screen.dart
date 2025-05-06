import 'package:driver/constant/constant.dart';
import 'package:driver/controller/home_controller.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/ui/home_screens/order_map_screen.dart';
import 'package:driver/utils/DarkThemeProvider.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/widget/location_view.dart';
import 'package:driver/widget/user_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class NewOrderScreen extends StatelessWidget {
  const NewOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    return GetX<HomeController>(
        init: HomeController(),
        dispose: (state) {
          FireStoreUtils().closeStream();
        },
        builder: (controller) {
          return controller.isLoading.value
              ? Constant.loader(context)
              : controller.driverModel.value.isOnline == false
                  ? Center(
                      child: Text(
                        "You are Now offline so you can't get nearest order.".tr,
                        style: GoogleFonts.poppins(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w400
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : StreamBuilder<List<OrderModel>>(
                      stream: FireStoreUtils().getOrders(controller.driverModel.value, Constant.currentLocation?.latitude, Constant.currentLocation?.longitude),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Constant.loader(context);
                        }
                        if (!snapshot.hasData || (snapshot.data?.isEmpty ?? true)) {
                          return Center(
                            child: Text("No se encontraron nuevos viajes".tr,
                            style: TextStyle(color: Colors.black)),
                          );
                        } else {
                          // ordersList = snapshot.data!;
                          return ListView.builder(
                            itemCount: snapshot.data!.length,
                            shrinkWrap: true,
                            itemBuilder: (context, index) {
                              OrderModel orderModel = snapshot.data![index];

                              DateTime currentTime = DateTime.now();
                              DateTime currentDate = DateTime.now();
                              DateTime startNightTimeString = DateTime.now();
                              DateTime endNightTimeString = DateTime.now();

                              double amount = 0.0;
                              double finalAmount = 0.0;
                              String startNightTime = "";
                              String endNightTime = "";
                              double totalNightFare = 0.0;
                              double totalChargeOfMinute = 0.0;
                              double basicFare = 0.0;

                              String formatTime(String? time) {
                                if (time == null || !time.contains(":")) {
                                  return "00:00";
                                }
                                List<String> parts = time.split(':');
                                if (parts.length != 2) return "00:00";
                                return "${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}";
                              }

                              startNightTime = formatTime(orderModel.service!.startNightTime);
                              endNightTime = formatTime(orderModel.service!.endNightTime);

                              List<String> startParts = startNightTime.split(':');
                              List<String> endParts = endNightTime.split(':');

                              startNightTimeString = DateTime(currentDate.year, currentDate.month, currentDate.day, int.parse(startParts[0]), int.parse(startParts[1]));
                              endNightTimeString = DateTime(currentDate.year, currentDate.month, currentDate.day, int.parse(endParts[0]), int.parse(endParts[1]));

                              double durationValueInMinutos = convertToMinutos(orderModel.duration.toString());
                              double distance = double.tryParse(orderModel.distance.toString()) ?? 0.0;
                              double nonAcChargeValue = double.tryParse(controller.driverModel.value.vehicleInformation!.nonAcPerKmRate.toString()) ?? 0.0;
                              double acChargeValue = double.tryParse(controller.driverModel.value.vehicleInformation!.acPerKmRate.toString()) ?? 0.0;
                              double kmCharge = double.tryParse(controller.driverModel.value.vehicleInformation!.perKmRate!.toString()) ?? 0.0;

                              totalChargeOfMinute = double.parse(durationValueInMinutos.toString()) * double.parse(orderModel.service!.perMinuteCharge.toString());
                              basicFare = double.parse(orderModel.service!.basicFareCharge.toString());

                              if (distance <= double.parse(orderModel.service!.basicFare.toString())) {
                                if (currentTime.isAfter(startNightTimeString) && currentTime.isBefore(endNightTimeString)) {
                                  amount = amount * double.parse(orderModel.service!.nightCharge.toString());
                                } else {
                                  amount = double.parse(orderModel.service!.basicFareCharge.toString());
                                }
                              } else {
                                double distanceValue = double.tryParse(orderModel.distance.toString()) ?? 0.0;
                                double basicFareValue = double.tryParse(orderModel.service!.basicFare.toString()) ?? 0.0;
                                double extraDist = distanceValue - basicFareValue;

                                double perKmCharge = orderModel.service!.isAcNonAc == true
                                    ? orderModel.isAcSelected == false
                                        ? nonAcChargeValue
                                        : acChargeValue
                                    : kmCharge;
                                amount = (perKmCharge * extraDist);

                                if (currentTime.isAfter(startNightTimeString) && currentTime.isBefore(endNightTimeString)) {
                                  amount = amount * double.parse(orderModel.service!.nightCharge.toString());
                                  totalChargeOfMinute = totalChargeOfMinute * double.parse(orderModel.service!.nightCharge.toString());
                                  basicFare = basicFare * double.parse(orderModel.service!.nightCharge.toString());
                                }
                              }

                              finalAmount = amount + basicFare + totalChargeOfMinute;

                              return InkWell(
                                onTap: () {
                                  Get.to(const OrderMapScreen(), arguments: {"orderModel": orderModel.id.toString()})!.then((value) {
                                    if (value != null && value == true) {
                                      controller.selectedIndex.value = 1;
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: themeChange.getThem() ? AppColors.darkContainerBackground : AppColors.containerBackground,
                                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                                      border: Border.all(color: themeChange.getThem() ? AppColors.darkContainerBorder : AppColors.containerBorder, width: 0.5),
                                      boxShadow: themeChange.getThem()
                                          ? null
                                          : [
                                              BoxShadow(
                                                color: Colors.grey.withOpacity(0.5),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2), // changes position of shadow
                                              ),
                                            ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                      child: Column(
                                        children: [
                                          UserView(
                                            userId: orderModel.userId,
                                            // Usar toStringAsFixed para mantener los decimales
                                            amount: (double.tryParse(orderModel.offerRate?.toString() ?? '0.0') ?? 0.0)
                                                .toStringAsFixed(2),  // Forzar a 2 decimales
                                            distance: orderModel.distance,
                                            distanceType: orderModel.distanceType,
                                            isAcOrNonAc: orderModel.service!.isAcNonAc == false ? null : orderModel.isAcSelected,
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 5),
                                            child: Divider(),
                                          ),
                                          LocationView(
                                            sourceLocation: orderModel.sourceLocationName.toString(),
                                            destinationLocation: orderModel.destinationLocationName.toString(),
                                          ),
                                          Column(
                                            children: [
                                              const SizedBox(
                                                height: 10,
                                              ),
                                              orderModel.service!.offerRate == true
                                                  ? Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                      child: Container(
                                                        width: Responsive.width(100, context),
                                                        decoration: BoxDecoration(
                                                            color: themeChange.getThem() ? AppColors.darkGray : AppColors.gray,
                                                            borderRadius: BorderRadius.all(Radius.circular(10))),
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                          child: Center(
                                                            child: Text(
                                                              '${'El precio recomendado es'.tr} \$${calculateRecommendedPrice(orderModel).toStringAsFixed(2)}. '
                                                              '${'Approx distance'.tr} ${double.parse(orderModel.distance.toString()).toStringAsFixed(Constant.currencyModel!.decimalDigits!)} ${Constant.distanceType}',
                                                              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                  : Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                      child: Container(
                                                        width: Responsive.width(100, context),
                                                        decoration: BoxDecoration(
                                                            color: themeChange.getThem() ? AppColors.darkGray : AppColors.gray,
                                                            borderRadius: BorderRadius.all(Radius.circular(10))),
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                          child: Center(
                                                            child: Text(
                                                              '${'El precio recomendado es'.tr} \$${calculateRecommendedPrice(orderModel).toStringAsFixed(2)}. '
                                                              '${'Approx distance'.tr} ${double.parse(orderModel.distance.toString()).toStringAsFixed(Constant.currencyModel!.decimalDigits!)} ${Constant.distanceType}',
                                                              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }
                      });
        });
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

  double calculateRecommendedPrice(OrderModel orderModel) {
    double rawDistance = double.parse(orderModel.distance.toString());
    // Redondear la distancia: si el decimal es >= 0.51, redondear hacia arriba
    double distance = (rawDistance % 1 >= 0.51) ? rawDistance.ceil().toDouble() : rawDistance.floor().toDouble();
    
    double basePrice = 15.0;  // Precio base para ≤ 2km
    
    if (distance <= 2.0) {
        return basePrice;
    } else {
        double extraKm = distance - 2.0;  // Kilómetros extras después de 2km
        return basePrice + (extraKm * 2.5);  // 2.5 por cada km extra
    }
  }
}
