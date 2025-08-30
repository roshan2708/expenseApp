import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const ExpenseApp());
}

class ExpenseApp extends StatefulWidget {
  const ExpenseApp({Key? key}) : super(key: key);

  @override
  State<ExpenseApp> createState() => _ExpenseAppState();
}

class _ExpenseAppState extends State<ExpenseApp> {
  final Telephony telephony = Telephony.instance;
  final List<String> _messages = [];
  bool _smsEnabled = false;
  bool _notificationEnabled = false;

  @override
  void initState() {
    super.initState();
    _initListeners();
  }

  Future<void> _initListeners() async {
    // Initialize SMS listener
    await _initSmsListener();
    
    // Initialize notification listener with delay to ensure proper setup
    await Future.delayed(const Duration(seconds: 1));
    await _initNotificationListener();
  }

  Future<void> _initSmsListener() async {
    try {
      bool? smsPermissionsGranted = await telephony.requestPhoneAndSmsPermissions;
      if (smsPermissionsGranted ?? false) {
        telephony.listenIncomingSms(
          onNewMessage: (SmsMessage message) {
            final body = message.body ?? "";
            setState(() {
              _messages.insert(0, "[SMS] $body");
              _smsEnabled = true;
            });
          },
          onBackgroundMessage: _backgroundMessageHandler,
        );
        print("SMS listener initialized successfully");
      } else {
        print("SMS permissions denied");
      }
    } catch (e) {
      print("Error initializing SMS listener: $e");
    }
  }

  Future<void> _initNotificationListener() async {
    try {
      // Check if notification listener permission is already granted
      bool isGranted = await NotificationListenerService.isPermissionGranted();
      
      if (!isGranted) {
        bool permissionGranted = await NotificationListenerService.requestPermission();
        if (!permissionGranted) {
          print("Notification permission denied");
          _showPermissionDialog();
          return;
        }
      }

      // Wait a bit more to ensure the service is properly initialized
      await Future.delayed(const Duration(seconds: 2));

      // Start listening to notifications
      NotificationListenerService.notificationsStream.listen(
        (notification) {
          _handleNotification(notification);
        },
        onError: (error) {
          print("Error in notification stream: $error");
        },
        onDone: () {
          print("Notification stream closed");
        },
      );

      setState(() {
        _notificationEnabled = true;
      });
      print("Notification listener initialized successfully");
      
    } catch (e) {
      print("Error initializing notification listener: $e");
      _showErrorDialog("Failed to initialize notification listener: $e");
    }
  }

  void _handleNotification(dynamic notification) {
    try {
      // Handle the notification safely
      String? packageName = notification?.packageName;
      String? title = notification?.title;
      String? content = notification?.content;
      
      if (packageName != null && (title != null || content != null)) {
        // Filter for messaging or banking apps
        bool isRelevant = packageName.contains("messaging") ||
            packageName.contains("bank") ||
            packageName.contains("pay") ||
            title?.toLowerCase().contains("bank") == true ||
            content?.toLowerCase().contains("bank") == true ||
            content?.toLowerCase().contains("transaction") == true;
            
        if (isRelevant) {
          String notificationText = "${title ?? ''}: ${content ?? ''}".trim();
          if (notificationText.isNotEmpty && notificationText != ":") {
            setState(() {
              _messages.insert(0, "[Notification] $notificationText");
            });
          }
        }
      }
    } catch (e) {
      print("Error handling notification: $e");
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Permission Required"),
        content: const Text("This app needs notification access to track expense messages. Please enable it in settings."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text("Settings"),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  static void _backgroundMessageHandler(SmsMessage message) async {
    print("📩 Background SMS: ${message.body}");
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text("Expense SMS Tracker"),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            // Status indicators
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.sms,
                    color: _smsEnabled ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text("SMS: ${_smsEnabled ? 'Enabled' : 'Disabled'}"),
                  const SizedBox(width: 20),
                  Icon(
                    Icons.notifications,
                    color: _notificationEnabled ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text("Notifications: ${_notificationEnabled ? 'Enabled' : 'Disabled'}"),
                ],
              ),
            ),
            const Divider(),
            
            // Messages list
            Expanded(
              child: _messages.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            "No messages received yet",
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Send an SMS or receive a notification to see them here",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              _messages[index],
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}