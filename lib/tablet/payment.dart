import 'dart:math';

import 'package:ez_pos_system_app/tablet/waiting.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/svg.dart';
import 'package:ez_pos_system_app/tablet/result.dart';
import 'package:flutter/services.dart';

class Payment extends StatefulWidget {
  final String currentOrderId;
  final List<Map<String, dynamic>> orders;
  const Payment({Key? key, required this.orders, required this.currentOrderId})
      : super(key: key);

  @override
  _PaymentState createState() => _PaymentState();
}

class _PaymentState extends State<Payment> {
  List<Map<String, dynamic>> orders = [];
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  String currentOrderId = '';
  num deposit = 0;
  String? depositError;
  static const squareChannel = MethodChannel('ezpos/square');

  num getQuantity() {
    num quantity = 0;
    for (final Map<String, dynamic> order in orders) {
      quantity += order['quantity'];
    }
    return quantity;
  }

  num getTotal() {
    num total = 0;
    for (final Map<String, dynamic> order in orders) {
      total += order['price'] * order['quantity'];
    }
    return total;
  }

  String generateRandomString(int len) {
    var r = Random();
    const chars = '0123456789';
    return List.generate(len, (index) => chars[r.nextInt(chars.length)]).join();
  }

  Future<void> openTerminal() async {
    await firestore
        .collection("CURRENT_ORDER")
        .doc(currentOrderId)
        .update({"status": "waitingSquare"});
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => Waiting(currentOrderId: currentOrderId)));
  }

  Future<void> _openSquareReaderPayment() async {
    await updateOrder(getTotal());
    final arguments = <String, dynamic>{
      'price': getTotal(),
      'memo': 'EZ POS SYSTEM / $currentOrderId',
    };
    try {
      final transactionID =
          await squareChannel.invokeMethod<String?>('openSquare', arguments);
      if (transactionID != null) {
        await completePayment(getTotal(), "square", transactionID);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Squareでの支払いに失敗しました'),
          ),
        );
      }
    } on PlatformException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Squareでの支払いに失敗しました: ${e.message}'),
        ),
      );
    }
  }

  Future<void> completePayment(
      num deposit, String type, String transactionId) async {
    String barcode = generateRandomString(13);
    await firestore.collection("CURRENT_ORDER").doc(currentOrderId).update({
      'receiptId': barcode,
      "deposit": deposit,
      "amount": getTotal(),
      "type": type,
      "orderedAt": FieldValue.serverTimestamp(),
    });
    if (type == "square") {
      await firestore
          .collection("CURRENT_ORDER")
          .doc(currentOrderId)
          .update({"transactionId": transactionId});
    }
    // move to ORDERS from CURRENT_ORDER
    await firestore
        .collection("CURRENT_ORDER")
        .doc(currentOrderId)
        .get()
        .then((DocumentSnapshot documentSnapshot) async {
      if (documentSnapshot.exists) {
        await firestore
            .collection("ORDERS")
            .add(documentSnapshot.data() as Map<String, dynamic>);
      }
    });
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => Result(
                  currentOrderId: currentOrderId,
                )));
  }

  Future<void> updateOrder(num deposit) async {
    await firestore.collection('CURRENT_ORDER').doc(currentOrderId).update({
      'deposit': deposit,
    });
  }

  Future<void> cancelPayment() async {
    await updateOrder(0);
    Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    orders = widget.orders;
    currentOrderId = widget.currentOrderId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: false,
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                    width: MediaQuery.of(context).size.width * 0.4,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("合計", style: TextStyle(fontSize: 24)),
                            Text("${getTotal().toString()}円",
                                style: TextStyle(fontSize: 24)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("点数", style: TextStyle(fontSize: 24)),
                            Text("${getQuantity().toString()}点",
                                style: TextStyle(fontSize: 24)),
                          ],
                        )
                      ],
                    )),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("現金", style: TextStyle(fontSize: 24)),
                              const SizedBox(height: 40),
                              TextField(
                                decoration: InputDecoration(
                                    border: const OutlineInputBorder(),
                                    labelText: "金額",
                                    errorText: depositError,
                                    suffixText: "円"),
                                keyboardType: TextInputType.number,
                                onChanged: (String value) {
                                  if (value == "") {
                                    setState(() {
                                      depositError = "金額を入力してください";
                                    });
                                    return;
                                  } else if (num.parse(value) < getTotal()) {
                                    updateOrder(num.parse(value));
                                    setState(() {
                                      depositError = "金額が足りません";
                                    });
                                    return;
                                  } else {
                                    updateOrder(num.parse(value));
                                    setState(() {
                                      depositError = null;
                                    });
                                  }
                                  setState(() {
                                    deposit = num.parse(value);
                                  });
                                },
                              ),
                              const SizedBox(height: 40),
                              SizedBox(
                                height: 60,
                                width: double.infinity,
                                child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      if (depositError != null) {
                                        return;
                                      }
                                      completePayment(deposit, "cash", "");
                                    },
                                    child: const Text("支払い",
                                        style: TextStyle(fontSize: 20))),
                              )
                            ],
                          )),
                    ),
                    Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                onPressed: () {
                                  //_openSquareReaderPayment();
                                  openTerminal();
                                },
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 60, horizontal: 30),
                                    child: SvgPicture.asset(
                                      "assets/square.svg",
                                      semanticsLabel: "Squareでお支払い",
                                      width: 150,
                                      height: 150,
                                      theme: const SvgTheme(
                                          currentColor: Colors.black),
                                    ))),
                          ),
                        ))
                  ],
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.4,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("戻る", style: TextStyle(fontSize: 20)),
                    onPressed: () {
                      cancelPayment();
                    },
                  ),
                )
              ]),
        ));
  }
}
