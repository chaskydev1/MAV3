import 'dart:developer';
import 'package:driver/constant/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:get/get.dart';

class OsmSearchPlaceController extends GetxController {
  Rx<TextEditingController> searchTxtController = TextEditingController().obs;
  RxList<SearchInfo> suggestionsList = <SearchInfo>[].obs;

  @override
  void onInit() {
    super.onInit();
    searchTxtController.value.addListener(() {
      _onChanged();
    });
  }

  _onChanged() {
    fetchAddress(searchTxtController.value.text);
  }

  fetchAddress(String text) async {
    log(":: fetchAddress :: $text");
    try {
      List<SearchInfo> results = await addressSuggestion(text);
      suggestionsList.value = results.where((place) {
        String? country = place.address?.country?.toLowerCase();
        String addressString = place.address.toString().toLowerCase();

        if (Constant.regionCountry.toLowerCase() == "all") {
          return true;
        }
        return country == Constant.regionCountry.toLowerCase() ||
            addressString.contains(Constant.regionCountry.toLowerCase());
      }).toList();
    } catch (e) {
      log(e.toString());
    }
  }

}
