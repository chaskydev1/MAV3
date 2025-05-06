import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/order_map_controller.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/themes/responsive.dart';
import 'package:driver/themes/text_field_them.dart';
import 'package:driver/utils/DarkThemeProvider.dart';
import 'package:driver/widget/location_view.dart';
import 'package:driver/widget/user_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:driver/controller/home_controller.dart';
import 'package:driver/ui/home_screens/home_screen.dart';
import 'package:driver/controller/dash_board_controller.dart';
import 'package:driver/ui/dashboard_screen.dart';
//here

class OrderMapScreen extends StatelessWidget {
  const OrderMapScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);

    return GetX<OrderMapController>(
      init: OrderMapController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            leading: InkWell(
              onTap: () {
                Get.back();
              },
              child: const Icon(Icons.arrow_back),
            ),
            title: Text(
              //"Detalles del Viaje",  // o alguna de estas alternativas:
              // "Nueva Solicitud"
              "Solicitud de Viaje",
              // "Detalles de la Carrera"
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: true,  // Centra el título en la barra
          ),
          body: controller.isLoading.value
              ? Constant.loader(context)
              : Stack(
                  children: [
                    /// Mapa de fondo
                    Positioned.fill(
                      child: GoogleMap(
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        mapType: MapType.normal,
                        zoomControlsEnabled: true,
                        polylines: Set<Polyline>.of(controller.polyLines.values),
                        markers: Set<Marker>.of(controller.markers.values),
                        onMapCreated: (GoogleMapController mapController) {
                          controller.mapController.complete(mapController);
                        },
                        initialCameraPosition: CameraPosition(
                          zoom: 15,
                          target: LatLng(
                            controller.orderModel.value.sourceLocationLAtLng?.latitude ?? 
                            Constant.currentLocation!.latitude ?? 45.521563,
                            controller.orderModel.value.sourceLocationLAtLng?.longitude ?? 
                            Constant.currentLocation!.longitude ?? -122.677433,
                          ),
                        ),
                      ),
                    ),

                    /// Cinta superior de color
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: Responsive.width(10, context),
                        color: AppColors.primary,
                      ),
                    ),

                    /// Caja inferior de detalles
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: SingleChildScrollView(  // Agregamos SingleChildScrollView aquí
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              /// Botón para mostrar/ocultar detalles
                            InkWell( 
                              onTap: () => controller.toggleBoxVisibility(),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(10),
                                    topRight: Radius.circular(10),
                                  ),
                                  border: const Border(
                                    top: BorderSide(width: 0.5, color: Colors.black26),
                                    left: BorderSide(width: 0.5, color: Colors.black26),
                                    right: BorderSide(width: 0.5, color: Colors.black26),
                                    // No border bottom
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      controller.isBoxVisible.value
                                          ? "Ocultar detalles"
                                          : "Mostrar detalles",
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      controller.isBoxVisible.value
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                              /// Detalles visibles si `isBoxVisible` es true
                              Visibility(
                                visible: controller.isBoxVisible.value,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: themeChange.getThem()
                                        ? AppColors.darkContainerBackground
                                        : AppColors.containerBackground,
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(10),
                                      bottomRight: Radius.circular(10),
                                    ),
                                    border: Border.all(
                                      color: themeChange.getThem()
                                          ? AppColors.darkContainerBorder
                                          : AppColors.containerBorder,
                                      width: 0.5,
                                    ),
                                    boxShadow: themeChange.getThem()
                                        ? null
                                        : [
                                            BoxShadow(
                                              color: Colors.grey.withOpacity(0.5),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        UserView(
                                          userId: controller.orderModel.value.userId,
                                          amount: controller.orderModel.value.offerRate,
                                          distance: controller.orderModel.value.distance,
                                          distanceType: controller.orderModel.value.distanceType,
                                          isAcOrNonAc: controller.orderModel.value.service!.isAcNonAc == false
                                              ? null
                                              : controller.orderModel.value.isAcSelected,
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 5),
                                          child: Divider(),
                                        ),
                                        LocationView(
                                          sourceLocation: controller.orderModel.value.sourceLocationName.toString(),
                                          destinationLocation:
                                              controller.orderModel.value.destinationLocationName.toString(),
                                        ),
                                        /* DISTANCIA VISUAL CON DECIMALES
                                        Text(
                                          'Distancia del viaje: ${controller.orderModel.value.distance} km',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: themeChange.getThem() ? Colors.white : Colors.black,
                                          ),
                                        ),
                                        */
                                        const SizedBox(height: 10),
                                        Visibility(
                                          visible: controller.orderModel.value.service != null &&
                                              controller.orderModel.value.service!.offerRate == true,
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                InkWell(
                                                  onTap: () {
                                                    controller.amount.value -= 10;
                                                    controller.finalAmount.value -= 10;
                                                    controller.enterOfferRateController.value.text =
                                                        controller.amount.value.toStringAsFixed(
                                                            Constant.currencyModel!.decimalDigits!);
                                                  },
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      border: Border.all(color: AppColors.textFieldBorder),
                                                      borderRadius: const BorderRadius.all(Radius.circular(30)),
                                                    ),
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                                                      child: Text("- 10", style: GoogleFonts.poppins()),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 20),
                                                /*
                                                Text(
                                                  Constant.amountShow(amount: controller.amount.value.toString()),
                                                  style: GoogleFonts.poppins(),
                                                ),
                                                */
                                                const SizedBox(width: 20),
                                                ButtonThem.roundButton(
                                                  context,
                                                  title: "+ 10",
                                                  btnWidthRatio: 0.22,
                                                  onPress: () {
                                                    controller.amount.value += 10;
                                                    controller.finalAmount.value += 10;
                                                    controller.enterOfferRateController.value.text =
                                                        controller.amount.value.toStringAsFixed(
                                                            Constant.currencyModel!.decimalDigits!);
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Visibility(
                                          visible: controller.orderModel.value.service != null &&
                                              controller.orderModel.value.service!.offerRate == true,
                                          child: TextFieldThem.buildTextFiledWithPrefixIcon(
                                            context,
                                            hintText: "Ingrese la tarifa",
                                            controller: controller.enterOfferRateController.value,
                                            keyBoardType:
                                                const TextInputType.numberWithOptions(decimal: true, signed: false),
                                            onChanged: (value) {
                                              if (value.isEmpty) {
                                                controller.amount.value = 0.0;
                                              } else {
                                                controller.amount.value = double.tryParse(value) ?? 0.0;
                                                controller.finalAmount.value = double.parse(value) +
                                                    controller.totalChargeOfMinute.value +
                                                    (double.tryParse(controller.orderModel.value.service!.basicFareCharge.toString()) ?? 0.0);
                                              }
                                            },
                                            prefix: Padding(
                                              padding: const EdgeInsets.only(right: 10),
                                              child: Text(Constant.currencyModel!.symbol.toString()),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        Text(
                                          '${'Tiempo aprox'.tr}: ${controller.convertToMinutes(controller.orderModel.value.duration.toString())} ${'Min.'.tr}',
                                          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                                        ),
                                        /*
                                        Text(
                                          '${'ETA'.tr}: ${controller.convertToMinutes(controller.orderModel.value.duration.toString())} ${'Minutos'.tr} / ${'Cargo por Minutos'.tr} (${Constant.amountShow(amount: controller.totalChargeOfMinute.value.toString())})',
                                          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                                        ),
                                        */
                                        Text(
                                          //'${controller.orderModel.value.service!.basicFare} ${Constant.distanceType} - ' +
                                          '${'Precio Recomendado'.tr}: \$${controller.calculateRecommendedPrice().toStringAsFixed(2)}',
                                            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(height: 20),
                                        ButtonThem.buildButton(
                                          context,
                                          title: '${'Aceptar tarifa en'.tr} ${controller.finalAmount.value.toStringAsFixed(2)}',
                                          isEnabled: !controller.isProcessingOrder.value,
                                          onPress: () async {
                                            if (double.parse(controller.amount.value.toString()) > 2) {
                                              await controller.acceptOrder();
                                              
                                              // Primero inicializamos los controladores
                                              final dashboardController = Get.put(DashBoardController());
                                              final homeController = Get.put(HomeController());
                                              
                                              // Actualizamos el índice del HomeController
                                              homeController.selectedIndex.value = 1;
                                              
                                              // Actualizamos el índice del DashboardController para mostrar el HomeScreen
                                              dashboardController.selectedDrawerIndex.value = 0;
                                              
                                              // Navegamos al DashBoardScreen con los controladores ya configurados
                                              Get.offAll(
                                                () => const DashBoardScreen(),
                                                binding: BindingsBuilder(() {
                                                  Get.put(DashBoardController());
                                                  Get.put(HomeController(), permanent: true);
                                                }),
                                              );
                                            } else {
                                              ShowToastDialog.showToast("Por favor, introduzca una tarifa válida".tr);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
