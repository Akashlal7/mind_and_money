import '../../../core/utils/money.dart';
import '../models/transaction.dart';

/// Staged draft transaction produced by parsing bank SMS or natural language one-liners.
class ParsedTransactionDraft {
  final Money amount;
  final TransactionType type;
  final String description;
  final String categoryId;
  final String paymentMethod;
  final DateTime date;
  final String rawText;
  final double confidence; // 0.0 to 1.0

  const ParsedTransactionDraft({
    required this.amount,
    required this.type,
    required this.description,
    required this.categoryId,
    required this.paymentMethod,
    required this.date,
    required this.rawText,
    this.confidence = 0.9,
  });

  ParsedTransactionDraft copyWith({
    Money? amount,
    TransactionType? type,
    String? description,
    String? categoryId,
    String? paymentMethod,
    DateTime? date,
    String? rawText,
    double? confidence,
  }) {
    return ParsedTransactionDraft(
      amount: amount ?? this.amount,
      type: type ?? this.type,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      date: date ?? this.date,
      rawText: rawText ?? this.rawText,
      confidence: confidence ?? this.confidence,
    );
  }
}

/// Offline parser that converts raw bank SMS alerts, copy-pasted notifications,
/// and natural language one-liners into structured transaction drafts.
class SmartTransactionParser {
  SmartTransactionParser._();

  // Category keyword mappings
  static final Map<String, List<String>> _categoryKeywords = {
    'cat_food': [
      'coffee',
      'cafe',
      'starbucks',
      'chai',
      'tea',
      'lunch',
      'dinner',
      'breakfast',
      'restaurant',
      'swiggy',
      'zomato',
      'mcdonald',
      'burger',
      'pizza',
      'kfc',
      'domino',
      'food',
      'snack',
      'bakery',
      'biryani',
      'dhabba',
      'subway',
    ],
    'cat_groceries': [
      'grocery',
      'groceries',
      'supermarket',
      'blinkit',
      'zepto',
      'instamart',
      'bigbasket',
      'dmart',
      'milk',
      'veggies',
      'fruits',
      'vegetable',
      'provisions',
      'mart',
    ],
    'cat_transport': [
      'uber',
      'ola',
      'rapido',
      'cab',
      'taxi',
      'metro',
      'train',
      'bus',
      'fuel',
      'petrol',
      'diesel',
      'parking',
      'toll',
      'fastag',
      'auto',
      'flight',
      'irctc',
    ],
    'cat_bills': [
      'electricity',
      'water',
      'gas',
      'broadband',
      'wifi',
      'recharge',
      'jio',
      'airtel',
      'bill',
      'bescom',
      'utility',
      'postpaid',
      'cylinder',
    ],
    'cat_shopping': [
      'amazon',
      'flipkart',
      'myntra',
      'clothes',
      'shoes',
      'electronics',
      'mall',
      'zara',
      'h&m',
      'shopping',
      'ajio',
      'meesho',
      'store',
    ],
    'cat_entertainment': [
      'netflix',
      'spotify',
      'prime',
      'cinema',
      'movie',
      'tickets',
      'pvr',
      'bookmyshow',
      'gaming',
      'steam',
      'youtube',
    ],
    'cat_health': [
      'pharmacy',
      'medicine',
      'medicines',
      'doctor',
      'hospital',
      'clinic',
      '1mg',
      'apollo',
      'lab',
      'gym',
      'fitness',
      'health',
      'dental',
    ],
    'cat_housing': [
      'rent',
      'housing',
      'landlord',
      'maintenance',
      'flat',
      'society',
    ],
    'cat_salary': ['salary', 'payroll', 'stipend', 'wages'],
    'cat_freelance': [
      'freelance',
      'client',
      'project',
      'consulting',
      'upwork',
      'fiverr',
      'invoice',
    ],
  };

