import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

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

class OrderMapController extends GetxController {
  /// API Key de Google Maps Directions (para flutter_polyline_points v3)
  static const String mapAPIKey = "AIzaSyBF8F0YnhknJa_cvyMmaJvRVTqPS-somdk";

  final Completer<GoogleMapController> mapController = Completer<GoogleMapController>();
  Rx<TextEditingController> enterOfferRateController = TextEditingController().obs;

  RxBool isLoading = true.obs;
  DateTime currentTime = DateTime.now();
  DateTime currentDate = DateTime.now();
  DateTime startNightTimeString = DateTime.now();
  DateTime endNightTimeString = DateTime.now();

  /// Evita doble tap en aceptar
  RxBool isProcessingOrder = false.obs;

  Rx<OrderModel> orderModel = OrderModel().obs;
  Rx<DriverUserModel> driverModel = DriverUserModel().obs;

  /// Íconos Google
  BitmapDescriptor? departureIcon;
  BitmapDescriptor? destinationIcon;

  /// Polylines Google
  RxMap<MarkerId, Marker> markers = <MarkerId, Marker>{}.obs;
  RxMap<PolylineId, Polyline> polyLines = <PolylineId, Polyline>{}.obs;

  /// Instancia v3 con apiKey en constructor
  final PolylinePoints polylinePoints = PolylinePoints(apiKey: OrderMapController.mapAPIKey);

  /// OSM
  late MapController mapOsmController;
  Rx<RoadInfo> roadInfo = RoadInfo().obs;
  Map<String, GeoPoint> osmMarkers = <String, GeoPoint>{};
  Image? departureOsmIcon; // OSM
  Image? destinationOsmIcon; // OSM

  RxDouble amount = 0.0.obs;
  RxDouble finalAmount = 0.0.obs;
  RxString startNightTime = "".obs;
  RxString endNightTime = "".obs;
  RxDouble totalNightFare = 0.0.obs;
  RxDouble totalChargeOfMinute = 0.0.obs;
  RxDouble basicFare = 0.0.obs;

  /// Control de visibilidad UI
  RxBool isBoxVisible = true.obs;

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

  /// Aceptar orden con protección de doble toque
  Future<void> acceptOrder() async {
    if (isProcessingOrder.value) {
      ShowToastDialog.showToast("Procesando solicitud anterior...".tr);
      return;
    }

    try {
      isProcessingOrder.value = true;
      ShowToastDialog.showLoader("Por favor espera".tr);

      if (double.parse(driverModel.value.walletAmount.toString()) >=
          double.parse(Constant.minimumDepositToRideAccept)) {
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

        await FireStoreUtils.setOrder(orderModel.value);

        await FireStoreUtils.getCustomer(orderModel.value.userId.toString()).then((value) async {
          if (value != null) {
            await SendNotification.sendOneNotification(
              token: value.fcmToken.toString(),
              title: 'New Driver Bid'.tr,
              body: 'Driver has offered ${Constant.amountShow(amount: finalAmount.value.toString())} for your journey.🚗'.tr,
              payload: {},
            );
          }
        });

        DriverIdAcceptReject driverIdAcceptReject = DriverIdAcceptReject(
          driverId: FireStoreUtils.getCurrentUid(),
          acceptedRejectTime: cloudFirestore.Timestamp.now(),
          offerAmount: finalAmount.value.toString(),
        );

        FireStoreUtils.acceptRide(orderModel.value, driverIdAcceptReject).then((value) async {
          ShowToastDialog.closeLoader();
          ShowToastDialog.showToast("Ride Accepted".tr);
          if (driverModel.value.subscriptionTotalOrders != "-1") {
            driverModel.value.subscriptionTotalOrders =
                (int.parse(driverModel.value.subscriptionTotalOrders.toString()) - 1).toString();
            await FireStoreUtils.updateDriverUser(driverModel.value);
          }
          Get.back(result: true);
        });
      } else {
        ShowToastDialog.showToast(
          "Debe tener mínimo de ${Constant.amountShow(amount: Constant.minimumDepositToRideAccept.toString())} para aceptar un pedido.".tr,
        );
      }
    } catch (e) {
      ShowToastDialog.showToast("Error al procesar la solicitud".tr);
    } finally {
      isProcessingOrder.value = false;
      ShowToastDialog.closeLoader();
    }
  }

