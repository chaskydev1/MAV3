import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' as cloudFirestore;
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/send_notification.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/order/driverId_accept_reject.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart' as prefix;
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
//here

class OrderMapController extends GetxController {
  // Agregar la API key como variable global
  static const String mapAPIKey = "AIzaSyBF8F0YnhknJa_cvyMmaJvRVTqPS-somdk";

  final Completer<GoogleMapController> mapController = Completer<GoogleMapController>();
  Rx<TextEditingController> enterOfferRateController = TextEditingController().obs;

  RxBool isLoading = true.obs;
  DateTime currentTime = DateTime.now();
  DateTime currentDate = DateTime.now();
  DateTime startNightTimeString = DateTime.now();
  DateTime endNightTimeString = DateTime.now();

  @override
  void onInit() {
    addMarkerSetup();
    getArgument();
    super.onInit();
  }

  @override
  void onClose() {
    ShowToastDialog.closeLoader();
    super.onClose();
  }

  // Agregar esta variable
  RxBool isProcessingOrder = false.obs;

  // Modificar el método acceptOrder
  Future<void> acceptOrder() async {
    if (isProcessingOrder.value) {
      ShowToastDialog.showToast("Procesando solicitud anterior...".tr);
      return;
    }

    try {
      isProcessingOrder.value = true;
      ShowToastDialog.showLoader("Por favor espera".tr);

      if (double.parse(driverModel.value.walletAmount.toString()) >= double.parse(Constant.minimumDepositToRideAccept)) {
        List<dynamic> newAcceptedDriverId = [];
        if (orderModel.value.acceptedDriverId != null) {
          newAcceptedDriverId = orderModel.value.acceptedDriverId!;
        } else {
          newAcceptedDriverId = [];
        }
        newAcceptedDriverId.add(FireStoreUtils.getCurrentUid());
        orderModel.value.acceptedDriverId = newAcceptedDriverId;
        if (orderModel.value.isAcSelected == true) {
          orderModel.value.acNonAcCharges = driverModel.value.vehicleInformation!.acPerKmRate;
        } else {
          orderModel.value.acNonAcCharges = driverModel.value.vehicleInformation!.nonAcPerKmRate;
        }
        // orderModel.value.offerRate = newAmount.value;
        await FireStoreUtils.setOrder(orderModel.value);

        await FireStoreUtils.getCustomer(orderModel.value.userId.toString()).then((value) async {
          if (value != null) {
            await SendNotification.sendOneNotification(
                token: value.fcmToken.toString(),
                title: 'New Driver Bid'.tr,
                body: 'Driver has offered ${Constant.amountShow(amount: finalAmount.value.toString())} for your journey.🚗'.tr,
                payload: {});
          }
        });

        DriverIdAcceptReject driverIdAcceptReject =
            DriverIdAcceptReject(driverId: FireStoreUtils.getCurrentUid(), acceptedRejectTime: cloudFirestore.Timestamp.now(), offerAmount: finalAmount.value.toString());
        FireStoreUtils.acceptRide(orderModel.value, driverIdAcceptReject).then((value) async {
          ShowToastDialog.closeLoader();
          ShowToastDialog.showToast("Ride Accepted".tr);
          if (driverModel.value.subscriptionTotalOrders != "-1") {
            driverModel.value.subscriptionTotalOrders = (int.parse(driverModel.value.subscriptionTotalOrders.toString()) - 1).toString();
            await FireStoreUtils.updateDriverUser(driverModel.value);
          }
          Get.back(result: true);
        });
      } else {
        ShowToastDialog.showToast(
            "You have to minimum ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept.toString())} wallet amount to Accept Order and place a bid".tr);
      }
    } catch (e) {
      ShowToastDialog.showToast("Error al procesar la solicitud".tr);
    } finally {
      isProcessingOrder.value = false;
      ShowToastDialog.closeLoader();
    }
  }

