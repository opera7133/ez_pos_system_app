import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'package:sunmi_printer_plus/enums.dart';
import 'package:image/image.dart' as im;

class CameraPage extends StatefulWidget {
  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  Future<void> bindPrinter() async {
    final bool? res = await SunmiPrinter.bindingPrinter();
    if (res != null && res) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('プリンターに接続しました'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('プリンターに接続できませんでした'),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    bindPrinter();
    _initializeControllerFuture = _initializeController();
  }

  Future<void> _initializeController() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;
    _controller = CameraController(
      firstCamera,
      ResolutionPreset.max,
    );
    await _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('カメラで撮影'),
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return SizedBox(
                width: 640,
                height: 480,
                child: RotatedBox(
                    quarterTurns: 3, child: CameraPreview(_controller)));
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.camera_alt),
        onPressed: () async {
          final XFile file = await _controller.takePicture();
          final Uint8List bytes = await file.readAsBytes();
          await SunmiPrinter.initPrinter();
          await SunmiPrinter.startTransactionPrint();
          await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
          await SunmiPrinter.lineWrap(2);
          await SunmiPrinter.printImage(bytes);
          await SunmiPrinter.lineWrap(4);
          await SunmiPrinter.submitTransactionPrint();
          await SunmiPrinter.cut();
          await SunmiPrinter.exitTransactionPrint();
        },
      ),
    );
  }
}
