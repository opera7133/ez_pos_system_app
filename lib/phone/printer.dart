import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:sunmi_printer_plus/column_maker.dart';
import 'package:sunmi_printer_plus/enums.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'package:sunmi_printer_plus/sunmi_style.dart';

class Printer extends StatefulWidget {
  final String deviceId;
  const Printer({Key? key, required this.deviceId}) : super(key: key);

  @override
  _PrinterState createState() => _PrinterState();
}

class _PrinterState extends State<Printer> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
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
    await SunmiPrinter.initPrinter();
    await SunmiPrinter.startTransactionPrint();
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.lineWrap(2);
    await SunmiPrinter.printText('電通部',
        style: SunmiStyle(fontSize: SunmiFontSize.LG));
    await SunmiPrinter.printText('東京都品川区東大井1-10-40');
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printText(formatter.format(DateTime.now()));
    await SunmiPrinter.printText('ID: ${order["deviceId"]}');
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.printText("領 収 書");
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.line();
    await SunmiPrinter.lineWrap(1);
    for (final Map<String, dynamic> item in order["items"]) {
      if (item["quantity"] > 1) {
        await SunmiPrinter.printText(item["name"]);
        await SunmiPrinter.printRow(cols: [
          ColumnMaker(text: '', width: 2, align: SunmiPrintAlign.LEFT),
          ColumnMaker(
              text: '¥${item["price"]}',
              width: 12,
              align: SunmiPrintAlign.LEFT),
          ColumnMaker(
              text: '${item["quantity"]}点',
              width: 7,
              align: SunmiPrintAlign.LEFT),
          ColumnMaker(
              text: '¥${item["price"] * item["quantity"]}',
              width: 12,
              align: SunmiPrintAlign.RIGHT)
        ]);
      } else {
        await SunmiPrinter.printRow(cols: [
          ColumnMaker(
              text: item["name"], width: 22, align: SunmiPrintAlign.LEFT),
          ColumnMaker(
              text: '¥${item["price"]}',
              width: 12,
              align: SunmiPrintAlign.RIGHT)
        ]);
      }
    }
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printRow(cols: [
      ColumnMaker(text: '小計', width: 10, align: SunmiPrintAlign.LEFT),
      ColumnMaker(
          text: "${getQuantity()}点", width: 9, align: SunmiPrintAlign.LEFT),
      ColumnMaker(
          text: '¥${getTotal()}', width: 14, align: SunmiPrintAlign.RIGHT)
    ]);
    await SunmiPrinter.bold();
    await SunmiPrinter.printRow(cols: [
      ColumnMaker(text: '合計', width: 20, align: SunmiPrintAlign.LEFT),
      ColumnMaker(
          text: '¥${getTotal()}', width: 14, align: SunmiPrintAlign.RIGHT)
    ]);
    await SunmiPrinter.resetBold();
    await SunmiPrinter.lineWrap(1);
    if (order["type"] == "cash") {
      await SunmiPrinter.printRow(cols: [
        ColumnMaker(text: '現金', width: 20, align: SunmiPrintAlign.LEFT),
        ColumnMaker(
            text: '¥${order["deposit"]}',
            width: 14,
            align: SunmiPrintAlign.RIGHT)
      ]);
    } else {
      await SunmiPrinter.printRow(cols: [
        ColumnMaker(text: '電子決済', width: 20, align: SunmiPrintAlign.LEFT),
        ColumnMaker(
            text: '¥${order["deposit"]}',
            width: 14,
            align: SunmiPrintAlign.RIGHT)
      ]);
    }
    await SunmiPrinter.printRow(cols: [
      ColumnMaker(text: 'お釣り', width: 20, align: SunmiPrintAlign.LEFT),
      ColumnMaker(
          text: '¥${order["deposit"] - getTotal()}',
          width: 14,
          align: SunmiPrintAlign.RIGHT)
    ]);
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.line();
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.printBarCode(
      order["receiptId"],
      height: 60,
      textPosition: SunmiBarcodeTextPos.TEXT_UNDER,
    );
    await SunmiPrinter.lineWrap(4);
    await SunmiPrinter.submitTransactionPrint();
    await SunmiPrinter.exitTransactionPrint();
    await firestore
        .collection("CURRENT_ORDER")
        .doc(currentOrderId)
        .update({"printed": true});
    processing = false;
  }

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
    getDeviceUniqueId();
    bindPrinter();
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
                    stream: firestore.collection("CURRENT_ORDER").snapshots(),
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
