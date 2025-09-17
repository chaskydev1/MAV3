import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:driver/constant/constant.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/utils/DarkThemeProvider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class RidePlacedDetailsPage extends StatelessWidget {
  final Map<String, dynamic> order;
  const RidePlacedDetailsPage({Key? key, required this.order})
      : super(key: key);

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
    final created = _fmtTs(order['createdDate']);
    final src = (order['sourceLocationName'] ?? '').toString();
    final dst = (order['destinationLocationName'] ?? '').toString();
    final paymentType = (order['paymentType'] ?? '').toString();
    final offerRate = num.tryParse((order['offerRate'] ?? '0').toString());
    final distance = num.tryParse((order['distance'] ?? '0').toString());
    final distanceType =
        (order['distanceType'] ?? Constant.distanceType).toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles del viaje'),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: themeChange.getThem()
                  ? AppColors.darkContainerBackground
                  : AppColors.containerBackground,
              borderRadius: BorderRadius.circular(14),
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header estado + fecha
                  Row(
                    children: [
                      const Icon(Icons.receipt_long, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Viaje Activo',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      Text(
                        created,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _chip('Tarifa', _money(offerRate)),
                      if (distance != null)
                        _chip('Distancia',
                            '${distance.toStringAsFixed(2)} $distanceType'),
                      if (paymentType.isNotEmpty) _chip('Pago', paymentType),
                    ],
                  ),

                  const SizedBox(height: 16),
                  _sectionTitle('Origen'),
                  _rowIconText(Icons.radio_button_checked, src.isEmpty ? '—' : src),

                  const SizedBox(height: 12),
                  _sectionTitle('Destino'),
                  _rowIconText(Icons.location_on, dst.isEmpty ? '—' : dst),

                  // Puedes agregar más secciones si tu doc trae más datos
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.poppins(fontSize: 12),
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Text(
      t,
      style: GoogleFonts.poppins(
        fontWeight: FontWeight.w700,
        fontSize: 14,
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
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
    );
  }
}
