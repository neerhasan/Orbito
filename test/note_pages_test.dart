import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbito/data/local/app_database.dart';
import 'package:orbito/data/repositories/capture_repository.dart';
import 'package:orbito/domain/note_tree.dart';

/// Notes as Notion-style pages: the tree rules and the repository.
void main() {
  late AppDatabase db;
  late CaptureRepository pages;
  late int counter;
  late DateTime clock;

  setUp(() {
    counter = 0;
    clock = DateTime.utc(2026, 11, 23, 9);
    db = AppDatabase(NativeDatabase.memory(), tablesManagedBySync: false);
    pages = CaptureRepository(
      db,
      newId: () => 'p${++counter}',
      stableId: (key) => 'stable-$key',
      now: () => clock = clock.add(const Duration(seconds: 1)),
    );
  });

  tearDown(() => db.close());

  Future<List<Note>> all() => pages.watchNotes('u').first;

  test('pages sit inside pages, in the order they were made', () async {
    final work = await pages.createPage(userId: 'u', title: 'Work');
    final home = await pages.createPage(userId: 'u');
    final ideas = await pages.createPage(userId: 'u', parentId: work);
    final plans = await pages.createPage(userId: 'u', parentId: work);

    final list = await all();
    expect(childrenOf(list, null).map((p) => p.id), [work, home]);
    expect(childrenOf(list, work).map((p) => p.id), [ideas, plans]);
    expect(pageTitle(pagesById(list)[home]!), 'Untitled');
    expect(pathTo(pagesById(list), plans).map((p) => p.id), [work, plans]);
    expect(descendantsOf(list, work), {ideas, plans});
  });

  test(
    'content saves with a plain-text copy; icon, cover, favourite',
    () async {
      final id = await pages.createPage(userId: 'u');
      await pages.savePage(
        id,
        title: ' Visa ',
        content: '{"document":{}}',
        body: 'Ask about D-2',
      );
      await pages.setPageIcon(id, '🎓');
      await pages.setPageCover(id, 'blue');
      await pages.setFavorite(id, favorite: true);

      final page = (await all()).single;
      expect(page.title, 'Visa');
      expect(page.content, '{"document":{}}');
      expect(page.body, 'Ask about D-2');
      expect((page.icon, page.cover), ('🎓', 'blue'));
      expect(favoritePages(await all()).single.id, id);
      expect(searchPages(await all(), 'd-2').single.id, id);
    },
  );

  test('a page cannot move inside itself or a page inside it', () async {
    final a = await pages.createPage(userId: 'u');
    final b = await pages.createPage(userId: 'u', parentId: a);
    final c = await pages.createPage(userId: 'u');

    expect(
      () => pages.movePage(a, userId: 'u', parentId: b, sortOrder: 1),
      throwsArgumentError,
    );
    expect(
      () => pages.movePage(a, userId: 'u', parentId: a, sortOrder: 1),
      throwsArgumentError,
    );
    await pages.movePage(c, userId: 'u', parentId: b, sortOrder: 1);
    expect(childrenOf(await all(), b).single.id, c);
  });

  test('the Trash hides the pages inside; restore brings them back', () async {
    final a = await pages.createPage(userId: 'u', title: 'A');
    final b = await pages.createPage(userId: 'u', parentId: a, title: 'B');
    await pages.setFavorite(b, favorite: true);

    await pages.trashPage(a);
    var list = await all();
    expect(childrenOf(list, null), isEmpty);
    expect(trashedPages(list).single.id, a);
    expect(isHidden(pagesById(list), b), isTrue);
    expect(favoritePages(list), isEmpty);
    expect(searchPages(list, 'B'), isEmpty);

    await pages.restorePage(a, userId: 'u');
    list = await all();
    expect(childrenOf(list, null).single.id, a);
    expect(childrenOf(list, a).single.id, b);
  });

  test(
    'a page restored while its parent is in the Trash goes to the top',
    () async {
      final a = await pages.createPage(userId: 'u');
      final b = await pages.createPage(userId: 'u', parentId: a);
      await pages.trashPage(b);
      await pages.trashPage(a);

      await pages.restorePage(b, userId: 'u');
      final list = await all();
      expect(childrenOf(list, null).single.id, b);
      expect(trashedPages(list).single.id, a);
    },
  );

  test('delete forever removes the page and every page inside it', () async {
    final a = await pages.createPage(userId: 'u');
    final b = await pages.createPage(userId: 'u', parentId: a);
    await pages.createPage(userId: 'u', parentId: b);
    final other = await pages.createPage(userId: 'u');

    await pages.trashPage(a);
    await pages.deleteForever(a, userId: 'u');
    expect((await all()).map((p) => p.id), [other]);
  });
}
