import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'dart:convert';

class PairingPage extends StatefulWidget {
  @override
  _PairingPageState createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  Future<String> _deviceId = Future.value('');
  String _displayColor = 'black';

  Future<String> getDeviceUniqueId() async {
    var deviceIdentifier = 'unknown';
    var deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      var androidInfo = await deviceInfo.androidInfo;
      deviceIdentifier = androidInfo.id;
    } else if (Platform.isIOS) {
      var iosInfo = await deviceInfo.iosInfo;
      deviceIdentifier = iosInfo.identifierForVendor!;
    }

    return deviceIdentifier;
  }

  @override
  void initState() {
    super.initState();
    _deviceId = getDeviceUniqueId();
  }

  Future<bool?> getSettings({String key = ""}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ペアリング'),
      ),
      body: FutureBuilder<String>(
        future: _deviceId,
        builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Center(
                child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(children: [
                  const Text("デバイスID", style: TextStyle(fontSize: 24)),
                  const SizedBox(height: 10),
                  QrImageView(
                    data: "${snapshot.data}",
                    version: QrVersions.auto,
                    size: 200.0,
                  ),
                  const SizedBox(height: 10),
                  Text("${snapshot.data}",
                      style: const TextStyle(fontSize: 24)),
                ]),
                Column(children: [
                  const Text("ディスプレイURL", style: TextStyle(fontSize: 24)),
                  const SizedBox(height: 10),
                  QrImageView(
                    data:
                        "https://${dotenv.env["EZ_POS_WEB_DOMAIN"]}/?color=${_displayColor}&deviceId=${snapshot.data}",
                    version: QrVersions.auto,
                    size: 200.0,
                  ),
                  const SizedBox(height: 10),
                  DropdownButton<String>(
                    value: _displayColor,
                    padding: const EdgeInsets.all(8),
                    items: <String>['black', 'blue', 'white']
                        .map((String value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value,
                                  style: const TextStyle(fontSize: 24)),
                            ))
                        .toList(),
                    onChanged: (String? value) async {
                      SharedPreferences prefs =
                          await SharedPreferences.getInstance();
                      prefs.setString("displayColor", value!);
                      setState(() {
                        _displayColor = value;
                      });
                    },
                  ),
                ]),
              ],
            ));
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
    );
  }
}
