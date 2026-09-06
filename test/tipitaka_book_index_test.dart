import 'package:flutter_test/flutter_test.dart';

import 'package:in4up/features/tipitaka/models/book.dart';

void main() {
  TipitakaBook book(String code, {String? metadata}) => TipitakaBook(
        id: 1,
        collectionId: 1,
        code: code,
        namePali: code,
        nameEn: '',
        nameVi: '',
        orderIndex: 1,
        metadataJson: metadata,
      );

  test('normalizes case and separators and exposes edition labels', () {
    final index = book('Abh01a Att').catalogIndex;

    expect(index.normalizedCode, 'ABH01A_ATT');
    expect(index.canonicalCode, 'ABH01A');
    expect(index.editionCode, 'ATT');
    expect(index.editionLabel, 'Aṭṭhakathā');
  });

  test('uses the raw source table from importer metadata', () {
    final index = book(
      'ABH01A_ATT',
      metadata: '{"source_table":"abh01a_att"}',
    ).catalogIndex;

    expect(index.sourceTable, 'abh01a_att');
  });

  test('recognizes the Vinaya Mūla code', () {
    final index = book('vin01m_mul').catalogIndex;

    expect(index.normalizedCode, 'VIN01M_MUL');
    expect(index.canonicalCode, 'VIN01M');
    expect(index.editionCode, 'MUL');
    expect(index.editionLabel, 'Mūla');
  });
}
