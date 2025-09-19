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
import 'package:flutter/services.dart'; // <-- nuevo

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
  bool _fareTouched = false; // <-- nuevo

  final TextEditingController _fareCtrl = TextEditingController(); // <-- nuevo
  final FocusNode _fareFocus = FocusNode(); // <-- nuevo

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
    _fareCtrl.text = _selectedFare.toStringAsFixed(0); // solo enteros visibles

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
        infoWindow: const InfoWindow(title: 'Origen'),
      ));
    }
    if (_dstLL != null) {
      _markers
          .add(const Marker(markerId: MarkerId('dst'), position: LatLng(0, 0)));
      _markers.removeWhere((m) => m.markerId.value == 'dst');
      _markers.add(Marker(
        markerId: const MarkerId('dst'),
        position: _dstLL!,
        infoWindow: const InfoWindow(title: 'Destino'),
      ));
    }

    // Recta placeholder mientras llega la ruta real
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

  @override
  void dispose() {
    _fareCtrl.dispose();
    _fareFocus.dispose();
    super.dispose();
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
            final decoded = decodePolyline(geometry, accuracyExponent: 5);
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
                  color: Colors.blueAccent, // azul como en la captura
                ));
              });
            }
          }
        }
      }
    } catch (_) {
      // Mantener placeholder si hay error
    } finally {
      _fitCamera();
    }
  }

  // -------- Helpers de programado --------

  bool _isScheduled(Map<String, dynamic> raw) =>
      (raw['orderType']?.toString().toLowerCase() == 'scheduled');

  String _fmtFechaEs(DateTime d) {
    const dias = [
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo'
    ];
    const meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre'
    ];
    final wd = dias[(d.weekday + 6) % 7];
    final m = meses[d.month - 1];
    return '$wd, ${d.day} de $m de ${d.year}';
  }

  String _fmtFechaEsFromYMD(String ymd) {
    try {
      final parts = ymd.split('-');
      final y = int.parse(parts[0]);
      final mo = int.parse(parts[1]);
      final da = int.parse(parts[2]);
      return _fmtFechaEs(DateTime(y, mo, da));
    } catch (_) {
      return ymd; // fallback
    }
  }

  /// Intenta obtener la "hora de inicio" local (si aplica)
  DateTime? _getScheduledStartLocal(Map<String, dynamic> raw) {
    final Map<String, dynamic> meta =
        ((raw['scheduledMeta'] ?? raw['scheduled']) as Map?)
                ?.cast<String, dynamic>() ??
            const <String, dynamic>{};

    final String? timeLocal = meta['timeLocal']?.toString();
    final String? mode = meta['mode']?.toString();

    // datesLocal[0] + timeLocal
    final List<String>? datesLocal =
        (meta['datesLocal'] as List?)?.cast<String>();
    if (datesLocal != null && datesLocal.isNotEmpty) {
      try {
        final p = datesLocal.first.split('-');
        final y = int.parse(p[0]);
        final mo = int.parse(p[1]);
        final da = int.parse(p[2]);
        int hh = 0, mm = 0;
        if (timeLocal != null && timeLocal.contains(':')) {
          final t = timeLocal.split(':');
          hh = int.tryParse(t[0]) ?? 0;
          mm = int.tryParse(t[1]) ?? 0;
        }
        return DateTime(y, mo, da, hh, mm);
      } catch (_) {}
    }

    // legacy: scheduledFor
    final legacy = raw['scheduledFor'];
    if (legacy is Timestamp) return legacy.toDate().toLocal();

    // occurrencesUtc[0]
    final List<dynamic> occ =
        (meta['occurrencesUtc'] as List?) ?? const <dynamic>[];
    if (occ.isNotEmpty && occ.first is Timestamp) {
      return (occ.first as Timestamp).toDate().toLocal();
    }

    // range.startLocal + timeLocal
    if (mode == 'range') {
      final Map<String, dynamic> range =
          (meta['range'] as Map?)?.cast<String, dynamic>() ?? const {};
      final String? start = range['startLocal']?.toString();
      if (start != null) {
        try {
          final p = start.split('-');
          final y = int.parse(p[0]);
          final mo = int.parse(p[1]);
          final da = int.parse(p[2]);
          int hh = 0, mm = 0;
          if (timeLocal != null && timeLocal.contains(':')) {
            final t = timeLocal.split(':');
            hh = int.tryParse(t[0]) ?? 0;
            mm = int.tryParse(t[1]) ?? 0;
          }
          return DateTime(y, mo, da, hh, mm);
        } catch (_) {}
      }
    }
    return null;
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              k,
              style: GoogleFonts.poppins(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              v,
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Encabezado de la tarjeta con estilo "pills" como en la captura
  Widget _scheduledHeaderPills() {
    return Row(
      children: [
        // pill activa
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFDBEAFE), // azul clarito como en la imagen
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.black12),
          ),
          child: Text(
            'Viaje programado',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // texto de la pestaña "inactiva"
        Text(
          'Días seleccionados',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black54,
            fontSize: 12,
          ),
        ),
        const Spacer(),
      ],
    );
  }

  /// Tarjeta con la info del programado
  Widget _scheduledCard(Map<String, dynamic> raw) {
    final Map<String, dynamic> meta =
        ((raw['scheduledMeta'] ?? raw['scheduled']) as Map?)
                ?.cast<String, dynamic>() ??
            <String, dynamic>{};

    final String? mode =
        meta['mode']?.toString(); // range | list | single | null
    final String? timeLocal = meta['timeLocal']?.toString();
    final String? tz = meta['tz']?.toString();
    final legacy = raw['scheduledFor'];
    final List<dynamic> occurrencesUtc =
        (meta['occurrencesUtc'] as List?) ?? const [];

    final List<Widget> lines = [];

    // Encabezado "pills"
    lines.add(_scheduledHeaderPills());
    lines.add(const SizedBox(height: 10));

    // Contenido (según modo)
    if (mode == 'range') {
      final Map<String, dynamic> range =
          (meta['range'] as Map?)?.cast<String, dynamic>() ?? const {};
      final String? start = range['startLocal']?.toString();
      final String? end = range['endLocal']?.toString();
      if (start != null || end != null) {
        lines.add(Text(
          'los días:',
          style: GoogleFonts.poppins(
            color: Colors.black54,
            fontWeight: FontWeight.w700,
          ),
        ));
        lines.add(const SizedBox(height: 6));
        if (start != null) lines.add(_kv('', _fmtFechaEsFromYMD(start)));
        if (end != null) lines.add(_kv('', _fmtFechaEsFromYMD(end)));
      }
      if (timeLocal != null) lines.add(_kv('hora:', timeLocal));
      if (tz != null) lines.add(_kv('zona:', tz));
    } else if (mode == 'list') {
      final List<String> dates =
          (meta['datesLocal'] as List?)?.cast<String>() ?? const [];
      lines.add(Text(
        'los días:',
        style: GoogleFonts.poppins(
          color: Colors.black54,
          fontWeight: FontWeight.w700,
        ),
      ));
      lines.add(const SizedBox(height: 6));
      const maxShow = 6;
      final show = dates.take(maxShow).toList();
      for (final d in show) {
        lines.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              _fmtFechaEsFromYMD(d),
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      }
      if (dates.length > maxShow) {
        lines.add(
          Text(
            '+${dates.length - maxShow} más',
            style: GoogleFonts.poppins(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }
      if (timeLocal != null) {
        lines.add(const SizedBox(height: 6));
        lines.add(_kv('hora:', timeLocal));
      }
      if (tz != null) lines.add(_kv('zona:', tz));
    } else if (mode == 'single') {
      final List<String>? dates = (meta['datesLocal'] as List?)?.cast<String>();
      if (dates != null && dates.isNotEmpty) {
        lines.add(Text(
          'los días:',
          style: GoogleFonts.poppins(
            color: Colors.black54,
            fontWeight: FontWeight.w700,
          ),
        ));
        lines.add(const SizedBox(height: 6));
        lines.add(Text(
          _fmtFechaEsFromYMD(dates.first),
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
          ),
        ));
        if (timeLocal != null) lines.add(_kv('hora:', timeLocal));
        if (tz != null) lines.add(_kv('zona:', tz));
      } else if (legacy is Timestamp) {
        final local = legacy.toDate().toLocal();
        lines.add(Text(
          'los días:',
          style: GoogleFonts.poppins(
            color: Colors.black54,
            fontWeight: FontWeight.w700,
          ),
        ));
        lines.add(const SizedBox(height: 6));
        lines.add(Text(
          _fmtFechaEs(local),
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
          ),
        ));
        final hh = local.hour.toString().padLeft(2, '0');
        final mm = local.minute.toString().padLeft(2, '0');
        lines.add(_kv('hora:', '$hh:$mm'));
      } else if (occurrencesUtc.isNotEmpty &&
          occurrencesUtc.first is Timestamp) {
        final local = (occurrencesUtc.first as Timestamp).toDate().toLocal();
        lines.add(Text(
          'los días:',
          style: GoogleFonts.poppins(
            color: Colors.black54,
            fontWeight: FontWeight.w700,
          ),
        ));
        lines.add(const SizedBox(height: 6));
        lines.add(Text(
          _fmtFechaEs(local),
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
          ),
        ));
        final hh = local.hour.toString().padLeft(2, '0');
        final mm = local.minute.toString().padLeft(2, '0');
        lines.add(_kv('hora:', '$hh:$mm'));
        if (tz != null) lines.add(_kv('zona:', tz));
      } else {
        if (timeLocal != null) lines.add(_kv('hora:', timeLocal));
        if (tz != null) lines.add(_kv('zona:', tz));
      }
    } else {
      lines.add(Text(
        'Programación pendiente',
        style: GoogleFonts.poppins(
          color: Colors.black87,
          fontWeight: FontWeight.w700,
        ),
      ));
      if (timeLocal != null) lines.add(_kv('hora:', timeLocal));
      if (tz != null) lines.add(_kv('zona:', tz));
    }

    // Próximo inicio (si se puede inferir)
    final start = _getScheduledStartLocal(raw);
    if (start != null) {
      final hh = start.hour.toString().padLeft(2, '0');
      final mm = start.minute.toString().padLeft(2, '0');
      lines.add(const SizedBox(height: 6));
      lines.add(_kv('inicia:', '${_fmtFechaEs(start)} • $hh:$mm'));
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: Colors.grey.shade300, width: 0.7),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines,
      ),
    );
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

    final bool scheduled = _isScheduled(widget.order);

    return Scaffold(
      appBar: AppBar(
        title: Text(scheduled ? 'Viaje programado' : 'Detalles del viaje'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
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
            initialChildSize: 0.46,
            minChildSize: 0.30,
            maxChildSize: 0.92,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white, // blanco como en la captura
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

                      // Tarjeta "Viaje programado"
                      if (scheduled) ...[
                        _scheduledCard(widget.order),
                        const SizedBox(height: 12),
                      ],

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
                      //_buildFareCarousel(base: _baseFare),
                      _buildFareStepper(),

                      const SizedBox(height: 16),

                      // CTA
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
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
        color: Colors.green, // ✅ fondo verde
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white), // ✅ icono blanco
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: Colors.white, // ✅ texto blanco
              ),
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
      style: GoogleFonts.poppins(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: Colors.black, // ✅ negro
      ),
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
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: Colors.black, // ✅ fuerza el texto en negro
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFareStepper() {
    const double h = 48;
    const double r = 12;

    void _syncText() {
      // refleja _selectedFare en el TextField (entero)
      final v = _selectedFare.round().toString();
      if (_fareCtrl.text != v) _fareCtrl.text = v;
    }

    void dec() {
      setState(() {
        _selectedFare = (_selectedFare - 1).clamp(0, double.infinity);
        _fareTouched = true;
        _syncText();
      });
    }

    void inc() {
      setState(() {
        _selectedFare = _selectedFare + 1;
        _fareTouched = true;
        _syncText();
      });
    }

    return Row(
      children: [
        // –1
        Expanded(
          child: InkWell(
            onTap: dec,
            borderRadius: BorderRadius.circular(r),
            child: Container(
              height: h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '- 1',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Valor editable (solo números)
        Expanded(
          child: SizedBox(
            height: h,
            child: TextField(
              controller: _fareCtrl,
              focusNode: _fareFocus,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: const Color(0xFFE8F5E9), // verde claro
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r),
                  borderSide: BorderSide(color: Colors.green.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r),
                  borderSide:
                      BorderSide(color: Colors.green.shade400, width: 1.6),
                ),
              ),
              style: GoogleFonts.poppins(
                color: Colors.green,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
              onTap: () {
                // seleccionar todo al tocar
                _fareCtrl.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _fareCtrl.text.length,
                );
              },
              onChanged: (val) {
                final n = int.tryParse(val);
                setState(() {
                  _selectedFare = (n ?? 0).toDouble();
                  _fareTouched = true;
                });
              },
            ),
          ),
        ),
        const SizedBox(width: 12),

        // +1
        Expanded(
          child: InkWell(
            onTap: inc,
            borderRadius: BorderRadius.circular(r),
            child: Container(
              height: h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '+ 1',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // -------- Carrusel de tarifas --------

  /*Widget _buildFareCarousel({required double base}) {
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
  }*/

  /*Widget _fareButton({
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
          color: selected ? Colors.green : Colors.grey.withOpacity(0.18),
          border: Border.all(
              color: selected ? Colors.green : Colors.transparent, width: 1.4),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: Colors.green.withOpacity(0.35),
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
  }*/
}
