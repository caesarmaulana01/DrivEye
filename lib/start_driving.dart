import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:ta_vehicle_detection/driving_mode.dart';
import 'package:ta_vehicle_detection/running_state.dart';

class StartPage extends StatelessWidget {
  const StartPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Driving Mode',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: const Color(0xFF225DF9),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Place your smartphone in the phone holder and press Start to enter Driving Mode.",
              style: GoogleFonts.poppins(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                print("Button pressed");
                context.read<RunningState>().isRunning = true;
                print("RunningState.isRunning: ${context.read<RunningState>().isRunning}");
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DrivingMode()),
                );
              },
              style: ElevatedButton.styleFrom(
                primary: const Color(0xFF225DF9),
                onPrimary: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                textStyle: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text("Start"),
            ),
          ],
        ),
      ),
    );
  }
}
