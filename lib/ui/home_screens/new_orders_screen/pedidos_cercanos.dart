// Encargado de calcular distancias y filtrar pedidos cercanos.
import 'package:driver/model/order_model.dart';
import 'package:geolocator/geolocator.dart';

class NearbyOrderFilterService {
  static List<OrderModel> filterNearbyOrders({
    required List<OrderModel> orders,
    required double driverLat,
    required double driverLng,
    double maxDistanceKm = 4.0,  //Distancia máxima permitida para aceptar un pedido en km Radio de la ubicación del conductor
  }) {
    print('🔍 Iniciando filtrado de pedidos cercanos...');
    print('📍 Coordenadas del conductor: lat=$driverLat, lng=$driverLng');
    print('🎯 Distancia máxima permitida: $maxDistanceKm km');
    print('🗂️ Total de pedidos recibidos: ${orders.length}');

    List<OrderModel> filteredOrders = [];

    for (var order in orders) {
      final lat = order.sourceLocationLAtLng?.latitude;
      final lng = order.sourceLocationLAtLng?.longitude;

      if (lat == null || lng == null) {
        print('⚠️ Pedido ${order.id} descartado: coordenadas del pasajero nulas.');
        continue;
      }

      final distance = Geolocator.distanceBetween(driverLat, driverLng, lat, lng) / 1000;

      print('📦 Evaluando pedido ${order.id}');
      print('   - Coordenadas del pasajero: lat=$lat, lng=$lng');
      print('   - Distancia al conductor: ${distance.toStringAsFixed(2)} km');

      if (distance <= maxDistanceKm) {
        print('✅ Pedido ${order.id} ACEPTADO (dentro del rango)');
        filteredOrders.add(order);
      } else {
        print('❌ Pedido ${order.id} DESCARTADO (fuera del rango)');
      }
    }

    print('📋 Total de pedidos aceptados: ${filteredOrders.length}');
    return filteredOrders;
  }
}
