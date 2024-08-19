import 'package:flutter/foundation.dart';

class RunningState extends ChangeNotifier {
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  set isRunning(bool value) {
    _isRunning = value;
    notifyListeners();
  }
}
