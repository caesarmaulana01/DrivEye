import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';

void showWarningPopup(BuildContext context) {
  playSystemSound(context);
  showDialog(
    context: context,
    barrierDismissible: false, // Mencegah dialog ditutup dengan menyentuh di luar
    builder: (BuildContext context) {
      return WillPopScope(
        onWillPop: () async => false, // Mencegah dialog ditutup dengan tombol back
        child: AlertDialog(
          contentPadding: EdgeInsets.zero, // Hilangkan padding di dalam content
          content: Container(
            padding: EdgeInsets.all(20), // Atur padding untuk konten
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning,
                  color: Colors.red,
                  size: 64, // Perbesar ukuran ikon
                ),
                SizedBox(height: 10),
                Text(
                  'The risk level is high!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      );
    },
  );
}

void playSystemSound(BuildContext context) async {
  final AudioCache cache = AudioCache();
  AudioPlayer player = await cache.play('sounds/warning.mp3'); // Play the system sound

  player.onPlayerCompletion.listen((event) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(); // Tutup dialog setelah suara selesai diputar
    }
  });
}
