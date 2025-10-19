import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Utility helpers used across the package.
class Utils {
  /// Encode a cell value for JSON transport. Blobs become base64 wrappers.
  static dynamic encodeCell(Object? v) {
    if (v is Uint8List) {
      return {'__blob__': base64Encode(v), 'length': v.length};
    }
    return v;
  }

  /// Read request body as JSON object (`Map<String, dynamic>`).
  /// - Empty body => empty map.
  /// - If JSON is a `Map<dynamic, dynamic>`, convert keys to strings.
  /// - Otherwise throws [FormatException].
  static Future<Map<String, dynamic>> readJson(HttpRequest r) async {
    final body = await utf8.decoder.bind(r).join();
    if (body.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.map((k, v) => MapEntry(k.toString(), v));
    throw const FormatException('Expected a JSON object');
  }

  /// Write JSON response and close.
  static void writeJson(HttpRequest r, Object data) {
    r.response.headers
        .set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
    r.response.write(jsonEncode(data));
    r.response.close();
  }

  /// Write bad request with message and close.
  static void writeBad(HttpRequest r, String msg) {
    r.response.statusCode = HttpStatus.badRequest;
    r.response.write(msg);
    r.response.close();
  }
}
