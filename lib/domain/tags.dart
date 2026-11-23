/// Task tags: short words such as `errand` or `deep-work`, kept lower case
/// without "#", stored comma separated. Plain functions, so they are easy
/// to test.
library;

import '../data/local/app_database.dart';

/// A tag as it is kept: trimmed, lower case, no "#", spaces made dashes.
/// Empty when nothing is left.
String cleanTag(String raw) => raw
    .trim()
    .replaceAll('#', '')
    .replaceAll(',', ' ')
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'\s+'), '-');

/// The tags as stored text (no duplicates, in order), or null for none.
String? joinTags(Iterable<String> tags) {
  final kept = <String>[];
  for (final tag in tags.map(cleanTag)) {
    if (tag.isNotEmpty && !kept.contains(tag)) kept.add(tag);
  }
  return kept.isEmpty ? null : kept.join(',');
}

/// The tags of a task.
List<String> tagsOf(Task task) => [
  for (final tag in (task.tags ?? '').split(','))
    if (tag.trim().isNotEmpty) tag.trim(),
];

/// Every tag in use, most used first, for suggestions.
List<String> knownTags(Iterable<Task> tasks) {
  final counts = <String, int>{};
  for (final task in tasks) {
    for (final tag in tagsOf(task)) {
      counts[tag] = (counts[tag] ?? 0) + 1;
    }
  }
  return counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
}
