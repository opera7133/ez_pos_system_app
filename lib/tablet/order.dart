import 'package:ez_pos_system_app/tablet/pairing.dart';
import 'package:ez_pos_system_app/tablet/settings.dart';
import 'package:ez_pos_system_app/utils/database.dart';
import 'package:ez_pos_system_app/utils/model.dart' as md;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ez_pos_system_app/tablet/payment.dart';
import 'package:ez_pos_system_app/tablet/wait.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class OrderPage extends StatefulWidget {
  const OrderPage({Key? key}) : super(key: key);

  @override
  _OrderState createState() => _OrderState();
}

class _OrderState extends State<OrderPage> {
  List<md.Item> items = [];
  List<Image> images = [];
  List<md.OrderItem> orders = [];
  final Database database = Database();
  final FirebaseStorage storage = FirebaseStorage.instance;
  final player = AudioPlayer();
  String currentOrderId = '';

  Future<void> getItems() async {
    setState(() {
      this.items = [];
      images = [];
    });
    final List<md.Item> items = await database.itemsCollection().all();
    for (final md.Item item in items) {
      Image img = await _downloadImage(item.thumbnail);
      setState(() {
        this.items.add(item);
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

  num getQuantity() {
    num quantity = 0;
    for (final md.OrderItem order in orders) {
      quantity += order.quantity;
    }
    return quantity;
  }

  num getTotal() {
    num total = 0;
    for (final md.OrderItem order in orders) {
      total += order.price * order.quantity;
    }
    return total;
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

  Future<void> addToOrder(int index) async {
    await displayLCD(items[index].name, items[index].price);
    if (orders.any((element) => element.itemId == items[index].itemId)) {
      final int orderIndex =
          orders.indexWhere((element) => element.itemId == items[index].itemId);
      setState(() {
        orders[orderIndex].quantity += 1;
      });
      await database.currentOrderCollection().update(
          currentOrderId, {'items': orders.map((e) => e.toMap()).toList()});
      return;
    }
    setState(() {
      orders.add(md.OrderItem(
        isdn: items[index].isdn,
        itemId: items[index].itemId,
        name: items[index].name,
        price: items[index].price,
        thumbnail: items[index].thumbnail,
        quantity: 1,
      ));
    });
    await database.currentOrderCollection().update(currentOrderId, {
      'items': orders.map((e) => e.toMap()).toList(),
    });
  }

  Future<void> updateOrder(int index, int quantity) async {
    setState(() {
      orders[index].quantity = quantity;
    });
    await database.currentOrderCollection().update(currentOrderId, {
      'items': orders.map((e) => e.toMap()).toList(),
    });
  }

  Future<void> deleteOrder(int index) async {
    setState(() {
      orders.removeAt(index);
    });
    await database.currentOrderCollection().update(currentOrderId, {
      'items': orders.map((e) => e.toMap()).toList(),
    });
    if (await getSettings(key: "enableLCD") ?? false) {
      await SunmiLcd.configLCD(status: SunmiLCDStatus.CLEAR);
    }
  }

  Future<void> getCurrentOrder() async {
    final List<md.Order?> currentOrder = await database
        .currentOrderCollection()
        .getByQuery({
      'type': 'isEqualTo',
      'field': 'deviceId',
      'value': await getDeviceUniqueId()
    });
    if (currentOrder.isNotEmpty) {
      setState(() {
        currentOrderId = currentOrder.first!.orderId!;
        orders = currentOrder.first!.items;
      });
    } else {
      final newDoc = database.currentOrderCollection().getId();

      await database.currentOrderCollection().set(newDoc, {
        'deviceId': await getDeviceUniqueId(),
        'items': [],
        'orderId': newDoc,
        'createdAt': FieldValue.serverTimestamp(),
      });
      setState(() {
        currentOrderId = newDoc;
      });
    }
  }

  Future<bool?> getSettings({String key = ""}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key);
  }

  Future<void> startLCD() async {
    await SunmiLcd.configLCD(status: SunmiLCDStatus.WAKE);
    await SunmiLcd.configLCD(status: SunmiLCDStatus.CLEAR);
  }

  Future<void> displayLCD(String itemName, num price) async {
    if (!(await getSettings(key: "enableLCD") ?? false)) {
      return;
    }
    await SunmiLcd.lcdString("$itemName\n$price円", size: 12, fill: false);
  }

  @override
  void initState() {
    super.initState();
    getItems();
    getCurrentOrder();
    getSettings(key: "enableLCD").then((value) {
      if (value ?? false) {
        startLCD();
      }
    });
  }

  @override
  void dispose() {
    player.dispose();
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
                      elevation: 0,
                      shape: BeveledRectangleBorder(
                        side: BorderSide(
                          color: Colors.black,
                          width: 2.0,
                        ),
                      ),
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
                                items[index].thumbnail != ''
                                    ? Expanded(child: images[index])
                                    : Container(),
                                const SizedBox(height: 10),
                                Text(
                                  items[index].name,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "${items[index].price.toString()}円",
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
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
                          title: Text(orders[index].name),
                          subtitle: Text(
                              '${orders[index].price} x ${orders[index].quantity} = ${orders[index].price * orders[index].quantity}'),
                          trailing: SizedBox(
                              width: 150,
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    onPressed: () {
                                      if (orders[index].quantity > 1) {
                                        updateOrder(
                                            index, orders[index].quantity - 1);
                                      } else {
                                        deleteOrder(index);
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () {
                                      updateOrder(
                                          index, orders[index].quantity + 1);
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
                    style: const TextStyle(
                        fontSize: 25, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "合計　${getTotal()}円",
                    style: const TextStyle(
                        fontSize: 25, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 50),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(0), // 任意の角丸さを指定
                        ),
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
                      child: const Text('会計',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () {
                              getItems();
                            },
                            tooltip: "商品を更新"),
                        IconButton(
                            icon: const Icon(Icons.smartphone),
                            onPressed: () {
                              Navigator.push((context),
                                  MaterialPageRoute(builder: (context) {
                                return PairingPage();
                              }));
                            },
                            tooltip: "ペアリング"),
                        IconButton(
                            icon: const Icon(Icons.receipt),
                            onPressed: () {
                              Navigator.push((context),
                                  MaterialPageRoute(builder: (context) {
                                return WaitScreen();
                              }));
                            },
                            tooltip: "順番受付"),
                        IconButton(
                            icon: const Icon(Icons.settings),
                            onPressed: () {
                              Navigator.push((context),
                                  MaterialPageRoute(builder: (context) {
                                return SettingsPage();
                              }));
                            },
                            tooltip: "設定"),
                      ])
                ],
              ),
            )),
      ],
    ));
  }
}
