import 'package:flutter_test/flutter_test.dart';
import 'package:flutterware/features/packages/data/pub_api_client.dart';
import 'package:flutterware/features/packages/domain/pub_package.dart';
import 'package:flutterware/features/projects/domain/project_configuration.dart';

void main() {
  test(
    'search uses the supported Pub name API and filters cached names',
    () async {
      late Uri requestedUri;
      var requests = 0;
      final client = PubApiClient(
        loader: (uri) async {
          requests++;
          requestedUri = uri;
          return {
            'packages': [
              'state_management',
              'management_state_tools',
              'riverpod',
            ],
          };
        },
      );

      final results = await client.search('state management');
      await client.search('riverpod');

      expect(requestedUri.path, '/api/package-name-completion-data');
      expect(requests, 1);
      expect(results.map((package) => package.name), [
        'state_management',
        'management_state_tools',
      ]);
    },
  );

  test(
    'details parses latest metadata and Android plugin compatibility',
    () async {
      final client = PubApiClient(
        loader: (uri) async => {
          'name': 'camera',
          'latest': {
            'version': '1.2.3',
            'pubspec': {
              'description': 'Camera support',
              'flutter': {
                'plugin': {
                  'platforms': {'android': <String, Object?>{}},
                },
              },
            },
          },
        },
      );

      final details = await client.details('camera');

      expect(details.name, 'camera');
      expect(details.version, '1.2.3');
      expect(details.compatibility, PackageCompatibility.androidPlugin);
      expect(details.canAdd, isTrue);
    },
  );

  test(
    'package classification covers Dart, Flutter, and unsupported plugins',
    () {
      expect(classifyPubPackage(const {}), PackageCompatibility.pureDart);
      expect(
        classifyPubPackage(const {
          'dependencies': {'flutter': 'sdk'},
        }),
        PackageCompatibility.flutter,
      );
      expect(
        classifyPubPackage(const {
          'flutter': {
            'plugin': {
              'platforms': {'ios': <String, Object?>{}},
            },
          },
        }),
        PackageCompatibility.unsupported,
      );
    },
  );
}
