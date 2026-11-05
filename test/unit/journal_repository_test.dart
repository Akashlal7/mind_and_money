import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind_and_money/core/database/app_database.dart';
import 'package:mind_and_money/core/database/tables.dart';
import 'package:mind_and_money/features/wellness/data/journal_repository.dart';
import 'package:mind_and_money/features/wellness/models/journal_entry.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase database;
  late JournalRepository repository;
  late String testDbPath;
  late Database rawDb;

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('journal_repo_test_');
    testDbPath = p.join(tempDir.path, 'journal_test.db');

    rawDb = await databaseFactoryFfi.openDatabase(
      testDbPath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, version) async {
          final batch = db.batch();
          batch.execute(DbTables.createJournalEntriesTable);
          batch.execute(
            'CREATE INDEX idx_journal_date ON ${DbTables.journalEntries} (entry_date);',
          );
          batch.execute(
            'CREATE INDEX idx_journal_type ON ${DbTables.journalEntries} (entry_type);',
          );
          await batch.commit();
        },
      ),
    );

    database = AppDatabase();
    database.setDatabaseForTesting(rawDb);
    repository = JournalRepository(database);
  });

  tearDown(() async {
    await database.close();
    final file = File(testDbPath);
    if (await file.exists()) {
      await file.delete();
    }
  });

  group('JournalRepository CRUD, Search, & Reflections Tests', () {
    test('Creates and retrieves journal entry preserving line breaks and formatting', () async {
      final now = DateTime.now();
      const multilineText =
          'First line of thoughts.\n\nSecond paragraph with reflection.\n- Bullet point 1\n- Bullet point 2';

      final entry = JournalEntry(
        id: 'jrn_1',
        title: 'Morning Mindfulness',
        content: multilineText,
        moodRating: 4,
        entryDate: '2026-10-28',
        entryType: 'journal',
        createdAt: now,
        updatedAt: now,
      );

      await repository.createEntry(entry);

      final fetched = await repository.getEntryById('jrn_1');
      expect(fetched, isNotNull);
      expect(fetched!.title, 'Morning Mindfulness');
      expect(fetched.content, multilineText);
      expect(fetched.moodRating, 4);
      expect(fetched.isReflection, isFalse);
    });

    test('Creates gratitude reflection with prompt and retrieves via entryType filter', () async {
      final now = DateTime.now();
      final reflection = JournalEntry(
        id: 'refl_1',
        title: null,
        content: 'I appreciate my morning coffee and quiet conversation with family.',
        moodRating: 5,
        entryDate: '2026-10-28',
        entryType: 'reflection',
        prompt: 'What is one thing you appreciate today?',
        createdAt: now,
        updatedAt: now,
      );

      await repository.createEntry(reflection);

      final fetched = await repository.getEntryById('refl_1');
      expect(fetched, isNotNull);
      expect(fetched!.isReflection, isTrue);
      expect(fetched.prompt, 'What is one thing you appreciate today?');

      // Filter by type
      final reflectionsOnly = await repository.getEntries(
        entryType: 'reflection',
      );
      expect(reflectionsOnly.length, 1);
      expect(reflectionsOnly.first.id, 'refl_1');

      final journalsOnly = await repository.getEntries(entryType: 'journal');
      expect(journalsOnly.isEmpty, isTrue);
    });

    test(
      'Searches entries locally across title, content, and prompt',
      () async {
        final now = DateTime.now();
        await repository.createEntry(
          JournalEntry(
            id: 'jrn_search_1',
            title: 'Financial Independence Plan',
            content: 'Focusing on reducing impulse purchases.',
            entryDate: '2026-10-25',
            createdAt: now,
            updatedAt: now,
          ),
        );
        await repository.createEntry(
          JournalEntry(
            id: 'jrn_search_2',
            title: 'Evening Relax',
            content: 'Deep breathing practice in the garden.',
            entryDate: '2026-10-26',
            createdAt: now,
            updatedAt: now,
          ),
        );
        await repository.createEntry(
          JournalEntry(
            id: 'refl_search_3',
            content: 'The sunrise was beautiful today.',
            entryDate: '2026-10-27',
            entryType: 'reflection',
            prompt: 'What helped you feel calm today?',
            createdAt: now,
            updatedAt: now,
          ),
        );

        // Search by keyword in title
        final titleMatch = await repository.getEntries(query: 'Independence');
        expect(titleMatch.length, 1);
        expect(titleMatch.first.id, 'jrn_search_1');

        // Search by keyword in content
        final contentMatch = await repository.getEntries(query: 'garden');
        expect(contentMatch.length, 1);
        expect(contentMatch.first.id, 'jrn_search_2');

        // Search by keyword in prompt
        final promptMatch = await repository.getEntries(query: 'calm');
        expect(promptMatch.length, 1);
        expect(promptMatch.first.id, 'refl_search_3');
      },
    );

    test('Updates and deletes journal entries cleanly', () async {
      final entry = JournalEntry(
        id: 'jrn_edit',
        title: 'Original Title',
        content: 'Original content',
        entryDate: '2026-10-28',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.createEntry(entry);

      final updated = entry.copyWith(
        title: 'Updated Title',
        content: 'Updated content with deeper insight',
        updatedAt: DateTime.now(),
      );
      await repository.updateEntry(updated);

      final fetched = await repository.getEntryById('jrn_edit');
      expect(fetched!.title, 'Updated Title');
      expect(fetched.content, 'Updated content with deeper insight');

      await repository.deleteEntry('jrn_edit');
      final afterDelete = await repository.getEntryById('jrn_edit');
      expect(afterDelete, isNull);
    });

    test('Privacy rule: toString redacts sensitive journal body and title', () {
      final entry = JournalEntry(
        id: 'jrn_secret',
        title: 'Super Secret Personal Diary',
        content: 'Highly confidential personal thoughts and sensitive feelings',
        entryDate: '2026-10-28',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final str = entry.toString();
      expect(str.contains('Super Secret'), isFalse);
      expect(str.contains('Highly confidential'), isFalse);
      expect(str.contains('REDACTED'), isTrue);
    });
  });
}
