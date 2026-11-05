import 'package:flutter/material.dart';

class PaymentMethod {
  final String id;
  final String label;
  final IconData icon;

  const PaymentMethod({
    required this.id,
    required this.label,
    required this.icon,
  });

  static const List<PaymentMethod> standard = [
    PaymentMethod(id: 'cash', label: 'Cash', icon: Icons.payments_outlined),
    PaymentMethod(id: 'upi', label: 'UPI', icon: Icons.qr_code_scanner_rounded),
    PaymentMethod(
      id: 'credit_card',
      label: 'Credit Card',
      icon: Icons.credit_card_rounded,
    ),
    PaymentMethod(
      id: 'debit_card',
      label: 'Debit Card',
      icon: Icons.account_balance_wallet_outlined,
    ),
    PaymentMethod(
      id: 'bank_transfer',
      label: 'Bank Transfer',
      icon: Icons.account_balance_rounded,
    ),
    PaymentMethod(id: 'other', label: 'Other', icon: Icons.more_horiz_rounded),
  ];

  static PaymentMethod fromId(String? id) {
    if (id == null) return standard.first;
    return standard.firstWhere(
      (m) => m.id.toLowerCase() == id.toLowerCase(),
      orElse: () =>
          PaymentMethod(id: id, label: id, icon: Icons.payment_rounded),
    );
  }
}
