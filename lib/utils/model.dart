import 'package:cloud_firestore/cloud_firestore.dart';

class Item {
  final String? isdn;
  final String itemId;
  final String name;
  final int price;
  final String thumbnail;

  Item(
      {this.isdn,
      required this.itemId,
      required this.name,
      required this.price,
      required this.thumbnail});
  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      isdn: map['isdn'],
      itemId: map['itemId'] ?? "",
      name: map['name'] ?? "",
      price: map['price'] ?? 0,
      thumbnail: map['thumbnail'] ?? "",
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isdn': isdn,
      'itemId': itemId,
      'name': name,
      'price': price,
      'thumbnail': thumbnail,
    };
  }
}

class OrderItem extends Item {
  int quantity;

  OrderItem(
      {super.isdn,
      required super.itemId,
      required super.name,
      required super.price,
      required super.thumbnail,
      required this.quantity});

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map['quantity'] = quantity;
    return map;
  }
}

class Order {
  final int? amount;
  final DateTime createdAt;
  final int? deposit;
  final String deviceId;
  final String? orderId;
  final DateTime? orderedAt;
  final List<OrderItem> items;
  final String? receiptId;
  final String? status;
  final String? type;
  final String? transactionId;
  final bool? printed;

  Order(
      {this.amount,
      required this.createdAt,
      this.deposit,
      required this.deviceId,
      required this.items,
      this.orderId,
      this.orderedAt,
      this.receiptId,
      this.status,
      this.type,
      this.printed,
      this.transactionId});

  factory Order.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Order(
      amount: data['amount'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      deposit: data['deposit'],
      deviceId: data['deviceId'],
      items: (data['items'] as List<dynamic>)
          .map((item) => OrderItem(
                isdn: item['isdn'],
                itemId: item['itemId'] ?? "",
                name: item['name'] ?? "",
                price: item['price'] ?? 0,
                thumbnail: item['thumbnail'] ?? "",
                quantity: item['quantity'] ?? 0,
              ))
          .toList(),
      orderId: data['orderId'],
      orderedAt: (data['orderedAt'] as Timestamp).toDate(),
      printed: data['printed'],
      receiptId: data['receiptId'],
      status: data['status'],
      type: data['type'],
      transactionId: data['transactionId'],
    );
  }

  factory Order.fromMap(Map<String, dynamic> data) {
    return Order(
      amount: data['amount'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      deposit: data['deposit'],
      deviceId: data['deviceId'],
      items: (data['items'] as List<dynamic>)
          .map((item) => OrderItem(
                isdn: item['isdn'],
                itemId: item['itemId'] ?? "",
                name: item['name'] ?? "",
                price: item['price'] ?? 0,
                thumbnail: item['thumbnail'] ?? "",
                quantity: item['quantity'] ?? 0,
              ))
          .toList(),
      orderId: data['orderId'],
      orderedAt: data['orderedAt'] != null
          ? (data['orderedAt'] as Timestamp).toDate()
          : null,
      printed: data['printed'],
      receiptId: data['receiptId'],
      status: data['status'],
      type: data['type'],
      transactionId: data['transactionId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'createdAt': Timestamp.fromDate(createdAt),
      'deposit': deposit,
      'deviceId': deviceId,
      'items': items
          .map((item) => {
                'isdn': item.isdn,
                'itemId': item.itemId,
                'name': item.name,
                'price': item.price,
                'thumbnail': item.thumbnail,
                'quantity': item.quantity,
              })
          .toList(),
      'orderId': orderId,
      'orderedAt': orderedAt != null ? Timestamp.fromDate(orderedAt!) : null,
      'printed': printed,
      'receiptId': receiptId,
      'status': status,
      'type': type,
      'transactionId': transactionId,
    };
  }
}

class Queue {
  final String queueId;
  final DateTime createdAt;
  DateTime? calledAt;
  bool called;
  final int number;
  final String? lineNotifyId;

  Queue(
      {required this.queueId,
      required this.createdAt,
      this.calledAt,
      this.called = false,
      this.lineNotifyId,
      required this.number});

  factory Queue.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Queue(
      queueId: data['queueId'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      calledAt: data['calledAt'] != null
          ? (data['calledAt'] as Timestamp).toDate()
          : null,
      called: data['called'] ?? false,
      number: data['number'] ?? 0,
      lineNotifyId: data['lineNotifyId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'queueId': queueId,
      'createdAt': Timestamp.fromDate(createdAt),
      'calledAt': calledAt != null ? Timestamp.fromDate(calledAt!) : null,
      'number': number,
      'called': called,
      'lineNotifyId': lineNotifyId,
    };
  }
}
