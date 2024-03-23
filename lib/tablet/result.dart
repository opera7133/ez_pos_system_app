import 'package:flutter/material.dart';
import 'package:ez_pos_system_app/tablet/order.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Result extends StatelessWidget {
  final String? transactionId;
  final String? currentOrderId;
  const Result({Key? key, this.transactionId, this.currentOrderId})
      : super(key: key);

  Future<void> completeOrder() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    await firestore.collection('CURRENT_ORDER').doc(currentOrderId).delete();
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
