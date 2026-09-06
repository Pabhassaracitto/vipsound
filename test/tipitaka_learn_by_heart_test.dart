import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/learn_by_heart/data/dhammapada_seed_data.dart';
import 'package:in4up/features/learn_by_heart/models/learn_by_heart_item.dart';
import 'package:in4up/models/tipitaka_source_anchor.dart';

void main() {
  test('LearnByHeartItem preserves Tipiṭaka provenance in JSON', () {
    final sourceAnchor = TipitakaSourceAnchor(
      sourceDatabaseId: 'tipitaka:test:1',
      bookId: 4,
      bookCode: 'DN01M_MUL',
      segmentId: 88,
      reference: 'DN 1.1',
      paragraphNo: 3,
      startOffset: 0,
      endOffset: 24,
      selectedText: 'evaṃ me sutaṃ',
      sourceTable: 'dn01m_mul',
      sourceRowKey: '88',
    );
    final snapshot = TipitakaContextSnapshot(
      paliText: 'evaṃ me sutaṃ',
      translationText: 'Tôi nghe như vầy.',
      translationLanguage: 'vi',
      contextBefore: 'atha kho',
      contextAfter: 'ekaṃ samayaṃ',
      paragraphNo: 3,
      capturedAt: DateTime.utc(2026, 9, 6),
    );
    final item = DhammapadaSeedData.getInitialItems().first.copyWith(
          sourceAnchor: sourceAnchor,
          contextSnapshot: snapshot,
        );

    final restored = LearnByHeartItem.fromJson(item.toJson());

    expect(restored.sourceAnchor?.stableKey, sourceAnchor.stableKey);
    expect(restored.sourceAnchor?.selectedText, 'evaṃ me sutaṃ');
    expect(restored.contextSnapshot?.translationText, 'Tôi nghe như vầy.');
    expect(restored.contextSnapshot?.contextBefore, 'atha kho');
  });

  test('legacy LearnByHeartItem without provenance remains readable', () {
    final json = DhammapadaSeedData.getInitialItems().first.toJson();
    json.remove('sourceAnchor');
    json.remove('contextSnapshot');

    final restored = LearnByHeartItem.fromJson(json);

    expect(restored.sourceAnchor, isNull);
    expect(restored.contextSnapshot, isNull);
  });
}
