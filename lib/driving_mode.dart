import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:pytorch_lite/pytorch_lite.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:camera/camera.dart';
import 'dart:ui' as ui;
import 'package:ta_vehicle_detection/success_screen.dart';
import 'package:ta_vehicle_detection/warning_popup.dart';
import 'package:provider/provider.dart';
import 'package:ta_vehicle_detection/running_state.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class DrivingMode extends StatefulWidget {
  const DrivingMode({Key? key}) : super(key: key);

  @override
  _DrivingModeState createState() => _DrivingModeState();
}

class _DrivingModeState extends State<DrivingMode> {

  late CameraController _cameraController;
  late ModelObjectDetection _objectModel;
  late Uint8List _croppedImageData;
  late File _image;
  double? dist;
  late int inferenceTime;
  double? infTime;
  double? w;
  double? h;
  bool isLoading = false;
  bool isFlashEnabled = false;
  bool isPredicting = false; // Flag for prediction state
  List<ResultObjectDetection?> objDetect = [];
  List<Map<String, dynamic>> detectionData = [];
  Map<String, dynamic>? nearestObject;
  double nearestDistance = 0.0;
  ui.Image? detectionImage;
  late int _tripNumber;
  late String _currentDateTime;
  bool _isRunning = true; // New flag to track running status

  @override
  void initState() {
    super.initState();
    initialize();

  }


  Future<void> initialize() async {
    setState(() {
      isLoading = true;
      isPredicting = false;
    });
    final runningState = Provider.of<RunningState>(context, listen: false);
    if (!runningState.isRunning) return;
    await loadModel();
    await initializeCamera();
    _tripNumber = DateTime.now().millisecondsSinceEpoch; // Set initial trip number based on current time
    _currentDateTime = DateTime.now().toString(); // Set initial datetime
    await saveToCSV(); // Save initial data for trip
    runObjectDetection();
    await loadCroppedImage(); // Load cropped image after initializing camera
  }



  Future<void> saveToCSV() async {
    if (nearestObject == null) return; // Exit if nearestObject is null
    if (!_isRunning) return; // Exit if not running

    String dateTime = DateTime.now().toString(); // Use current datetime
    String nearestObjectClass = nearestObject!['className'];
    double nearestObjectDistance = nearestObject!['distance'];
    double nearestObjectScore = nearestObject!['score'];

    // Get the external storage directory
    Directory? externalDirectory = await getExternalStorageDirectory();
    if (externalDirectory == null) {
      print('Error: Could not access the external storage directory');
      return;
    }

    // Specify the directory where you want to store the file
    String desiredDirectory = 'my_custom_directory';
    String directoryPath = '${externalDirectory.path}/$desiredDirectory';

    // Create the directory if it doesn't exist
    Directory(directoryPath).createSync(recursive: true);

    // Create a path for the CSV file
    String filePath = '$directoryPath/trip_data_$_tripNumber.csv';
    print('File path: $filePath');

    // Write header if the file doesn't exist yet
    bool fileExists = await File(filePath).exists();
    if (!fileExists) {
      await File(filePath).writeAsString(
        'DateTime,NearestObjectClass,NearestObjectDistance,NearestObjectScore\n',
        mode: FileMode.append,
      );
    }

    // Write data to CSV file
    String dataRow = '$dateTime,$nearestObjectClass,$nearestObjectDistance,$nearestObjectScore\n';
    await File(filePath).writeAsString(dataRow, mode: FileMode.append);
    print('Data saved to CSV: $dataRow');
  }

  Future<void> loadModel() async {
    String pathObjectDetectionModel = "assets/models/yolov5vehicle120e.torchscript";
    try {
      _objectModel = await PytorchLite.loadObjectDetectionModel(
        pathObjectDetectionModel, 7, 416, 416,
        labelPath: "assets/labels/yolov5newvehicle200e.txt",
      );
    } catch (e) {
      if (e is PlatformException) {
        print("Only supported for Android. Error: $e");
      } else {
        print("Error: $e");
      }
    }
  }

