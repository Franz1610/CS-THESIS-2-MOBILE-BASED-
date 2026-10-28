import 'package:flutter_test/flutter_test.dart';
import 'package:handicraft_app/utils/detection_utils.dart';

void main() {
  test('counts detections separately by product class', () {
    final counts = countDetectionsByClass([
      {'tag': 'ella_placemat_plain'},
      {'tag': 'lina_coaster_leaf'},
      {'tag': 'ella_placemat_plain'},
    ]);

    expect(counts, {'ella_placemat_plain': 2, 'lina_coaster_leaf': 1});
  });

  test('returns no counts when there are no detections', () {
    expect(countDetectionsByClass([]), isEmpty);
  });
}
