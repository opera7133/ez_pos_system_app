import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool enableSquare = false;
  bool enablePrinter = false;
  bool enableLCD = false;

  @override
  void initState() {
    super.initState();
    getSettings(key: "enableSquare").then((value) {
      setState(() {
        enableSquare = value ?? false;
      });
    });
    getSettings(key: "enablePrinter").then((value) {
      setState(() {
        enablePrinter = value ?? false;
      });
    });
    getSettings(key: "enableLCD").then((value) {
      setState(() {
        enableLCD = value ?? false;
      });
    });
  }

  Future<bool?> getSettings({String key = ""}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: Column(children: [
        SwitchListTile(
          title: const Text('Square'),
          value: enableSquare,
          onChanged: (bool value) async {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            prefs.setBool("enableSquare", value);
            setState(() {
              enableSquare = value;
            });
          },
        ),
        SwitchListTile(
          title: const Text('プリンター'),
          value: enablePrinter,
          onChanged: (bool value) async {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            prefs.setBool("enablePrinter", value);
            setState(() {
              enablePrinter = value;
            });
          },
        ),
        SwitchListTile(
          title: const Text('LCD'),
          value: enableLCD,
          onChanged: (bool value) async {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            prefs.setBool("enableLCD", value);
            setState(() {
              enableLCD = value;
            });
          },
        ),
      ]),
    );
  }
}
