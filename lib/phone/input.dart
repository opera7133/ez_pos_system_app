import 'package:ez_pos_system_app/phone/printer.dart';
import 'package:ez_pos_system_app/phone/waypoint.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class InputPage extends StatefulWidget {
  const InputPage({Key? key}) : super(key: key);

  @override
  _InputPageState createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> {
  final MobileScannerController mbcontroller = MobileScannerController(
      autoStart: true,
      facing: CameraFacing.back,
      detectionTimeoutMs: 1500,
      detectionSpeed: DetectionSpeed.normal);
  String deviceId = "";
  TextEditingController controller = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    mbcontroller.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              height: 200,
              width: 200,
              child: MobileScanner(
                controller: mbcontroller,
                onDetect: (capture) {
                  setState(() {
                    deviceId = capture.barcodes.first.rawValue!;
                    controller.text = deviceId;
                  });
                },
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'デバイスID',
              ),
              onChanged: (text) {
                setState(() {
                  deviceId = text;
                });
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WayPoint(deviceId: deviceId),
                  ),
                );
              },
              child: const Text('決済モード'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Printer(deviceId: deviceId),
                  ),
                );
              },
              child: const Text('印刷モード'),
            ),
          ]),
    ));
  }
}
