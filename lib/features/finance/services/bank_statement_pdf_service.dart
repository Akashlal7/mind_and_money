import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../core/utils/money.dart';
import '../models/transaction.dart';
import 'smart_transaction_parser.dart';

/// Result from parsing a bank statement PDF
class BankStatementParseResult {
  final List<ParsedTransactionDraft> transactions;
  final String? bankName;
  final Money totalDebits;
  final Money totalCredits;
  final int totalLinesScanned;
  final bool isPasswordProtected;
  final String? error;

  const BankStatementParseResult({
    required this.transactions,
    this.bankName,
    required this.totalDebits,
    required this.totalCredits,
    this.totalLinesScanned = 0,
    this.isPasswordProtected = false,
    this.error,
  });

  bool get isSuccess => error == null && transactions.isNotEmpty;
}

/// Offline service that extracts text from bank statement PDFs and parses
/// transaction line items into structured drafts.
class BankStatementPdfService {
  BankStatementPdfService._();

  /// Extracts text from PDF bytes and converts transaction lines into drafts.
  /// If the PDF is encrypted, [password] can be provided.
  static Future<BankStatementParseResult> parsePdfBytes(
    Uint8List bytes, {
    String? password,
  }) async {
    PdfDocument? loadedDocument;
    try {
      if (password != null && password.isNotEmpty) {
        loadedDocument = PdfDocument(inputBytes: bytes, password: password);
      } else {
        loadedDocument = PdfDocument(inputBytes: bytes);
      }

      final textExtractor = PdfTextExtractor(loadedDocument);
      final fullText = textExtractor.extractText();
      loadedDocument.dispose();

      if (fullText.trim().isEmpty) {
        return const BankStatementParseResult(
          transactions: [],
          totalDebits: Money.zero(),
          totalCredits: Money.zero(),
          error:
              'No readable text found in PDF. Scanned image-only PDFs require OCR.',
        );
      }

      return parseStatementText(fullText);
    } on ArgumentError catch (e) {
      if (e.toString().toLowerCase().contains('password')) {
        return const BankStatementParseResult(
          transactions: [],
          totalDebits: Money.zero(),
          totalCredits: Money.zero(),
          isPasswordProtected: true,
          error: 'Statement is password protected.',
        );
      }
      return BankStatementParseResult(
        transactions: [],
        totalDebits: const Money.zero(),
        totalCredits: const Money.zero(),
        error: 'Failed to open PDF: ${e.message}',
      );
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('password') || errStr.contains('encrypted')) {
        return const BankStatementParseResult(
          transactions: [],
          totalDebits: Money.zero(),
          totalCredits: Money.zero(),
          isPasswordProtected: true,
          error: 'Statement is password protected.',
        );
      }
      return BankStatementParseResult(
        transactions: [],
        totalDebits: const Money.zero(),
        totalCredits: const Money.zero(),
        error: 'PDF parsing error: $e',
      );
    } finally {
      try {
        loadedDocument?.dispose();
      } catch (_) {}
    }
  }

  /// Parses raw statement text line-by-line into transactions
  static BankStatementParseResult parseStatementText(String text) {
    final lines = text.split(RegExp(r'\r?\n'));
    final transactions = <ParsedTransactionDraft>[];
    String? bankName;

    // Detect Bank Brand from header lines
    final first10Lines = lines.take(15).join(' ').toLowerCase();
    if (first10Lines.contains('hdfc')) {
      bankName = 'HDFC Bank';
    } else if (first10Lines.contains('state bank') || first10Lines.contains('sbi')) {
      bankName = 'State Bank of India';
    } else if (first10Lines.contains('icici')) {
      bankName = 'ICICI Bank';
    } else if (first10Lines.contains('axis')) {
      bankName = 'Axis Bank';
    } else if (first10Lines.contains('kotak')) {
      bankName = 'Kotak Mahindra Bank';
    } else if (first10Lines.contains('chase')) {
      bankName = 'Chase Bank';
    } else if (first10Lines.contains('bank of america')) {
      bankName = 'Bank of America';
    } else if (first10Lines.contains('barclays')) {
      bankName = 'Barclays';
    } else if (first10Lines.contains('hsbc')) {
      bankName = 'HSBC Bank';
    }

    int totalDebitCents = 0;
    int totalCreditCents = 0;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final draft = _parseStatementLine(trimmed);
      if (draft != null) {
        transactions.add(draft);
        if (draft.type == TransactionType.expense) {
          totalDebitCents += draft.amount.cents;
        } else {
          totalCreditCents += draft.amount.cents;
        }
      }
    }

    return BankStatementParseResult(
      transactions: transactions,
      bankName: bankName,
      totalDebits: Money(totalDebitCents),
      totalCredits: Money(totalCreditCents),
      totalLinesScanned: lines.length,
      error: transactions.isEmpty
          ? 'Could not detect tabular transaction rows. Ensure statement contains date and amount columns.'
          : null,
    );
  }

  /// Date regex matching formats like:
  /// - 01/11/2026, 01-11-2026, 01.11.2026
  /// - 01-Nov-2026, 01 Nov 2026, 01-Nov-26
  static final RegExp _dateRegex = RegExp(
    r'\b(\d{1,2})[-/. ](Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|\d{1,2})[-/. ](\d{2,4})\b',
    caseSensitive: false,
  );

  /// Number regex matching currency figures with 2 decimal places: e.g. 1,499.00 or 340.50
  static final RegExp _amountRegex = RegExp(
    r'\b([0-9]{1,3}(?:,[0-9]{2,3})*(?:\.[0-9]{2}))\b',
  );

  static ParsedTransactionDraft? _parseStatementLine(String line) {
    // A statement transaction row MUST have a valid date
    final dateMatch = _dateRegex.firstMatch(line);
    if (dateMatch == null) return null;

    final date = _parseDateMatch(dateMatch);

    // Find all amounts in this line
    final amountMatches = _amountRegex.allMatches(line).toList();
    if (amountMatches.isEmpty) return null;

    // Filter out matches that overlap with the date digits (e.g. year 2026)
    final validAmounts = <double>[];
    for (final am in amountMatches) {
      if (am.start >= dateMatch.start && am.end <= dateMatch.end) continue;
      final valStr = am.group(1)!.replaceAll(',', '');
      final val = double.tryParse(valStr);
      if (val != null && val > 0) {
        validAmounts.add(val);
      }
    }

    if (validAmounts.isEmpty) return null;

    final lower = line.toLowerCase();

    // Determine type: Credit (Income) or Debit (Expense)
    var isCredit = false;
    if (lower.contains(' cr') ||
        lower.contains('/cr') ||
        lower.contains('credit') ||
        lower.contains('deposit')) {
      // Check if it's explicitly credit
      if (!lower.contains('credit card') && !lower.contains('debited')) {
        isCredit = true;
      }
    }

    // Determine transaction amount:
    // When there are 2 numbers (e.g. Transaction Amount & Running Balance),
    // the transaction amount is typically the first number, and balance is second.
    final txAmount = validAmounts.first;
    final amount = Money((txAmount * 100).round());

    // Extract Description / Narration:
    // Clean out the date, the numbers, and common noise keywords
    var description = line;
    description = description.replaceFirst(dateMatch.group(0)!, ' ');
    for (final am in amountMatches) {
      description = description.replaceFirst(am.group(0)!, ' ');
    }

    final noiseWords = RegExp(
      r'\b(cr|dr|inr|rs\.?|chq|ref|no|bal|balance|clear|transfer|by|to|via)\b',
      caseSensitive: false,
    );
    description = description.replaceAll(noiseWords, ' ').trim();
    // Clean bank prefix patterns like "UPI/12345/MERCHANT" -> "MERCHANT"
    description = _cleanBankNarration(description);

    if (description.isEmpty) {
      description = isCredit ? 'Bank Deposit' : 'Bank Expense';
    }

    // Determine payment method
    var paymentMethod = 'bank_transfer';
    if (lower.contains('upi') || lower.contains('vpa') || lower.contains('gpay')) {
      paymentMethod = 'upi';
    } else if (lower.contains('pos') || lower.contains('card')) {
      paymentMethod = 'card';
    } else if (lower.contains('atm') || lower.contains('cash')) {
      paymentMethod = 'cash';
    }

    final type = isCredit ? TransactionType.income : TransactionType.expense;

    // Use smart parser category matcher
    final categoryId = SmartTransactionParser.matchCategory(
      '$description $line',
      isIncome: isCredit,
    );

    return ParsedTransactionDraft(
      amount: amount,
      type: type,
      description: description,
      categoryId: categoryId,
      paymentMethod: paymentMethod,
      date: date,
      rawText: line,
      confidence: 0.95,
    );
  }

  static String _cleanBankNarration(String raw) {
    var s = raw;
    // Replace typical separators: slashes, dashes, underscores
    s = s.replaceAll(RegExp(r'[/_-]'), ' ');

    // Filter out long reference IDs or alphanumeric codes (>6 chars with digits)
    final words = s.split(RegExp(r'\s+'));
    final cleanWords = <String>[];
    for (final w in words) {
      final hasDigit = RegExp(r'\d').hasMatch(w);
      if (hasDigit && w.length > 5) continue; // Skip ref numbers like 491029103
      if (w.length < 2) continue;
      cleanWords.add(w);
    }

    var result = cleanWords.join(' ').trim();
    if (result.length > 30) {
      result = result.substring(0, 30).trim();
    }
    return _capitalizeWords(result);
  }

  static DateTime _parseDateMatch(Match dateMatch) {
    final now = DateTime.now();
    final day = int.tryParse(dateMatch.group(1)!) ?? 1;
    final rawMonth = dateMatch.group(2)!;
    final rawYear = dateMatch.group(3);

    int month = now.month;
    final monthMap = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    if (monthMap.containsKey(rawMonth.toLowerCase())) {
      month = monthMap[rawMonth.toLowerCase()]!;
    } else {
      month = int.tryParse(rawMonth) ?? now.month;
    }

    var year = now.year;
    if (rawYear != null) {
      final yVal = int.tryParse(rawYear) ?? now.year;
      year = yVal < 100 ? (2000 + yVal) : yVal;
    }

    return DateTime(year, month, day, 12, 0);
  }

  static String _capitalizeWords(String input) {
    if (input.isEmpty) return input;
    return input
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
}
