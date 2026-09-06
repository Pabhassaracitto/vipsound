// B2 (Wave 2) — "in bản chụp": phủ highlight/ghi chú lên ảnh trang đã render,
// trực tiếp trên pixel.
//
// Vì sao composite tay mà không qua Canvas/dart:ui: `PdfPage.render()` của
// pdfrx_engine 0.3.9 trả về `PdfImage.pixels` = **BGRA8888 thô**, nên toàn bộ
// phần này là số học trên `Uint8List` — thuần Dart, chạy được trong
// `flutter test`, không cần thiết bị, không cần plugin. Đổi lại: không in được
// CHỮ của ghi chú lên ảnh (app không có font rasterizer trong tiến trình này);
// ghi chú đi theo marker + sidecar, và điều đó được nói thẳng ở docs.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color, Rect;

import '../models/pdf_annotation.dart';

/// Hình chữ nhật theo PIXEL của ảnh trang (gốc trên-trái).
final class PdfPixelRect {
  const PdfPixelRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final int x;
  final int y;
  final int width;
  final int height;

  bool get isEmpty => width <= 0 || height <= 0;

  @override
  bool operator ==(Object other) =>
      other is PdfPixelRect &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(x, y, width, height);

  @override
  String toString() => 'PdfPixelRect($x,$y ${width}x$height)';
}

/// Đổi một `Rect` trong không gian PDF (gốc DƯỚI-trái, `top > bottom`) sang pixel
/// của ảnh trang (gốc TRÊN-trái). Đây chính là chỗ dễ lật trục sai nhất của tính
/// năng này, nên nó tách ra và có test riêng.
PdfPixelRect? pdfAnnotationPixelRect(
  Rect bounds, {
  required double pageWidthPts,
  required double pageHeightPts,
  required int imageWidth,
  required int imageHeight,
}) {
  if (pageWidthPts <= 0 || pageHeightPts <= 0) return null;
  if (imageWidth <= 0 || imageHeight <= 0) return null;
  final left = bounds.left, right = bounds.right;
  final high = math.max(bounds.top, bounds.bottom);
  final low = math.min(bounds.top, bounds.bottom);
  if (right <= left || high <= low) return null;

  final sx = imageWidth / pageWidthPts;
  final sy = imageHeight / pageHeightPts;

  var x0 = (left * sx).floor();
  var x1 = (right * sx).ceil();
  var y0 = ((pageHeightPts - high) * sy).floor();
  var y1 = ((pageHeightPts - low) * sy).ceil();

  if (x0 < 0) x0 = 0;
  if (y0 < 0) y0 = 0;
  if (x1 > imageWidth) x1 = imageWidth;
  if (y1 > imageHeight) y1 = imageHeight;
  if (x1 <= x0 || y1 <= y0) return null;
  return PdfPixelRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0);
}

/// Vuông nhỏ đánh dấu "chỗ này có ghi chú", đặt ở mép phải của vùng được chọn.
/// Không thể in chữ nên phải có dấu hiệu nhìn thấy được.
PdfPixelRect pdfNoteMarkerRect(PdfPixelRect region, {required int imageWidth}) {
  final side = region.height.clamp(6, 14).toInt();
  // `int.clamp()` trả về `num` ⇒ phải `.toInt()`; quên là không biên dịch được
  // (và `flutter analyze` của repo báo error ngay, không chỉ warning).
  var x = region.x + region.width + 2;
  if (x + side > imageWidth) {
    x = (region.x + region.width - side)
        .clamp(0, math.max(0, imageWidth - side))
        .toInt();
  }
  return PdfPixelRect(
    x: x.clamp(0, math.max(0, imageWidth - side)).toInt(),
    y: region.y,
    width: side,
    height: side,
  );
}

