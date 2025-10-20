import 'package:ez_pos_system_app/tablet/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sunmi_printer_plus/enums.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

class IllustPage extends StatefulWidget {
  @override
  _IllustPageState createState() => _IllustPageState();
}

class _IllustPageState extends State<IllustPage> {
  final ImagePicker picker = ImagePicker();

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('イラストを印刷'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('イラストを選択してください'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final XFile? result = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (result != null) {
                  final Uint8List bytes = await result.readAsBytes();
                  await SunmiPrinter.initPrinter();
                  await SunmiPrinter.startTransactionPrint();
                  await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
                  await SunmiPrinter.lineWrap(2);
                  await SunmiPrinter.printImage(bytes);
                  await SunmiPrinter.lineWrap(4);
                  await SunmiPrinter.submitTransactionPrint();
                  await SunmiPrinter.cut();
                  await SunmiPrinter.exitTransactionPrint();
                }
              },
              child: Text('画像を選択'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => CameraPage()));
              },
              child: Text('カメラで撮影'),
            ),
            ElevatedButton(
                onPressed: () async {
                  await SunmiPrinter.openDrawer();
                },
                child: Text('ドロワーを開く'))
          ],
        ),
      ),
    );
  }
}
