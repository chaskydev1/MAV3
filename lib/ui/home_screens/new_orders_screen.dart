import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/collection_name.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/utils/DarkThemeProvider.dart';
import 'package:driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'ride_placed_details_page.dart';

class NewOrderFreightScreen extends StatelessWidget {
  const NewOrderFreightScreen({Key? key}) : super(key: key);

  String _money(num? v) {
    final sym = Constant.currencyModel?.symbol ?? '';
    final dec = Constant.currencyModel?.decimalDigits ?? 2;
    final d = (v ?? 0).toDouble();
    return '$sym${d.toStringAsFixed(dec)}';
  }

  String _fmtTs(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);

    // 🔹 Stream del perfil del conductor para leer isOnline en tiempo real
    final driverStream = FirebaseFirestore.instance
        .collection(CollectionName.driverUsers)
        .doc(FireStoreUtils.getCurrentUid())
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: driverStream,
      builder: (context, driverSnap) {
        if (driverSnap.connectionState == ConnectionState.waiting) {
          return Constant.loader(context);
        }
        if (driverSnap.hasError) {
          return const _DiagEmpty(
            title: 'Error',
            details: ['No se pudo leer el estado del conductor.'],
          );
        }

        final data = driverSnap.data?.data() ?? {};
        final bool isOnline = (data['isOnline'] ?? false) == true;

        // 🔻 Si está offline, muestra el mensaje traducido
        if (!isOnline) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                "You are Now offline so you can't get nearest order.".tr,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          );
        }

        // ✅ Si está online, mostramos los Ride Placed como antes
        final col =
            FirebaseFirestore.instance.collection(CollectionName.orders);

        final stream = col
            .where('status', isEqualTo: Constant.ridePlaced) // Ride Placed
            .orderBy('createdDate', descending: true)
            .limit(50)
            .snapshots();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snap) {
            if (snap.hasError) {
              return const _DiagEmpty(
                title: 'Error',
                details: [
                  'No se pudo cargar.',
                  'Si Firestore solicita índice, créalo y vuelve a intentar.',
                ],
              );
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return Constant.loader(context);
            }

            final docs = snap.data?.docs ?? const [];
            if (docs.isEmpty) {
              return const _DiagEmpty(
                title: 'No se encontraron nuevos viajes',
                details: [
                  '• No hay documentos con status "Ride Placed".',
                  '• Verifica que "createdDate" exista y sea Timestamp.',
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(10),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final m = docs[i].data();

                final id = (m['id'] ?? docs[i].id).toString();
                final created = _fmtTs(m['createdDate']);

                final src = (m['sourceLocationName'] ?? '').toString();
                final dst = (m['destinationLocationName'] ?? '').toString();
                final paymentType = (m['paymentType'] ?? '').toString();

                final offerRate =
                    num.tryParse((m['offerRate'] ?? '0').toString());
                final distance =
                    num.tryParse((m['distance'] ?? '0').toString());
                final distanceType =
                    (m['distanceType'] ?? Constant.distanceType).toString();

                return InkWell(
                  onTap: () {
                    // Navega a la página de detalles (NO muestra ID)
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RidePlacedDetailsPage(order: m),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: _RidePlacedCard(
                    themeChange: themeChange,
                    titleRight: created,
                    chips: [
                      _chipData('Tarifa', _money(offerRate)),
                      if (distance != null)
                        _chipData('Distancia',
                            '${distance.toStringAsFixed(2)} $distanceType'),
                      if (paymentType.isNotEmpty) _chipData('Pago', paymentType),
                      // ID oculto por defecto; se muestra con toque al auto
                      _chipData('ID', id, hidden: true),
                    ],
                    src: src,
                    dst: dst,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/* ------------ Card + chips + easter-egg (ID) ------------- */

class _RidePlacedCard extends StatefulWidget {
  final DarkThemeProvider themeChange;
  final String titleRight;
  final List<_ChipData> chips;
  final String src;
  final String dst;

  const _RidePlacedCard({
    Key? key,
    required this.themeChange,
    required this.titleRight,
    required this.chips,
    required this.src,
    required this.dst,
  }) : super(key: key);

  @override
  State<_RidePlacedCard> createState() => _RidePlacedCardState();
}

class _RidePlacedCardState extends State<_RidePlacedCard> {
  bool _showId = false;
  int _tapCount = 0;
  Timer? _hideTimer;

  void _onCarTapped() {
    _tapCount += 1;
    if (_tapCount >= 4) {
      _tapCount = 0;
      setState(() => _showId = true);
      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _showId = false);
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeChange = widget.themeChange;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: themeChange.getThem()
                ? AppColors.darkContainerBackground
                : AppColors.containerBackground,
            borderRadius: BorderRadius.circular(12),
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
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.receipt_long, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Viaje Activo',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      widget.titleRight,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Chips (si _showId es true, también muestra el chip del ID)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: widget.chips
                      .where((c) => !c.hidden || _showId)
                      .map(_buildChip)
                      .toList(),
                ),

                const SizedBox(height: 12),

                _rowIconText(Icons.radio_button_checked,
                    widget.src.isEmpty ? '—' : widget.src),
                const SizedBox(height: 6),
                _rowIconText(
                    Icons.location_on, widget.dst.isEmpty ? '—' : widget.dst),
              ],
            ),
          ),
        ),

        // Ícono auto (easter-egg: 4 taps muestra ID 5s)
        Positioned(
          top: 6,
          right: 6,
          child: Material(
            color: Colors.transparent,
            child: InkResponse(
              onTap: _onCarTapped,
              radius: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.directions_car, size: 20),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChip(_ChipData c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${c.label}: ${c.value}',
        style: GoogleFonts.poppins(fontSize: 12),
      ),
    );
  }

  Widget _rowIconText(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(),
          ),
        ),
      ],
    );
  }
}

class _ChipData {
  final String label;
  final String value;
  final bool hidden;
  _ChipData(this.label, this.value, {this.hidden = false});
}

_ChipData _chipData(String l, String v, {bool hidden = false}) =>
    _ChipData(l, v, hidden: hidden);

/* ------------ Vistas auxiliares ------------- */

class _DiagEmpty extends StatelessWidget {
  final String title;
  final List<String> details;
  const _DiagEmpty({required this.title, required this.details, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 36, color: Colors.grey),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ...details.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  d,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
