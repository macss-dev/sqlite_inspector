import 'dart:convert';
import 'dart:io';

class HttpJson {
  HttpJson(this.baseUrl, {this.token});
  final Uri baseUrl;
  final String? token;

  Future<dynamic> get(String path) async {
    final client = HttpClient();
    final req = await client.getUrl(baseUrl.resolve(path));
    final t = token;
    if (t != null) req.headers.add('x-debug-token', t);
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('GET $path => ${res.statusCode}: $body');
    }
    return body.isEmpty ? <String, dynamic>{} : jsonDecode(body);
  }

  Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> json) async {
    final client = HttpClient();
    final req = await client.postUrl(baseUrl.resolve(path));
    req.headers.contentType = ContentType.json;
    final t = token;
    if (t != null) req.headers.add('x-debug-token', t);
    req.write(jsonEncode(json));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('POST $path => ${res.statusCode}: $body');
    }
    return body.isEmpty
        ? <String, dynamic>{}
        : (jsonDecode(body) as Map<String, dynamic>);
  }

  Future<int> postExpectStatus(String path, Map<String, dynamic> json) async {
    final client = HttpClient();
    final req = await client.postUrl(baseUrl.resolve(path));
    req.headers.contentType = ContentType.json;
    final t = token;
    if (t != null) req.headers.add('x-debug-token', t);
    req.write(jsonEncode(json));
    final res = await req.close();
    // Consumir body para no dejar sockets colgados
    await res.drain();
    return res.statusCode;
  }
}
