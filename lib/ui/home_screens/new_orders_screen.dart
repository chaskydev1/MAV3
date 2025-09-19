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

class NewOrderFreightScreen extends StatefulWidget {
  const NewOrderFreightScreen({Key? key}) : super(key: key);

  @override
  State<NewOrderFreightScreen> createState() => _NewOrderFreightScreenState();
}

class _NewOrderFreightScreenState extends State<NewOrderFreightScreen> {
  final Set<String> _processed = <String>{};

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

  bool _isScheduled(Map<String, dynamic> m) {
    final t = m['orderType']?.toString().toLowerCase();
    return t == 'scheduled';
  }

  DateTime? _getScheduledStartLocal(Map<String, dynamic> m) {
    final Map<String, dynamic> meta =
        ((m['scheduledMeta'] ?? m['scheduled']) as Map?)
                ?.cast<String, dynamic>() ??
            const <String, dynamic>{};

    final String? timeLocal = meta['timeLocal']?.toString();
    final String? mode = meta['mode']?.toString();

    final List<String>? datesLocal =
        (meta['datesLocal'] as List?)?.cast<String>();
    if (datesLocal != null && datesLocal.isNotEmpty) {
      try {
        final parts = datesLocal.first.split('-');
        final y = int.parse(parts[0]);
        final mo = int.parse(parts[1]);
        final da = int.parse(parts[2]);
        int hh = 0, mm = 0;
        if (timeLocal != null && timeLocal.contains(':')) {
          final t = timeLocal.split(':');
          hh = int.tryParse(t[0]) ?? 0;
          mm = int.tryParse(t[1]) ?? 0;
        }
        return DateTime(y, mo, da, hh, mm);
      } catch (_) {}
    }

    final scheduledForLegacy = m['scheduledFor'];
    if (scheduledForLegacy is Timestamp) {
      return scheduledForLegacy.toDate().toLocal();
    }

    final List<dynamic> occ =
        (meta['occurrencesUtc'] as List?) ?? const <dynamic>[];
    if (occ.isNotEmpty && occ.first is Timestamp) {
      return (occ.first as Timestamp).toDate().toLocal();
    }

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

  Future<void> _maybeAutoCancel({
    required DocumentReference<Map<String, dynamic>> docRef,
    required Map<String, dynamic> m,
  }) async {
    final docId = docRef.id;
    if (_processed.contains(docId)) return;

    try {
      final String status = (m['status'] ?? '').toString();
      if (status != Constant.ridePlaced) return;

      final now = DateTime.now();
      final isSched = _isScheduled(m);

      if (!isSched) {
        final created = m['createdDate'];
        DateTime? createdAt;
        if (created is Timestamp) createdAt = created.toDate();
        if (createdAt != null && now.difference(createdAt).inMinutes >= 5) {
          await docRef.update({
            'status': Constant.rideCanceled,
            'acceptedDriverId': <dynamic>[],
          });
          _processed.add(docId);
        }
      } else {
        final start = _getScheduledStartLocal(m);
        final driverId = m['driverId']?.toString() ?? '';
        final accepted = (m['acceptedDriverId'] as List?) ?? const [];
        final noOneAccepted = (driverId.isEmpty) &&
            (accepted.isEmpty ||
                accepted.every((e) => e == null || e.toString().isEmpty));

        if (start != null && now.isAfter(start) && noOneAccepted) {
          await docRef.update({
            'status': Constant.rideCanceled,
            'acceptedDriverId': <dynamic>[],
          });
          _processed.add(docId);
        }
      }
    } catch (_) {}
  }

  String _headerTitleForCard(Map<String, dynamic> m) {
    if (_isScheduled(m)) {
      final start = _getScheduledStartLocal(m);
      if (start != null && DateTime.now().isBefore(start)) {
        return 'Viaje programado';
      }
    }
    return 'Viaje Activo';
  }

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);

    // Fondo elegante
    return Container(
      color: const Color(0xFFF5F7FB),
      child: _buildBody(themeChange),
    );
  }

  Widget _buildBody(DarkThemeProvider themeChange) {
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

        final col =
            FirebaseFirestore.instance.collection(CollectionName.orders);

        final stream = col
            .where('status', isEqualTo: Constant.ridePlaced)
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
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final d = docs[i];
                final m = d.data();

                _maybeAutoCancel(docRef: d.reference, m: m);

                final id = (m['id'] ?? d.id).toString();
                final created = _fmtTs(m['createdDate']);

                final src = (m['sourceLocationName'] ?? '').toString();
                final dst = (m['destinationLocationName'] ?? '').toString();

                final offerRate =
                    num.tryParse((m['offerRate'] ?? '0').toString());
                final distance =
                    num.tryParse((m['distance'] ?? '0').toString());
                final distanceType =
                    (m['distanceType'] ?? Constant.distanceType).toString();

                final titleText = _headerTitleForCard(m);

                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RidePlacedDetailsPage(order: m),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: _RidePlacedCard(
                    titleRight: created,
                    titleText: titleText,
                    chips: [
                      _chipData('Tarifa', _money(offerRate)),
                      if (distance != null)
                        _chipData('Distancia',
                            '${distance.toStringAsFixed(2)} $distanceType'),
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
  final String titleRight;
  final String titleText;
  final List<_ChipData> chips;
  final String src;
  final String dst;

  const _RidePlacedCard({
    Key? key,
    required this.titleRight,
    required this.titleText,
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
    return Stack(
      children: [
        // CARD
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE9EDF4), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A0F172A), // sombra muy sutil
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    // Badge/pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9), // verde claro
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        widget.titleText,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          color: Colors.green.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 14, color: Colors.black45),
                        const SizedBox(width: 4),
                        Text(
                          widget.titleRight,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Chips fila
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.chips
                      .where((c) => !c.hidden || _showId)
                      .map(_buildChip)
                      .toList(),
                ),

                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFE9EDF4)),
                const SizedBox(height: 12),

                // Origen
                _rowIconText(
                  icon: Icons.radio_button_checked,
                  iconBg: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF2563EB),
                  label: 'Origen',
                  text: widget.src.isEmpty ? '—' : widget.src,
                ),
                const SizedBox(height: 10),

                // Destino
                _rowIconText(
                  icon: Icons.location_on,
                  iconBg: const Color(0xFFFFF1F2),
                  iconColor: const Color(0xFFDC2626),
                  label: 'Destino',
                  text: widget.dst.isEmpty ? '—' : widget.dst,
                ),
              ],
            ),
          ),
        ),

        // Action (Easter Egg ID)
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
    // Pills elegantes
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Text(
        '${c.label}: ${c.value}',
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.green.shade800,
        ),
      ),
    );
  }

  Widget _rowIconText({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icono redondo
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 10),
        // Texto
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.black54,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
    