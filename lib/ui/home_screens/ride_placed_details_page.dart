// lib/ui/home_screens/ride_placed_details_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/utils/DarkThemeProvider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

class RidePlacedDetailsPage extends StatefulWidget {
  final Map<String, dynamic> order;
  const RidePlacedDetailsPage({Key? key, required this.order})
      : super(key: key);

  @override
  State<RidePlacedDetailsPage> createState() => _RidePlacedDetailsPageState();
}

class _RidePlacedDetailsPageState extends State<RidePlacedDetailsPage> {
  static const String _mapboxToken =
      'pk.eyJ1IjoibXVqZXJlc2Fsdm9sYW50ZSIsImEiOiJjbWFoZTR1ZzEwYXdvMmtxMHg5ZXZneXgyIn0.9aNpyQyi5wP1qKi0SjiR5Q';

  final Completer<GoogleMapController> _mapCtrl =
      Completer<GoogleMapController>();

  late final double _baseFare;
  late double _selectedFare;

  LatLng? _srcLL;
  LatLng? _dstLL;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _baseFare =
        (num.tryParse((widget.order['offerRate'] ?? '0').toString()) ?? 0)
            .toDouble();
    _selectedFare = _baseFare;

    _srcLL = _latLngFrom(widget.order['sourceLocationLAtLng'] ??
        widget.order['sourceLocationLatLng']);
    _dstLL = _latLngFrom(widget.order['destinationLocationLAtLng'] ??
        widget.order['destinationLocationLatLng']);

    if (_srcLL != null) {
      _markers
          .add(const Marker(markerId: MarkerId('src'), position: LatLng(0, 0)));
      _markers.removeWhere((m) => m.markerId.value == 'src');
      _markers.add(Marker(
          markerId: const MarkerId('src'),
          position: _srcLL!,
          infoWindow: const InfoWindow(title: 'Origen')));
    }
    if (_dstLL != null) {
      _markers
          .add(const Marker(markerId: MarkerId('dst'), position: LatLng(0, 0)));
      _markers.removeWhere((m) => m.markerId.value == 'dst');
      _markers.add(Marker(
          markerId: const MarkerId('dst'),
          position: _dstLL!,
          infoWindow: const InfoWindow(title: 'Destino')));
    }