  /// Parses input text (which can contain a single one-liner, a single bank SMS,
  /// or multiple SMS messages separated by newlines) into a list of transaction drafts.
  static List<ParsedTransactionDraft> parse(
    String input, {
    DateTime? fallbackDate,
  }) {
    final cleanInput = input.trim();
    if (cleanInput.isEmpty) return [];

    final baseDate = fallbackDate ?? DateTime.now();

    // Check if input contains multiple distinct bank alerts separated by multiple newlines
    final segments = cleanInput
        .split(RegExp(r'\n{2,}'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (segments.length > 1) {
      final results = <ParsedTransactionDraft>[];
      for (final segment in segments) {
        final parsed = _parseSingle(segment, baseDate);
        if (parsed != null) results.add(parsed);
      }
      if (results.isNotEmpty) return results;
    }

    // Check if multiple single-line quick entries: e.g. "Coffee 120\nMetro 40\nLunch 250"
    final lines = cleanInput
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.length > 1 && !_isBankSms(cleanInput)) {
      final results = <ParsedTransactionDraft>[];
      for (final line in lines) {
        final parsed = _parseSingle(line, baseDate);
        if (parsed != null) results.add(parsed);
      }
      if (results.isNotEmpty) return results;
    }

    // Otherwise parse as a single entry or SMS
    final single = _parseSingle(cleanInput, baseDate);
    return single != null ? [single] : [];
  }

  static bool _isBankSms(String text) {
    final lower = text.toLowerCase();
    return lower.contains('debited') ||
        lower.contains('credited') ||
        lower.contains('a/c') ||
        lower.contains('acct') ||
        lower.contains('vpa') ||
        lower.contains('txn') ||
        lower.contains('spent on');
  }

  static ParsedTransactionDraft? _parseSingle(String text, DateTime baseDate) {
    if (text.trim().isEmpty) return null;

    if (_isBankSms(text)) {
      return _parseBankSms(text, baseDate);
    } else {
      return _parseOneLiner(text, baseDate);
    }
  }

  /// Parses bank SMS / card / UPI debit and credit alerts
  static ParsedTransactionDraft? _parseBankSms(String text, DateTime baseDate) {
    final lower = text.toLowerCase();

    // 1. Determine Type
    final isIncome = lower.contains('credited') ||
        lower.contains('deposited') ||
        lower.contains('refund') ||
        (lower.contains('salary') && !lower.contains('debited'));
    final type = isIncome ? TransactionType.income : TransactionType.expense;

    // 2. Extract Amount
    double? amountVal;
    final amountPatterns = [
      RegExp(
        r'(?:rs\.?|inr|₹|\$)\s*([0-9]+(?:,[0-9]+)*(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:debited|credited|spent|paid)\s*(?:by|for|with)?\s*(?:rs\.?|inr|₹|\$)?\s*([0-9]+(?:,[0-9]+)*(?:\.[0-9]{1,2})?)',
        caseSensitive: false,
      ),
      RegExp(r'\b(?:inr|rs\.?)\s*([0-9]+(?:\.[0-9]{1,2})?)\b', caseSensitive: false),
    ];

    for (final pattern in amountPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        final rawNum = match.group(1)!.replaceAll(',', '');
        amountVal = double.tryParse(rawNum);
        if (amountVal != null && amountVal > 0) break;
      }
    }

    if (amountVal == null || amountVal <= 0) return null;
    final amount = Money((amountVal * 100).round());

    // 3. Extract Payment Method
    String paymentMethod = 'card';
    if (lower.contains('upi') ||
        lower.contains('vpa') ||
        lower.contains('gpay') ||
        lower.contains('phonepe') ||
        lower.contains('paytm')) {
      paymentMethod = 'upi';
    } else if (lower.contains('credit card') || lower.contains('cc ending')) {
      paymentMethod = 'credit_card';
    } else if (lower.contains('debit card') || lower.contains('atm')) {
      paymentMethod = 'debit_card';
    } else if (lower.contains('netbanking') ||
        lower.contains('imps') ||
        lower.contains('neft') ||
        lower.contains('rtgs') ||
        lower.contains('transfer')) {
      paymentMethod = 'bank_transfer';
    }

    // 4. Extract Merchant / Payee
    String merchant = '';
    final merchantPatterns = [
      RegExp(
        r'(?:at|to|towards|vpa|info)\s+([a-zA-Z0-9\s&_.-]{2,25})',
        caseSensitive: false,
      ),
      RegExp(r'(?:paid to)\s+([a-zA-Z0-9\s&_.-]{2,25})', caseSensitive: false),
    ];

    for (final mp in merchantPatterns) {
      final match = mp.firstMatch(text);
      if (match != null && match.group(1) != null) {
        var rawM = match.group(1)!.trim();
        // Clean trailing noise like "on 04-Nov", "ref", "using", "avl", "bal"
        final noiseCut = rawM.split(
          RegExp(r'\b(on|ref|using|avl|bal|date|via|with)\b', caseSensitive: false),
        );
        merchant = noiseCut.first.trim();
        if (merchant.isNotEmpty) break;
      }
    }

    if (merchant.isEmpty) {
      merchant = isIncome ? 'Income Deposit' : 'Bank Transaction';
    } else {
      // Capitalize nicely
      merchant = _capitalizeWords(merchant);
    }

    // 5. Extract Date
    final parsedDate = _extractDate(text, baseDate);

    // 6. Match Category
    final categoryId = matchCategory(
      '$merchant $text',
      isIncome: isIncome,
    );

    return ParsedTransactionDraft(
      amount: amount,
      type: type,
      description: merchant,
      categoryId: categoryId,
      paymentMethod: paymentMethod,
      date: parsedDate,
      rawText: text,
      confidence: 0.95,
    );
  }

