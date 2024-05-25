import 'package:flutter/material.dart';
import 'package:ez_pos_system_app/tablet/order.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

class ResultPage extends StatefulWidget {
  final String? transactionId;
  final String? currentOrderId;
  const ResultPage({Key? key, this.transactionId, this.currentOrderId})
      : super(key: key);

  @override
  _ResultState createState() => _ResultState();
}

class _ResultState extends State<ResultPage> {
  String? transactionId;
  String? currentOrderId;

  Future<void> completeOrder() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    await firestore.collection('CURRENT_ORDER').doc(currentOrderId).delete();
  }

  Future<bool?> getSettings({String key = ""}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key);
  }

  Future<void> startLCD() async {
    await SunmiPrinter.lcdInitialize();
    await SunmiPrinter.lcdWakeup();
    await SunmiPrinter.lcdClear();
  }

  num getTotal(dynamic items) {
    num total = 0;
    for (final Map<String, dynamic> item in items) {
      total += item['price'] * item['quantity'];
    }
    return total;
  }

  Future<void> displayLCD() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final DocumentSnapshot documentSnapshot =
        await firestore.collection('CURRENT_ORDER').doc(currentOrderId).get();
    final Map<String, dynamic> data =
        documentSnapshot.data() as Map<String, dynamic>;
    final List<dynamic> items = data['items'];
    final num price = data['deposit'] - getTotal(items);
    await SunmiPrinter.lcdDoubleString("お釣り  $price円", "ご購入感謝！");
  }

  @override
  void initState() {
    super.initState();
    transactionId = widget.transactionId;
    currentOrderId = widget.currentOrderId;
    getSettings(key: "enableLCD").then((value) {
      if (value == true) {
        startLCD();
        displayLCD();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(44),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 100,
                color: Colors.green,
              ),
              const Text(
                'お支払いが完了しました。',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              transactionId != "" && transactionId != null
                  ? Text(
                      '決済ID：$transactionId',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : Container(),
              SizedBox(
                  height: 60,
                  width: MediaQuery.of(context).size.width * 0.4,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      completeOrder();
                      Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const OrderPage()));
                    },
                    child: const Text('ホームに戻る', style: TextStyle(fontSize: 20)),
                  ))
            ]),
      ),
    );
  }
}
