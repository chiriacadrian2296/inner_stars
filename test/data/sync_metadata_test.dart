import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:inner_stars/data/constellation_shape.dart';
import 'package:inner_stars/data/custom_constellation_repository.dart';
import 'package:inner_stars/data/habit_completion_repository.dart';
import 'package:inner_stars/data/habit_cycle_repository.dart';
import 'package:inner_stars/data/habit_repository.dart';
import 'package:inner_stars/data/local_data_migration.dart';
import 'package:inner_stars/data/project_repository.dart';
import 'package:inner_stars/data/reflection_answer_repository.dart';
import 'package:inner_stars/data/star_repository.dart';
import 'package:inner_stars/data/uuid_migration.dart';
import 'package:inner_stars/models/life_area.dart';

class _FailingStore extends InMemorySharedPreferencesStore {
  _FailingStore(Map<String, Object> data, this.key, {this.throwsError = false})
    : super.withData({
        for (final entry in data.entries) 'flutter.${entry.key}': entry.value,
      });
  final String key;
  final bool throwsError;
  bool armed = true;
  @override
  Future<bool> setValue(String valueType, String storageKey, Object value) {
    if (armed && storageKey == 'flutter.$key') {
      armed = false;
      if (throwsError) throw StateError('Simulated write failure');
      return Future.value(false);
    }
    return super.setValue(valueType, storageKey, value);
  }
}

Map<String, Object> snapshot(SharedPreferences prefs) => {
  for (final key in prefs.getKeys()) key: prefs.get(key)!,
};

