import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ez_pos_system_app/utils/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WayPoint extends StatefulWidget {
  final String deviceId;
  const WayPoint({Key? key, required this.deviceId}) : super(key: key);

  @override
  _WayPointState createState() => _WayPointState();
}

class _WayPointState extends State<WayPoint> {
  final Database database = Database();
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
    await database.currentOrderCollection().update(currentOrderId, {
      'deposit': deposit,
    });
  }

  Future<void> stopOrder() async {
    await database.currentOrderCollection().update(currentOrderId, {
      'status': 'canceled',
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
        await stopOrder();
        processing = false;
        await updateOrder(0);
      }
    } on PlatformException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Squareでの支払いに失敗しました: ${e.message}'),
        ),
      );
      await stopOrder();
      processing = false;
      await updateOrder(0);
    }
  }

  String generateRandomString(int len) {
    var r = Random();
    const chars = '0123456789';
    return List.generate(len, (index) => chars[r.nextInt(chars.length)]).join();
  }

  Future<void> completePayment(num deposit, String transactionId) async {
    String barcode = generateRandomString(13);
    await database.currentOrderCollection().update(currentOrderId, {
      'receiptId': barcode,
      "deposit": deposit,
      "amount": getTotal(),
      "type": "square",
      "orderedAt": FieldValue.serverTimestamp(),
      "status": "complete"
    });
    await database
        .currentOrderCollection()
        .update(currentOrderId, {"transactionId": transactionId});
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
                      return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.sensors, size: 100),
                            const Text('Squareでの支払いを待機中です'),
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
