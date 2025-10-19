import 'dart:io';

/// Small auth helper that checks optional x-debug-token header.
class Auth {
  final String? token;

  Auth(this.token);

  bool check(HttpRequest r) {
    if (token == null) return true;
    final got = r.headers.value('x-debug-token');
    return got == token;
  }
}

String? guessPackageName() {
  try {
    final b = File('/proc/self/cmdline').readAsBytesSync();
    final i = b.indexOf(0);
    final s = String.fromCharCodes(b.sublist(0, i >= 0 ? i : b.length));
    final m = RegExp(r'[a-zA-Z0-9_.]+').firstMatch(s);
    return m?.group(0);
  } catch (_) {
    return null;
  }
}

Directory detectDbDir(String pkg) {
  final candidates = [
    '/data/user/0/$pkg/databases',
    '/data/data/$pkg/databases',
  ];
  for (final p in candidates) {
    final d = Directory(p);
    if (d.existsSync()) return d;
  }
  final d = Directory('/data/data/$pkg/databases');
  d.createSync(recursive: true);
  return d;
}