Future<void> seed(SharedPreferences prefs) async {
  final projects = ProjectRepository(prefs);
  final shapes = StarsShapeRepository(prefs);
  final shape = await shapes.add(
    name: 'Shape',
    shape: const ConstellationShape(points: [], edges: []),
  );
  final project = await projects.add(
    name: 'Project',
    area: LifeArea.personal,
    iconSlug: '',
    starsShapeId: shape.id,
  );
  await StarRepository(prefs).add(title: 'Goal', projectId: project.id);
  final habit = await HabitRepository(prefs)
      .add(title: 'Habit', projectId: project.id, cycleLength: 1);
  final completions = HabitCompletionRepository(prefs);
  await completions.markDone(habit.id);
  await HabitCycleRepository(prefs).sync(habit, completions.getAll());
  await ReflectionAnswerRepository(prefs)
      .setAnswer(LifeArea.personal, '0', answerText: 'Answer');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('returned records have the persisted clock; unrelated and no-op saves do not change it', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ProjectRepository(prefs);
    final start = DateTime.now().toUtc();
    final first = await repo.add(
      name: 'First',
      area: LifeArea.personal,
      iconSlug: '',
    );
    expect(first.updatedAt.isBefore(start), isFalse);
    final second = await repo.add(
      name: 'Second',
      area: LifeArea.personal,
      iconSlug: '',
    );
    expect(
      repo.getAll().singleWhere((p) => p.id == first.id).updatedAt,
      first.updatedAt,
    );
    final renamed = await repo.renameProject(
      projectId: first.id,
      name: 'Renamed',
    );
    expect(renamed.updatedAt.isAfter(first.updatedAt), isTrue);
    expect(repo.getAll().singleWhere((p) => p.id == first.id), renamed);
    expect(
      repo.getAll().singleWhere((p) => p.id == second.id).updatedAt,
      second.updatedAt,
    );
    final same = await repo.renameProject(projectId: first.id, name: 'Renamed');
    expect(same.updatedAt, renamed.updatedAt);
  });

  test(
    'clocks advance even when the previous timestamp is in the future',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = ProjectRepository(prefs);
      final first = await repo.add(
        name: 'First',
        area: LifeArea.personal,
        iconSlug: '',
      );
      final future = first.copyWith(
        updatedAt: DateTime.now().toUtc().add(const Duration(days: 1)),
      );
      await prefs.setString('projects-list', jsonEncode([future.toJson()]));
      final renamed = await repo.renameProject(
        projectId: first.id,
        name: 'Renamed',
      );
      expect(renamed.updatedAt.isAfter(future.updatedAt), isTrue);
    },
  );

  test('permanent deletions stay hidden and survive unrelated writes and repeated clears', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ProjectRepository(prefs);
    final first = await repo.add(
      name: 'First',
      area: LifeArea.personal,
      iconSlug: '',
    );
    await repo.delete(first.id);
    final tombstone = repo.getAll(includeDeleted: true).single;
    expect(tombstone.deleted, isTrue);
    expect(tombstone.updatedAt.isAfter(first.updatedAt), isTrue);
    expect(repo.getProjectsForArea(LifeArea.personal), isEmpty);
    await repo.add(name: 'Second', area: LifeArea.personal, iconSlug: '');
    expect(
      repo.getAll(includeDeleted: true).singleWhere((p) => p.id == first.id),
      tombstone,
    );
    await repo.clear();
    expect(repo.getAll(), isEmpty);
    final cleared = repo.getAll(includeDeleted: true);
    expect(cleared, hasLength(2));
    expect(cleared.every((p) => p.deleted), isTrue);
    await repo.clear();
    expect(repo.getAll(includeDeleted: true), cleared);
  });

  test(
    'activity archiving remains distinct from project deletion and reset',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await seed(prefs);
      final stars = StarRepository(prefs);
      final habits = HabitRepository(prefs);
      final completions = HabitCompletionRepository(prefs);
      final projectId = ProjectRepository(prefs).getAll().single.id;
      final archivedStar = await stars.delete(stars.getAll().single.id);
      final archivedHabit = await habits.delete(habits.getAll().single.id);
      expect(archivedStar.dead && !archivedStar.deleted, isTrue);
      expect(archivedHabit.dead && !archivedHabit.deleted, isTrue);
      expect(stars.getAll(), hasLength(1));
      expect(habits.getAll(), hasLength(1));
      expect(completions.getAll(), hasLength(1));
      await stars.deleteAllForProject(projectId);
      final habitIds = await habits.deleteAllForProject(projectId);
      for (final id in habitIds) {
        await completions.deleteAllForHabit(id);
      }
      final cycles = HabitCycleRepository(prefs);
      await cycles.deleteAllForHabits(habitIds);
      expect(stars.getAll(), isEmpty);
      expect(habits.getAll(), isEmpty);
      expect(completions.getAll(), isEmpty);
      expect(cycles.getAll(), isEmpty);
      expect(stars.getAll(includeDeleted: true).single.deleted, isTrue);
      expect(habits.getAll(includeDeleted: true).single.deleted, isTrue);
      expect(completions.getAll(includeDeleted: true).single.deleted, isTrue);
      expect(cycles.getAll(includeDeleted: true).single.deleted, isTrue);
    },
  );

  test(
    'undoing a check-in keeps its tombstone when a new check-in is added',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = HabitCompletionRepository(prefs);
      final day = DateTime(2026, 10, 19);
      await repo.markDone('habit', date: day);
      final first = repo.getAll().single;
      await repo.unmarkDone('habit', day);
      expect(repo.getAllForHabit('habit'), isEmpty);
      await repo.markDone('habit', date: day);
      expect(repo.getAll().single.id, isNot(first.id));
      expect(repo.getAll(includeDeleted: true), hasLength(2));
      expect(
        repo
            .getAll(includeDeleted: true)
            .singleWhere((c) => c.id == first.id)
            .deleted,
        isTrue,
      );
    },
  );

  test('undoing a completed cycle leaves a tombstone rather than losing its identity', () async {
    final prefs = await SharedPreferences.getInstance();
    await seed(prefs);
    final repo = HabitCycleRepository(prefs);
    final habit = HabitRepository(prefs).getAll().single;
    final first = repo.getAll().single;
    await repo.sync(habit, []);
    expect(repo.pendingFor(habit.id), isNull);
    expect(repo.getAll(includeDeleted: true).single.id, first.id);
    expect(repo.getAll(includeDeleted: true).single.deleted, isTrue);
  });

  test(
    'clear hides shapes and reflections while retaining their sync records',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await seed(prefs);
      final shapes = StarsShapeRepository(prefs);
      final answers = ReflectionAnswerRepository(prefs);
      final shapeId = shapes.getAll().single.id;
      await shapes.clear();
      await answers.setAnswer(LifeArea.personal, '0', answerText: ' ');
      expect(shapes.getById(shapeId), isNull);
      expect(shapes.getAll(includeDeleted: true).single.deleted, isTrue);
      expect(answers.getAnswer(LifeArea.personal, '0'), isNull);
      expect(answers.getAnswersForArea(LifeArea.personal), isEmpty);
      expect(
        answers.getAll(includeDeleted: true).values.single.deleted,
        isTrue,
      );
      final before = answers
          .getAll(includeDeleted: true)
          .values
          .single
          .updatedAt;
      await answers.setAnswer(
        LifeArea.physical,
        '1',
        answerText: 'Another area',
      );
      expect(
        answers.getAll(includeDeleted: true)['personal|0']!.updatedAt,
        before,
      );
      await answers.clear();
      expect(answers.getAll(), isEmpty);
      expect(answers.getAll(includeDeleted: true), hasLength(2));
    },
  );

  test(
    'failed writes restore data and timestamps without notifying readers',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = ProjectRepository(prefs);
      final first = await repo.add(
        name: 'First',
        area: LifeArea.personal,
        iconSlug: '',
      );
      final before = snapshot(prefs);
      final store = SharedPreferencesStorePlatform.instance;
      addTearDown(() => SharedPreferencesStorePlatform.instance = store);
      SharedPreferencesStorePlatform.instance = _FailingStore(
        before,
        'projects-list',
      );
      var notifications = 0;
      repo.addListener(() => notifications++);
      await expectLater(repo.delete(first.id), throwsStateError);
      expect(snapshot(prefs), before);
      expect(repo.getAll().single, first);
      expect(notifications, 0);
    },
  );

  test(
    'metadata migration preserves UUIDs and content and is idempotent',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await seed(prefs);
      for (final key in prefs.getKeys().toList()) {
        final decoded = jsonDecode(prefs.getString(key)!);
        final rows = decoded is List ? decoded : (decoded as Map).values;
        for (final row in rows) {
          (row as Map).remove('updatedAt');
          row.remove('deleted');
          row['legacy-extra'] = 'preserved';
        }
        await prefs.setString(key, jsonEncode(decoded));
      }
      final before = ProjectRepository(prefs).getAll().single;
      await prefs.setString(localSchemaKey, jsonEncode({'version': 1}));
      await migrateLocalData(prefs);
      expect(
        jsonDecode(prefs.getString(localSchemaKey)!)['version'],
        currentLocalSchemaVersion,
      );
      final migrated = ProjectRepository(prefs).getAll().single;
      expect(migrated.id, before.id);
      expect(migrated.updatedAt, migrated.createdAt);
      expect(migrated.deleted, isFalse);
      final rawProject =
          (jsonDecode(prefs.getString('projects-list')!) as List).single;
      expect(rawProject['legacy-extra'], 'preserved');
      final snapshotAfter = snapshot(prefs);
      await migrateLocalData(prefs);
      expect(snapshot(prefs), snapshotAfter);
    },
  );

  for (final key in [
    'projects-list',
    'stars-list-v1',
    'habits-list-v1',
    'habit-completions-list-v1',
    'habit-cycles-v1',
    'custom-constellations-list',
    'reflection-answers-v1',
    localSchemaKey,
    metadataMigrationJournalKey,
  ]) {
    for (final throwsError in [false, true]) {
      test(
        'metadata migration resumes after failure at $key (throws=$throwsError)',
        () async {
          final prefs = await SharedPreferences.getInstance();
          await seed(prefs);
          await prefs.setString(localSchemaKey, jsonEncode({'version': 1}));
          final before = snapshot(prefs);
          final store = SharedPreferencesStorePlatform.instance;
          addTearDown(() => SharedPreferencesStorePlatform.instance = store);
          SharedPreferencesStorePlatform.instance = _FailingStore(
            before,
            key,
            throwsError: throwsError,
          );
          await expectLater(migrateLocalData(prefs), throwsStateError);
          expect(jsonDecode(prefs.getString(localSchemaKey)!)['version'], 1);
          final journal = prefs.getString(metadataMigrationJournalKey);
          await prefs.reload();
          await migrateLocalData(prefs);
          expect(
            ProjectRepository(prefs).getAll().single.id,
            ProjectRepository(prefs).getAll(includeDeleted: true).single.id,
          );
          expect(prefs.getString(metadataMigrationJournalKey), isNull);
          if (journal != null) {
            for (final entry
                in (jsonDecode(journal) as Map<String, dynamic>).entries) {
              if (entry.key != 'reflection-answers-v1') {
                expect(prefs.getString(entry.key), entry.value);
              }
            }
          }
        },
      );
    }
  }

  test(
    'malformed metadata stops migration before any collection is changed',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await seed(prefs);
      await prefs.setString(localSchemaKey, jsonEncode({'version': 1}));
      final shapes =
          jsonDecode(prefs.getString('custom-constellations-list')!) as List;
      shapes.single['updatedAt'] = 'invalid date';
      await prefs.setString('custom-constellations-list', jsonEncode(shapes));
      final before = snapshot(prefs);
      await expectLater(migrateLocalData(prefs), throwsFormatException);
      expect(snapshot(prefs), before);
    },
  );
}
