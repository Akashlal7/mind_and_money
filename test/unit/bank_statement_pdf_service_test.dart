import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind_and_money/features/finance/models/transaction.dart';
import 'package:mind_and_money/features/finance/services/bank_statement_pdf_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  group('BankStatementPdfService — Statement Text Parsing', () {
    test('Parses multi-row bank statement text into transactions', () {
      const sampleStatement = '''
HDFC BANK ACCOUNT STATEMENT
Account Number: 50100491029102
Period: 01/11/2026 to 05/11/2026

Date       Narration                          Chq/Ref No    Amount       Balance
01/11/2026 UPI/STARBUCKS/53910291             REF98201      340.00       14,660.00
02/11/2026 POS 4102 AMAZON INDIA              POS2910       1,499.00     13,161.00
03/11/2026 SWIGGY BANGALORE                   UPI3910       420.00       12,741.00
04/11/2026 SALARY CREDIT EMPLOYER LTD         NEFT991       65,000.00 CR 77,741.00
05/11/2026 ATM WDL CASH                       ATM492        2,000.00     75,741.00
''';

      final result = BankStatementPdfService.parseStatementText(sampleStatement);

      expect(result.isSuccess, isTrue);
      expect(result.bankName, 'HDFC Bank');
      expect(result.transactions, hasLength(5));

      // 1. Starbucks expense
      final t1 = result.transactions[0];
      expect(t1.description, contains('Starbucks'));
      expect(t1.amount.cents, 34000); // 340.00
      expect(t1.type, TransactionType.expense);
      expect(t1.categoryId, 'cat_food');
      expect(t1.date.day, 1);
      expect(t1.date.month, 11);

      // 2. Amazon expense
      final t2 = result.transactions[1];
      expect(t2.description, contains('Amazon'));
      expect(t2.amount.cents, 149900); // 1,499.00
      expect(t2.type, TransactionType.expense);
      expect(t2.categoryId, 'cat_shopping');

      // 3. Swiggy expense
      final t3 = result.transactions[2];
      expect(t3.description, contains('Swiggy'));
      expect(t3.amount.cents, 42000); // 420.00
      expect(t3.type, TransactionType.expense);

      // 4. Salary credit
      final t4 = result.transactions[3];
      expect(t4.description, contains('Salary'));
      expect(t4.amount.cents, 6500000); // 65,000.00
      expect(t4.type, TransactionType.income);
      expect(t4.categoryId, 'cat_salary');

      // 5. ATM cash withdrawal
      final t5 = result.transactions[4];
      expect(t5.amount.cents, 200000); // 2,000.00
      expect(t5.paymentMethod, 'cash');
      expect(t5.type, TransactionType.expense);

      // Totals
      expect(result.totalCredits.cents, 6500000);
      expect(result.totalDebits.cents, 34000 + 149900 + 42000 + 200000);
    });

    test('Parses State Bank of India statement with DD-MMM-YYYY dates', () {
      const sbiStatement = '''
STATE BANK OF INDIA
Account Statement for 01-Nov-2026 to 03-Nov-2026
Txn Date    Details                      Amount       Type
01-Nov-2026 METRO CARD RECHARGE          500.00       DR
02-Nov-2026 GROCERY BLINKIT STORE        850.50       DR
''';

      final result = BankStatementPdfService.parseStatementText(sbiStatement);

      expect(result.isSuccess, isTrue);
      expect(result.bankName, 'State Bank of India');
      expect(result.transactions, hasLength(2));
      expect(result.transactions[0].amount.cents, 50000);
      expect(result.transactions[0].categoryId, 'cat_transport');
      expect(result.transactions[1].amount.cents, 85050);
      expect(result.transactions[1].categoryId, 'cat_groceries');
    });
  });

  group('BankStatementPdfService — PDF Binary Extraction', () {
    test('Generates in-memory PDF and successfully parses transactions', () async {
      // Create a valid PDF document in memory using syncfusion_flutter_pdf
      final pdfDocument = PdfDocument();
      final page = pdfDocument.pages.add();

      const text = '''
AXIS BANK STATEMENT
01/11/2026 UPI/ZOMATO/49102 450.00
02/11/2026 UBER RIDE MUMBAI 320.00
03/11/2026 FREELANCE INVOICE PAYMENT 15,000.00 CR
''';

      page.graphics.drawString(
        text,
        PdfStandardFont(PdfFontFamily.helvetica, 12),
      );

      final pdfBytes = pdfDocument.saveSync();
      pdfDocument.dispose();

      final result = await BankStatementPdfService.parsePdfBytes(
        Uint8List.fromList(pdfBytes),
      );

      expect(result.isSuccess, isTrue);
      expect(result.bankName, 'Axis Bank');
      expect(result.transactions, hasLength(3));
      expect(result.transactions[0].description, contains('Zomato'));
      expect(result.transactions[0].amount.cents, 45000);
      expect(result.transactions[1].description, contains('Uber'));
      expect(result.transactions[1].amount.cents, 32000);
      expect(result.transactions[2].type, TransactionType.income);
      expect(result.transactions[2].amount.cents, 1500000);
    });
  });
}
