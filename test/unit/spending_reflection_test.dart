import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind_and_money/core/database/app_database.dart';
import 'package:mind_and_money/core/database/tables.dart';
import 'package:mind_and_money/features/finance/repositories/transaction_repository.dart';
import 'package:mind_and_money/features/wellness/data/spending_reflection_repository.dart';
import 'package:mind_and_money/features/wellness/models/spending_reflection.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase database;
  late SpendingReflectionRepository reflectionRepo;
  late TransactionRepository transactionRepo;
  late String testDbPath;
  late Database rawDb;

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp(
      'spending_refl_test_',
    );
    testDbPath = p.join(tempDir.path, 'spending_refl_test.db');

    rawDb = await databaseFactoryFfi.openDatabase(
      testDbPath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, version) async {
          final batch = db.batch();
          batch.execute(DbTables.createCategoriesTable);
          batch.execute(DbTables.createTransactionsTable);
          batch.execute(DbTables.createSpendingReflectionsTable);
          batch.execute(
            'CREATE INDEX idx_spending_reflections_tx ON ${DbTables.spendingReflections} (transaction_id);',
          );
          await batch.commit();
        },
      ),
    );

    database = AppDatabase();
    database.setDatabaseForTesting(rawDb);
    reflectionRepo = SpendingReflectionRepository(database);
    transactionRepo = TransactionRepository(database);

    // Seed test category & transaction
    await rawDb.insert(DbTables.categories, {
      'id': 'cat_dining',
      'name': 'Dining',
      'icon': 'restaurant',
      'color': 4287661230,
      'type': 'expense',
      'is_default': 1,
      'created_at': DateTime.now().toIso8601String(),
    });

    await rawDb.insert(DbTables.transactions, {
      'id': 'tx_101',
      'amount_cents': 3500,
      'type': 'expense',
      'category_id': 'cat_dining',
      'transaction_date': '2026-10-28T12:00:00.000',
      'description': 'Lunch',
      'payment_method': 'card',
      'note': null,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  });

  tearDown(() async {
    await database.close();
    final file = File(testDbPath);
    if (await file.exists()) {
      await file.delete();
    }
  });

  group('SpendingReflectionRepository Tests', () {
    test('Creates and retrieves reflection linked to transaction', () async {
      final now = DateTime.now();
      final reflection = SpendingReflection(
        id: 'refl_1',
        transactionId: 'tx_101',
        feeling: 'Calm',
        wasPlanned: true,
        spendingNature: 'necessary',
        notes: 'Planned lunch with teammate',
        createdAt: now,
        updatedAt: now,
      );

      await reflectionRepo.createReflection(reflection);

      final fetched = await reflectionRepo.getReflectionForTransaction(
        'tx_101',
      );
      expect(fetched, isNotNull);
      expect(fetched!.feeling, 'Calm');
      expect(fetched.wasPlanned, isTrue);
      expect(fetched.spendingNature, 'necessary');
      expect(fetched.natureLabel, 'Necessary');
      expect(fetched.notes, 'Planned lunch with teammate');
    });

    test('Updates reflection fields', () async {
      final now = DateTime.now();
      final reflection = SpendingReflection(
        id: 'refl_update',
        transactionId: 'tx_101',
        feeling: 'Impulsive',
        wasPlanned: false,
        spendingNature: 'optional',
        createdAt: now,
        updatedAt: now,
      );
      await reflectionRepo.createReflection(reflection);

      final updated = reflection.copyWith(
        feeling: 'Content',
        wasPlanned: true,
        notes: 'Reflected later and felt fine',
        updatedAt: DateTime.now(),
      );
      await reflectionRepo.updateReflection(updated);

      final fetched = await reflectionRepo.getReflectionForTransaction(
        'tx_101',
      );
      expect(fetched!.feeling, 'Content');
      expect(fetched.wasPlanned, isTrue);
      expect(fetched.notes, 'Reflected later and felt fine');
    });

    test(
      'Transaction deletion cleanly removes linked spending reflection',
      () async {
        final now = DateTime.now();
        final reflection = SpendingReflection(
          id: 'refl_cascade',
          transactionId: 'tx_101',
          feeling: 'Stressed',
          wasPlanned: false,
          spendingNature: 'impulsive',
          createdAt: now,
          updatedAt: now,
        );
        await reflectionRepo.createReflection(reflection);

        // Verify reflection exists
        expect(
          await reflectionRepo.getReflectionForTransaction('tx_101'),
          isNotNull,
        );

        // Delete parent transaction using transactionRepo
        await transactionRepo.deleteTransaction('tx_101');

        // Verify transaction is deleted
        final txRow = await rawDb.query(
          DbTables.transactions,
          where: 'id = ?',
          whereArgs: ['tx_101'],
        );
        expect(txRow.isEmpty, isTrue);

        // Verify linked reflection is also removed without leaving dangling references
        final remainingRefl = await reflectionRepo.getReflectionForTransaction(
          'tx_101',
        );
        expect(remainingRefl, isNull);
      },
    );

    test('Computes aggregate spending reflection metrics', () async {
      final now = DateTime.now();

      // Insert extra transaction and reflections
      await rawDb.insert(DbTables.transactions, {
        'id': 'tx_102',
        'amount_cents': 1500,
        'type': 'expense',
        'category_id': 'cat_dining',
        'transaction_date': '2026-10-28T13:00:00.000',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await reflectionRepo.createReflection(
        SpendingReflection(
          id: 'refl_a',
          transactionId: 'tx_101',
          feeling: 'Calm',
          wasPlanned: true,
          spendingNature: 'necessary',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await reflectionRepo.createReflection(
        SpendingReflection(
          id: 'refl_b',
          transactionId: 'tx_102',
          feeling: 'Impulsive',
          wasPlanned: false,
          spendingNature: 'impulsive',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final summary = await reflectionRepo.getSummary();
      expect(summary.totalReflections, 2);
      expect(summary.plannedCount, 1);
      expect(summary.unplannedCount, 1);
      expect(summary.natureCounts['necessary'], 1);
      expect(summary.natureCounts['impulsive'], 1);
      expect(summary.feelingCounts['Calm'], 1);
      expect(summary.feelingCounts['Impulsive'], 1);
    });
  });
}
