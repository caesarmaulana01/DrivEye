import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ta_vehicle_detection/splash_screen.dart';
import 'package:ta_vehicle_detection/start_driving.dart';
import 'package:ta_vehicle_detection/running_state.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:ta_vehicle_detection/image_selection.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => RunningState(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(), // Use the existing SplashScreen function
      routes: {
        '/chooseMode': (context) => const ChooseMode(),
      },
    );
  }
}

class ChooseMode extends StatelessWidget {
  const ChooseMode({Key? key}) : super(key: key);

  void navigateToImageSelection(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageSelectionPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/splash_logo.png', // Replace with your logo asset path
              height: 40,
            ),
            const SizedBox(width: 8),
            Text(
              'DRIVEYE',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF225DF9),
        automaticallyImplyLeading: false, // Remove back button
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Text(
                "WELCOME TO DRIVEYE!",
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Select Image to detect only on the chosen image and Driving Mode to record data and provide early warnings while you are driving.",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => navigateToImageSelection(context),
                      style: ElevatedButton.styleFrom(
                        primary: const Color(0xFF225DF9), // Button background color
                        onPrimary: Colors.white, // Button text color
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        textStyle: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.image), // Add icon to button
                      label: const Text("Select Image"),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => StartPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        primary: const Color(0xFF225DF9), // Button background color
                        onPrimary: Colors.white, // Button text color
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        textStyle: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.videocam), // Add icon to button
                      label: const Text("Driving Mode"),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Additional widgets if needed
            ],
          ),
        ),
      ),
      backgroundColor: Colors.white, // Background color of the screen
    );
  }
}