    // Dibuja recta como placeholder mientras llega la ruta real
    if (_srcLL != null && _dstLL != null) {
      _polylines.add(Polyline(
        polylineId: const PolylineId('placeholder'),
        points: [_srcLL!, _dstLL!],
        width: 3,
        color: Colors.blueGrey.shade300,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ));
      _fetchRoute(); // pide ruta real a Mapbox Directions
    }
  }

  // ---------------- Helpers ----------------

  String _money(num? v) {
    final sym = Constant.currencyModel?.symbol ?? '';
    final dec = Constant.currencyModel?.decimalDigits ?? 2;
    final d = (v ?? 0).toDouble();
    return '$sym${d.toStringAsFixed(dec)}';
  }

  LatLng? _latLngFrom(dynamic v) {
    try {
      if (v == null) return null;
      if (v is GeoPoint) return LatLng(v.latitude, v.longitude);
      if (v is Map && v['latitude'] != null && v['longitude'] != null) {
        final lat = (v['latitude'] as num).toDouble();
        final lng = (v['longitude'] as num).toDouble();
        return LatLng(lat, lng);
      }
    } catch (_) {}
    return null;
  }

  LatLng _midpoint(LatLng a, LatLng b) =>
      LatLng((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2);

  LatLngBounds _boundsFromTwo(LatLng a, LatLng b) {
    final sw = LatLng(
        math.min(a.latitude, b.latitude), math.min(a.longitude, b.longitude));
    final ne = LatLng(
        math.max(a.latitude, b.latitude), math.max(a.longitude, b.longitude));
    return LatLngBounds(southwest: sw, northeast: ne);
  }

  Future<void> _fitCamera() async {
    if (_srcLL == null || _dstLL == null) return;
    final ctrl = await _mapCtrl.future;
    await Future.delayed(const Duration(milliseconds: 200));
    final b = _boundsFromTwo(_srcLL!, _dstLL!);
    ctrl.animateCamera(CameraUpdate.newLatLngBounds(b, 60));
  }

  /// Ruta real con Mapbox Directions (overview=full, geometries=polyline *5dec*)
  Future<void> _fetchRoute() async {
    if (_srcLL == null || _dstLL == null) return;
    try {
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
        '${_srcLL!.longitude},${_srcLL!.latitude};'
        '${_dstLL!.longitude},${_dstLL!.latitude}'
        '?alternatives=false&geometries=polyline&overview=full&access_token=$_mapboxToken',
      );

      final res = await http.get(url).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final geometry = routes[0]['geometry'] as String?;
          if (geometry != null && geometry.isNotEmpty) {
            final decoded = decodePolyline(geometry,
                accuracyExponent: 5); // [[lat,lng], ...]
            final points = decoded
                .map<LatLng>((e) =>
                    LatLng((e[0] as num).toDouble(), (e[1] as num).toDouble()))
                .toList(growable: false);
            if (mounted) {
              setState(() {
                _polylines
                    .removeWhere((p) => p.polylineId.value == 'placeholder');
                _polylines.add(Polyline(
                  polylineId: const PolylineId('route'),
                  points: points,
                  width: 5,
                  color: Colors.blueAccent,
                ));
              });
            }
          }
        }
      } else {
        // Si falla, mantenemos la recta (placeholder)
      }
    } catch (_) {
      // Mantén placeholder si hay error
    } finally {
      _fitCamera();
    }
  }

  // --------------- UI ------------------

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);

    final srcName = (widget.order['sourceLocationName'] ?? '').toString();
    final dstName = (widget.order['destinationLocationName'] ?? '').toString();
    final distance = num.tryParse((widget.order['distance'] ?? '0').toString());
    final distanceType =
        (widget.order['distanceType'] ?? Constant.distanceType).toString();

    final LatLng initialCenter = (_srcLL != null && _dstLL != null)
        ? _midpoint(_srcLL!, _dstLL!)
        : (_srcLL ?? _dstLL ?? const LatLng(0, 0));

    final bool isBaseSelected = (_selectedFare == _baseFare);
    final String ctaText = isBaseSelected ? 'Aceptar viaje' : 'Hacer oferta';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles del viaje'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Mapa de fondo
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition:
                  CameraPosition(target: initialCenter, zoom: 13),
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (c) async {
                if (!_mapCtrl.isCompleted) _mapCtrl.complete(c);
                if (_srcLL != null && _dstLL != null) {
                  await _fitCamera();
                }
              },
            ),
          ),

          // Panel deslizante
          DraggableScrollableSheet(
            initialChildSize: 0.42,
            minChildSize: 0.30,
            maxChildSize: 0.92,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: themeChange.getThem()
                      ? AppColors.darkContainerBackground
                      : Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, -2)),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          width: 52,
                          height: 5,
                          decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Chips (Tarifa / Distancia)
                      Row(
                        children: [
                          Expanded(
                            child: _chip(context,
                                icon: Icons.attach_money,
                                text: 'Tarifa: ${_money(_baseFare)}'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _chip(
                              context,
                              icon: Icons.route,
                              text:
                                  'Distancia: ${distance != null ? distance.toStringAsFixed(2) : '0.00'} $distanceType',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Carrusel de tarifas
                      _buildFareCarousel(base: _baseFare),

                      const SizedBox(height: 16),

                      // CTA
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            final msg = isBaseSelected
                                ? 'Aceptar viaje en ${_money(_selectedFare)}'
                                : 'Oferta enviada: ${_money(_selectedFare)}';
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text(msg)));
                            // TODO: integrar lógica real (aceptar / ofertar) aquí.
                          },
                          child: Text(ctaText,
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Datos del viaje
                      _sectionTitle('Origen'),
                      _rowIconText(Icons.radio_button_checked,
                          srcName.isEmpty ? '—' : srcName),

                      const SizedBox(height: 12),
                      _sectionTitle('Destino'),
                      _rowIconText(
                          Icons.location_on, dstName.isEmpty ? '—' : dstName),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------- Widgets auxiliares ----------------

  Widget _chip(BuildContext context,
      {required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black87),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Text(
      t,
      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14),
    );
  }

  Widget _rowIconText(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: GoogleFonts.poppins())),
        ],
      ),
    );
  }

  // -------- Carrusel de tarifas --------

  Widget _buildFareCarousel({required double base}) {
    // Opciones: -6, -3, base, +3, +6 (mínimo 0.0)
    final raw = <double>[base - 6, base - 3, base, base + 3, base + 6];
    final List<double> options =
        raw.map<double>((v) => v < 0 ? 0.0 : v.toDouble()).toList();

    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final double fare = options[i];
          final selected = fare == _selectedFare;
          return _fareButton(
            label: _money(fare),
            selected: selected,
            onTap: () => setState(() => _selectedFare = fare),
          );
        },
      ),
    );
  }

  Widget _fareButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? AppColors.primary : Colors.grey.withOpacity(0.18),
          border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 1.4),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 2))
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : Colors.black87),
        ),
      ),
    );
  }
}
