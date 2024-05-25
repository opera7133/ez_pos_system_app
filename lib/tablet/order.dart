import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:ez_pos_system_app/tablet/settings.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ez_pos_system_app/tablet/payment.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({Key? key}) : super(key: key);

  @override
  _OrderState createState() => _OrderState();
}

class _OrderState extends State<OrderPage> {
  String kuttLink = '';
  List<Map<String, dynamic>> items = [];
  List<Image> images = [];
  List<Map<String, dynamic>> orders = [];
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;
  final player = AudioPlayer();
  String currentOrderId = '';
  Future<String> _deviceId = Future.value('');
  MobileScannerController controller = MobileScannerController(
      facing: CameraFacing.back,
      detectionTimeoutMs: 1500,
      detectionSpeed: DetectionSpeed.normal);

  Future<void> getItems() async {
    setState(() {
      this.items = [];
      images = [];
    });
    final QuerySnapshot<Map<String, dynamic>> items =
        await firestore.collection('ITEMS').get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> item in items.docs) {
      Image img = await _downloadImage(item.data()['thumbnail']);
      setState(() {
        this.items.add(item.data());
        images.add(img);
      });
    }
  }

  Future<Image> _downloadImage(String url) async {
    final Reference ref = storage.ref().child(url);
    final String path = await ref.getDownloadURL();
    final img = Image(image: CachedNetworkImageProvider(path));
    return img;
  }

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

  Future<void> addToOrder(int index) async {
    await displayLCD(items[index]['name'], items[index]['price']);
    if (orders.any((element) => element['itemId'] == items[index]['itemId'])) {
      final int orderIndex = orders
          .indexWhere((element) => element['itemId'] == items[index]['itemId']);
      setState(() {
        orders[orderIndex]['quantity'] += 1;
      });
      await firestore
          .collection('CURRENT_ORDER')
          .doc(currentOrderId)
          .update({'items': orders});
      return;
    }
    setState(() {
      orders.add({
        ...items[index],
        'quantity': 1,
      });
    });
    await firestore.collection('CURRENT_ORDER').doc(currentOrderId).update({
      'items': orders,
    });
  }

  Future<void> updateOrder(int index, int quantity) async {
    setState(() {
      orders[index]['quantity'] = quantity;
    });
    await firestore.collection('CURRENT_ORDER').doc(currentOrderId).update({
      'items': orders,
    });
  }

  Future<void> deleteOrder(int index) async {
    setState(() {
      orders.removeAt(index);
    });
    await firestore.collection('CURRENT_ORDER').doc(currentOrderId).update({
      'items': orders,
    });
    await SunmiPrinter.lcdClear();
  }

  Future<void> getCurrentOrder() async {
    final QuerySnapshot<Map<String, dynamic>> currentOrder = await firestore
        .collection('CURRENT_ORDER')
        .where("deviceId", isEqualTo: await getDeviceUniqueId())
        .get();
    if (currentOrder.docs.isNotEmpty) {
      List<Map<String, dynamic>> order =
          List<Map<String, dynamic>>.from(currentOrder.docs.first['items']);
      setState(() {
        currentOrderId = currentOrder.docs.first.id;
        orders = order;
      });
    } else {
      final newDoc = firestore.collection('CURRENT_ORDER').doc();

      await newDoc.set({
        'deviceId': await getDeviceUniqueId(),
        'items': [],
        'orderId': newDoc.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
      setState(() {
        currentOrderId = newDoc.id;
      });
    }
  }

  Future<void> resumeCamera() async {
    await controller.stop().whenComplete(() => controller.start());
  }

  Future<void> createShortenLink() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    Uri url = Uri.parse("https://${dotenv.env["KUTT_DOMAIN"]}/api/v2/links");
    Map<String, String> headers = {
      "X-API-KEY": dotenv.env["KUTT_APIKEY"]!,
      "Content-Type": "application/json"
    };
    String body = jsonEncode({
      'target':
          "https://${dotenv.env["EZ_POS_WEB_DOMAIN"]}/?color=black&deviceId=${await getDeviceUniqueId()}",
      'expire_in': "10 hours",
    });
    http.Response response = await http.post(url, headers: headers, body: body);
    if (response.statusCode == 201) {
      Map<String, dynamic> data = jsonDecode(response.body);
      prefs.setString("kuttLink", data['link']);
      setState(() {
        kuttLink = data['link'];
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('短縮URLを作成できませんでした'),
        ),
      );
    }
  }

  Future<void> getShortenLink() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? kuttLink = prefs.getString("kuttLink");
    if (kuttLink == null) {
      createShortenLink();
    } else {
      setState(() {
        this.kuttLink = kuttLink;
      });
    }
  }

  Future<bool?> getSettings({String key = ""}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key);
  }

  Future<void> startLCD() async {
    await SunmiPrinter.bindingPrinter();
    await SunmiPrinter.lcdInitialize();
    await SunmiPrinter.lcdWakeup();
    await SunmiPrinter.lcdClear();
  }

  Future<void> displayLCD(String itemName, num price) async {
    await SunmiPrinter.lcdDoubleString(itemName, "$price円");
  }

  @override
  void initState() {
    super.initState();
    resumeCamera();
    _deviceId = getDeviceUniqueId();
    getItems();
    getCurrentOrder();
    getShortenLink();
    getSettings(key: "enableLCD").then((value) {
      if (value ?? false) {
        startLCD();
      }
    });
  }

  @override
  void dispose() {
    player.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Row(
      children: [
        Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: GridView.count(
                crossAxisCount: 3,
                children: List.generate(items.length, (int index) {
                  return Card(
                      clipBehavior: Clip.hardEdge,
                      child: InkWell(
                        onTap: () {
                          addToOrder(index);
                        },
                        child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                items[index].containsKey("thumbnail") &&
                                        items[index]['thumbnail'] != ''
                                    ? Expanded(child: images[index])
                                    : Container(),
                                Text(
                                  items[index]['name'],
                                  style: const TextStyle(fontSize: 16),
                                ),
                                Text(
                                  "${items[index]['price'].toString()}円",
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            )),
                      ));
                }),
              ),
            )),
        Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: orders.length,
                      itemBuilder: (BuildContext context, int index) {
                        return ListTile(
                          title: Text(orders[index]['name']),
                          subtitle: Text(
                              '${orders[index]['price']} x ${orders[index]['quantity']} = ${orders[index]['price'] * orders[index]['quantity']}'),
                          trailing: SizedBox(
                              width: 150,
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    onPressed: () {
                                      if (orders[index]['quantity'] > 1) {
                                        updateOrder(index,
                                            orders[index]['quantity'] - 1);
                                      } else {
                                        deleteOrder(index);
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () {
                                      updateOrder(
                                          index, orders[index]['quantity'] + 1);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () {
                                      deleteOrder(index);
                                    },
                                  )
                                ],
                              )),
                        );
                      },
                    ),
                  ),
                  Text(
                    "点数　${getQuantity()}点",
                    style: const TextStyle(fontSize: 25),
                  ),
                  Text(
                    "合計　${getTotal()}円",
                    style: const TextStyle(fontSize: 25),
                  ),
                  const SizedBox(height: 50),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        if (orders.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Payment(
                                  orders: orders,
                                  currentOrderId: currentOrderId),
                            ),
                          );
                        }
                      },
                      child: const Text('会計', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(height: 30),
                  FutureBuilder<String>(
                    future: _deviceId,
                    builder:
                        (BuildContext context, AsyncSnapshot<String> snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: () {
                                    getItems();
                                  },
                                  tooltip: "商品を更新"),
                              QrImageView(
                                data: snapshot.data!,
                                version: QrVersions.auto,
                                size: 100.0,
                              ),
                              IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: () {
                                    createShortenLink();
                                  },
                                  tooltip: "URLを更新"),
                              QrImageView(
                                data: kuttLink,
                                version: QrVersions.auto,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Colors.blue,
                                ),
                                size: 100.0,
                              ),
                              IconButton(
                                  icon: const Icon(Icons.settings),
                                  onPressed: () {
                                    Navigator.push((context),
                                        MaterialPageRoute(builder: (context) {
                                      return SettingsPage();
                                    }));
                                  },
                                  tooltip: "設定"),
                            ]);
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Text("Loading device info...");
                      }
                      return const Icon(Icons.error);
                    },
                  ),
                ],
              ),
            )),
      ],
    ));
  }
}
