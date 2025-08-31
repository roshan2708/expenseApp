import 'package:expenseapp/Constants/Colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MessageList extends StatelessWidget {
  final List<Map<String, dynamic>> messages;

  const MessageList({Key? key, required this.messages}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return messages.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: AppColors.iconGrey),
                const SizedBox(height: 16),
                Text(
                  "No messages received yet",
                  style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  "Send an SMS or receive a notification to see them here",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: () async {
              await Future.delayed(const Duration(seconds: 1));
            },
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final isNotification = message['type'] == 'Notification';
                final isSMS = message['type'] == 'SMS';
                final category = message['category'] ?? 'Uncategorized';
                final amount = message['amount'] as double?;
                final isDebit = message['isDebit'] as bool?;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  elevation: 2,
                  color: AppColors.cardBackground,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isNotification ? Icons.notifications : Icons.sms,
                                  color: isNotification ? AppColors.accent : AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  message['type'] ?? 'Unknown',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isNotification ? AppColors.accent : AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              _formatTimestamp(message['timestamp']),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          message['content'] ?? 'No content',
                          style: const TextStyle(fontSize: 16),
                        ),
                        if (message['source'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              isSMS
                                  ? 'From: ${message['source']}'
                                  : 'App: ${message['source']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Chip(
                              label: Text(category),
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                            ),
                            const SizedBox(width: 8),
                            if (amount != null && isDebit != null)
                              Text(
                                '${isDebit ? '-' : '+'} ₹${amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: isDebit ? AppColors.error : AppColors.success,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
  }

  String _formatTimestamp(dynamic timestamp) {
    DateTime dateTime;

    if (timestamp is DateTime) {
      dateTime = timestamp;
    } else if (timestamp is String) {
      dateTime = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else {
      dateTime = DateTime.now();
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEE').format(dateTime);
    } else {
      return DateFormat('MMM dd').format(dateTime);
    }
  }
}