  Future<void> loadCroppedImage() async {
    _croppedImageData = await cropSquare(_image);
    setState(() {});
  }

  Future<void> captureImage() async {
    final XFile? image = await _cameraController.takePicture(); // Ambil gambar yang mengembalikan XFile
    if (image != null) {
      _image = File(image.path); // Konversi XFile ke File
    }
  }

  Future<void> initializeCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.first;

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _cameraController.initialize();

    if (mounted) {
      setState(() {});
    }
    // Matikan flash secara default
    isFlashEnabled = false;
    _cameraController.setFlashMode(FlashMode.off);
  }

  Future<void> runObjectDetection() async {
    final runningState = Provider.of<RunningState>(context, listen: false);
    if (!runningState.isRunning) return;

    if (!_cameraController.value.isInitialized) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    setState(() {
      isPredicting = true;
    });

    try {
      final XFile? image = await _cameraController.takePicture();

      if (image != null) {
        _image = File(image.path); // Konversi XFile ke File
      }

      if (_image == null) {
        setState(() {
          isLoading = false;
          isPredicting = false;
        });
        return;
      }

      // final bytes = await _image!.readAsBytes();
      // final ui.Image originalImage = await decodeImageFromList(bytes);
      Uint8List croppedImage = await cropSquare(_image);

      Stopwatch stopwatch = Stopwatch()..start();
      objDetect = await _objectModel.getImagePrediction(
        croppedImage,
        minimumScore: 0.5,
        iOUThreshold: 0.5,
      );

      setState(() {
        isLoading = false;
      });

      dist = null;
      detectionData.clear();
      nearestObject = null;
      nearestDistance = double.infinity;

      for (var element in objDetect) {
        if (element != null) {
          w = element.rect.width * 416;
          h = element.rect.height * 416;
          double widthBB = element.rect.width * 416;
          double heightBB = element.rect.height * 416;
          if (element.className == "motorcycle") {
            dist = (((2 * 3.14 * 180) / (widthBB + heightBB * 360) * 1000 + 3) * 0.254) - 2;
          } else if (element.className == "car") {
            dist = (((2 * 3.14 * 180) / (widthBB + heightBB * 360) * 1000 + 3) * 0.254) - 0.5;
          } else if (element.className == "person") {
            dist = (((2 * 3.14 * 180) / (widthBB + heightBB * 360) * 1000 + 3) * 0.254);
          } else if (element.className == "bus") {
            dist = (((2 * 3.14 * 180) / (widthBB + heightBB * 360) * 1000 + 3) * 0.254) - 0.5;
          } else if (element.className == "truck") {
            dist = (((2 * 3.14 * 180) / (widthBB + heightBB * 360) * 1000 + 3) * 0.254) - 0.5;
          } else if (element.className == "van") {
            dist = (((2 * 3.14 * 180) / (widthBB + heightBB * 360) * 1000 + 3) * 0.254) - 0.5;
          } else if (element.className == "bicycle") {
            dist = (((2 * 3.14 * 180) / (widthBB + heightBB * 360) * 1000 + 3) * 0.254) - 0.5;
          }

          if (dist != null && dist! < nearestDistance) {
            nearestDistance = dist!;
            nearestObject = {
              "score": element.score,
              "className": element.className,
              "class": element.classIndex,
              "distance": dist,
              "width": w,
              "height": h,
              "rect": {
                "left": element.rect.left,
                "top": element.rect.top,
                "width": element.rect.width,
                "height": element.rect.height,
                "right": element.rect.right,
                "bottom": element.rect.bottom,
              },
            };
          }

          if (nearestObject != null) {
            await saveToCSV();
          }

          detectionData.add({
            "score": element.score,
            "className": element.className,
            "class": element.classIndex,
            "distance": dist,
            "width": w,
            "height": h,
            "rect": {
              "left": element.rect.left,
              "top": element.rect.top,
              "width": element.rect.width,
              "height": element.rect.height,
              "right": element.rect.right,
              "bottom": element.rect.bottom,
            },
          });
          print({
            "score": element.score,
            "className": element.className,
            "class": element.classIndex,
            "distance": dist,
            "width_box": w,
            "height_box": h,
          });
        }
      }

      inferenceTime = stopwatch.elapsed.inMilliseconds;
      infTime = inferenceTime * 0.001;
      print('object executed in $infTime s');

      double riskPercentage = calculateRiskLevel(nearestDistance);
      if (nearestObject != null && riskPercentage >= 66) {
        showWarningPopup(context);
      }

      setState(() {
        isPredicting = false;
      });

      runObjectDetection();
    } catch (e) {
      setState(() {
        isLoading = false;
        isPredicting = false;
      });
      print("Error: $e");
    }
  }

  Future<Uint8List> cropSquare(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final originalImage = img.decodeImage(bytes);

    if (originalImage == null) {
      throw Exception('Could not decode image');
    }

    int width = originalImage.width;
    int height = originalImage.height;
    int size = width < height ? width : height;

    int offsetX = (width - size) ~/ 2;
    int offsetY = (height - size) ~/ 2;

    // Ensure the x, y, width, and height parameters are provided correctly
    final croppedImage = img.copyCrop(originalImage, x: offsetX, y: offsetY, width: size, height: size);

    // Encode the cropped image to Uint8List (e.g., JPEG format)
    return Uint8List.fromList(img.encodeJpg(croppedImage));
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }


  double calculateRiskLevel(double nearestDistance) {
    nearestDistance = math.min(math.max(nearestDistance, 0.0), 12.0);

    double riskPercentage = 100.0 - (nearestDistance / 12.0 * 100.0);

    // Set riskPercentage menjadi 100 jika nearestDistance lebih dari 12 meter
    if (nearestDistance > 12.0) {
      riskPercentage = 100.0;
    }

    return riskPercentage;
  }

  @override
  Widget build(BuildContext context) {
    double riskPercentage = nearestObject != null ? calculateRiskLevel(nearestDistance) : 0.0;

    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Driving Mode',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          backgroundColor: const Color(0xFF225DF9),
          automaticallyImplyLeading: false,
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                final runningState = Provider.of<RunningState>(context, listen: false);
                switch (value) {
                  case 'toggle_flash':
                    setState(() {
                      isFlashEnabled = !isFlashEnabled;
                    });
                    if (isFlashEnabled) {
                      _cameraController.setFlashMode(FlashMode.torch);
                    } else {
                      _cameraController.setFlashMode(FlashMode.off);
                    }
                    break;
                  case 'stop':
                    runningState.isRunning = false;

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const SuccessScreen()),
                    );
                    break;
                }
              },
              itemBuilder: (BuildContext context) {
                return [
                  PopupMenuItem(
                    value: 'toggle_flash',
                    child: Text(isFlashEnabled ? 'Flash Off' : 'Flash On'),
                  ),
                  PopupMenuItem(
                    value: 'stop',
                    child: const Text('Stop'),
                  ),
                ];
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            if (!isLoading)
              SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    if (isPredicting)
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5, // Adjusted height for the preview image container
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.grey[200],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: AspectRatio(
                                    aspectRatio: 1, // Make the container a square
                                    child: objDetect.isNotEmpty
                                        ? _objectModel.renderBoxesOnImage(_image, objDetect)
                                        : Image.file(
                                      _image,
                                      fit: BoxFit.cover, // Tambahkan ini
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (isPredicting)
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 10, top: 10), // Padding untuk teks Risk Level
                                  child: Text(
                                    'Risk Level',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8), // Memberi jarak antara teks Risk Level dan gauge meter
                                SizedBox(
                                  width: 200,
                                  height: 180, // Mengurangi tinggi rectangle
                                  child: Stack(
                                    alignment: Alignment.centerLeft,
                                    children: [
                                      Positioned.fill(
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: SfRadialGauge(
                                            axes: <RadialAxis>[
                                              RadialAxis(
                                                minimum: 0,
                                                maximum: 100,
                                                ranges: <GaugeRange>[
                                                  GaugeRange(startValue: 0, endValue: 33, color: Colors.green),
                                                  GaugeRange(startValue: 33, endValue: 66, color: Colors.yellow),
                                                  GaugeRange(startValue: 66, endValue: 100, color: Colors.red),
                                                ],
                                                pointers: <GaugePointer>[
                                                  NeedlePointer(
                                                    value: riskPercentage,
                                                  ),
                                                ],
                                                annotations: <GaugeAnnotation>[
                                                  GaugeAnnotation(
                                                    widget: Container(
                                                      padding: EdgeInsets.only(right: 10), // Padding untuk nilai riskPercentage
                                                      child: Text(
                                                        '${riskPercentage.toStringAsFixed(2)}',
                                                        style: GoogleFonts.poppins(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    angle: 90,
                                                    positionFactor: 0.5,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              children: [
                                // Informasi Inference Time
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8.0),
                                  decoration: BoxDecoration(
                                    color: Colors.lightBlueAccent,
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  child: Row(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Icon(Icons.access_time, color: Colors.white, size: 25), // Icon untuk Inference time
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Inference time",
                                                style: GoogleFonts.poppins(fontSize: 12),
                                              ),
                                              SizedBox(height: 2),
                                              Text(
                                                infTime != null
                                                    ? "${infTime!.toStringAsFixed(2)} s"
                                                    : "-",
                                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: 2), // Memberi jarak antara setiap baris informasi

                                // Informasi Objek Terdekat
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8.0),
                                  decoration: BoxDecoration(
                                    color: Colors.lightBlueAccent,
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  child: Row(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Icon(Icons.image_search, color: Colors.white, size: 25), // Icon untuk Objek terdekat
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Nearest Object",
                                                style: GoogleFonts.poppins(fontSize: 12),
                                              ),
                                              SizedBox(height: 2),
                                              Text(
                                                nearestObject != null
                                                    ? "${nearestObject!['className']}"
                                                    : "-",
                                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: 2), // Memberi jarak antara setiap baris informasi

                                // Informasi Jarak Terdekat
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.lightBlueAccent,
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  child: Row(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Icon(Icons.directions_car, color: Colors.white, size: 25), // Icon untuk Jarak terdekat
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Nearest Distance",
                                                style: GoogleFonts.poppins(fontSize: 12),
                                              ),
                                              SizedBox(height: 2),
                                              Text(
                                                nearestObject != null
                                                    ? "${nearestObject!['distance']?.toStringAsFixed(2)} m"
                                                    : "-",
                                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    if (isPredicting)
                      Column(
                        children: [
                          Text(
                            "Another Detected Object",
                            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Column(
                            children: detectionData.where((data) => data != nearestObject).map((data) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 16.0),
                                padding: const EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                  color: Colors.lightBlueAccent,
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                width: double.infinity,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "${data['className']}",
                                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      "${data['distance']?.toStringAsFixed(2)} m",
                                      style: GoogleFonts.poppins(fontSize: 16),
                                    ),
                                    Text(
                                      "${data['score']?.toStringAsFixed(2)}",
                                      style: GoogleFonts.poppins(fontSize: 16),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    if (nearestObject == null && detectionData.isEmpty)
                      Column(
                        children: [
                          Text(
                            "No objects detected.",
                            style: GoogleFonts.poppins(fontSize: 16),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            if (isLoading)
              Center(
                child: SpinKitCubeGrid(
                  color: Colors.blue,
                  size: 50.0,
                ),
              ),
          ],
        ),
      ),
    );
  }

}

class ImagePainter extends CustomPainter {
  final ui.Image image;

  ImagePainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImage(image, Offset.zero, Paint());
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
