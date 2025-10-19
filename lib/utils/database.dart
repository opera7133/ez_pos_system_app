import 'package:cloud_firestore/cloud_firestore.dart';
import 'model.dart' as md;
import 'dart:math';

class BaseCollection {
  final String ref;
  final FirebaseFirestore firestore;

  BaseCollection(this.ref, this.firestore);

  CollectionReference<Map<String, dynamic>> get collection {
    return firestore.collection(ref);
  }

  String getId() {
    return collection.doc().id;
  }

  Future<DocumentReference<Map<String, dynamic>>> add(
      Map<String, dynamic> data) {
    return collection.add(data);
  }

  Map<String, dynamic> getDataFromDocumentData(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data["id"] = doc.id;
    return data;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> stream() {
    return collection.snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamById(String id) {
    return collection.doc(id).snapshots();
  }

  Future<void> set(String id, Map<String, dynamic> data) {
    return collection.doc(id).set(data);
  }

  Future<void> update(String id, Map<String, dynamic> data) {
    return collection.doc(id).update(data);
  }

  Future<void> delete(String id) {
    return collection.doc(id).delete();
  }

  Future<dynamic> findById(String id) {
    return collection.doc(id).get().then((doc) {
      if (doc.exists) {
        return getDataFromDocumentData(doc);
      } else {
        return {};
      }
    });
  }

  Future<List<dynamic>> all() async {
    final snapshot = await collection.get();
    return snapshot.docs.map((doc) {
      return getDataFromDocumentData(doc);
    }).toList();
  }

  Future<List<dynamic>> getByOrder(String field, bool descending) async {
    Query<Map<String, dynamic>> ref = collection;
    ref = ref.orderBy(field, descending: descending);
    final snapshot = await ref.get();
    return snapshot.docs.map((doc) {
      return getDataFromDocumentData(doc);
    }).toList();
  }

  Future<List<dynamic>> getByQuery(Map<String, dynamic> query) async {
    Query<Map<String, dynamic>> ref = collection;
    switch (query['type']) {
      case 'isEqualTo':
        ref = ref.where(query['field'], isEqualTo: query['value']);
        break;
      case 'isNotEqualTo':
        ref = ref.where(query['field'], isNotEqualTo: query['value']);
        break;
      case 'isGreaterThan':
        ref = ref.where(query['field'], isGreaterThan: query['value']);
        break;
      case 'isGreaterThanOrEqualTo':
        ref = ref.where(query['field'], isGreaterThanOrEqualTo: query['value']);
        break;
      case 'isLessThan':
        ref = ref.where(query['field'], isLessThan: query['value']);
        break;
      case 'isLessThanOrEqualTo':
        ref = ref.where(query['field'], isLessThanOrEqualTo: query['value']);
        break;
      case 'arrayContains':
        ref = ref.where(query['field'], arrayContains: query['value']);
        break;
      case 'arrayContainsAny':
        ref = ref.where(query['field'], arrayContainsAny: query['value']);
        break;
      case 'whereIn':
        ref = ref.where(query['field'], whereIn: query['value']);
        break;
      case 'whereNotIn':
        ref = ref.where(query['field'], whereNotIn: query['value']);
        break;
      case 'isNull':
        ref = ref.where(query['field'], isNull: query['value']);
        break;
      default:
        break;
    }
    final snapshot = await ref.get();
    return snapshot.docs.map((doc) {
      return getDataFromDocumentData(doc);
    }).toList();
  }

  Future<dynamic> getRandomDoc(String? attribute) async {
    List<dynamic> allData = [];
    if (attribute != null && attribute.isNotEmpty) {
      allData = await getByQuery(
          {'type': 'isEqualTo', 'field': 'attribute', 'value': attribute});
    } else {
      allData = await all();
    }
    int length = allData.length;
    int rand = Random().nextInt(length);
    return allData[rand];
  }
}

class CurrentOrderCollection extends BaseCollection {
  CurrentOrderCollection(FirebaseFirestore firestore)
      : super('CURRENT_ORDER', firestore);

  Future<md.Order?> findByDeviceId(String deviceId) async {
    final snapshot =
        await collection.where('deviceId', isEqualTo: deviceId).limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      final data = getDataFromDocumentData(snapshot.docs.first);
      return md.Order.fromMap(data);
    } else {
      return null;
    }
  }

  @override
  Future<md.Order?> findById(String id) async {
    final doc = await collection.doc(id).get();
    if (doc.exists) {
      final data = getDataFromDocumentData(doc);
      return md.Order.fromMap(data);
    } else {
      return null;
    }
  }

  @override
  Future<List<md.Order?>> getByQuery(Map<String, dynamic> query) async {
    final results = await super.getByQuery(query);
    return results.map((data) => md.Order.fromMap(data)).toList();
  }
}

class OrdersCollection extends BaseCollection {
  OrdersCollection(FirebaseFirestore firestore) : super('ORDERS', firestore);
}

class ItemsCollection extends BaseCollection {
  ItemsCollection(FirebaseFirestore firestore) : super('ITEMS', firestore);

  @override
  Future<md.Item?> findById(String id) async {
    final doc = await collection.doc(id).get();
    if (doc.exists) {
      final data = getDataFromDocumentData(doc);
      return md.Item.fromMap(data);
    } else {
      return null;
    }
  }

  @override
  Future<List<md.Item>> all() async {
    final snapshot = await collection.get();
    return snapshot.docs.map((doc) {
      final data = getDataFromDocumentData(doc);
      return md.Item.fromMap(data);
    }).toList();
  }
}

class QueuesCollection extends BaseCollection {
  QueuesCollection(FirebaseFirestore firestore) : super('QUEUES', firestore);

  Future<int> getNextQueueNumber() async {
    final snapshot =
        await collection.orderBy('number', descending: true).limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      final data = getDataFromDocumentData(snapshot.docs.first);
      return (data['number'] ?? 0) + 1;
    } else {
      return 1;
    }
  }
}

class Database {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  CurrentOrderCollection currentOrderCollection() {
    return CurrentOrderCollection(firestore);
  }

  OrdersCollection ordersCollection() {
    return OrdersCollection(firestore);
  }

  ItemsCollection itemsCollection() {
    return ItemsCollection(firestore);
  }

  QueuesCollection queuesCollection() {
    return QueuesCollection(firestore);
  }
}
