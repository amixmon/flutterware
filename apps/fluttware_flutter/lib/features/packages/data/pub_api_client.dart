import 'dart:convert';
import 'dart:io';

import '../domain/pub_package.dart';

typedef PubJsonLoader = Future<Map<String, Object?>> Function(Uri uri);

class PubApiException implements Exception {
  const PubApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PubApiClient {
  PubApiClient({PubJsonLoader? loader}) : _loader = loader ?? _loadJson;

  static const _origin = 'https://pub.dev';
  static const _nameCacheLifetime = Duration(hours: 8);
  static List<String>? _cachedNames;
  static DateTime? _cachedNamesAt;
  final PubJsonLoader _loader;

  Future<List<PubPackageSummary>> search(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];
    final packages = await _packageNames();
    final terms = normalized
        .toLowerCase()
        .split(RegExp(r'[\s_]+'))
        .where((term) => term.isNotEmpty)
        .toList(growable: false);
    final exact = terms.join('_');
    final matches = packages
        .where((name) => terms.every(name.toLowerCase().contains))
        .toList();
    matches.sort((left, right) {
      int rank(String name) {
        final value = name.toLowerCase();
        if (value == exact) return 0;
        if (value.startsWith(exact)) return 1;
        if (value.startsWith(terms.first)) return 2;
        return 3;
      }

      final rankResult = rank(left).compareTo(rank(right));
      return rankResult != 0 ? rankResult : left.compareTo(right);
    });
    return matches
        .take(50)
        .map((name) => PubPackageSummary(name: name))
        .toList(growable: false);
  }

  Future<List<String>> _packageNames() async {
    final cachedAt = _cachedNamesAt;
    if (_cachedNames != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _nameCacheLifetime) {
      return _cachedNames!;
    }
    final json = await _loader(
      Uri.parse('$_origin/api/package-name-completion-data'),
    );
    final values = json['packages'];
    if (values is! List) {
      throw const PubApiException('Invalid Pub package-name response');
    }
    final names = values
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    _cachedNames = names;
    _cachedNamesAt = DateTime.now();
    return names;
  }

  Future<PubPackageDetails> details(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw const PubApiException('Package name is empty');
    }
    final json = await _loader(Uri.parse('$_origin/api/packages/$normalized'));
    final details = PubPackageDetails.fromJson(json);
    if (details.name.isEmpty || details.version.isEmpty) {
      throw const PubApiException('Invalid Pub package response');
    }
    return details;
  }

  static Future<Map<String, Object?>> _loadJson(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'gzip');
      request.headers.set(HttpHeaders.userAgentHeader, 'Flutterware');
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode != HttpStatus.ok) {
        throw PubApiException(
          response.statusCode == HttpStatus.notFound
              ? 'Package not found on pub.dev'
              : 'Pub API request failed (${response.statusCode})',
        );
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        throw const PubApiException('Invalid Pub API response');
      }
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } on PubApiException {
      rethrow;
    } on SocketException {
      throw const PubApiException('Could not connect to pub.dev');
    } on FormatException {
      throw const PubApiException('Pub returned an invalid response');
    } finally {
      client.close(force: true);
    }
  }
}