/// Sơn một chữ nhật lên buffer BGRA (hoà màu theo alpha, giữ nguyên kênh alpha
/// của nền vì ảnh render từ pdfium là opaque).
///
/// Trả về số byte đã sửa (để test/đo mà không cần so cả mảng).
int fillBgraRect({
  required Uint8List bgra,
  required int imageWidth,
  required int imageHeight,
  required PdfPixelRect rect,
  required int colorArgb,
  required double alpha,
}) {
  if (bgra.length < imageWidth * imageHeight * 4) return 0;
  if (rect.isEmpty) return 0;
  final a = alpha.clamp(0.0, 1.0);
  if (a <= 0) return 0;
  final srcR = (colorArgb >> 16) & 0xFF;
  final srcG = (colorArgb >> 8) & 0xFF;
  final srcB = colorArgb & 0xFF;
  final xEnd = math.min(imageWidth, rect.x + rect.width);
  final yEnd = math.min(imageHeight, rect.y + rect.height);
  var touched = 0;
  for (var y = math.max(0, rect.y); y < yEnd; y++) {
    var i = (y * imageWidth + math.max(0, rect.x)) * 4;
    for (var x = math.max(0, rect.x); x < xEnd; x++, i += 4, touched += 4) {
      bgra[i] = (srcB * a + bgra[i] * (1 - a)).round();
      bgra[i + 1] = (srcG * a + bgra[i + 1] * (1 - a)).round();
      bgra[i + 2] = (srcR * a + bgra[i + 2] * (1 - a)).round();
      bgra[i + 3] = 255;
    }
  }
  return touched;
}

/// Toàn bộ bước burn: lấy `lineRects` (nếu có) rồi `bounds`, bỏ bookmark, bỏ
/// annotation không hình học. `noteMarkerColor` vẽ vuông dấu ghi chú.
///
/// Trả về số vùng đã sơn — 0 nghĩa là trang này không có gì để in.
int burnPdfAnnotationsIntoBgra(
  Uint8List bgra, {
  required int imageWidth,
  required int imageHeight,
  required double pageWidthPts,
  required double pageHeightPts,
  required List<PdfAnnotation> annotations,
  double highlightAlpha = 0.35,
  int noteMarkerColorArgb = 0xFF1E88E5,
  bool drawNoteMarkers = true,
}) {
  var painted = 0;
  for (final a in annotations) {
    if (a.type == AnnotationType.bookmark) continue;
    for (final rect in a.rectsForPainting) {
      final px = pdfAnnotationPixelRect(
        rect,
        pageWidthPts: pageWidthPts,
        pageHeightPts: pageHeightPts,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );
      if (px == null) continue;
      fillBgraRect(
        bgra: bgra,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        rect: px,
        colorArgb: a.color.toARGB32(),
        alpha: highlightAlpha,
      );
      painted++;
      final hasNote = (a.note?.trim().isNotEmpty ?? false);
      if (drawNoteMarkers && hasNote) {
        fillBgraRect(
          bgra: bgra,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
          rect: pdfNoteMarkerRect(px, imageWidth: imageWidth),
          colorArgb: noteMarkerColorArgb,
          alpha: 1.0,
        );
      }
    }
  }
  return painted;
}

/// Kích thước ảnh hợp lý cho một trang: ~150 dpi (2x mật độ in thông thường của
/// máy tính tiền văn phòng), chặn ở 1800px cạnh dài để không nổ RAM trên điện
/// thoại khi xuất 40 trang.
({int width, int height}) pdfSnapshotRenderSize({
  required double pageWidthPts,
  required double pageHeightPts,
  double dpi = 150,
  int maxLongEdge = 1800,
}) {
  if (pageWidthPts <= 0 || pageHeightPts <= 0) return (width: 0, height: 0);
  final scale = dpi / 72.0;
  var w = (pageWidthPts * scale).round();
  var h = (pageHeightPts * scale).round();
  final long = math.max(w, h);
  if (long > maxLongEdge) {
    final shrink = maxLongEdge / long;
    w = (w * shrink).round();
    h = (h * shrink).round();
  }
  return (width: math.max(1, w), height: math.max(1, h));
}

/// Màu nền trang khi render cho bản in (trắng, không phải nền tối của app).
Color get pdfSnapshotPageBackground => const Color(0xFFFFFFFF);
