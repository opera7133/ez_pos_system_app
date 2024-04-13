# EZ POS SYSTEM APP

簡易的なPOSアプリ。

カスタマーディスプレイ：[EZ POS SYSTEM WEB](https://github.com/opera7133/ez_pos_system_web)

レシートプリンター（USB）：[EZ POS SYSTEM PRINT](https://github.com/opera7133/ez_pos_system_print)

## 機能

- Squareアプリでの決済
- レシート印刷
- 複数デバイスでの会計

## 対応環境

- Android
- iOS（未検証）

> [!NOTE]
> レシートプリンターはSUNMI端末のみサポートしています。

## ビルド

0. flutterfireを入れる
1. Firebaseの設定

```shell
flutterfire configure
```

2. `.env`の設定

3. 依存関係の追加

```shell
flutter pub get
```

4. ビルド

```shell
flutter build apk
```

> [!NOTE]
> 商品はFirebaseコンソールのCloud Firestoreから**手動で**登録してください。
> FireCMSなどのFirebase向けHeadless CMSを使用すると便利です。

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
  printed: Boolean
  receiptId: String
  status: "waitingSquare" | "complete"
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
  printed?: Boolean
  receiptId?: String
  status?: "waitingSquare" | "complete"
  type?: "cash" | "square"
}
```
