/// Depth-first order of a flat category list (parents before their children) with each one's depth.
List<(Map<String, dynamic>, int)> flattenCategories(List<Map<String, dynamic>> flat) {
  final byParent = <int?, List<Map<String, dynamic>>>{};
  for (final c in flat) {
    byParent.putIfAbsent(c['parent_id'] as int?, () => []).add(c);
  }

  final out = <(Map<String, dynamic>, int)>[];
  void walk(int? parent, int depth) {
    for (final c in byParent[parent] ?? const <Map<String, dynamic>>[]) {
      out.add((c, depth));
      walk(c['id'] as int, depth + 1);
    }
  }

  walk(null, 0);
  return out;
}

/// The id itself plus every category below it, at any depth.
Set<int> categoryAndDescendants(List<Map<String, dynamic>> flat, int id) {
  final children = <int, List<int>>{};
  for (final c in flat) {
    final parent = c['parent_id'] as int?;
    if (parent != null) children.putIfAbsent(parent, () => []).add(c['id'] as int);
  }

  final found = <int>{id};
  final queue = <int>[id];
  while (queue.isNotEmpty) {
    for (final child in children[queue.removeLast()] ?? const <int>[]) {
      if (found.add(child)) queue.add(child);
    }
  }

  return found;
}