  Rx<OrderModel> orderModel = OrderModel().obs;
  Rx<DriverUserModel> driverModel = DriverUserModel().obs;

  getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      String orderId = argumentData['orderModel'];
      await getData(orderId);
      
      // Inicializar el campo de texto con offerRate
      enterOfferRateController.value.text = orderModel.value.offerRate?.toString() ?? '0.00';
      // También actualizar las variables amount y finalAmount
      amount.value = double.tryParse(orderModel.value.offerRate?.toString() ?? '0.00') ?? 0.00;
      finalAmount.value = amount.value + totalChargeOfMinute.value +
          (double.tryParse(orderModel.value.service?.basicFareCharge.toString() ?? '0.00') ?? 0.00);

      // Agregar marcadores cuando tengamos los datos
      if (orderModel.value.sourceLocationLAtLng != null) {
        addMarker(
          LatLng(
            orderModel.value.sourceLocationLAtLng!.latitude ?? 0.0,  // Valor por defecto 0.0
            orderModel.value.sourceLocationLAtLng!.longitude ?? 0.0  // Valor por defecto 0.0
          ),
          "pickup",
          departureIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
        );
      }

      if (orderModel.value.destinationLocationLAtLng != null) {
        addMarker(
          LatLng(
            orderModel.value.destinationLocationLAtLng!.latitude ?? 0.0,  // Valor por defecto 0.0
            orderModel.value.destinationLocationLAtLng!.longitude ?? 0.0  // Valor por defecto 0.0
          ),
          "destination",
          destinationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
        );
      }

      // Dibujar la ruta entre los puntos
      if (orderModel.value.sourceLocationLAtLng != null && 
          orderModel.value.destinationLocationLAtLng != null) {
        getPolyline(
          driverLatitude: Constant.currentLocation?.latitude,
          driverLongitude: Constant.currentLocation?.longitude,
          sourceLatitude: orderModel.value.sourceLocationLAtLng?.latitude,
          sourceLongitude: orderModel.value.sourceLocationLAtLng?.longitude,
          destinationLatitude: orderModel.value.destinationLocationLAtLng?.latitude,
          destinationLongitude: orderModel.value.destinationLocationLAtLng?.longitude,
        );
      }
    }

    FireStoreUtils.fireStore.collection(CollectionName.driverUsers).doc(FireStoreUtils.getCurrentUid()).snapshots().listen((event) async {
      if (event.exists) {
        driverModel.value = DriverUserModel.fromJson(event.data()!);
// No llamar a calculateAmount() aquí para preservar el valor inicial
      }
    });

    isLoading.value = false;
  }

  getData(String id) async {
    await FireStoreUtils.getOrder(id).then((value) {
      if (value != null) {
        orderModel.value = value;
      }
    });
  }

  RxDouble amount = 0.0.obs;
  RxDouble finalAmount = 0.0.obs;
  RxString startNightTime = "".obs;
  RxString endNightTime = "".obs;
  RxDouble totalNightFare = 0.0.obs;
  RxDouble totalChargeOfMinute = 0.0.obs;
  RxDouble basicFare = 0.0.obs;

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

    double durationValueInMinutes = convertToMinutes(orderModel.value.duration.toString());
    double distance = double.tryParse(orderModel.value.distance.toString()) ?? 0.0;
    double nonAcChargeValue = double.tryParse(driverModel.value.vehicleInformation!.nonAcPerKmRate.toString()) ?? 0.0;
    double acChargeValue = double.tryParse(driverModel.value.vehicleInformation!.acPerKmRate.toString()) ?? 0.0;
    double kmCharge = double.tryParse(driverModel.value.vehicleInformation!.perKmRate!.toString()) ?? 0.0;

    totalChargeOfMinute.value = double.parse(durationValueInMinutes.toString()) * double.parse(orderModel.value.service!.perMinuteCharge.toString());
    basicFare.value = double.parse(orderModel.value.service!.basicFareCharge.toString());

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
        amount.value = amount.value * double.parse(orderModel.value.service!.nightCharge.toString());
        totalChargeOfMinute.value = totalChargeOfMinute.value * double.parse(orderModel.value.service!.nightCharge.toString());
        basicFare.value = basicFare.value * double.parse(orderModel.value.service!.nightCharge.toString());
      }
    }

