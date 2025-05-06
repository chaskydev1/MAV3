import 'dart:async';
import 'dart:math';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/constant/show_toast_dialog.dart';
import 'package:driver/controller/active_order_controller.dart';
import 'package:driver/model/driver_user_model.dart';
import 'package:driver/model/intercity_order_model.dart';
import 'package:driver/model/order_model.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/utils/fire_store_utils.dart';
//import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:driver/controller/active_order_controller.dart';
//here

class LiveTrackingController extends GetxController {
  final String mapAPIKey = "AIzaSyBF8F0YnhknJa_cvyMmaJvRVTqPS-somdk";
  GoogleMapController? mapController;

  @override
  void onInit() {
    super.onInit();
    addMarkerSetup();
    getArgument();
    // playSound();
  }

  @override
  void onClose() {
    ShowToastDialog.closeLoader();
    super.onClose();
  }

  Rx<DriverUserModel> driverUserModel = DriverUserModel().obs;
  Rx<OrderModel> orderModel = OrderModel().obs;
  Rx<InterCityOrderModel> intercityOrderModel = InterCityOrderModel().obs;

  RxBool isLoading = true.obs;
  RxString type = "".obs;

  getArgument() async {
    dynamic argumentData = Get.arguments;
    print("==== Argumentos recibidos ====");
    print(argumentData);
    
    if (argumentData != null) {
        type.value = argumentData['type'];
        print("Tipo de orden: ${type.value}");
        
        if (type.value == "orderModel") {
            OrderModel argumentOrderModel = argumentData['orderModel'];
            print("Datos del modelo de orden:");
            print("==== Ubicación de origen (pasajero) ====");
            print("Latitud: ${argumentOrderModel.sourceLocationLAtLng?.latitude}");
            print("Longitud: ${argumentOrderModel.sourceLocationLAtLng?.longitude}");
            
            print("==== Ubicación de destino ====");
            print("Latitud: ${argumentOrderModel.destinationLocationLAtLng?.latitude}");
            print("Longitud: ${argumentOrderModel.destinationLocationLAtLng?.longitude}");

            // Agregar el marcador del pasajero INMEDIATAMENTE
            if (argumentOrderModel.sourceLocationLAtLng?.latitude != null && 
                argumentOrderModel.sourceLocationLAtLng?.longitude != null) {
                
                // Limpiar marcadores existentes
                markers.clear();
                
                // Agregar el marcador rojo del pasajero
                addMarker(
                    latitude: argumentOrderModel.sourceLocationLAtLng!.latitude,
                    longitude: argumentOrderModel.sourceLocationLAtLng!.longitude,
                    id: "Pasajero",
                    descriptor: BitmapDescriptor.defaultMarker,
                    rotation: 0.0
                );

                // Agregar el marcador del conductor inmediatamente
                if (driverUserModel.value.location != null) {
                    addMarker(
                        latitude: driverUserModel.value.location!.latitude,
                        longitude: driverUserModel.value.location!.longitude,
                        id: "Conductor",
                        descriptor: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                        rotation: driverUserModel.value.rotation
                    );

                    // Trazar la ruta inmediatamente
                    getPolyline(
                        sourceLatitude: driverUserModel.value.location!.latitude,
                        sourceLongitude: driverUserModel.value.location!.longitude,
                        destinationLatitude: argumentOrderModel.sourceLocationLAtLng!.latitude,
                        destinationLongitude: argumentOrderModel.sourceLocationLAtLng!.longitude
                    );
                }

                // Mover la cámara para mostrar toda la ruta
                if (mapController != null) {
                    mapController!.animateCamera(
                        CameraUpdate.newLatLngBounds(
                            LatLngBounds(
                                southwest: LatLng(
                                    min(driverUserModel.value.location!.latitude ?? 0, argumentOrderModel.sourceLocationLAtLng!.latitude ?? 0),
                                    min(driverUserModel.value.location!.longitude ?? 0, argumentOrderModel.sourceLocationLAtLng!.longitude ?? 0)
                                ),
                                northeast: LatLng(
                                    max(driverUserModel.value.location!.latitude ?? 0, argumentOrderModel.sourceLocationLAtLng!.latitude ?? 0),
                                    max(driverUserModel.value.location!.longitude ?? 0, argumentOrderModel.sourceLocationLAtLng!.longitude ?? 0)
                                )
                            ),
                            100 // padding
                        )
                    );
                }
                
                print("🔴 Marcadores y ruta agregados inicialmente");
            }

            FireStoreUtils.fireStore.collection(CollectionName.orders).doc(argumentOrderModel.id).snapshots().listen((event) {
              if (event.data() != null) {
                OrderModel orderModelStream = OrderModel.fromJson(event.data()!);

                orderModel.value = orderModelStream;
                FireStoreUtils.fireStore.collection(CollectionName.driverUsers).doc(argumentOrderModel.driverId).snapshots().listen((event) {
                  if (event.data() != null) {
                    driverUserModel.value = DriverUserModel.fromJson(event.data()!);
                    print("==== Datos del conductor ====");
                    print("Ubicación del conductor: ${driverUserModel.value.location?.latitude}, ${driverUserModel.value.location?.longitude}");
                    
                    // Actualizar marcador y ruta cuando el conductor se mueve
                    if (driverUserModel.value.location != null) {
                        // Actualizar marcador del conductor
                        addMarker(
                            latitude: driverUserModel.value.location!.latitude,
                            longitude: driverUserModel.value.location!.longitude,
                            id: "Conductor",
                            descriptor: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                            rotation: driverUserModel.value.rotation
                        );
                        
                        // Actualizar la ruta
                        getPolyline(
                            sourceLatitude: driverUserModel.value.location!.latitude,
                            sourceLongitude: driverUserModel.value.location!.longitude,
                            destinationLatitude: orderModel.value.sourceLocationLAtLng!.latitude,
                            destinationLongitude: orderModel.value.sourceLocationLAtLng!.longitude
                        );
                    }
                  }
                });

                if (orderModel.value.status == Constant.rideComplete) {
                  Get.back();
                }
              }
            });

            if (argumentOrderModel.destinationLocationLAtLng?.latitude != null && 
                argumentOrderModel.destinationLocationLAtLng?.longitude != null) {
                
                // Agregar el marcador verde del destino
                addMarker(
                    latitude: argumentOrderModel.destinationLocationLAtLng!.latitude,
                    longitude: argumentOrderModel.destinationLocationLAtLng!.longitude,
                    id: "Destino",
                    descriptor: destinationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                    rotation: 0.0
                );
                
                print("🟢 Marcador de destino agregado");
            }
        } else {
            InterCityOrderModel argumentOrderModel = argumentData['interCityOrderModel'];
            print("Datos del modelo de orden intercity:");
            print("Source: ${argumentOrderModel.sourceLocationLAtLng}");
            print("Destination: ${argumentOrderModel.destinationLocationLAtLng}");

            FireStoreUtils.fireStore.collection(CollectionName.ordersIntercity).doc(argumentOrderModel.id).snapshots().listen((event) {
              if (event.data() != null) {
                InterCityOrderModel orderModelStream = InterCityOrderModel.fromJson(event.data()!);
                print("====>");
                intercityOrderModel.value = orderModelStream;
                FireStoreUtils.fireStore.collection(CollectionName.driverUsers).doc(argumentOrderModel.driverId).snapshots().listen((event) {
                  if (event.data() != null) {
                    driverUserModel.value = DriverUserModel.fromJson(event.data()!);
                    if (Constant.selectedMapType != 'osm') {
                      if (intercityOrderModel.value.status == Constant.rideInProgress) {
                        getPolyline(
                            sourceLatitude: driverUserModel.value.location!.latitude,
                            sourceLongitude: driverUserModel.value.location!.longitude,
                            destinationLatitude: intercityOrderModel.value.destinationLocationLAtLng!.latitude,
                            destinationLongitude: intercityOrderModel.value.destinationLocationLAtLng!.longitude);
                      } else {
                        getPolyline(
                            sourceLatitude: driverUserModel.value.location!.latitude,
                            sourceLongitude: driverUserModel.value.location!.longitude,
                            destinationLatitude: intercityOrderModel.value.sourceLocationLAtLng!.latitude,
                            destinationLongitude: intercityOrderModel.value.sourceLocationLAtLng!.longitude);
                      }
                    }
                  }
                });

                if (intercityOrderModel.value.status == Constant.rideComplete) {
                  Get.back();
                }
              }
            });
        }
    }
    isLoading.value = false;
    update();
  }

