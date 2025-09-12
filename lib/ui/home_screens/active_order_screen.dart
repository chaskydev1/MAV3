import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/active_order_controller.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/model/wallet_transaction_model.dart';
import 'package:driver/model/user_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/button_them.dart';
import 'package:driver/ui/chat_screen/chat_screen.dart';
import 'package:driver/ui/home_screens/live_tracking_screen.dart';
import 'package:driver/utils/DarkThemeProvider.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:driver/utils/utils.dart';
import 'package:driver/widget/location_view.dart';
import 'package:driver/widget/user_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;

class ActiveOrderScreen extends StatelessWidget {
  const ActiveOrderScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);

    return GetBuilder<ActiveOrderController>(
        init: ActiveOrderController(),
        builder: (controller) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection(CollectionName.orders).where('driverId', isEqualTo: FireStoreUtils.getCurrentUid()).where('status', whereIn: [
              Constant.rideInProgress,
              Constant.rideActive,
              Constant.rideHoldAccepted,
              Constant.rideHold,
            ]).snapshots(),
            builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (snapshot.hasError) {
                return Text('Something went wrong'.tr);
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Constant.loader(context);
              }
              return snapshot.data!.docs.isEmpty
                  ? Center(
                      child: Text("No se encontraron viajes activos".tr,
                        style: GoogleFonts.poppins(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w400
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      scrollDirection: Axis.vertical,
                      shrinkWrap: true,
                      itemBuilder: (context, index) {
                        OrderModel orderModel = OrderModel.fromJson(snapshot.data!.docs[index].data() as Map<String, dynamic>);
                        return InkWell(
                          onTap: () {
                            /*
                            if (Constant.mapType == "inappmap") {
                              if (orderModel.status == Constant.rideActive || orderModel.status == Constant.rideInProgress) {
                                Get.to(const LiveTrackingScreen(), arguments: {
                                  "orderModel": orderModel,
                                  "type": "orderModel",
                                });
                              }
                            } else {
                              if (orderModel.status == Constant.rideInProgress) {
                                Utils.redirectMap(
                                    latitude: orderModel.destinationLocationLAtLng!.latitude!,
                                    longLatitude: orderModel.destinationLocationLAtLng!.longitude!,
                                    name: orderModel.destinationLocationName.toString());
                              } else {
                                Utils.redirectMap(
                                    latitude: orderModel.sourceLocationLAtLng!.latitude!,
                                    longLatitude: orderModel.sourceLocationLAtLng!.longitude!,
                                    name: orderModel.destinationLocationName.toString());
                              }
                            }
                            */
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
                                      amount: orderModel.finalRate,
                                      distance: orderModel.distance,
                                      distanceType: orderModel.distanceType,
                                      isAcOrNonAc: orderModel.service!.isAcNonAc == false?null:orderModel.isAcSelected,
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 5),
                                      child: Divider(),
                                    ),
                                    LocationView(
                                      sourceLocation: orderModel.sourceLocationName.toString(),
                                      destinationLocation: orderModel.destinationLocationName.toString(),
                                    ),
                                    // Viaje programado
                                    if (orderModel.scheduledDate != null)
                                      Container(
                                        margin: const EdgeInsets.only(top: 10, bottom: 2),
                                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.blue.shade100, width: 1),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Icon(Icons.schedule, color: Colors.blue.shade700, size: 22),
                                            const SizedBox(width: 10),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "Viaje Programado para el:",
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue.shade700,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  Constant.dateAndTimeFormatTimestamp(orderModel.scheduledDate),
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.blue.shade600,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                    ),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Row(
                                      children: [
                                    Expanded(
                                      child: orderModel.status == Constant.rideInProgress
                                          ? ButtonThem.buildBorderButton(
                                              context,
                                              title: "💵COBRAR VIAJE💸".tr,
                                              btnHeight: 44,
                                              iconVisibility: false,
                                              onPress: () async {
                                                // Mostrar diálogo de confirmación
                                                bool? confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (BuildContext context) {
                                                    // Ventana modal de confirmación
                                                    return AlertDialog(
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                      backgroundColor: Colors.white,
                                                      title: Row(
                                                        children: [
                                                          Icon(Icons.info_outline, color: Colors.blueAccent),
                                                          const SizedBox(width: 10),
                                                          Text(
                                                            "Confirmación".tr,
                                                            style: GoogleFonts.poppins(
                                                              fontWeight: FontWeight.w600,
                                                              fontSize: 20,
                                                              color: Colors.black87,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      content: Text(
                                                        "¿El pasajero ya llegó a su destino?".tr,
                                                        style: GoogleFonts.poppins(
                                                          fontSize: 16,
                                                          color: Colors.black54,
                                                        ),
                                                      ),
                                                      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                                      actions: [
                                                        TextButton(
                                                          style: TextButton.styleFrom(
                                                            backgroundColor: Colors.grey.shade200,
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(context).pop(false); // No
                                                          },
                                                          child: Text(
                                                            "No".tr,
                                                            style: GoogleFonts.poppins(
                                                              fontWeight: FontWeight.w600,
                                                              color: Colors.grey.shade800,
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                        ),
                                                        ElevatedButton(
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: Colors.blueAccent,
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                                                          ),
                                                          onPressed: () {
                                                            Navigator.of(context).pop(true); // Sí
                                                          },
                                                          child: Text(
                                                            "Sí".tr,
                                                            style: GoogleFonts.poppins(
                                                              fontWeight: FontWeight.w700,
                                                              fontSize: 16,
                                                              color: Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                    // Ventana modal de confirmación
                                                  },
                                                );

                                                if (confirm == true) {
                                                  // El usuario confirmó, ejecutamos la lógica de completar viaje
                                                  orderModel.status = Constant.rideComplete;

                                                  // Si es pago en efectivo, confirmar pago aquí mismo
                                                  if (controller.paymentModel.value.cash?.name == orderModel.paymentType.toString() && orderModel.paymentStatus == false) {
                                                    orderModel.paymentStatus = true;
                                                    orderModel.updateDate = Timestamp.now();

                                                    await FireStoreUtils.getCustomer(orderModel.userId.toString()).then((value) async {
                                                      if (value != null && value.fcmToken != null) {
                                                        await SendNotification.sendOneNotification(
                                                            token: value.fcmToken.toString(),
                                                            title: 'Cash Payment confirmed'.tr,
                                                            body: 'Driver has confirmed your cash payment'.tr,
                                                            payload: {});
                                                      }
                                                    });

                                                    await FireStoreUtils.getFirestOrderOrNOt(orderModel).then((value) async {
                                                      if (value == true) {
                                                        await FireStoreUtils.updateReferralAmount(orderModel);
                                                      }
                                                    });
                                                  } else {
                                                    // De lo contrario, notificar que el viaje fue completado
                                                    await FireStoreUtils.getCustomer(orderModel.userId.toString()).then((value) async {
                                                      if (value != null && value.fcmToken != null) {
                                                        Map<String, dynamic> playLoad = <String, dynamic>{
                                                          "type": "city_order_complete",
                                                          "orderId": orderModel.id,
                                                        };

                                                        await SendNotification.sendOneNotification(
                                                          token: value.fcmToken.toString(),
                                                          title: 'Ride complete!'.tr,
                                                          body: 'Please complete your payment.'.tr,
                                                          payload: playLoad,
                                                        );
                                                      }
                                                    });
                                                  }

                                                  await FireStoreUtils.setOrder(orderModel).then((value) {
                                                    if (value == true) {
                                                      ShowToastDialog.showToast("Viaje completado con éxito.".tr);
                                                      controller.homeController.selectedIndex.value = 3;
                                                    }
                                                  });
                                                }
                                                // Si confirm es false o null, no hacemos nada y el diálogo se cierra
                                              },
                                            )
                                          : orderModel.status == Constant.rideHold || orderModel.status == Constant.rideHoldAccepted
                                              ? SizedBox.shrink()
                                              : ButtonThem.buildBorderButton(
                                                  context,
                                                  title: "CODIGO DEL PASAJERO".tr,
                                                  btnHeight: 44,
                                                  iconVisibility: false,
                                                  onPress: () async {
                                                    showDialog(
                                                      context: context,
                                                      builder: (BuildContext context) => otpDialog(context, controller, orderModel),
                                                    );
                                                  },
                                                ),
                                    ),
                                        const SizedBox(
                                          width: 10,
                                        ),
                                        Row(
                                          children: [
                                            InkWell(
                                              onTap: () async {
                                                UserModel? customer = await FireStoreUtils.getCustomer(orderModel.userId.toString());
                                                DriverUserModel? driver = await FireStoreUtils.getDriverProfile(orderModel.driverId.toString());

                                                Get.to(ChatScreens(
                                                  driverId: driver!.id,
                                                  customerId: customer!.id,
                                                  customerName: customer.fullName,
                                                  customerProfileImage: customer.profilePic,
                                                  driverName: driver.fullName,
                                                  driverProfileImage: driver.profilePic,
                                                  orderId: orderModel.id,
                                                  token: customer.fcmToken,
                                                ));
                                              },
                                              child: Container(
                                                height: 44,
                                                width: 44,
                                                decoration: BoxDecoration(
                                                    color: themeChange.getThem() ? AppColors.darkModePrimary : AppColors.primary, borderRadius: BorderRadius.circular(5)),
                                                child: Icon(Icons.chat, color: themeChange.getThem() ? Colors.black : Colors.white),
                                              ),
                                            ),
                                            const SizedBox(
                                              width: 10,
                                            ),
                                            InkWell(
                                              onTap: () async {
                                                UserModel? customer = await FireStoreUtils.getCustomer(orderModel.userId.toString());
                                                Constant.makePhoneCall("${customer!.countryCode}${customer.phoneNumber}");
                                              },
                                              child: Container(
                                                height: 44,
                                                width: 44,
                                                decoration: BoxDecoration(
                                                    color: themeChange.getThem() ? AppColors.darkModePrimary : AppColors.primary, borderRadius: BorderRadius.circular(5)),
                                                child: Icon(Icons.call, color: themeChange.getThem() ? Colors.black : Colors.white),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    (orderModel.status == Constant.rideHold || orderModel.status == Constant.rideHoldAccepted)
                                        ? const SizedBox.shrink()
                                        : orderModel.status == Constant.rideActive
                                            ? Column(
                                                children: [
                                                  ButtonThem.buildButton(
                                                    context,
                                                    title: "Ir por el Pasajero",
                                                    btnHeight: 45,
                                                    // Te lleva a Google Maps para iniciar la navegación al punto de recogida
                                                    onPress: () async {
                                                      final lat = orderModel.sourceLocationLAtLng!.latitude;
                                                      final lng = orderModel.sourceLocationLAtLng!.longitude;

                                                      String url;

                                                      if (Platform.isAndroid) {
                                                        // Android: iniciar navegación directamente
                                                        url = 'google.navigation:q=$lat,$lng&mode=d';
                                                      } else {
                                                        // iOS: solo abre Google Maps con la ruta (no inicia automáticamente)
                                                        url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';
                                                      }

                                                      if (await canLaunch(url)) {
                                                        await launch(url);
                                                      } else {
                                                        ShowToastDialog.showToast("No se pudo abrir Google Maps".tr);
                                                      }
                                                    },
                                                  ),
                                                  const SizedBox(height: 10),
                                                                                                     ButtonThem.buildButton(
                                                     context,
                                                     title: "Cancelar Viaje",
                                                     btnHeight: 45,
                                                     bgColors: Colors.red,
                                                    onPress: () async {
                                                      // Mostrar diálogo de confirmación
                                                      bool? confirm = await showDialog<bool>(
                                                        context: context,
                                                        builder: (BuildContext context) {
                                                          return AlertDialog(
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                            backgroundColor: Colors.white,
                                                                                                                         title: Padding(
                                                               padding: const EdgeInsets.only(bottom: 10),
                                                               child: Row(
                                                                 children: [
                                                                   Icon(Icons.warning_amber_rounded, color: Colors.red),
                                                                   const SizedBox(width: 10),
                                                                   Text(
                                                                     "Confirmar Cancelación".tr,
                                                                     style: GoogleFonts.poppins(
                                                                       fontWeight: FontWeight.w600,
                                                                       fontSize: 15,
                                                                       color: Colors.black87,
                                                                     ),
                                                                   ),
                                                                 ],
                                                                 ),
                                                             ),
                                                                                                                         content: Padding(
                                                               padding: const EdgeInsets.symmetric(vertical: 15),
                                                               child: Text(
                                                                 "¿Está seguro que quiere cancelar este viaje?".tr,
                                                                 style: GoogleFonts.poppins(
                                                                   fontSize: 16,
                                                                   color: Colors.black54,
                                                                 ),
                                                                 textAlign: TextAlign.center,
                                                               ),
                                                             ),
                                                            actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                                            actions: [
                                                              TextButton(
                                                                style: TextButton.styleFrom(
                                                                  backgroundColor: Colors.grey.shade200,
                                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                                                ),
                                                                onPressed: () {
                                                                  Navigator.of(context).pop(false); // No
                                                                },
                                                                child: Text(
                                                                  "No".tr,
                                                                  style: GoogleFonts.poppins(
                                                                    fontWeight: FontWeight.w600,
                                                                    color: Colors.grey.shade800,
                                                                    fontSize: 16,
                                                                  ),
                                                                ),
                                                              ),
                                                              ElevatedButton(
                                                                style: ElevatedButton.styleFrom(
                                                                  backgroundColor: Colors.red,
                                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                                                                ),
                                                                onPressed: () {
                                                                  Navigator.of(context).pop(true); // Sí
                                                                },
                                                                child: Text(
                                                                  "Sí, Cancelar".tr,
                                                                  style: GoogleFonts.poppins(
                                                                    fontWeight: FontWeight.w700,
                                                                    fontSize: 16,
                                                                    color: Colors.white,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      );

                                                      if (confirm == true) {
                                                        // El usuario confirmó, ejecutamos la lógica de cancelar viaje
                                                        ShowToastDialog.showLoader("Cancelando viaje...".tr);
                                                        orderModel.status = Constant.rideCanceled;

                                                        await FireStoreUtils.getCustomer(orderModel.userId.toString()).then((value) async {
                                                          if (value != null && value.fcmToken != null) {
                                                            Map<String, dynamic> playLoad = <String, dynamic>{
                                                              "type": "city_order_canceled",
                                                              "orderId": orderModel.id,
                                                            };

                                                            await SendNotification.sendOneNotification(
                                                              token: value.fcmToken.toString(),
                                                              title: 'Viaje Cancelado'.tr,
                                                              body: 'El conductor ha cancelado el viaje.'.tr,
                                                              payload: playLoad,
                                                            );
                                                          }
                                                        });

                                                        await FireStoreUtils.setOrder(orderModel).then((value) {
                                                          if (value == true) {
                                                            ShowToastDialog.closeLoader();
                                                            ShowToastDialog.showToast("Viaje cancelado exitosamente.".tr);
                                                          }
                                                        });
                                                      }
                                                    },
                                                  ),
                                                ],
                                              )
                                            : orderModel.status == Constant.rideInProgress
                                                ? ButtonThem.buildButton(
                                                    context,
                                                    title: "Llevar al pasajero",
                                                    btnHeight: 45,
                                                    // Te lleva a Google Maps para iniciar la navegación al destino
                                                    onPress: () async {
                                                      print("Botón 'Llevar al pasajero' presionado");
                                                      final lat = orderModel.destinationLocationLAtLng!.latitude;
                                                      final lng = orderModel.destinationLocationLAtLng!.longitude;

                                                      String url;

                                                      if (Platform.isAndroid) {
                                                        url = 'google.navigation:q=$lat,$lng&mode=d';
                                                      } else {
                                                        // iOS fallback: abrir Maps con destino
                                                        url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';
                                                      }

                                                      if (await canLaunch(url)) {
                                                        await launch(url);
                                                      } else {
                                                        ShowToastDialog.showToast("No se pudo abrir Google Maps".tr);
                                                      }
                                                    }

                                                  )
                                                : const SizedBox.shrink(),
                                    const SizedBox(height: 5),
                                    orderModel.status.toString() == Constant.rideHold
                                        ? Align(
                                            alignment: Alignment.topLeft,
                                            child: Text("¿Quieres aceptar o rechazar la solicitud de retención?".tr, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                          )
                                        : SizedBox.shrink(),
                                    orderModel.status.toString() == Constant.rideHold
                                        ? Row(
                                            children: [
                                              Expanded(
                                                child: ButtonThem.buildBorderButton(
                                                  context,
                                                  title: "Reject".tr,
                                                  btnHeight: 45,
                                                  iconVisibility: false,
                                                  onPress: () async {
                                                    ShowToastDialog.showLoader("Por favor espera...".tr);
                                                    orderModel.status = Constant.rideInProgress;

                                                    await FireStoreUtils.setOrder(orderModel).then((value) {
                                                      if (value == true) {
                                                        ShowToastDialog.closeLoader();
                                                        ShowToastDialog.showToast("Ride hold request has been rejected.".tr);
                                                      }
                                                    });
                                                  },
                                                ),
                                              ),
                                              const SizedBox(
                                                width: 10,
                                              ),
                                              Expanded(
                                                child: ButtonThem.buildButton(
                                                  context,
                                                  title: "Accept".tr,
                                                  btnHeight: 45,
                                                  onPress: () async {
                                                    ShowToastDialog.showLoader("Por favor espera...".tr);
                                                    orderModel.status = Constant.rideHoldAccepted;
                                                    orderModel.acceptHoldTime = Timestamp.now();

                                                    await FireStoreUtils.setOrder(orderModel).then((value) {
                                                      if (value == true) {
                                                        ShowToastDialog.closeLoader();
                                                        ShowToastDialog.showToast("Ride has been put on hold.".tr);
                                                      }
                                                    });
                                                    await FireStoreUtils.getCustomer(orderModel.userId.toString()).then((value) async {
                                                      if (value != null) {
                                                        await SendNotification.sendOneNotification(
                                                            token: value.fcmToken.toString(),
                                                            title: 'Ride Hold Accepted'.tr,
                                                            body: 'Driver has accepted your ride hold request'.tr,
                                                            payload: {});
                                                      }
                                                    });
                                                  },
                                                ),
                                              )
                                            ],
                                          )
                                        : SizedBox.shrink(),
                                    orderModel.status.toString() == Constant.rideHoldAccepted
                                        ? ButtonThem.buildButton(
                                            context,
                                            title: "Finalizar antiguo".tr,
                                            btnHeight: 45,
                                            onPress: () async {
                                              ShowToastDialog.showLoader("Por favor espera...".tr);
                                              orderModel.status = Constant.rideInProgress;
                                              DateTime acceptTime = orderModel.acceptHoldTime!.toDate();
                                              int rideHoldTimeInSeconds = DateTime.now().difference(acceptTime).inSeconds;
                                              int rideHoldTimeInMinutos = (rideHoldTimeInSeconds / 60).ceil();

                                              int chargePerInterval = int.parse(orderModel.service!.holdingMinuteCharge.toString());
                                              int holdingInterval = int.parse(orderModel.service!.holdingMinute.toString());

                                              int intervals = rideHoldTimeInMinutos ~/ holdingInterval;
                                              int extraTime = rideHoldTimeInMinutos % holdingInterval;

                                              int totalHoldingCharges = intervals * chargePerInterval;

                                              if (extraTime > 0 || rideHoldTimeInSeconds % 60 > 0) {
                                                totalHoldingCharges += chargePerInterval;
                                              }
                                              orderModel.acceptHoldTime = null;
                                              orderModel.rideHoldTimeMinutos = rideHoldTimeInMinutos.toString();
                                              orderModel.totalHoldingCharges = totalHoldingCharges.toString();

                                              await FireStoreUtils.setOrder(orderModel).then((value) {
                                                if (value == true) {
                                                  ShowToastDialog.closeLoader();
                                                  ShowToastDialog.showToast("Ride hold has ended".tr);
                                                }
                                              });
                                              await FireStoreUtils.getCustomer(orderModel.userId.toString()).then((value) async {
                                                if (value != null) {
                                                  await SendNotification.sendOneNotification(
                                                      token: value.fcmToken.toString(), title: 'Ride Hold Ended'.tr, body: 'Driver has ended the ride hold.'.tr, payload: {});
                                                }
                                              });
                                            },
                                          )
                                        : SizedBox.shrink(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      });
            },
          );
        });
  }

  otpDialog(BuildContext context, ActiveOrderController controller, OrderModel orderModel) {
    final themeChange = Provider.of<DarkThemeProvider>(context);

    return WillPopScope(
      onWillPop: () async {
        controller.resetOTPController();
        return true;
      },
      child: Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
              const SizedBox(height: 10),
              Text("Verificar codigo del cliente".tr, 
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: PinCodeTextField(
                length: 6,
                appContext: context,
                keyboardType: TextInputType.phone,
                pinTheme: PinTheme(
                  fieldHeight: 40,
                  fieldWidth: 40,
                    activeColor: themeChange.getThem() 
                        ? AppColors.darkTextFieldBorder 
                        : AppColors.textFieldBorder,
                    selectedColor: themeChange.getThem() 
                        ? AppColors.darkTextFieldBorder 
                        : AppColors.textFieldBorder,
                    inactiveColor: themeChange.getThem() 
                        ? AppColors.darkTextFieldBorder 
                        : AppColors.textFieldBorder,
                    activeFillColor: themeChange.getThem() 
                        ? AppColors.darkTextField 
                        : AppColors.textField,
                    inactiveFillColor: themeChange.getThem() 
                        ? AppColors.darkTextField 
                        : AppColors.textField,
                    selectedFillColor: themeChange.getThem() 
                        ? AppColors.darkTextField 
                        : AppColors.textField,
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
              const SizedBox(height: 10),
              ButtonThem.buildButton(
                context, 
                title: "Verificar codigo".tr, 
                onPress: () async {
              if (orderModel.otp.toString() == controller.otpController.value.text) {
                Get.back();
                ShowToastDialog.showLoader("Por favor espera...".tr);
                orderModel.status = Constant.rideInProgress;
                // Aplicar comisión de administrador al verificar el código del pasajero
                String? couponAmount = "0.0";
                if (orderModel.coupon != null) {
                  if (orderModel.coupon?.code != null) {
                    if (orderModel.coupon!.type == "fix") {
                      couponAmount = orderModel.coupon!.amount.toString();
                    } else {
                      couponAmount =
                          ((double.parse(orderModel.finalRate.toString()) * double.parse(orderModel.coupon!.amount.toString())) / 100)
                              .toString();
                    }
                  }
                }

                WalletTransactionModel adminCommissionWallet = WalletTransactionModel(
                    id: Constant.getUuid(),
                    amount:
                        "-${Constant.calculateAdminCommission(amount: (double.parse(orderModel.finalRate.toString()) - double.parse(couponAmount.toString())).toString(), adminCommission: Constant.adminCommission)}",
                    createdDate: Timestamp.now(),
                    paymentType: "wallet".tr,
                    transactionId: orderModel.id,
                    orderType: "city",
                    userType: "driver",
                    userId: orderModel.driverId.toString(),
                    note: "Comisión de administración (${Constant.adminCommission?.amount}%)".tr);

                await FireStoreUtils.setWalletTransaction(adminCommissionWallet).then((value) async {
                  if (value == true) {
                    await FireStoreUtils.updatedDriverWallet(
                        amount:
                            "-${Constant.calculateAdminCommission(amount: (double.parse(orderModel.finalRate.toString()) - double.parse(couponAmount.toString())).toString(), adminCommission: Constant.adminCommission)}");
                  }
                });
                
                await FireStoreUtils.getCustomer(orderModel.userId.toString())
                    .then((value) async {
                  if (value != null) {
                    await SendNotification.sendOneNotification(
                        token: value.fcmToken.toString(),
                        title: 'Ride Started'.tr,
                        body: 'The ride has officially started. Please follow the designated route to the destination.'.tr,
                        payload: {});
                  }
                });

                await FireStoreUtils.setOrder(orderModel).then((value) {
                  if (value == true) {
                    ShowToastDialog.closeLoader();
                    ShowToastDialog.showToast("Cliente Recogido con éxito".tr);
                  }
                });
              } else {
                    ShowToastDialog.showToast("OTP Incorrecto".tr);
              }
                }
              ),
              const SizedBox(height: 10),
              ButtonThem.buildBorderButton(
                context,
                title: "Cancelar".tr,
                btnHeight: 44,
                iconVisibility: false,
                onPress: () {
                  controller.resetOTPController();
                  Get.back();
                },
            ),
          ],
          ),
        ),
      ),
    );
  }
}
