import 'package:ez_pos_system_app/tablet/result.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Waiting extends StatefulWidget {
  final String currentOrderId;
  const Waiting({Key? key, required this.currentOrderId}) : super(key: key);

  @override
  _WaitingState createState() => _WaitingState();
}

class _WaitingState extends State<Waiting> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  String currentOrderId = "";
  bool processing = false;

  Future<void> cancelPayment() async {
    await firestore
        .collection("CURRENT_ORDER")
        .doc(currentOrderId)
        .update({"status": FieldValue.delete()});
    Navigator.pop(context);
  }

  Future<void> completePayment() async {
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
            builder: (context) => ResultPage(
                  currentOrderId: currentOrderId,
                )));
  }

  @override
  void initState() {
    super.initState();
    currentOrderId = widget.currentOrderId;
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
                child: StreamBuilder<DocumentSnapshot>(
                    stream: firestore
                        .collection("CURRENT_ORDER")
                        .doc(currentOrderId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final document =
                            snapshot.data!.data() as Map<String, dynamic>;
                        if (document.containsKey("status") &&
                            document["status"] == "complete") {
                          completePayment();
                        }
                      }
                      return const Center(child: CircularProgressIndicator());
                    })),
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
