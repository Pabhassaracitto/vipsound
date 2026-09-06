import 'package:flutter_test/flutter_test.dart';

import 'package:in4up/models/tipitaka_source_anchor.dart';
import 'package:in4up/models/word_entry.dart';

void main() {
  test('round-trips a Tipiṭaka source anchor and context snapshot', () {
    final anchor = TipitakaSourceAnchor(
      sourceDatabaseId: 'tipitaka:test:123',
      bookId: 7,
      bookCode: 'ABH01A_ATT',
      segmentId: 42,
      reference: 'abh01a_att:42',
      paragraphNo: 12,
      startOffset: 4,
      endOffset: 15,
      selectedText: 'dhammaṃ saraṇaṃ',
      sourceTable: 'abh01a_att',
      sourceRowKey: '42',
    );
    final restored = TipitakaSourceAnchor.fromJson(anchor.toJson());

    expect(restored.stableKey, anchor.stableKey);
    expect(restored.selectedText, anchor.selectedText);
    expect(restored.sourceTable, 'abh01a_att');
    expect(restored.startOffset, 4);

    final snapshot = TipitakaContextSnapshot(
      paliText: 'dhammaṃ saraṇaṃ gacchāmi',
      translationText: 'Con xin nương tựa Pháp.',
      contextBefore: 'iti pi so',
      contextAfter: 'saṅghaṃ saraṇaṃ',
      paragraphNo: 12,
      capturedAt: DateTime.utc(2026, 9, 6),
    );
    final restoredSnapshot =
        TipitakaContextSnapshot.fromJson(snapshot.toJson());
    expect(restoredSnapshot.translationText, snapshot.translationText);
    expect(restoredSnapshot.contextBefore, 'iti pi so');
    expect(restoredSnapshot.paragraphNo, 12);
  });

  test('persists anchors on the existing WordEntry format', () {
    final anchor = TipitakaSourceAnchor(
      sourceDatabaseId: 'db',
      bookId: 1,
      bookCode: 'DN01',
      segmentId: 2,
      reference: 'DN 1.1',
      paragraphNo: 1,
      startOffset: 0,
      endOffset: 5,
      selectedText: 'evaṃ',
    );
    final entry = WordEntry(
      id: 'word-1',
      word: 'evaṃ',
      meaning: '',
      tipitakaAnchors: [anchor],
      tipitakaContexts: [
        TipitakaContextSnapshot(
          paliText: 'evaṃ me sutaṃ',
          paragraphNo: 1,
          capturedAt: DateTime.utc(2026, 9, 6),
        ),
      ],
    );
    final restored = WordEntry.fromJson(entry.toJson());

    expect(restored.tipitakaAnchors.single.stableKey, anchor.stableKey);
    expect(restored.tipitakaContexts.single.paliText, 'evaṃ me sutaṃ');
  });
}
