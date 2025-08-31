import 'package:expenseapp/Constants/Colors.dart';
import 'package:flutter/material.dart';

class TotalsDisplay extends StatelessWidget {
  final int totalTransactions;
  final double totalDebits;
  final double totalCredits;

  const TotalsDisplay({
    Key? key,
    required this.totalTransactions,
    required this.totalDebits,
    required this.totalCredits,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.cardBackground,
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Transactions: $totalTransactions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total Debits: ₹${totalDebits.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Total Credits: ₹${totalCredits.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ),
    );
  }
}