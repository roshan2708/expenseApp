import 'package:expenseapp/Constants/Colors.dart';
import 'package:flutter/material.dart';

class StatusIndicator extends StatelessWidget {
  final bool smsEnabled;
  final bool notificationEnabled;

  const StatusIndicator({
    Key? key,
    required this.smsEnabled,
    required this.notificationEnabled,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.sms,
            color: smsEnabled ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 8),
          Text("SMS: ${smsEnabled ? 'Enabled' : 'Disabled'}"),
          const SizedBox(width: 20),
          Icon(
            Icons.notifications,
            color: notificationEnabled ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 8),
          Text("Notifications: ${notificationEnabled ? 'Enabled' : 'Disabled'}"),
        ],
      ),
    );
  }
}