import 'package:ez_pos_system_app/utils/database.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

class Printer extends StatefulWidget {
  final String deviceId;
  const Printer({Key? key, required this.deviceId}) : super(key: key);

  @override
  _PrinterState createState() => _PrinterState();
}

class _PrinterState extends State<Printer> {
  final Database database = Database();
  Map<String, dynamic> order = {};
  String deviceId = "";
  String currentOrderId = "";
  bool processing = false;
  DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm');

  num getQuantity() {
    num quantity = 0;
    for (final Map<String, dynamic> item in order["items"]) {
      quantity += item['quantity'];
    }
    return quantity;
  }

  num getTotal() {
    num total = 0;
    for (final Map<String, dynamic> item in order["items"]) {
      total += item['price'] * item['quantity'];
    }
    return total;
  }

  Future<void> getDeviceUniqueId() async {
    setState(() {
      deviceId = widget.deviceId;
    });
  }

  Future<void> printReceipt() async {
    await SunmiPrinter.lineWrap(3);
    await SunmiPrinter.printText('電通部',
        style: SunmiTextStyle(fontSize: 48, align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.printText('東京都品川区東大井1-10-40',
        style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.lineWrap(2);
    await SunmiPrinter.printText(formatter.format(DateTime.now()));
    await SunmiPrinter.printText('ID: ${order["deviceId"]}');
    await SunmiPrinter.lineWrap(2);
    await SunmiPrinter.printText("領 収 書",
        style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.lineWrap(2);
    await SunmiPrinter.line();
    await SunmiPrinter.lineWrap(2);
    for (final Map<String, dynamic> item in order["items"]) {
      if (item["quantity"] > 1) {
        await SunmiPrinter.printText(item["name"]);
        await SunmiPrinter.printRow(cols: [
          SunmiColumn(
              text: '',
              width: 2,
              style: SunmiTextStyle(align: SunmiPrintAlign.LEFT)),
          SunmiColumn(
              text: '¥${item["price"]}',
              width: 12,
              style: SunmiTextStyle(align: SunmiPrintAlign.LEFT)),
          SunmiColumn(
              text: '${item["quantity"]}点',
              width: 7,
              style: SunmiTextStyle(align: SunmiPrintAlign.LEFT)),
          SunmiColumn(
              text: '¥${item["price"] * item["quantity"]}',
              width: 12,
              style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT)),
        ]);
      } else {
        await SunmiPrinter.printRow(cols: [
          SunmiColumn(
              text: item["name"],
              width: 22,
              style: SunmiTextStyle(align: SunmiPrintAlign.LEFT)),
          SunmiColumn(
              text: '¥${item["price"]}',
              width: 12,
              style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT))
        ]);
      }
    }
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printRow(cols: [
      SunmiColumn(
          text: '小計',
          width: 10,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT)),
      SunmiColumn(
          text: "${getQuantity()}点",
          width: 9,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT)),
      SunmiColumn(
          text: '¥${getTotal()}',
          width: 14,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT))
    ]);
    await SunmiPrinter.printRow(cols: [
      SunmiColumn(
          text: '合計',
          width: 20,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT, bold: true)),
      SunmiColumn(
          text: '¥${getTotal()}',
          width: 14,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true))
    ]);
    await SunmiPrinter.lineWrap(2);
    if (order["type"] == "cash") {
      await SunmiPrinter.printRow(cols: [
        SunmiColumn(
            text: '現金',
            width: 20,
            style: SunmiTextStyle(align: SunmiPrintAlign.LEFT)),
        SunmiColumn(
            text: '¥${order["deposit"]}',
            width: 14,
            style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT))
      ]);
    } else {
      await SunmiPrinter.printRow(cols: [
        SunmiColumn(
            text: '電子決済',
            width: 20,
            style: SunmiTextStyle(align: SunmiPrintAlign.LEFT)),
        SunmiColumn(
            text: '¥${order["deposit"]}',
            width: 14,
            style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT))
      ]);
    }
    await SunmiPrinter.printRow(cols: [
      SunmiColumn(
          text: 'お釣り',
          width: 20,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT)),
      SunmiColumn(
          text: '¥${order["deposit"] - getTotal()}',
          width: 14,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT))
    ]);
    await SunmiPrinter.lineWrap(2);
    await SunmiPrinter.line();
    await SunmiPrinter.lineWrap(2);
    await SunmiPrinter.printBarCode(order["receiptId"],
        style: SunmiBarcodeStyle(
            height: 60, textPos: SunmiBarcodeTextPos.TEXT_UNDER));
    await SunmiPrinter.lineWrap(6);
    await SunmiPrinter.cutPaper();
    await database
        .currentOrderCollection()
        .update(currentOrderId, {"printed": true});
    processing = false;
  }

  @override
  void initState() {
    super.initState();
    getDeviceUniqueId();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
                child: StreamBuilder<QuerySnapshot>(
                    stream: database.currentOrderCollection().stream(),
                    builder: (context, snapshot) {
                      if (!processing) {
                        if (snapshot.hasData) {
                          final List<DocumentSnapshot> documents =
                              snapshot.data!.docs;
                          for (final DocumentSnapshot document in documents) {
                            Map<String, dynamic> data =
                                document.data() as Map<String, dynamic>;
                            if (data.containsKey("status") &&
                                data.containsKey("deviceId") &&
                                !data.containsKey("printed") &&
                                data["status"] == "complete" &&
                                data["deviceId"] == deviceId) {
                              currentOrderId = document.id;
                              order = data;
                              processing = true;
                              printReceipt();
                            }
                          }
                        }
                      }
                      return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.sensors, size: 100),
                            const Text('印刷待機中です'),
                            const SizedBox(height: 20),
                            ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: const Text('戻る'))
                          ]);
                    }))
          ]),
    ));
  }
}
