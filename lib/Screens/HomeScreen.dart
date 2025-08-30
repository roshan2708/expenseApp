import 'package:expenseapp/Components/MessageList.dart';
import 'package:expenseapp/Components/StatusIndicator.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:telephony/telephony.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Telephony telephony = Telephony.instance;
  final List<Map<String, dynamic>> _messages = [];
  bool _smsEnabled = false;
  bool _notificationEnabled = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _totalMessagesReceived = 0;
  int _totalMessagesSaved = 0;

  @override
  void initState() {
    super.initState();
    _checkFirebaseConnection();
    _initListeners();
    _loadMessagesFromFirebase();
  }

  // Debug: Check Firebase connection
  Future<void> _checkFirebaseConnection() async {
    try {
      final user = _auth.currentUser;
      print("🔥 Firebase Auth - Current User: ${user?.uid ?? 'No user'}");
      print("🔥 Firebase Auth - Email: ${user?.email ?? 'No email'}");
      
      if (user != null) {
        // Test write to Firebase
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('test')
            .add({
          'message': 'Test connection',
          'timestamp': FieldValue.serverTimestamp(),
          'testTime': DateTime.now().toIso8601String(),
        });
        print("✅ Firebase connection test successful");
      } else {
        print("❌ No authenticated user for Firebase");
      }
    } catch (e) {
      print("❌ Firebase connection test failed: $e");
    }
  }

  Future<void> _loadMessagesFromFirebase() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print("❌ No user logged in for loading messages");
        return;
      }

      print("📥 Loading messages from Firebase for user: ${user.uid}");
      
      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('expenses')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      print("📥 Loaded ${querySnapshot.docs.length} messages from Firebase");

      setState(() {
        _messages.clear();
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          _messages.add({
            "id": doc.id,
            "type": data['type'] ?? 'Unknown',
            "content": data['content'] ?? data['message'] ?? '',
            "source": data['source'] ?? 'Unknown',
            "timestamp": (data['timestamp'] as Timestamp?)?.toDate() ?? 
                        DateTime.tryParse(data['createdAt'] ?? '') ?? 
                        DateTime.now(),
          });
        }
      });
    } catch (e) {
      print("❌ Error loading messages from Firebase: $e");
      _showErrorDialog("Error loading messages: $e");
    }
  }

  Future<void> _initListeners() async {
    await _initSmsListener();
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
            final senderNumber = message.address ?? "Unknown";
            
            print("📱 SMS received from $senderNumber: $body");
            _totalMessagesReceived++;
            
            // Check if it's a financial/expense related SMS
            if (_isExpenseRelated(body)) {
              print("💰 Expense-related SMS detected, saving to Firebase");
              _saveMessageToFirebase("SMS", body, senderNumber);
              setState(() {
                _messages.insert(0, {
                  "type": "SMS", 
                  "content": body,
                  "source": senderNumber,
                  "timestamp": DateTime.now()
                });
                _smsEnabled = true;
              });
            } else {
              print("❌ SMS not expense-related, skipping");
            }
          },
          onBackgroundMessage: _backgroundMessageHandler,
        );
        print("✅ SMS listener initialized successfully");
      } else {
        print("❌ SMS permissions denied");
      }
    } catch (e) {
      print("❌ Error initializing SMS listener: $e");
      _showErrorDialog("Error initializing SMS listener: $e");
    }
  }

  Future<void> _initNotificationListener() async {
    try {
      bool isGranted = await NotificationListenerService.isPermissionGranted();
      print("🔔 Notification permission granted: $isGranted");
      
      if (!isGranted) {
        bool permissionGranted = await NotificationListenerService.requestPermission();
        if (!permissionGranted) {
          _showPermissionDialog();
          return;
        }
      }

      await Future.delayed(const Duration(seconds: 2));
      
      // Use the correct ServiceNotificationEvent type
      NotificationListenerService.notificationsStream.listen(
        (ServiceNotificationEvent event) {
          print("🔔 Notification received from ${event.packageName}");
          _handleNotificationEvent(event);
        },
        onError: (error) {
          print("❌ Error in notification stream: $error");
        },
        onDone: () {
          print("🔔 Notification stream closed");
        },
      );

      setState(() {
        _notificationEnabled = true;
      });
      print("✅ Notification listener initialized successfully");
    } catch (e) {
      print("❌ Error initializing notification listener: $e");
      _showErrorDialog("Error initializing notification listener: $e");
    }
  }

  void _handleNotificationEvent(ServiceNotificationEvent event) {
    try {
      String? packageName = event.packageName;
      String? title = event.title;
      String? content = event.content;
      
      print("🔔 Processing notification:");
      print("   Package: $packageName");
      print("   Title: $title");
      print("   Content: $content");
      
      _totalMessagesReceived++;
      
      if (packageName != null && (title != null || content != null)) {
        String fullContent = "${title ?? ''}: ${content ?? ''}".trim();
        
        // Enhanced filtering for expense-related notifications
        bool isRelevant = _isNotificationRelevant(packageName, title, content);
        print("   Is Relevant: $isRelevant");
            
        if (isRelevant) {
          if (fullContent.isNotEmpty && fullContent != ":") {
            print("💰 Saving relevant notification to Firebase: $fullContent");
            _saveMessageToFirebase("Notification", fullContent, packageName);
            setState(() {
              _messages.insert(0, {
                "type": "Notification",
                "content": fullContent,
                "source": packageName,
                "timestamp": DateTime.now()
              });
            });
          }
        } else {
          print("❌ Notification not relevant, skipping");
        }
      } else {
        print("❌ Notification missing required data");
      }
    } catch (e) {
      print("❌ Error handling notification: $e");
    }
  }

  bool _isNotificationRelevant(String packageName, String? title, String? content) {
    String lowerPackage = packageName.toLowerCase();
    String searchText = "${title ?? ''} ${content ?? ''}".toLowerCase();
    
    print("   🔍 Filtering notification:");
    print("   Package: $packageName");
    print("   Content: $searchText");
    
    // First, check if it's from a financial app
    List<String> financialPackages = [
      'paytm', 'gpay', 'phonepe', 'bhim', 'amazonpay', 'mobikwik',
      'sbi', 'hdfc', 'icici', 'axis', 'kotak', 'pnb', 'bank',
      'upi', 'wallet', 'pay'
    ];
    
    bool isFinancialApp = false;
    for (String pkg in financialPackages) {
      if (lowerPackage.contains(pkg)) {
        isFinancialApp = true;
        print("   ✅ Financial app detected: $pkg");
        break;
      }
    }
    
    // Then check if content contains expense keywords
    bool hasExpenseContent = _isExpenseRelated(searchText);
    
    // Only return true if BOTH conditions are met
    bool isRelevant = isFinancialApp && hasExpenseContent;
    
    print("   📊 Financial App: $isFinancialApp, Expense Content: $hasExpenseContent");
    print("   🎯 Final Result: $isRelevant");
    
    return isRelevant;
  }

  bool _isExpenseRelated(String text) {
    // More specific expense-related keywords
    List<String> expenseKeywords = [
      // Transaction keywords
      'debited', 'credited', 'transaction', 'payment', 'paid', 'sent', 'received',
      'transferred', 'withdraw', 'deposit',
      
      // Amount keywords  
      'rs.', 'rs ', '₹', 'rupees', 'amount', 'balance',
      
      // Banking keywords
      'account', 'a/c', 'atm', 'card', 'wallet', 'bank',
      
      // UPI/Digital payment keywords
      'upi', 'txn', 'transaction id', 'ref no', 'reference',
      'imps', 'neft', 'rtgs',
      
      // Money transfer keywords
      'money', 'fund', 'bill', 'recharge', 'top up',
      
      // Expense categories
      'purchase', 'shopping', 'grocery', 'fuel', 'restaurant'
    ];
    
    String lowerText = text.toLowerCase();
    
    // Check for financial keywords
    for (String keyword in expenseKeywords) {
      if (lowerText.contains(keyword)) {
        print("   💰 Expense keyword found: '$keyword'");
        return true;
      }
    }
    
    // Additional check for amount patterns (like Rs 100, ₹500, etc.)
    RegExp amountPattern = RegExp(r'(rs\.?\s*\d+|₹\s*\d+|\d+\s*rupees)', caseSensitive: false);
    if (amountPattern.hasMatch(lowerText)) {
      print("   💰 Amount pattern found");
      return true;
    }
    
    return false;
  }

  Future<void> _saveMessageToFirebase(String type, String content, String? source) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print("❌ Cannot save to Firebase: No authenticated user");
        return;
      }

      print("💾 Attempting to save to Firebase:");
      print("   User ID: ${user.uid}");
      print("   Type: $type");
      print("   Content: $content");
      print("   Source: $source");

      final docRef = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('expenses')
          .add({
        'type': type,
        'content': content,
        'source': source ?? 'Unknown',
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
        'userId': user.uid, // Add for extra verification
      });

      _totalMessagesSaved++;
      print("✅ Message saved to Firebase with ID: ${docRef.id}");
      print("📊 Stats - Received: $_totalMessagesReceived, Saved: $_totalMessagesSaved");
      
    } catch (e) {
      print("❌ Error saving to Firebase: $e");
      print("❌ Error type: ${e.runtimeType}");
      if (e is FirebaseException) {
        print("❌ Firebase error code: ${e.code}");
        print("❌ Firebase error message: ${e.message}");
      }
      
      // Show error to user
      _showErrorDialog("Failed to save message to database: $e");
    }
  }

  // Test function to manually save a message
  Future<void> _testSaveMessage() async {
    await _saveMessageToFirebase(
      "Test", 
      "Test message - ${DateTime.now()}", 
      "Manual Test"
    );
    setState(() {
      _messages.insert(0, {
        "type": "Test",
        "content": "Test message - ${DateTime.now()}",
        "source": "Manual Test",
        "timestamp": DateTime.now()
      });
    });
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Expense SMS Tracker"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: _testSaveMessage,
            tooltip: "Test Save Message",
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMessagesFromFirebase,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          StatusIndicator(
            smsEnabled: _smsEnabled,
            notificationEnabled: _notificationEnabled,
          ),
          // Debug info
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text("Received: $_totalMessagesReceived"),
                Text("Saved: $_totalMessagesSaved"),
                Text("Local: ${_messages.length}"),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: MessageList(messages: _messages),
          ),
        ],
      ),
    );
  }
}