  /// Parses quick one-liners: e.g. "Coffee 120", "Uber 350 card yesterday", "Salary 50000 1 nov"
  static ParsedTransactionDraft? _parseOneLiner(String text, DateTime baseDate) {
    var working = text.trim();
    if (working.isEmpty) return null;

    // 1. Detect Type & Payment Method keywords
    var type = TransactionType.expense;
    var paymentMethod = 'cash';

    final lower = working.toLowerCase();
    if (lower.contains('income') || lower.contains('salary')) {
      type = TransactionType.income;
    }

    if (lower.contains('upi') || lower.contains('gpay') || lower.contains('paytm')) {
      paymentMethod = 'upi';
    } else if (lower.contains('card') || lower.contains('cc')) {
      paymentMethod = 'card';
    } else if (lower.contains('bank') || lower.contains('transfer')) {
      paymentMethod = 'bank_transfer';
    } else if (lower.contains('cash')) {
      paymentMethod = 'cash';
    }

    // 2. Extract Date (yesterday, 2 days ago, etc.)
    final parsedDate = _extractDate(working, baseDate);

    // 3. Extract Amount
    double? amountVal;
    final numMatch = RegExp(r'\b([0-9]+(?:\.[0-9]{1,2})?)\b').allMatches(working);
    // Find the number that represents the amount
    for (final m in numMatch) {
      final val = double.tryParse(m.group(1)!);
      if (val != null && val > 0) {
        amountVal = val;
        // remove the number from working text to leave the description
        working = working.replaceFirst(m.group(1)!, ' ');
        break;
      }
    }

    if (amountVal == null || amountVal <= 0) return null;
    final amount = Money((amountVal * 100).round());

    // 4. Clean remaining words to form Description
    // Remove payment, date, currency words
    final noiseWords = RegExp(
      r'\b(yesterday|today|days?|ago|cash|card|upi|gpay|bank|transfer|income|expense|rs\.?|inr|₹|\$)\b',
      caseSensitive: false,
    );
    var description = working.replaceAll(noiseWords, ' ').trim();
    // remove multiple spaces
    description = description.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (description.isEmpty) {
      description = type == TransactionType.income ? 'Income' : 'Expense';
    } else {
      description = _capitalizeWords(description);
    }

    // 5. Match Category
    final categoryId = matchCategory(
      '$description $text',
      isIncome: type == TransactionType.income,
    );

    return ParsedTransactionDraft(
      amount: amount,
      type: type,
      description: description,
      categoryId: categoryId,
      paymentMethod: paymentMethod,
      date: parsedDate,
      rawText: text,
      confidence: 0.85,
    );
  }

  static DateTime _extractDate(String text, DateTime baseDate) {
    final lower = text.toLowerCase();

    if (lower.contains('yesterday')) {
      return DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day - 1,
        baseDate.hour,
        baseDate.minute,
      );
    }

    final daysAgoMatch = RegExp(r'(\d+)\s+days?\s+ago').firstMatch(lower);
    if (daysAgoMatch != null) {
      final days = int.tryParse(daysAgoMatch.group(1)!) ?? 1;
      return DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day - days,
        baseDate.hour,
        baseDate.minute,
      );
    }

    // Match DD-MMM-YY or DD-MMM-YYYY or DD/MM/YYYY: e.g. "04-Nov-26", "04/11/26", "4 Nov"
    final dateMatch = RegExp(
      r'\b(\d{1,2})[-/ ](Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|\d{1,2})[-/ ]?(\d{2,4})?\b',
      caseSensitive: false,
    ).firstMatch(text);

    if (dateMatch != null) {
      final day = int.tryParse(dateMatch.group(1)!) ?? baseDate.day;
      final rawMonth = dateMatch.group(2)!;
      final rawYear = dateMatch.group(3);

      int month = baseDate.month;
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
        month = int.tryParse(rawMonth) ?? baseDate.month;
      }

      var year = baseDate.year;
      if (rawYear != null) {
        final yVal = int.tryParse(rawYear) ?? baseDate.year;
        year = yVal < 100 ? (2000 + yVal) : yVal;
      }

      return DateTime(year, month, day, baseDate.hour, baseDate.minute);
    }

    return baseDate;
  }

  /// Matches a category ID based on description and transaction type.
  static String matchCategory(String text, {required bool isIncome}) {
    final lower = text.toLowerCase();

    if (isIncome) {
      if (lower.contains('salary') || lower.contains('payroll')) {
        return 'cat_salary';
      }
      if (lower.contains('freelance') ||
          lower.contains('consulting') ||
          lower.contains('invoice')) {
        return 'cat_freelance';
      }
      return 'cat_other_income';
    }

    for (final entry in _categoryKeywords.entries) {
      for (final kw in entry.value) {
        if (lower.contains(kw)) {
          return entry.key;
        }
      }
    }

    return 'cat_other_expense';
  }

  static String _capitalizeWords(String input) {
    if (input.isEmpty) return input;
    return input
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
}

