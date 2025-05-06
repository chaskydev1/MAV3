import 'package:driver/constant/constant.dart';
import 'package:driver/themes/app_colors.dart';
import 'package:driver/themes/responsive.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class RecargarScreen extends StatelessWidget {
  const RecargarScreen({super.key});

  Future<void> _launchWhatsApp() async {
    final Uri url = Uri.parse('https://wa.me/59171525805?text=Hola%2C%20adjunto%20comprobante%20de%20pago%20para%20recarga%20de%20mi%20billetera');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.green,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.3),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(
          "Recargar Billetera".tr,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            color: Colors.white,
            fontSize: 18
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // Imagen QR
            Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    spreadRadius: 1,
                  )
                ]
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/PagoQr.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 30),
            // Texto de instrucción
            Text(
              "Escanear el código QR para realizar tu pago".tr,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: Colors.black,
                fontSize: 16
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // Texto de WhatsApp
            Text(
              "Una vez realizado el pago, envía el comprobante al siguiente número de WhatsApp:".tr,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                color: Colors.black,
                fontSize: 14
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            // Botón de enviar comprobante
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _launchWhatsApp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  "Enviar comprobante".tr,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 16
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
