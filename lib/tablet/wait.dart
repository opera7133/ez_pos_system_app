import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sunmi_printer_plus/enums.dart';
import 'package:sunmi_printer_plus/sunmi_style.dart';
import '../utils/database.dart';
import '../utils/model.dart' as md;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

// 順番待ちメイン画面
class WaitScreen extends StatelessWidget {
  const WaitScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('順番待ち管理'),
      ),
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildMenuCard(
              context,
              title: '番号発行',
              icon: Icons.add_box,
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const IssueNumberScreen(),
                  ),
                );
              },
            ),
            _buildMenuCard(
              context,
              title: '呼び出し',
              icon: Icons.campaign,
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CallNumberScreen(),
                  ),
                );
              },
            ),
            _buildMenuCard(
              context,
              title: '呼び出し済み',
              icon: Icons.history,
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CalledNumbersScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 100, color: Colors.white),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 番号発行画面
class IssueNumberScreen extends StatefulWidget {
  const IssueNumberScreen({Key? key}) : super(key: key);

  @override
  State<IssueNumberScreen> createState() => _IssueNumberScreenState();
}

class _IssueNumberScreenState extends State<IssueNumberScreen> {
  final Database _database = Database();
  bool _isIssuing = false;
  int? _issuedNumber;
  bool enablePrinter = false;
  DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm');

