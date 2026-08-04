import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/fluttware_app.dart';
import 'runtime/runtime_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await RuntimeController.instance.initialize();
  runApp(const FlutterwareApp());
}
