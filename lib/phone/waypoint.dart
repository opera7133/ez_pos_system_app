import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WayPoint extends StatefulWidget {
  final String deviceId;
  const WayPoint({Key? key, required this.deviceId}) : super(key: key);

  @override
  _WayPointState createState() => _WayPointState();
}

class _WayPointState extends State<WayPoint> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  List<dynamic> orders = [];
  String deviceId = "";
  String currentOrderId = "";
  bool processing = false;
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

  Future<void> getDeviceUniqueId() async {
    setState(() {
      deviceId = widget.deviceId;
    });
  }

  Future<void> updateOrder(num deposit) async {
    await firestore.collection('CURRENT_ORDER').doc(currentOrderId).update({
      'deposit': deposit,
    });
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
        await completePayment(getTotal(), transactionID);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Squareでの支払いに失敗しました'),
          ),
        );
        processing = false;
        updateOrder(0);
      }
    } on PlatformException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Squareでの支払いに失敗しました: ${e.message}'),
        ),
      );
      processing = false;
      updateOrder(0);
    }
  }

  String generateRandomString(int len) {
    var r = Random();
    const chars = '0123456789';
    return List.generate(len, (index) => chars[r.nextInt(chars.length)]).join();
  }

  Future<void> completePayment(num deposit, String transactionId) async {
    String barcode = generateRandomString(13);
    await firestore.collection("CURRENT_ORDER").doc(currentOrderId).update({
      'receiptId': barcode,
      "deposit": deposit,
      "amount": getTotal(),
      "type": "square",
      "orderedAt": FieldValue.serverTimestamp(),
      "status": "complete"
    });
    await firestore
        .collection("CURRENT_ORDER")
        .doc(currentOrderId)
        .update({"transactionId": transactionId});
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
        body: Padding(
      padding: const EdgeInsets.all(24),
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
                                data["status"] == "waitingSquare" &&
                                data["deviceId"] == deviceId) {
                              currentOrderId = document.id;
                              orders = data["items"];
                              _openSquareReaderPayment();
                              processing = true;
                            }
                          }
                        }
                      }
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }))
          ]),
    ));
  }
}