  BitmapDescriptor? departureIcon;
  BitmapDescriptor? destinationIcon;
  BitmapDescriptor? driverIcon;

void getPolyline({
    required double? sourceLatitude, 
    required double? sourceLongitude, 
    required double? destinationLatitude, 
    required double? destinationLongitude
}) async {
    print("==== Trazando rutas ====");
    
    try {
        polyLines.clear(); // Limpiar rutas existentes

        // Ruta 1: Conductor -> Pasajero (Azul)
        PolylineResult driverToSource = await polylinePoints.getRouteBetweenCoordinates(
            googleApiKey: mapAPIKey,
            request: PolylineRequest(
                origin: PointLatLng(sourceLatitude!, sourceLongitude!),
                destination: PointLatLng(destinationLatitude!, destinationLongitude!),
                mode: TravelMode.driving,
            )
        );

        List<LatLng> polylineCoordinates1 = driverToSource.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();

        PolylineId id1 = const PolylineId("poly1");
        final Polyline polyline1 = Polyline(
            polylineId: id1,
            color: Colors.blue,
            points: polylineCoordinates1,
            width: 6,
            geodesic: true
        );
        polyLines[id1] = polyline1;

        // Ruta 2: Pasajero -> Destino (Verde)
        PolylineResult sourceToDestination = await polylinePoints.getRouteBetweenCoordinates(
            googleApiKey: mapAPIKey,
            request: PolylineRequest(
                origin: PointLatLng(destinationLatitude!, destinationLongitude!),
                destination: PointLatLng(
                    orderModel.value.destinationLocationLAtLng!.latitude!,
                    orderModel.value.destinationLocationLAtLng!.longitude!
                ),
                mode: TravelMode.driving,
            )
        );

        List<LatLng> polylineCoordinates2 = sourceToDestination.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();

        PolylineId id2 = const PolylineId("poly2");
        final Polyline polyline2 = Polyline(
            polylineId: id2,
            color: Colors.green,
            points: polylineCoordinates2,
            width: 6,
            geodesic: true
        );
        polyLines[id2] = polyline2;

        update();
    } catch (e) {
        print("❌ Error al trazar las rutas: $e");
    }
}

