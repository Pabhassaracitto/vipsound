import 'package:in4up/features/learn_by_heart/controllers/learn_by_heart_provider.dart';
import 'package:in4up/features/learn_by_heart/models/learn_by_heart_item.dart';
import 'package:in4up/features/learn_by_heart/models/recitation_category.dart';
import 'package:in4up/features/learn_by_heart/models/recitation_language.dart';
import 'package:in4up/features/tipitaka/models/book.dart';
import 'package:in4up/features/tipitaka/models/segment.dart';
import 'package:in4up/features/tipitaka/services/tipitaka_worklist_service.dart';

/// Creates a normal LearnByHeartItem from a Tipiṭaka paragraph. This keeps
/// FSRS, audio controls and chunking in the existing Learn by Heart module;
/// Tipiṭaka only supplies content and provenance.
class TipitakaLearnByHeartService {
  const TipitakaLearnByHeartService();

  Future<LearnByHeartItem> savePassage({
    required LearnByHeartProvider provider,
    required TipitakaBook book,
    required TipitakaSegment segment,
    required String bookName,
    String contextBefore = '',
    String contextAfter = '',
  }) async {
    final translationLanguage = segment.translationVi?.trim().isNotEmpty == true
        ? 'vi'
        : 'en';
    final capture = await const TipitakaWorklistService().capture(
      book: book,
      segment: segment,
      selectedText: segment.paliText,
      startOffset: 0,
      endOffset: segment.paliText.length,
      translationLanguage: translationLanguage,
      contextBefore: contextBefore,
      contextAfter: contextAfter,
    );

    final existing = provider.allItems.cast<LearnByHeartItem?>().firstWhere(
          (item) => item?.sourceAnchor?.stableKey == capture.anchor.stableKey,
          orElse: () => null,
        );
    final item = existing == null
        ? _newItem(book, segment, bookName, capture)
        : existing.copyWith(
            title: _title(book, segment),
            subtitle: 'Tipiṭaka · $bookName',
            paliText: segment.paliText,
            vietnameseText:
                segment.translationVi ?? segment.translationEn ?? '',
            sourceAnchor: capture.anchor,
            contextSnapshot: capture.snapshot,
          );

    await provider.saveItem(item);
    return item;
  }

  LearnByHeartItem _newItem(
    TipitakaBook book,
    TipitakaSegment segment,
    String bookName,
    TipitakaStudyCapture capture,
  ) {
    final now = DateTime.now();
    return LearnByHeartItem(
      id: 'tipitaka-${capture.anchor.bookId}-${capture.anchor.segmentId}',
      title: _title(book, segment),
      subtitle: 'Tipiṭaka · $bookName',
      category: RecitationCategory.sutta,
      paliText: segment.paliText,
      vietnameseText: segment.translationVi ?? segment.translationEn ?? '',
      sourceLang: 'pi',
      targetLang: capture.snapshot.translationLanguage,
      // Tipiṭaka passages are memorized in Pāli; translation remains the
      // aligned support side in the existing bilingual/chunking pipeline.
      memorizeSide: MemorizeSide.source,
      ttsLanguage: 'pi',
      sourceAnchor: capture.anchor,
      contextSnapshot: capture.snapshot,
      createdAt: now,
    );
  }

  String _title(TipitakaBook book, TipitakaSegment segment) {
    final reference = segment.reference.trim().isEmpty
        ? 'paragraph ${segment.paragraphNo ?? ''}'.trim()
        : segment.reference.trim();
    return '${book.catalogIndex.compactLabel} · $reference';
  }
}