  /// Obtener argumentos y preparar mapa
  Future<void> getArgument() async {
    final argumentData = Get.arguments;
    if (argumentData != null) {
      final String orderId = argumentData['orderModel'];
      await getData(orderId);

      // Inicializaciones de oferta
      enterOfferRateController.value.text = orderModel.value.offerRate?.toString() ?? '0.00';
      amount.value = double.tryParse(orderModel.value.offerRate?.toString() ?? '0.00') ?? 0.00;
      finalAmount.value = amount.value +
          totalChargeOfMinute.value +
          (double.tryParse(orderModel.value.service?.basicFareCharge.toString() ?? '0.00') ?? 0.00);

      // Marcadores
      if (orderModel.value.sourceLocationLAtLng != null) {
        addMarker(
          LatLng(
            orderModel.value.sourceLocationLAtLng!.latitude ?? 0.0,
            orderModel.value.sourceLocationLAtLng!.longitude ?? 0.0,
          ),
          "pickup",
          departureIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        );
      }

      if (orderModel.value.destinationLocationLAtLng != null) {
        addMarker(
          LatLng(
            orderModel.value.destinationLocationLAtLng!.latitude ?? 0.0,
            orderModel.value.destinationLocationLAtLng!.longitude ?? 0.0,
          ),
          "destination",
          destinationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        );
      }

      // Polylines
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

    FireStoreUtils.fireStore
        .collection(CollectionName.driverUsers)
        .doc(FireStoreUtils.getCurrentUid())
        .snapshots()
        .listen((event) async {
      if (event.exists) {
        driverModel.value = DriverUserModel.fromJson(event.data()!);
        // Intencionalmente NO llamamos calculateAmount() aquí para preservar el valor inicial
      }
    });

    isLoading.value = false;
  }

  Future<void> getData(String id) async {
    await FireStoreUtils.getOrder(id).then((value) {
      if (value != null) {
        orderModel.value = value;
      }
    });
  }

  Future<void> addMarkerSetup() async {
    if (Constant.selectedMapType == 'google') {
      final Uint8List departure = await Constant().getBytesFromAsset('assets/images/pickup.png', 100);
      final Uint8List destination = await Constant().getBytesFromAsset('assets/images/dropoff.png', 100);
      departureIcon = BitmapDescriptor.fromBytes(departure);
      destinationIcon = BitmapDescriptor.fromBytes(destination);
    } else {
      departureOsmIcon = Image.asset("assets/images/pickup.png", width: 30, height: 30); // OSM
      destinationOsmIcon = Image.asset("assets/images/dropoff.png", width: 30, height: 30); // OSM
    }
  }

  void addMarker(LatLng? position, String id, BitmapDescriptor? descriptor) {
    final markerId = MarkerId(id);
    final marker = Marker(
      markerId: markerId,
      icon: id == "pickup"
          ? BitmapDescriptor.defaultMarker
          : (descriptor ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
      position: position!,
      infoWindow: InfoWindow(
        title: id == "pickup" ? "Pasajero" : "Destino",
      ),
    );
    markers[markerId] = marker;
  }

  /// Traza dos rutas: Conductor->Pasajero y Pasajero->Destino (API v3)
  void getPolyline({
    required double? driverLatitude,
    required double? driverLongitude,
    required double? sourceLatitude,
    required double? sourceLongitude,
    required double? destinationLatitude,
    required double? destinationLongitude,
  }) async {
    if (driverLatitude != null &&
        driverLongitude != null &&
        sourceLatitude != null &&
        sourceLongitude != null &&
        destinationLatitude != null &&
        destinationLongitude != null) {
      try {
        // Conductor -> Pasajero
        final request1 = PolylineRequest(
          origin: PointLatLng(driverLatitude, driverLongitude),
          destination: PointLatLng(sourceLatitude, sourceLongitude),
          mode: TravelMode.driving,
        );

        final driverToSource = await polylinePoints.getRouteBetweenCoordinates(
          request: request1,
        );

        // Pasajero -> Destino
        final request2 = PolylineRequest(
          origin: PointLatLng(sourceLatitude, sourceLongitude),
          destination: PointLatLng(destinationLatitude, destinationLongitude),
          mode: TravelMode.driving,
        );

        final sourceToDestination = await polylinePoints.getRouteBetweenCoordinates(
          request: request2,
        );

        polyLines.clear();

        if (driverToSource.points.isNotEmpty) {
          final coords = driverToSource.points
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList();

          polyLines[const PolylineId("poly1")] = Polyline(
            polylineId: const PolylineId("poly1"),
            color: Colors.blue,
            points: coords,
            width: 6,
            geodesic: true,
          );
        }

        if (sourceToDestination.points.isNotEmpty) {
          final coords = sourceToDestination.points
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList();

          polyLines[const PolylineId("poly2")] = Polyline(
            polylineId: const PolylineId("poly2"),
            color: Colors.green,
            points: coords,
            width: 6,
            geodesic: true,
          );
        }

        update(); // refresca UI
      } catch (e) {
        if (kDebugMode) {
          print("❌ Error al trazar las rutas: $e");
        }
      }
    } else {
      if (kDebugMode) {
        print("❌ Coordenadas incompletas para trazar las rutas");
      }
    }
  }

  double zoomLevel = 0;

  Future<void> movePosition() async {
    final distance = double.parse(
      (prefix.Geolocator.distanceBetween(
                orderModel.value.sourceLocationLAtLng!.latitude ?? 0.0,
                orderModel.value.sourceLocationLAtLng!.longitude ?? 0.0,
                orderModel.value.destinationLocationLAtLng!.latitude ?? 0.0,
                orderModel.value.destinationLocationLAtLng!.longitude ?? 0.0,
              ) /
              1609.32)
          .toString(),
    );

    final center = LatLng(
      (orderModel.value.sourceLocationLAtLng!.latitude! +
              orderModel.value.destinationLocationLAtLng!.latitude!) /
          2,
      (orderModel.value.sourceLocationLAtLng!.longitude! +
              orderModel.value.destinationLocationLAtLng!.longitude!) /
          2,
    );

    final radiusElevated = (distance / 2) + ((distance / 2) / 2);
    final scale = radiusElevated / 500;

    zoomLevel = 5 - log(scale) / log(2);

    final controller = await mapController.future;
    controller.moveCamera(CameraUpdate.newLatLngZoom(center, zoomLevel));
  }

  void _addPolyLine(List<LatLng> polylineCoordinates) {
    const id = PolylineId("poly");
    final polyline = Polyline(
      polylineId: id,
      points: polylineCoordinates,
      width: 6,
    );
    polyLines[id] = polyline;
  }

  /// ===================== OSM =====================
  Future<void> getOSMPolyline(themeChange) async {
    try {
      if (orderModel.value.sourceLocationLAtLng != null &&
          orderModel.value.destinationLocationLAtLng != null) {
        setOsmMarker(
          departure: GeoPoint(
            latitude: orderModel.value.sourceLocationLAtLng?.latitude ?? 0.0,
            longitude: orderModel.value.sourceLocationLAtLng?.longitude ?? 0.0,
          ),
          destination: GeoPoint(
            latitude: orderModel.value.destinationLocationLAtLng?.latitude ?? 0.0,
            longitude: orderModel.value.destinationLocationLAtLng?.longitude ?? 0.0,
          ),
        );
        await mapOsmController.removeLastRoad();
        roadInfo.value = await mapOsmController.drawRoad(
          GeoPoint(
            latitude: orderModel.value.sourceLocationLAtLng?.latitude ?? 0,
            longitude: orderModel.value.sourceLocationLAtLng?.longitude ?? 0,
          ),
          GeoPoint(
            latitude: orderModel.value.destinationLocationLAtLng?.latitude ?? 0,
            longitude: orderModel.value.destinationLocationLAtLng?.longitude ?? 0,
          ),
          roadType: RoadType.car,
          roadOption: RoadOption(
            roadWidth: 15,
            roadColor: themeChange ? AppColors.darkModePrimary : AppColors.primary,
            zoomInto: false,
          ),
        );

        await updateCameraLocation(
          source: GeoPoint(
            latitude: orderModel.value.sourceLocationLAtLng?.latitude ?? 0,
            longitude: orderModel.value.sourceLocationLAtLng?.longitude ?? 0,
          ),
          destination: GeoPoint(
            latitude: orderModel.value.destinationLocationLAtLng?.latitude ?? 0,
            longitude: orderModel.value.destinationLocationLAtLng?.longitude ?? 0,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error OSM: $e');
      }
    }
  }

  Future<void> updateCameraLocation({
    required GeoPoint source,
    required GeoPoint destination,
  }) async {
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

  Future<void> setOsmMarker({
    required GeoPoint departure,
    required GeoPoint destination,
  }) async {
    if (osmMarkers.containsKey('Source')) {
      await mapOsmController.removeMarker(osmMarkers['Source']!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await mapOsmController
          .addMarker(
            departure,
            markerIcon: MarkerIcon(iconWidget: departureOsmIcon),
            angle: pi / 3,
            iconAnchor: IconAnchor(anchor: Anchor.top),
          )
          .then((v) => osmMarkers['Source'] = departure);

      if (osmMarkers.containsKey('Destination')) {
        await mapOsmController.removeMarker(osmMarkers['Destination']!);
      }

      await mapOsmController
          .addMarker(
            destination,
            markerIcon: MarkerIcon(iconWidget: destinationOsmIcon),
            angle: pi / 3,
            iconAnchor: IconAnchor(anchor: Anchor.top),
          )
          .then((v) => osmMarkers['Destination'] = destination);
    });
  }

  /// ===================== Cálculos =====================
  Future<void> calculateAmount() async {
    String formatTime(String? time) {
      if (time == null || !time.contains(":")) return "00:00";
      final parts = time.split(':');
      if (parts.length != 2) return "00:00";
      return "${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}";
    }

    startNightTime.value = formatTime(orderModel.value.service!.startNightTime);
    endNightTime.value = formatTime(orderModel.value.service!.endNightTime);

    final startParts = startNightTime.split(':');
    final endParts = endNightTime.split(':');

    startNightTimeString = DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day,
      int.parse(startParts[0]),
      int.parse(startParts[1]),
    );
    endNightTimeString = DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day,
      int.parse(endParts[0]),
      int.parse(endParts[1]),
    );

    final durationValueInMinutes = convertToMinutes(orderModel.value.duration.toString());
    final distance = double.tryParse(orderModel.value.distance.toString()) ?? 0.0;
    final nonAcChargeValue = double.tryParse(driverModel.value.vehicleInformation!.nonAcPerKmRate.toString()) ?? 0.0;
    final acChargeValue = double.tryParse(driverModel.value.vehicleInformation!.acPerKmRate.toString()) ?? 0.0;
    final kmCharge = double.tryParse(driverModel.value.vehicleInformation!.perKmRate!.toString()) ?? 0.0;

    totalChargeOfMinute.value =
        double.parse(durationValueInMinutes.toString()) *
        double.parse(orderModel.value.service!.perMinuteCharge.toString());
    basicFare.value = double.parse(orderModel.value.service!.basicFareCharge.toString());

    if (distance <= double.parse(orderModel.value.service!.basicFare.toString())) {
      if (currentTime.isAfter(startNightTimeString) && currentTime.isBefore(endNightTimeString)) {
        amount.value = amount.value * double.parse(orderModel.value.service!.nightCharge.toString());
      } else {
        amount.value = double.parse(orderModel.value.service!.basicFareCharge.toString());
      }
    } else {
      final distanceValue = double.tryParse(orderModel.value.distance.toString()) ?? 0.0;
      final basicFareValue = double.tryParse(orderModel.value.service!.basicFare.toString()) ?? 0.0;
      final extraDist = distanceValue - basicFareValue;

      final perKmCharge = orderModel.value.service!.isAcNonAc == true
          ? (orderModel.value.isAcSelected == false ? nonAcChargeValue : acChargeValue)
          : kmCharge;

      amount.value = (perKmCharge * extraDist);

      if (currentTime.isAfter(startNightTimeString) && currentTime.isBefore(endNightTimeString)) {
        final mult = double.parse(orderModel.value.service!.nightCharge.toString());
        amount.value *= mult;
        totalChargeOfMinute.value *= mult;
        basicFare.value *= mult;
      }
    }

    // Si tenías una oferta previa y amount es 0, dejamos la oferta del pedido
    if (amount.value == 0.0 &&
        (orderModel.value.offerRate == null || orderModel.value.offerRate == '0.00')) {
      // no-op: mantenemos el valor inicial que ya setearon arriba
    }

    finalAmount.value = amount.value + basicFare.value + totalChargeOfMinute.value;
  }

  /// Precio recomendado simple
  double calculateRecommendedPrice() {
    final rawDistance = double.parse(orderModel.value.distance.toString());
    final distance =
        (rawDistance % 1 >= 0.51) ? rawDistance.ceil().toDouble() : rawDistance.floor().toDouble();

    const basePrice = 15.0; // ≤ 2km
    if (distance <= 2.0) return basePrice;

    final extraKm = distance - 2.0;
    return basePrice + (extraKm * 2.5);
  }

  /// Utilitarios
  double convertToMinutes(String duration) {
    double durationValue = 0.0;
    try {
      final hoursRegex = RegExp(r"(\d+)\s*hour");
      final minutesRegex = RegExp(r"(\d+)\s*min");

      final hoursMatch = hoursRegex.firstMatch(duration);
      if (hoursMatch != null) {
        final hours = int.parse(hoursMatch.group(1)!.trim());
        durationValue += hours * 60;
      }

      final minutesMatch = minutesRegex.firstMatch(duration);
      if (minutesMatch != null) {
        final minutes = int.parse(minutesMatch.group(1)!.trim());
        durationValue += minutes;
      }
    } catch (e) {
      if (kDebugMode) {
        print("Exception: $e");
      }
      throw FormatException("Invalid duration format: $duration");
    }
    return durationValue;
  }

  /// Toggle UI
  void toggleBoxVisibility() {
    isBoxVisible.value = !isBoxVisible.value;
  }
}