// Solo actualizar si amount es 0 o no hay offerRate previo
    if (amount.value == 0.0 && (orderModel.value.offerRate == null || orderModel.value.offerRate == '0.00')) {
        // ... resto del código de cálculo ...
    }

    // Actualizar finalAmount pero NO el texto del controlador
    finalAmount.value = amount.value + basicFare.value + totalChargeOfMinute.value;
      }

  // Add this method to calculate the recommended price
  double calculateRecommendedPrice() {
    double rawDistance = double.parse(orderModel.value.distance.toString());
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

  BitmapDescriptor? departureIcon;
  BitmapDescriptor? destinationIcon;

  addMarkerSetup() async {
    if (Constant.selectedMapType == 'google') {
      final Uint8List departure = await Constant().getBytesFromAsset('assets/images/pickup.png', 100);
      final Uint8List destination = await Constant().getBytesFromAsset('assets/images/dropoff.png', 100);
      departureIcon = BitmapDescriptor.fromBytes(departure);
      destinationIcon = BitmapDescriptor.fromBytes(destination);
    } else {
      departureOsmIcon = Image.asset("assets/images/pickup.png", width: 30, height: 30); //OSM
      destinationOsmIcon = Image.asset("assets/images/dropoff.png", width: 30, height: 30); //OSM
    }
  }

  RxMap<MarkerId, Marker> markers = <MarkerId, Marker>{}.obs;
  RxMap<PolylineId, Polyline> polyLines = <PolylineId, Polyline>{}.obs;
  PolylinePoints polylinePoints = PolylinePoints();

  void getPolyline({
    required double? driverLatitude,
    required double? driverLongitude,
    required double? sourceLatitude,
    required double? sourceLongitude,
    required double? destinationLatitude,
    required double? destinationLongitude
}) async {
    print("==== Trazando rutas ====");
    
    if (driverLatitude != null && driverLongitude != null && 
        sourceLatitude != null && sourceLongitude != null && 
        destinationLatitude != null && destinationLongitude != null) {
        try {
            // Ruta 1: Conductor -> Pasajero
            final request1 = PolylineRequest(
                origin: PointLatLng(driverLatitude, driverLongitude),
                destination: PointLatLng(sourceLatitude, sourceLongitude),
                mode: TravelMode.driving,
            );

            PolylineResult driverToSource = await polylinePoints.getRouteBetweenCoordinates(
                googleApiKey: mapAPIKey,
                request: request1
            );

            // Ruta 2: Pasajero -> Destino
            final request2 = PolylineRequest(
                origin: PointLatLng(sourceLatitude, sourceLongitude),
                destination: PointLatLng(destinationLatitude, destinationLongitude),
                mode: TravelMode.driving,
            );

            PolylineResult sourceToDestination = await polylinePoints.getRouteBetweenCoordinates(
                googleApiKey: mapAPIKey,
                request: request2
            );

            polyLines.clear();

            // Dibujar ruta conductor -> pasajero
            if (driverToSource.points.isNotEmpty) {
                List<LatLng> polylineCoordinates = driverToSource.points
                    .map((point) => LatLng(point.latitude, point.longitude))
                    .toList();

                PolylineId id1 = const PolylineId("poly1");
                final Polyline polyline1 = Polyline(
                    polylineId: id1,
                    color: Colors.blue,
                    points: polylineCoordinates,
                    width: 6,
                    geodesic: true
                );
                polyLines[id1] = polyline1;
            }

            // Dibujar ruta pasajero -> destino
            if (sourceToDestination.points.isNotEmpty) {
                List<LatLng> polylineCoordinates = sourceToDestination.points
                    .map((point) => LatLng(point.latitude, point.longitude))
                    .toList();

                PolylineId id2 = const PolylineId("poly2");
                final Polyline polyline2 = Polyline(
                    polylineId: id2,
                    color: Colors.green,
                    points: polylineCoordinates,
                    width: 6,
                    geodesic: true
                );
                polyLines[id2] = polyline2;
            }

            update();  // Actualizar UI
            
        } catch (e) {
            print("❌ Error al trazar las rutas: $e");
        }
    } else {
        print("❌ Coordenadas incompletas para trazar las rutas");
    }
  }

  double zoomLevel = 0;

  movePosition() async {
    double distance = double.parse((prefix.Geolocator.distanceBetween(
              orderModel.value.sourceLocationLAtLng!.latitude ?? 0.0,
              orderModel.value.sourceLocationLAtLng!.longitude ?? 0.0,
              orderModel.value.destinationLocationLAtLng!.latitude ?? 0.0,
              orderModel.value.destinationLocationLAtLng!.longitude ?? 0.0,
            ) /
            1609.32)
        .toString());
    LatLng center = LatLng(
      (orderModel.value.sourceLocationLAtLng!.latitude! + orderModel.value.destinationLocationLAtLng!.latitude!) / 2,
      (orderModel.value.sourceLocationLAtLng!.longitude! + orderModel.value.destinationLocationLAtLng!.longitude!) / 2,
    );

    double radiusElevated = (distance / 2) + ((distance / 2) / 2);
    double scale = radiusElevated / 500;

    zoomLevel = 5 - log(scale) / log(2);

    final GoogleMapController controller = await mapController.future;
    controller.moveCamera(CameraUpdate.newLatLngZoom(center, zoomLevel));
  }

  _addPolyLine(List<LatLng> polylineCoordinates) {
    PolylineId id = const PolylineId("poly");
    Polyline polyline = Polyline(
      polylineId: id,
      points: polylineCoordinates,
      width: 6,
    );
    polyLines[id] = polyline;
  }

  addMarker(LatLng? position, String id, BitmapDescriptor? descriptor) {
    MarkerId markerId = MarkerId(id);
    Marker marker = Marker(
      markerId: markerId,
      icon: id == "pickup" 
          ? BitmapDescriptor.defaultMarker
        // BitmapDescriptor.defaultMarker (rojo)
        // BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)
        // BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)
        : (descriptor ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
      position: position!,
      infoWindow: InfoWindow(
        title: id == "pickup" ? "Pasajero" : "Destino",
        //snippet: id == "pickup" ? orderModel.value.userName : null,
      ),
    );
    markers[markerId] = marker;
  }

  //OSM
  late MapController mapOsmController;
  Rx<RoadInfo> roadInfo = RoadInfo().obs;
  Map<String, GeoPoint> osmMarkers = <String, GeoPoint>{};
  Image? departureOsmIcon; //OSM
  Image? destinationOsmIcon; //OSM

  void getOSMPolyline(themeChange) async {
    try {
      if (orderModel.value.sourceLocationLAtLng != null && orderModel.value.destinationLocationLAtLng != null) {
        setOsmMarker(
          departure: GeoPoint(latitude: orderModel.value.sourceLocationLAtLng?.latitude ?? 0.0, longitude: orderModel.value.sourceLocationLAtLng?.longitude ?? 0.0),
          destination: GeoPoint(latitude: orderModel.value.destinationLocationLAtLng?.latitude ?? 0.0, longitude: orderModel.value.destinationLocationLAtLng?.longitude ?? 0.0),
        );
        await mapOsmController.removeLastRoad();
        roadInfo.value = await mapOsmController.drawRoad(
          GeoPoint(latitude: orderModel.value.sourceLocationLAtLng?.latitude ?? 0, longitude: orderModel.value.sourceLocationLAtLng?.longitude ?? 0),
          GeoPoint(latitude: orderModel.value.destinationLocationLAtLng?.latitude ?? 0, longitude: orderModel.value.destinationLocationLAtLng?.longitude ?? 0),
          roadType: RoadType.car,
          roadOption: RoadOption(
            roadWidth: 15,
            roadColor: themeChange ? AppColors.darkModePrimary : AppColors.primary,
            zoomInto: false,
          ),
        );

        updateCameraLocation(
            source: GeoPoint(latitude: orderModel.value.sourceLocationLAtLng?.latitude ?? 0, longitude: orderModel.value.sourceLocationLAtLng?.longitude ?? 0),
            destination: GeoPoint(latitude: orderModel.value.destinationLocationLAtLng?.latitude ?? 0, longitude: orderModel.value.destinationLocationLAtLng?.longitude ?? 0));
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> updateCameraLocation({required GeoPoint source, required GeoPoint destination}) async {
    BoundingBox bounds;

    if (source.latitude > destination.latitude && source.longitude > destination.longitude) {
      bounds = BoundingBox(
        north: source.latitude,
        south: destination.latitude,
        east: source.longitude,
        west: destination.longitude,
      );
    } else if (source.longitude > destination.longitude) {
      bounds = BoundingBox(
        north: destination.latitude,
        south: source.latitude,
        east: source.longitude,
        west: destination.longitude,
      );
    } else if (source.latitude > destination.latitude) {
      bounds = BoundingBox(
        north: source.latitude,
        south: destination.latitude,
        east: destination.longitude,
        west: source.longitude,
      );
    } else {
      bounds = BoundingBox(
        north: destination.latitude,
        south: source.latitude,
        east: destination.longitude,
        west: source.longitude,
      );
    }

    await mapOsmController.zoomToBoundingBox(bounds, paddinInPixel: 300);
  }

  setOsmMarker({required GeoPoint departure, required GeoPoint destination}) async {
    if (osmMarkers.containsKey('Source')) {
      await mapOsmController.removeMarker(osmMarkers['Source']!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await mapOsmController
          .addMarker(departure,
              markerIcon: MarkerIcon(iconWidget: departureOsmIcon),
              angle: pi / 3,
              iconAnchor: IconAnchor(
                anchor: Anchor.top,
              ))
          .then((v) {
        osmMarkers['Source'] = departure;
      });

      if (osmMarkers.containsKey('Destination')) {
        await mapOsmController.removeMarker(osmMarkers['Destination']!);
      }

      await mapOsmController
          .addMarker(destination,
              markerIcon: MarkerIcon(iconWidget: destinationOsmIcon),
              angle: pi / 3,
              iconAnchor: IconAnchor(
                anchor: Anchor.top,
              ))
          .then((v) {
        osmMarkers['Destination'] = destination;
      });
    });
  }

  double convertToMinutes(String duration) {
    double durationValue = 0.0;

    try {
      final RegExp hoursRegex = RegExp(r"(\d+)\s*hour");
      final RegExp minutesRegex = RegExp(r"(\d+)\s*min");

      final Match? hoursMatch = hoursRegex.firstMatch(duration);
      if (hoursMatch != null) {
        int hours = int.parse(hoursMatch.group(1)!.trim());
        durationValue += hours * 60;
      }

      final Match? minutesMatch = minutesRegex.firstMatch(duration);
      if (minutesMatch != null) {
        int minutes = int.parse(minutesMatch.group(1)!.trim());
        durationValue += minutes;
      }
    } catch (e) {
      print("Exception: $e");
      throw FormatException("Invalid duration format: $duration");
    }

    return durationValue;
  }

  // Agregar variable para controlar la visibilidad
  RxBool isBoxVisible = true.obs;

  // Agregar método para alternar la visibilidad
  void toggleBoxVisibility() {
    isBoxVisible.value = !isBoxVisible.value;
  }
}
