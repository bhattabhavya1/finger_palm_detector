// lib/services/image_analysis_service.dart
import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';
import '../core/constants/app_constants.dart';
import '../domain/entities/luminosity_record.dart';

class ImageAnalysisService {
  final Logger _logger = Logger();

  /// ─── BLUR DETECTION (Laplacian Variance) ───────────────────────────────
  /// Returns a score: lower = more blurry. Below threshold = blurred.
  Future<double> computeBlurScore(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return 0.0;

      // Convert to grayscale
      final gray = img.grayscale(image);

      // Resize for speed
      final resized = img.copyResize(gray, width: 256, height: 256);

      // Laplacian kernel: [0,1,0],[1,-4,1],[0,1,0]
      double sum = 0;
      double sumSq = 0;
      int count = 0;

      for (int y = 1; y < resized.height - 1; y++) {
        for (int x = 1; x < resized.width - 1; x++) {
          final center = img.getLuminance(resized.getPixel(x, y));
          final top = img.getLuminance(resized.getPixel(x, y - 1));
          final bottom = img.getLuminance(resized.getPixel(x, y + 1));
          final left = img.getLuminance(resized.getPixel(x - 1, y));
          final right = img.getLuminance(resized.getPixel(x + 1, y));

          final laplacian = (top + bottom + left + right - 4 * center).toDouble();
          sum += laplacian;
          sumSq += laplacian * laplacian;
          count++;
        }
      }

      if (count == 0) return 0.0;
      final mean = sum / count;
      final variance = (sumSq / count) - (mean * mean);
      return variance.abs();
    } catch (e) {
      _logger.e('Blur detection error: $e');
      return 0.0;
    }
  }

  bool isBlurred(double blurScore) => blurScore < AppConstants.blurThreshold;

  /// ─── BRIGHTNESS SCORE ──────────────────────────────────────────────────
  Future<double> computeBrightnessScore(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return 0.0;

      final resized = img.copyResize(image, width: 128, height: 128);
      double totalLum = 0;
      int count = 0;

      for (int y = 0; y < resized.height; y++) {
        for (int x = 0; x < resized.width; x++) {
          totalLum += img.getLuminance(resized.getPixel(x, y));
          count++;
        }
      }

      return count > 0 ? totalLum / count : 0.0;
    } catch (e) {
      _logger.e('Brightness error: $e');
      return 0.0;
    }
  }

  LightCondition getLightCondition(double brightnessScore) {
    if (brightnessScore < AppConstants.lowLightThreshold) return LightCondition.low;
    if (brightnessScore > AppConstants.brightLightThreshold) return LightCondition.bright;
    return LightCondition.normal;
  }

  /// ─── PERCEPTUAL HASH (pHash) ───────────────────────────────────────────
  /// Returns a hex string representing the image hash
  String computePerceptualHash(img.Image image) {
    // Resize to 32x32
    final resized = img.copyResize(img.grayscale(image), width: 32, height: 32);

    // Compute mean
    double mean = 0;
    final pixels = <double>[];
    for (int y = 0; y < resized.height; y++) {
      for (int x = 0; x < resized.width; x++) {
        final lum = img.getLuminance(resized.getPixel(x, y)).toDouble();
        pixels.add(lum);
        mean += lum;
      }
    }
    mean /= pixels.length;

    // Build binary hash
    final buffer = StringBuffer();
    for (final p in pixels) {
      buffer.write(p >= mean ? '1' : '0');
    }

    // Convert binary to hex
    final binary = buffer.toString();
    final hex = StringBuffer();
    for (int i = 0; i < binary.length; i += 4) {
      final chunk = binary.substring(i, math.min(i + 4, binary.length)).padRight(4, '0');
      hex.write(int.parse(chunk, radix: 2).toRadixString(16));
    }
    return hex.toString();
  }

  /// Hamming distance between two hex hashes (0 = identical)
  int hammingDistance(String hash1, String hash2) {
    if (hash1.length != hash2.length) return hash1.length;
    int dist = 0;
    for (int i = 0; i < hash1.length; i++) {
      if (hash1[i] != hash2[i]) dist++;
    }
    return dist;
  }

  bool isSameImage(String hash1, String hash2, {int threshold = 12}) {
    return hammingDistance(hash1, hash2) <= threshold;
  }

  /// ─── HISTOGRAM SIGNATURE ───────────────────────────────────────────────
  /// Returns a 128-dim histogram of grayscale intensities (normalised)
  List<double> computeHistogramSignature(img.Image image) {
    const bins = 128;
    final histogram = List<double>.filled(bins, 0);
    final gray = img.grayscale(image);

    int total = 0;
    for (int y = 0; y < gray.height; y++) {
      for (int x = 0; x < gray.width; x++) {
        final lum = img.getLuminance(gray.getPixel(x, y));
        final bin = ((lum / 255.0) * (bins - 1)).floor().clamp(0, bins - 1);
        histogram[bin]++;
        total++;
      }
    }
    // Normalise
    if (total > 0) {
      for (int i = 0; i < bins; i++) {
        histogram[i] /= total;
      }
    }
    return histogram;
  }

  /// Cosine similarity between two histogram signatures (1.0 = identical)
  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0.0;
    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }

  bool isSameFingerByHistogram(List<double> sig1, List<double> sig2, {double threshold = 0.80}) {
    return cosineSimilarity(sig1, sig2) >= threshold;
  }

  /// ─── MINUTIAE POINTS EXTRACTION ───────────────────────────────────────
  /// Extracts ridge endpoints and bifurcations from grayscale fingerprint image
  Future<List<double>> extractMinutiaePoints(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return [];

      final gray = img.grayscale(image);
      final resized = img.copyResize(gray, width: 200, height: 200);

      final points = <double>[];

      // Threshold to binary
      final binary = _threshold(resized);

      // Thin the ridges (simplified Zhang-Suen thinning concept)
      final thinned = _simpleThin(binary, 200, 200);

      // Crossing number for minutiae detection
      for (int y = 1; y < 199; y++) {
        for (int x = 1; x < 199; x++) {
          if (thinned[y][x] == 0) continue; // background

          final cn = _crossingNumber(thinned, x, y);
          // cn==1 -> ridge ending; cn==3 -> bifurcation
          if (cn == 1 || cn == 3) {
            points.add(x / 200.0); // normalized x
            points.add(y / 200.0); // normalized y
            points.add(cn.toDouble()); // type
          }
        }
      }
      return points;
    } catch (e) {
      _logger.e('Minutiae extraction error: $e');
      return [];
    }
  }

  List<List<int>> _threshold(img.Image image) {
    final result = List.generate(image.height, (_) => List<int>.filled(image.width, 0));
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final lum = img.getLuminance(image.getPixel(x, y));
        result[y][x] = lum > 128 ? 0 : 1;
      }
    }
    return result;
  }

  List<List<int>> _simpleThin(List<List<int>> binary, int w, int h) {
    // Simple erosion-based thinning (not full Zhang-Suen but sufficient for feature extraction)
    final result = List.generate(h, (y) => List<int>.from(binary[y]));
    for (int iter = 0; iter < 5; iter++) {
      for (int y = 1; y < h - 1; y++) {
        for (int x = 1; x < w - 1; x++) {
          if (result[y][x] == 0) continue;
          final neighbors = _getNeighbors(result, x, y);
          final nCount = neighbors.fold(0, (a, b) => a + b);
          if (nCount >= 7) result[y][x] = 0;
        }
      }
    }
    return result;
  }

  List<int> _getNeighbors(List<List<int>> grid, int x, int y) {
    return [
      grid[y - 1][x], grid[y - 1][x + 1], grid[y][x + 1], grid[y + 1][x + 1],
      grid[y + 1][x], grid[y + 1][x - 1], grid[y][x - 1], grid[y - 1][x - 1],
    ];
  }

  int _crossingNumber(List<List<int>> grid, int x, int y) {
    final n = _getNeighbors(grid, x, y);
    int cn = 0;
    for (int i = 0; i < 8; i++) {
      cn += (n[(i + 1) % 8] - n[i]).abs();
    }
    return cn ~/ 2;
  }

  /// Compare two sets of minutiae points (returns similarity 0.0-1.0)
  double compareMinutiaePoints(List<double> points1, List<double> points2) {
    if (points1.isEmpty || points2.isEmpty) return 0.0;

    // Build point pairs (x,y,type triplets)
    final pts1 = _buildPointList(points1);
    final pts2 = _buildPointList(points2);

    if (pts1.isEmpty || pts2.isEmpty) return 0.0;

    int matched = 0;
    const distThreshold = 0.08; // 8% of image width/height
    const typeWeight = 0.3;

    for (final p1 in pts1) {
      double bestScore = 0;
      for (final p2 in pts2) {
        final dist = math.sqrt(math.pow(p1[0] - p2[0], 2) + math.pow(p1[1] - p2[1], 2));
        if (dist < distThreshold) {
          final typeMatch = p1[2] == p2[2] ? 1.0 : (1.0 - typeWeight);
          final score = (1.0 - dist / distThreshold) * typeMatch;
          if (score > bestScore) bestScore = score;
        }
      }
      if (bestScore > 0.5) matched++;
    }

    return matched / math.max(pts1.length, pts2.length);
  }

  List<List<double>> _buildPointList(List<double> flat) {
    final result = <List<double>>[];
    for (int i = 0; i + 2 < flat.length; i += 3) {
      result.add([flat[i], flat[i + 1], flat[i + 2]]);
    }
    return result;
  }

  bool isSameFingerByMinutiae(List<double> pts1, List<double> pts2, {double threshold = 0.35}) {
    return compareMinutiaePoints(pts1, pts2) >= threshold;
  }

  /// ─── DORSAL/PALM SIDE DETECTION ────────────────────────────────────────
  /// Heuristic: dorsal side has less ridge density and more uniform texture
  Future<bool> isDorsalSide(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return false;

      final gray = img.grayscale(image);
      final resized = img.copyResize(gray, width: 100, height: 100);

      // Compute standard deviation of pixel intensities
      // Palm side (ridges) has higher std dev than dorsal side (skin)
      double sum = 0;
      double sumSq = 0;
      int count = 0;

      for (int y = 0; y < resized.height; y++) {
        for (int x = 0; x < resized.width; x++) {
          final lum = img.getLuminance(resized.getPixel(x, y)).toDouble();
          sum += lum;
          sumSq += lum * lum;
          count++;
        }
      }

      final mean = sum / count;
      final variance = (sumSq / count) - (mean * mean);
      final stdDev = math.sqrt(variance.abs());

      // Low stdDev = smooth skin (dorsal), high = textured (palm ridges)
      return stdDev < 25.0;
    } catch (e) {
      _logger.e('Dorsal detection error: $e');
      return false;
    }
  }
}
