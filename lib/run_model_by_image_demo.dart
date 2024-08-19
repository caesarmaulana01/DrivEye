import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:pytorch_lite/pytorch_lite.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';


class RunModelByImageDemo extends StatefulWidget {
  final File imageFile;

  const RunModelByImageDemo({Key? key, required this.imageFile}) : super(key: key);

  @override
  _RunModelByImageDemoState createState() => _RunModelByImageDemoState();
}

class _RunModelByImageDemoState extends State<RunModelByImageDemo> {
  late ModelObjectDetection _objectModel;
  late Uint8List _croppedImageData;
  double? dist;
  late int inferenceTime;
  double? infTime;
  double? w;
  double? h;
  bool isLoading = true;
  List<ResultObjectDetection?> objDetect = [];
  List<Map<String, dynamic>> detectionData = [];
  Map<String, dynamic>? nearestObject;
  double nearestDistance = 0.0;
  Directory? _tempDir;
  File? _tempImageFile;

  @override
  void initState() {
    super.initState();
    loadModel();
    loadCroppedImage();
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

  Future<void> loadModel() async {
    String pathObjectDetectionModel = "assets/models/yolov5m110e.torchscript";
    try {
      _objectModel = await PytorchLite.loadObjectDetectionModel(
        pathObjectDetectionModel, 7, 416, 416,
        labelPath: "assets/labels/yolov5newvehicle200e.txt",
      );
      await runObjectDetection(); // Pastikan runObjectDetection menunggu sampai selesai
    } catch (e) {
      if (e is PlatformException) {
        print("Only supported for Android. Error: $e");
      } else {
        print("Error: $e");
      }
      setState(() {
        isLoading = false; // Stop loading indicator on error
      });
    }
  }



  Future<void> loadCroppedImage() async {
    _croppedImageData = await cropSquare(widget.imageFile); // Crop image to square

    // Get temporary directory
    _tempDir = await getTemporaryDirectory();

    // Create a temporary file and write the cropped image data to it
    _tempImageFile = File('${_tempDir!.path}/cropped_image.jpg');
    await _tempImageFile!.writeAsBytes(_croppedImageData);

    setState(() {});
  }

  Future<void> runObjectDetection() async {
    final File image = widget.imageFile;
    Uint8List imageBytes = await cropSquare(image); // Crop image to square

    Stopwatch stopwatch = Stopwatch()..start();
    objDetect = await _objectModel.getImagePrediction(
      imageBytes,
      minimumScore: 0.3,
      iOUThreshold: 0.3,
    );

    dist = null; // Initialize distance
    detectionData.clear(); // Clear previous detection data
    nearestObject = null;
    nearestDistance = double.infinity;

    for (var element in objDetect) {
      if (element != null) {
        w = element.rect.width * 416;
        h = element.rect.height * 416;
        double widthBB = element.rect.width * 416;
        double heightBB = element.rect.height * 416;
        if (element.className == "motorcycle") {
          dist = (((2 * 3.14 * 180) / (widthBB + heightBB * 360) * 1000 + 3) * 0.254);
          // dist = dist! - ((2.7316 * widthBB) - (1.7530 * heightBB) + 21.2416);
        } else if (element.className == "car") {
          dist = (((2 * 3.14 * 180) / (widthBB + heightBB * 360) * 1000 + 3) * 0.254);
          // dist = dist! - ((1.7942 * widthBB) - (1.8766 * heightBB) + 7.1975);
        } else if (element.className == "person") {
          dist = (((2 * 3.14 * 180) / (widthBB + heightBB * 360) * 1000 + 3) * 0.254);
          // dist = dist! - ((1.7896 * widthBB) - (0.5159 * heightBB) + 3.920);
        } else if (element.className == "bus") {
          dist = (((2 * 3.14 * 180) / (widthBB + heightBB * 360) * 1000 + 3) * 0.254);
        } else if (element.className == "truck") {
          dist = (((2 * 3.14 * 180) / (widthBB + heightBB * 360) * 1000 + 3) * 0.254);
        } else if (element.className == "van") {
          dist = (((2 * 3.14 * 180) / (widthBB + heightBB * 360) * 1000 + 3) * 0.254);
        } else if (element.className == "bicycle") {
          dist = (((2 * 3.14 * 180) / (widthBB + heightBB * 360) * 1000 + 3) * 0.254);
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
          print('Nearest object updated: $nearestObject');
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
    setState(() {
      isLoading = false; // Stop loading indicator when done
      print('Final nearest object: $nearestObject');
    });
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
  Widget build(BuildContext context) {
    double riskPercentage = nearestObject != null ? calculateRiskLevel(nearestDistance) : 0.0;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Detection Result',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: const Color(0xFF225DF9),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // Use pop instead of push
          },
        ),
      ),
      body: Stack(
        children: [
          if (!isLoading)
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
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
                                    ? _objectModel.renderBoxesOnImage(File('${_tempDir!.path}/cropped_image.jpg'), objDetect)
                                    : _croppedImageData != null
                                    ? Image.memory(
                                  _croppedImageData,
                                  fit: BoxFit.cover,
                                )
                                    : Center(child: CircularProgressIndicator()),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 0), // Adjusted space between image and elements below
                  if (detectionData.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 10), // Reduced padding for Risk Level text
                                child: Text(
                                  'Risk Level',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(height: 2), // Reduced space between Risk Level text and gauge meter
                              SizedBox(
                                width: 200,
                                height: 160, // Adjusted height for gauge meter
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
                                                    padding: EdgeInsets.only(right: 10), // Padding for riskPercentage value
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
                        const SizedBox(width: 2), // Reduced space between columns
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Informasi Inference Time
                              Container(
                                margin: const EdgeInsets.only(bottom: 8.0), // Adjusted bottom margin
                                decoration: BoxDecoration(
                                  color: Colors.lightBlueAccent,
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                child: Row(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Icon(Icons.access_time, color: Colors.white, size: 25), // Icon for Inference time
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

                              SizedBox(height: 2), // Reduced space between rows

                              // Informasi Objek Terdekat
                              Container(
                                margin: const EdgeInsets.only(bottom: 8.0), // Adjusted bottom margin
                                decoration: BoxDecoration(
                                  color: Colors.lightBlueAccent,
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                child: Row(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Icon(Icons.image_search, color: Colors.white, size: 25), // Icon for Objek terdekat
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

                              SizedBox(height: 2), // Reduced space between rows

                              // Informasi Jarak Terdekat
                              Container(
                                margin: const EdgeInsets.only(bottom: 8.0), // Adjusted bottom margin
                                decoration: BoxDecoration(
                                  color: Colors.lightBlueAccent,
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                child: Row(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Icon(Icons.directions_car, color: Colors.white, size: 25), // Icon for Jarak terdekat
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Neearest Distance",
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
                  if (detectionData.isNotEmpty)

                    Column(
                      children: [
                        Text(
                          "Detected Object",
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Column(
                          children: detectionData.where((data) => data != nearestObject).map((data) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8.0), // Adjusted margin for consistency
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
                          "No Detected Object",
                          style: GoogleFonts.poppins(fontSize: 16),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          if (isLoading)
            Center(
              child: SpinKitCubeGrid (
                color: Colors.blue,
                size: 50.0,
              ),
            ),

        ],
      ),
    );
  }
}
