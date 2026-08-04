import 'package:flutter/services.dart';

abstract final class PlatformActions {
  static const _channel = MethodChannel('com.flutterware.app/runtime');

  static Future<void> openExternalUrl(String url) =>
      _channel.invokeMethod<void>('openExternalUrl', {'url': url});
}