  Future<bool?> getSettings({String key = ""}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key);
  }

  Future<void> bindPrinter() async {
    final bool? res = await SunmiPrinter.bindingPrinter();
    if (res != null && res) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('プリンターに接続しました'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('プリンターに接続できませんでした'),
        ),
      );
    }
  }

  Future<void> printQueueTicket(md.Queue queue) async {
    try {
      await SunmiPrinter.lineWrap(2);
      await SunmiPrinter.printText('電通部',
          style: SunmiStyle(
              fontSize: SunmiFontSize.XL, align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.printText('順番待ち整理券',
          style: SunmiStyle(
              fontSize: SunmiFontSize.LG, align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.lineWrap(2);
      await SunmiPrinter.printText('あなたの番号は',
          style: SunmiStyle(
              fontSize: SunmiFontSize.MD, align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.printText('${queue.number}',
          style: SunmiStyle(
              fontSize: SunmiFontSize.XL,
              align: SunmiPrintAlign.CENTER,
              bold: true));
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.printText('番です',
          style: SunmiStyle(
              fontSize: SunmiFontSize.MD, align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.lineWrap(2);
      await SunmiPrinter.line();
      await SunmiPrinter.lineWrap(1);

      await SunmiPrinter.printText('発行日時: ${formatter.format(queue.createdAt)}',
          style: SunmiStyle(align: SunmiPrintAlign.LEFT));

      await SunmiPrinter.printText('整理券ID: ${queue.queueId}',
          style: SunmiStyle(align: SunmiPrintAlign.LEFT));
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.line();
      await SunmiPrinter.lineWrap(1);

      await SunmiPrinter.printText('お呼び出しまで',
          style: SunmiStyle(align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.printText('しばらくお待ちください',
          style: SunmiStyle(align: SunmiPrintAlign.CENTER));
      await SunmiPrinter.lineWrap(1);

      // QRコード印刷
      await SunmiPrinter.printQRCode(
          'https://wait.ja1ykl.com?id=${queue.queueId}',
          size: 6);
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.printText('QRコードで状況確認',
          style: SunmiStyle(align: SunmiPrintAlign.CENTER));

      await SunmiPrinter.lineWrap(2);
      await SunmiPrinter.cut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('印刷エラー: $e')),
        );
      }
    }
  }

  Future<void> _issueNumber() async {
    setState(() {
      _isIssuing = true;
    });

    try {
      final queuesCollection = _database.queuesCollection();
      final nextNumber = await queuesCollection.getNextQueueNumber();
      final queueId = queuesCollection.getId();

      final queue = md.Queue(
        queueId: queueId,
        createdAt: DateTime.now(),
        number: nextNumber,
      );

      await queuesCollection.set(queueId, queue.toMap());

      // プリンターが有効な場合は印刷
      if (enablePrinter) {
        await printQueueTicket(queue);
      }

      setState(() {
        _issuedNumber = nextNumber;
        _isIssuing = false;
      });
    } catch (e) {
      setState(() {
        _isIssuing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    }
  }

  void _resetForNextIssue() {
    setState(() {
      _issuedNumber = null;
    });
  }

  @override
  void initState() {
    super.initState();
    getSettings(key: "enablePrinter").then((value) {
      setState(() {
        enablePrinter = value ?? false;
        if (enablePrinter) {
          bindPrinter();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('番号発行'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_issuedNumber != null)
              Column(
                children: [
                  const Text(
                    'あなたの番号は',
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.green, width: 5),
                    ),
                    child: Text(
                      '$_issuedNumber',
                      style: const TextStyle(
                        fontSize: 120,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    '番です',
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 50),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[600],
                          padding: const EdgeInsets.symmetric(
                            horizontal: 50,
                            vertical: 30,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.arrow_back,
                                size: 40, color: Colors.white),
                            SizedBox(height: 10),
                            Text(
                              '戻る',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 30),
                      ElevatedButton(
                        onPressed: _resetForNextIssue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 50,
                            vertical: 30,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.add_box, size: 40, color: Colors.white),
                            SizedBox(height: 10),
                            Text(
                              '続けて発行',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else if (_isIssuing)
              const CircularProgressIndicator(
                strokeWidth: 6,
              )
            else
              ElevatedButton(
                onPressed: _issueNumber,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 80,
                    vertical: 40,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.add_box, size: 80, color: Colors.white),
                    SizedBox(height: 20),
                    Text(
                      '番号を発行',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// 呼び出し画面
class CallNumberScreen extends StatefulWidget {
  const CallNumberScreen({Key? key}) : super(key: key);

  @override
  State<CallNumberScreen> createState() => _CallNumberScreenState();
}

class _CallNumberScreenState extends State<CallNumberScreen> {
  final Database _database = Database();

  Stream<List<md.Queue>> _getWaitingQueues() {
    return _database
        .queuesCollection()
        .collection
        .where('called', isEqualTo: false)
        .orderBy('number')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return md.Queue.fromDocument(doc);
      }).toList();
    });
  }

  Future<void> _callQueue(md.Queue queue) async {
    try {
      await _database.queuesCollection().update(
        queue.queueId,
        {'calledAt': Timestamp.fromDate(DateTime.now()), 'called': true},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${queue.number}番をお呼びしました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    }
  }

  Future<void> _deleteQueue(md.Queue queue) async {
    try {
      await _database.queuesCollection().delete(queue.queueId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${queue.number}番を削除しました'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('呼び出し'),
      ),
      body: StreamBuilder<List<md.Queue>>(
        stream: _getWaitingQueues(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('エラー: ${snapshot.error}'));
          }

          final queues = snapshot.data ?? [];

          if (queues.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 100, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    '待機中の番号はありません',
                    style: TextStyle(fontSize: 24, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 1.2,
            ),
            itemCount: queues.length,
            itemBuilder: (context, index) {
              final queue = queues[index];
              final waitTime = DateTime.now().difference(queue.createdAt);
              final minutes = waitTime.inMinutes;

              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: InkWell(
                  onTap: () => _callQueue(queue),
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteQueue(queue),
                              tooltip: '削除',
                            ),
                          ],
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '${queue.number}',
                              style: const TextStyle(
                                fontSize: 60,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          '待ち時間: ${minutes}分',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () => _callQueue(queue),
                          icon: const Icon(Icons.campaign),
                          label: const Text('呼び出す'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// 呼び出し済み一覧画面
class CalledNumbersScreen extends StatefulWidget {
  const CalledNumbersScreen({Key? key}) : super(key: key);

  @override
  State<CalledNumbersScreen> createState() => _CalledNumbersScreenState();
}

class _CalledNumbersScreenState extends State<CalledNumbersScreen> {
  final Database _database = Database();

  Stream<List<md.Queue>> _getCalledQueues() {
    return _database
        .queuesCollection()
        .collection
        .where('called', isEqualTo: true)
        .orderBy('calledAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return md.Queue.fromDocument(doc);
      }).toList();
    });
  }

  Future<void> _cancelCall(md.Queue queue) async {
    // 呼び出しをキャンセルして待機リストに戻す
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認'),
        content: Text('${queue.number}番の呼び出しをキャンセルしますか？\n待機リストに戻ります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('いいえ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('はい'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _database.queuesCollection().update(
          queue.queueId,
          {'calledAt': null, 'called': false},
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${queue.number}番を待機リストに戻しました'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('エラーが発生しました: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteQueue(md.Queue queue) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認'),
        content: Text('${queue.number}番を完全に削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('いいえ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _database.queuesCollection().delete(queue.queueId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${queue.number}番を削除しました'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('エラーが発生しました: $e')),
          );
        }
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('呼び出し済み'),
      ),
      body: StreamBuilder<List<md.Queue>>(
        stream: _getCalledQueues(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('エラー: ${snapshot.error}'));
          }

          final queues = snapshot.data ?? [];

          if (queues.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 100, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    '呼び出し済みの番号はありません',
                    style: TextStyle(fontSize: 24, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: queues.length,
            itemBuilder: (context, index) {
              final queue = queues[index];
              final calledTime = queue.calledAt != null
                  ? _formatDateTime(queue.calledAt!)
                  : '--:--';
              final waitDuration = queue.calledAt != null
                  ? queue.calledAt!.difference(queue.createdAt)
                  : Duration.zero;
              final waitMinutes = waitDuration.inMinutes;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  leading: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${queue.number}',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 20, color: Colors.grey),
                      const SizedBox(width: 5),
                      Text(
                        '呼び出し時刻: $calledTime',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '待ち時間: ${waitMinutes}分',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _cancelCall(queue),
                        icon: const Icon(Icons.undo, size: 20),
                        label: const Text('キャンセル'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            color: Colors.red, size: 28),
                        onPressed: () => _deleteQueue(queue),
                        tooltip: '削除',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
