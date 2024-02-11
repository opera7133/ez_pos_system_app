# EZ POS SYSTEM APP

簡易的なPOSアプリ。

カスタマーディスプレイ：[EZ POS SYSTEM WEB](https://github.com/opera7133/ez_pos_system_web)

レシートプリンター：[EZ POS SYSTEM PRINT](https://github.com/opera7133/ez_pos_system_print)

## 対応環境

Android

## ビルド

0. flutterfireを入れる
1. Firebaseの設定

```shell
flutterfire configure
```

2. 依存関係の追加

```shell
flutter pub get
```

3. ビルド

```shell
flutter build apk
```

## 利用サービス

- Firebase
  - Cloud Firestore
  - Firebase Storage
  - Firebase Hosting (-> EZ POS SYSTEM WEB)
- Square

## Firestore 構造

```plain
/ITEMS/{itemId}
{
  isdn?: String
  itemId: String
  name: String
  price: Number
  thumbnail?: String
}

/ORDERS/{orderId}
{
  amount: Number
  createdAt: Timestamp
  deposit: Number
  deviceId: String
  items: {
    isdn?: String
    itemId: String
    name: String
    price: Number
    quantity: Number
    thumbnail?: String
  }[]
  orderedAt: Timestamp
  orderId: String
  receiptId: String
  type: "cash" | "square"
}

/CURRENT_ORDER/{currentOrderId}
{
  amount?: Number
  createdAt: Timestamp
  deposit?: Number
  deviceId: String
  items: {
    isdn?: String
    itemId: String
    name: String
    price: Number
    quantity: Number
    thumbnail?: String
  }[]
  orderedAt?: Timestamp
  orderId: String
  receiptId?: String
  type?: "cash" | "square"
}
```
