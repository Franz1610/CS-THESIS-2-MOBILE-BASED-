Map<String, int> countDetectionsByClass(List<Map<String, dynamic>> detections) {
  final counts = <String, int>{};
  for (final detection in detections) {
    final tag = detection['tag'];
    if (tag is String && tag.isNotEmpty) {
      counts.update(tag, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  return counts;
}
