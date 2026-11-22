/// The rules of the Notes page tree, as in Notion: pages sit inside pages,
/// in their own order; a page in the Trash hides the pages inside it; a
/// page cannot move inside itself. Plain functions, so they are easy to
/// test.
library;

import '../data/local/app_database.dart';

/// The name shown for a page with no title.
const untitled = 'Untitled';

/// The page's title, or "Untitled".
String pageTitle(Note page) =>
    page.title.trim().isEmpty ? untitled : page.title.trim();

/// True for a favourite page.
bool isFavorite(Note page) => page.favorite == 1;

/// Every page by its id.
Map<String, Note> pagesById(Iterable<Note> pages) => {
  for (final page in pages) page.id: page,
};

/// Compares two sibling pages: by their place, then the oldest first.
int comparePages(Note a, Note b) {
  final order = (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0);
  return order != 0 ? order : a.createdAt.compareTo(b.createdAt);
}

/// The parent a page shows under: its parent, or null (top level) when the
/// parent is gone.
String? shownParent(Note page, Map<String, Note> byId) =>
    byId.containsKey(page.parentId) ? page.parentId : null;

/// The pages directly inside [parentId] (null: the top level) that are not
/// in the Trash, in order.
List<Note> childrenOf(Iterable<Note> pages, String? parentId) {
  final byId = pagesById(pages);
  return pages
      .where(
        (page) =>
            page.trashedAt == null && shownParent(page, byId) == parentId,
      )
      .toList()
    ..sort(comparePages);
}

/// The ids of every page inside [id], at any depth.
Set<String> descendantsOf(Iterable<Note> pages, String id) {
  final found = <String>{};
  var frontier = {id};
  while (frontier.isNotEmpty) {
    final next = <String>{
      for (final page in pages)
        if (frontier.contains(page.parentId) && found.add(page.id)) page.id,
    };
    frontier = next;
  }
  return found;
}

/// The pages from the top level down to [id] (for the breadcrumbs),
/// [id] last.
List<Note> pathTo(Map<String, Note> byId, String id) {
  final path = <Note>[];
  final seen = <String>{};
  String? current = id;
  while (current != null && seen.add(current)) {
    final page = byId[current];
    if (page == null) break;
    path.insert(0, page);
    current = page.parentId;
  }
  return path;
}

/// True when the page or a page it sits inside is in the Trash.
bool isHidden(Map<String, Note> byId, String id) =>
    pathTo(byId, id).any((page) => page.trashedAt != null);

/// The pages the Trash lists: the ones put there themselves, newest first.
List<Note> trashedPages(Iterable<Note> pages) =>
    pages.where((page) => page.trashedAt != null).toList()
      ..sort((a, b) => b.trashedAt!.compareTo(a.trashedAt!));

/// Favourite pages that can be seen, in title order.
List<Note> favoritePages(Iterable<Note> pages) {
  final byId = pagesById(pages);
  return pages
      .where((page) => isFavorite(page) && !isHidden(byId, page.id))
      .toList()
    ..sort((a, b) => pageTitle(a).compareTo(pageTitle(b)));
}

/// True when [id] may move inside [newParent]: not into itself and not
/// into a page that is inside it.
bool canMoveUnder(Iterable<Note> pages, String id, String? newParent) {
  if (newParent == null) return true;
  if (newParent == id) return false;
  return !descendantsOf(pages, id).contains(newParent);
}

/// The place for a new page at the end of [parentId]'s pages.
double nextSortOrder(Iterable<Note> pages, String? parentId) {
  final siblings = childrenOf(pages, parentId);
  if (siblings.isEmpty) return 1;
  return (siblings.last.sortOrder ?? 0) + 1;
}

/// Pages that can be seen whose title or text contains [query] (any
/// case), titles first.
List<Note> searchPages(Iterable<Note> pages, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const [];
  final byId = pagesById(pages);
  final visible = pages.where((page) => !isHidden(byId, page.id));
  final inTitle = visible
      .where((page) => page.title.toLowerCase().contains(needle))
      .toList();
  final inText = visible
      .where(
        (page) =>
            !inTitle.contains(page) &&
            page.body.toLowerCase().contains(needle),
      )
      .toList();
  return [...inTitle, ...inText];
}