  RxMap<MarkerId, Marker> markers = <MarkerId, Marker>{}.obs;

  addMarker({
    required double? latitude, 
    required double? longitude, 
    required String id, 
    required BitmapDescriptor descriptor, 
    required double? rotation
}) {
    if (latitude == null || longitude == null) {
        print("Error: Coordenadas nulas para el marcador $id");
        return;
    }
    
    print("Agregando marcador: $id en ($latitude, $longitude)");
    MarkerId markerId = MarkerId(id);
    Marker marker = Marker(
        markerId: markerId,
        position: LatLng(latitude, longitude),
        icon: descriptor,
        rotation: rotation ?? 0, // Rotación del auto según bearing
        anchor: (id == "Conductor") ? Offset(0.5, 0.5) : Offset(0.5, 1.0), // Centro de rotación para el auto
        infoWindow: InfoWindow(title: id),
        visible: true
    );
    markers[markerId] = marker;
    update();
    print("Marcador agregado. Total de marcadores: ${markers.length}");
}

  addMarkerSetup() async {
    print("==== Inicializando marcadores ====");
    try {
        // Iconos de origen y destino
        departureIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
        destinationIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
        
        // Cargar icono del auto
        driverIcon = await BitmapDescriptor.fromAssetImage(
            ImageConfiguration(size: Size(48, 48)),
            'assets/images/car_top.png',
        );
        
        print("✅ Marcadores configurados exitosamente");
    } catch (e) {
        print("❌ Error al configurar los marcadores: $e");
        // Fallback al marcador default si falla la carga del auto
        driverIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
    }
  }

  RxMap<PolylineId, Polyline> polyLines = <PolylineId, Polyline>{}.obs;
  PolylinePoints polylinePoints = PolylinePoints();

  Future<void> updateCameraLocation(
    LatLng source,
    LatLng destination,
    GoogleMapController? mapController,
  ) async {
    if (mapController == null) return;

    LatLngBounds bounds;

    if (source.latitude > destination.latitude && source.longitude > destination.longitude) {
      bounds = LatLngBounds(southwest: destination, northeast: source);
    } else if (source.longitude > destination.longitude) {
      bounds = LatLngBounds(southwest: LatLng(source.latitude, destination.longitude), northeast: LatLng(destination.latitude, source.longitude));
    } else if (source.latitude > destination.latitude) {
      bounds = LatLngBounds(southwest: LatLng(destination.latitude, source.longitude), northeast: LatLng(source.latitude, destination.longitude));
    } else {
      bounds = LatLngBounds(southwest: source, northeast: destination);
    }

    CameraUpdate cameraUpdate = CameraUpdate.newLatLngBounds(bounds, 10);

    return checkCameraLocation(cameraUpdate, mapController);
  }

  Future<void> checkCameraLocation(CameraUpdate cameraUpdate, GoogleMapController mapController) async {
    mapController.animateCamera(cameraUpdate);
    LatLngBounds l1 = await mapController.getVisibleRegion();
    LatLngBounds l2 = await mapController.getVisibleRegion();

    if (l1.southwest.latitude == -90 || l2.southwest.latitude == -90) {
      return checkCameraLocation(cameraUpdate, mapController);
    }
  }

}
