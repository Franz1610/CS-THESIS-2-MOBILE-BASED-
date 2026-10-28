import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:handicraft_app/app/my_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var cameras = <CameraDescription>[];
  try {
    cameras = await availableCameras();
  } catch (error, stackTrace) {
    debugPrint('Could not enumerate cameras: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
  runApp(MyApp(cameras: cameras));
}
