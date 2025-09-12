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
import 'package:driver/ui/home_screens/new_orders_screen/order_card.dart';
import 'package:geolocator/geolocator.dart';
import 'package:driver/ui/home_screens/new_orders_screen/pedidos_cercanos.dart';
import 'package:driver/ui/home_screens/new_orders_screen/sin_pedidos.dart';
import 'package:driver/ui/home_screens/new_orders_screen/construir_pedidos.dart';

class NewOrderScreen extends StatelessWidget {
  const NewOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);

    return GetX<HomeController>(
      init: HomeController(),
      dispose: (state) => FireStoreUtils().closeStream(),
      builder: (controller) {
        if (controller.isLoading.value) {
          return Constant.loader(context);
        }

        if (controller.driverModel.value.isOnline != true) {
          return const NoOrdersView(message: "Estás desconectado, no se mostrarán pedidos.");
        }

        final driverLat = Constant.currentLocation?.latitude;
        final driverLng = Constant.currentLocation?.longitude;

        if (driverLat == null || driverLng == null) {
          return const NoOrdersView(message: "Ubicación del conductor no disponible.");
        }

        return StreamBuilder<List<OrderModel>>(
          stream: FireStoreUtils().getOrders(controller.driverModel.value, driverLat, driverLng),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Constant.loader(context);
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const NoOrdersView(message: "No se encontraron nuevos viajes.");
            }

            final nearbyOrders = NearbyOrderFilterService.filterNearbyOrders(
              orders: snapshot.data!,
              driverLat: driverLat,
              driverLng: driverLng,
            );

            if (nearbyOrders.isEmpty) {
              return const NoOrdersView(message: "No hay pedidos a menos de 4 km.");
            }

            return OrderListBuilder(
              orders: nearbyOrders,
              themeChange: themeChange,
            );
          },
        );
      },
    );
  }
}
