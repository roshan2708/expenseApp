import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expenseapp/Components/MessageList.dart';
import 'package:expenseapp/Components/PieChartDisplay.dart';
import 'package:expenseapp/Components/StatusIndicator.dart';
import 'package:expenseapp/Components/TotalsDisplay.dart';
import 'package:expenseapp/Constants/Colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';

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
  double _totalDebits = 0.0;
  double _totalCredits = 0.0;
  Map<String, double> _categorySums = {};
  
  // Add loading state
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    setState(() {
      _isLoading = true;
    });
    
    await _checkFirebaseConnection();
    await _initListeners();
    await _loadMessagesFromFirebase();
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _checkFirebaseConnection() async {
    try {
      final user = _auth.currentUser;
      print("🔥 Firebase Auth - Current User: ${user?.uid ?? 'No user'}");
      print("🔥 Firebase Auth - Email: ${user?.email ?? 'No email'}");

      if (user != null) {
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
        // Navigate to login if no user
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/login');
        });
      }
    } catch (e) {
      print("❌ Firebase connection test failed: $e");
      _showErrorDialog("Firebase connection failed: $e");
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

      if (mounted) {
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
              "category": data['category'] ?? 'Uncategorized',
              "amount": data['amount'] as double?,
              "isDebit": data['isDebit'] as bool?,
            });
          }
          _computeTotals();
        });
      }
    } catch (e) {
      print("❌ Error loading messages from Firebase: $e");
      if (mounted) {
        _showErrorDialog("Error loading messages: $e");
      }
    }
  }

  void _computeTotals() {
    _totalDebits = 0.0;
    _totalCredits = 0.0;
    _categorySums = {};

    for (var message in _messages) {
      final amount = message['amount'] as double?;
      final isDebit = message['isDebit'] as bool?;
      if (amount != null && isDebit != null) {
        if (isDebit) {
          _totalDebits += amount;
          final category = message['category'] as String? ?? 'Uncategorized';
          _categorySums[category] = (_categorySums[category] ?? 0) + amount;
        } else {
          _totalCredits += amount;
        }
      }
    }
    print("📊 Computed totals - Debits: $_totalDebits, Credits: $_totalCredits");
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
            _handleNewSmsMessage(message);
          },
          onBackgroundMessage: _backgroundMessageHandler,
        );
        
        if (mounted) {
          setState(() {
            _smsEnabled = true;
          });
        }
        print("✅ SMS listener initialized successfully");
      } else {
        print("❌ SMS permissions denied");
        if (mounted) {
          _showErrorDialog("SMS permissions are required for the app to work properly.");
        }
      }
    } catch (e) {
      print("❌ Error initializing SMS listener: $e");
      if (mounted) {
        _showErrorDialog("Error initializing SMS listener: $e");
      }
    }
  }

  void _handleNewSmsMessage(SmsMessage message) async {
    final body = message.body ?? "";
    final senderNumber = message.address ?? "Unknown";

    print("📱 SMS received from $senderNumber: $body");
    
    if (mounted) {
      setState(() {
        _totalMessagesReceived++;
      });
    }

    if (_isExpenseRelated(body)) {
      print("💰 Expense-related SMS detected, saving to Firebase");
      final parsed = _parseMessage(body, senderNumber);
      
      // Save to Firebase first
      await _saveMessageToFirebase("SMS", body, senderNumber, parsed);
      
      // Then update UI
      if (mounted) {
        setState(() {
          _messages.insert(0, {
            "id": DateTime.now().millisecondsSinceEpoch.toString(),
            "type": "SMS",
            "content": body,
            "source": senderNumber,
            "timestamp": DateTime.now(),
            "category": parsed['category'],
            "amount": parsed['amount'],
            "isDebit": parsed['isDebit'],
          });
          _computeTotals();
        });
      }
    } else {
      print("❌ SMS not expense-related, skipping");
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
        // Wait a bit after permission is granted
        await Future.delayed(const Duration(seconds: 3));
        isGranted = await NotificationListenerService.isPermissionGranted();
      }

      if (isGranted) {
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

        if (mounted) {
          setState(() {
            _notificationEnabled = true;
          });
        }
        print("✅ Notification listener initialized successfully");
      }
    } catch (e) {
      print("❌ Error initializing notification listener: $e");
      if (mounted) {
        _showErrorDialog("Error initializing notification listener: $e");
      }
    }
  }

  void _handleNotificationEvent(ServiceNotificationEvent event) async {
    try {
      String? packageName = event.packageName;
      String? title = event.title;
      String? content = event.content;

      print("🔔 Processing notification:");
      print("   Package: $packageName");
      print("   Title: $title");
      print("   Content: $content");

      if (mounted) {
        setState(() {
          _totalMessagesReceived++;
        });
      }

      if (packageName != null && (title != null || content != null)) {
        String fullContent = "${title ?? ''}: ${content ?? ''}".trim();
        if (fullContent == ":") fullContent = content ?? title ?? "";

        bool isRelevant = _isNotificationRelevant(packageName, title, content);
        print("   Is Relevant: $isRelevant");

        if (isRelevant && fullContent.isNotEmpty) {
          print("💰 Saving relevant notification to Firebase: $fullContent");
          final parsed = _parseMessage(fullContent, packageName);
          
          // Save to Firebase first
          await _saveMessageToFirebase("Notification", fullContent, packageName, parsed);
          
          // Then update UI
          if (mounted) {
            setState(() {
              _messages.insert(0, {
                "id": DateTime.now().millisecondsSinceEpoch.toString(),
                "type": "Notification",
                "content": fullContent,
                "source": packageName,
                "timestamp": DateTime.now(),
                "category": parsed['category'],
                "amount": parsed['amount'],
                "isDebit": parsed['isDebit'],
              });
              _computeTotals();
            });
          }
        } else {
          print("❌ Notification not relevant or empty, skipping");
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

  List<String> financialKeywords = [
    'gpay', 'google pay', 'paisa', 'paytm', 'phonepe', 'bhim', 'amazonpay', 'mobikwik',
    'sbi', 'hdfc', 'icici', 'axis', 'kotak', 'pnb', 'bank',
    'upi', 'wallet', 'pay', 'razorpay', 'freecharge'
  ];

  bool isFinancialApp = financialKeywords.any(
    (keyword) => lowerPackage.contains(keyword) || searchText.contains(keyword),
  );

  bool hasExpenseContent = _isExpenseRelated(searchText);

  bool isRelevant = isFinancialApp && hasExpenseContent;

  print("📊 Financial App: $isFinancialApp, Expense Content: $hasExpenseContent");
  print("🎯 Final Result: $isRelevant");

  return isRelevant;
}



  bool _isExpenseRelated(String text) {
    List<String> expenseKeywords = [
      'debited', 'credited', 'transaction', 'payment', 'paid', 'sent', 'received',
      'transferred', 'withdraw', 'deposit', 'deducted', 'added',
      'rs.', 'rs ', '₹', 'rupees', 'amount', 'balance',
      'account', 'a/c', 'atm', 'card', 'wallet', 'bank',
      'upi', 'txn', 'transaction id', 'ref no', 'reference',
      'imps', 'neft', 'rtgs',
      'money', 'fund', 'bill', 'recharge', 'top up',
      'purchase', 'shopping', 'grocery', 'fuel', 'restaurant',
      'successful', 'failed', 'declined'
    ];

    String lowerText = text.toLowerCase();

    for (String keyword in expenseKeywords) {
      if (lowerText.contains(keyword)) {
        print("   💰 Expense keyword found: '$keyword'");
        return true;
      }
    }

    // Enhanced amount pattern matching
    RegExp amountPattern = RegExp(
      r'(rs\.?\s*[\d,]+(?:\.\d{1,2})?|₹\s*[\d,]+(?:\.\d{1,2})?|[\d,]+(?:\.\d{1,2})?\s*rupees)',
      caseSensitive: false
    );
    if (amountPattern.hasMatch(lowerText)) {
      print("   💰 Amount pattern found");
      return true;
    }

    return false;
  }

  Map<String, dynamic> _parseMessage(String content, String source) {
    final lowerContent = content.toLowerCase();
    final lowerSource = source.toLowerCase();

    // Enhanced category mapping
    final Map<String, String> categoryMap = {
      'swiggy': 'Food',
      'zomato': 'Food',
      'dominos': 'Food',
      'kfc': 'Food',
      'mcdonald': 'Food',
      'uber': 'Travel',
      'ola': 'Travel',
      'rapido': 'Travel',
      'amazon': 'Shopping',
      'flipkart': 'Shopping',
      'myntra': 'Shopping',
      'grocery': 'Groceries',
      'bigbasket': 'Groceries',
      'grofers': 'Groceries',
      'petrol': 'Fuel',
      'diesel': 'Fuel',
      'fuel': 'Fuel',
      'electricity': 'Utilities',
      'gas': 'Utilities',
      'water': 'Utilities',
      'recharge': 'Mobile',
      'airtel': 'Mobile',
      'jio': 'Mobile',
      'vi': 'Mobile',
      'netflix': 'Entertainment',
      'spotify': 'Entertainment',
      'hotstar': 'Entertainment',
    };

    String category = 'Uncategorized';
    for (var entry in categoryMap.entries) {
      if (lowerContent.contains(entry.key) || lowerSource.contains(entry.key)) {
        category = entry.value;
        break;
      }
    }

    // Enhanced amount parsing
    final RegExp amountRegex = RegExp(
      r'(?:rs\.?|₹|inr)\s*([\d,]+(?:\.\d{1,2})?)|(?:amount|amt)[\s:]*(?:rs\.?|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false
    );
    
    double? amount;
    final matches = amountRegex.allMatches(lowerContent);
    for (var match in matches) {
      final amountStr = (match.group(1) ?? match.group(2))?.replaceAll(',', '');
      if (amountStr != null) {
        amount = double.tryParse(amountStr);
        if (amount != null && amount > 0) {
          break;
        }
      }
    }

    // Enhanced debit/credit detection
    bool? isDebit;
    if (lowerContent.contains('debited') || 
        lowerContent.contains('paid') || 
        lowerContent.contains('deducted') ||
        lowerContent.contains('sent') ||
        lowerContent.contains('transferred') ||
        lowerContent.contains('withdrawn')) {
      isDebit = true;
    } else if (lowerContent.contains('credited') || 
               lowerContent.contains('received') || 
               lowerContent.contains('added') ||
               lowerContent.contains('deposited')) {
      isDebit = false;
    }

    print("   📝 Parsed - Category: $category, Amount: $amount, IsDebit: $isDebit");

    return {
      'category': category,
      'amount': amount,
      'isDebit': isDebit,
    };
  }

  Future<void> _saveMessageToFirebase(String type, String content, String? source, Map<String, dynamic> parsed) async {
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
      print("   Parsed: $parsed");

      final docData = {
        'type': type,
        'content': content,
        'source': source ?? 'Unknown',
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
        'userId': user.uid,
        'category': parsed['category'],
        'amount': parsed['amount'],
        'isDebit': parsed['isDebit'],
      };

      print("💾 Document data to save: $docData");

      final docRef = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('expenses')
          .add(docData);

      if (mounted) {
        setState(() {
          _totalMessagesSaved++;
        });
      }
      
      print("✅ Message saved to Firebase with ID: ${docRef.id}");
      print("📊 Stats - Received: $_totalMessagesReceived, Saved: $_totalMessagesSaved");
    } catch (e) {
      print("❌ Error saving to Firebase: $e");
      print("❌ Error type: ${e.runtimeType}");
      if (e is FirebaseException) {
        print("❌ Firebase error code: ${e.code}");
        print("❌ Firebase error message: ${e.message}");
      }
      if (mounted) {
        _showErrorDialog("Failed to save message to database: $e");
      }
    }
  }

  Future<void> _testSaveMessage() async {
    final testMessages = [
      "Debited Rs. 500 from Swiggy for food order",
      "Credited Rs. 1000 to your account",
      "UPI payment of ₹250 to Amazon successful",
    ];
    
    for (String testContent in testMessages) {
      final parsed = _parseMessage(testContent, "Test");
      await _saveMessageToFirebase(
        "Test",
        testContent,
        "Manual Test",
        parsed,
      );
      
      if (mounted) {
        setState(() {
          _messages.insert(0, {
            "id": DateTime.now().millisecondsSinceEpoch.toString() + _messages.length.toString(),
            "type": "Test",
            "content": testContent,
            "source": "Manual Test",
            "timestamp": DateTime.now(),
            "category": parsed['category'],
            "amount": parsed['amount'],
            "isDebit": parsed['isDebit'],
          });
        });
      }
    }
    
    if (mounted) {
      setState(() {
        _computeTotals();
      });
    }
    
    // Reload from Firebase to verify save
    await Future.delayed(const Duration(seconds: 1));
    await _loadMessagesFromFirebase();
  }

  void _showPermissionDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Permission Required"),
        content: const Text(
          "This app needs notification access to track expense messages. Please enable it in settings.\n\n"
          "Go to Settings > Apps > Special App Access > Notification Access > Enable for this app"
        ),
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
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Error"),
        content: SingleChildScrollView(
          child: Text(message),
        ),
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
    // Note: Background message handler has limited functionality
    // Most processing should be done in the foreground handler
  }

@override
Widget build(BuildContext context) {
  final mq = MediaQuery.of(context);
  final height = mq.size.height;
  final width = mq.size.width;
  
  if (_isLoading) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Expense SMS Tracker",
          style: TextStyle(fontSize: width * 0.045),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.primaryForeground,
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
  
  return Scaffold(
    appBar: AppBar(
      title: Text(
        "Expense SMS Tracker",
        style: TextStyle(fontSize: width * 0.045),
      ),
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.primaryForeground,
      actions: [
        IconButton(
          icon: Icon(Icons.bug_report, size: width * 0.06),
          onPressed: _testSaveMessage,
          tooltip: "Test Save Message",
        ),
        IconButton(
          icon: Icon(Icons.refresh, size: width * 0.06),
          onPressed: _loadMessagesFromFirebase,
          tooltip: "Refresh from Firebase",
        ),
        IconButton(
          icon: Icon(Icons.logout, size: width * 0.06),
          onPressed: () async {
            try {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            } catch (e) {
              print("❌ Error signing out: $e");
            }
          },
        ),
      ],
    ),
    body: SingleChildScrollView(
      child: Column(
        children: [
          StatusIndicator(
            smsEnabled: _smsEnabled,
            notificationEnabled: _notificationEnabled,
          ),
          Container(
            padding: EdgeInsets.all(width * 0.02),
            color: AppColors.divider,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text("Received: $_totalMessagesReceived",
                    style: TextStyle(fontSize: width * 0.035)),
                Text("Saved: $_totalMessagesSaved",
                    style: TextStyle(fontSize: width * 0.035)),
                Text("Local: ${_messages.length}",
                    style: TextStyle(fontSize: width * 0.035)),
              ],
            ),
          ),
          TotalsDisplay(
            totalTransactions: _messages.length,
            totalDebits: _totalDebits,
            totalCredits: _totalCredits,
          ),
          if (_categorySums.isNotEmpty)
            SizedBox(
              height: height * 0.4,
              child: PieChartDisplay(categorySums: _categorySums),
            ),
          Divider(thickness: height * 0.0015),
          // Changed from Expanded to Container with fixed height for scrollable content
          Container(
            height: _messages.isEmpty ? height * 0.3 : height * 0.5,
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: width * 0.18, color: Colors.grey),
                        SizedBox(height: height * 0.02),
                        Text("No messages yet",
                            style: TextStyle(fontSize: width * 0.04)),
                        SizedBox(height: height * 0.01),
                        Text(
                          "Send yourself a test SMS or use the test button",
                          style: TextStyle(
                              color: Colors.grey, fontSize: width * 0.035),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : MessageList(messages: _messages),
          ),
        ],
      ),
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: () {
        _testSaveMessage();
      },
      backgroundColor: AppColors.primary,
      child: Icon(Icons.add,
          color: AppColors.primaryForeground, size: width * 0.07),
      tooltip: "Add Test Messages",
    ),
  );
}}