import 'package:zephyr/service/image_recovery.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:zephyr/page/video/omo_network.dart';

/// The server returned vector content to a raster poster request. Retrying the
/// same successful HTTP response cannot make the raster codec decode it.
class UnsupportedVideoImageContent implements Exception, ImageFailureEvidence {
  const UnsupportedVideoImageContent();
  @override
  bool get retryable => false;
  @override
  String toString() => 'Unsupported video image content';
}

/// The visit is part of the image key: an old proxy failure cannot poison the
/// next visit's image cache. All OmoFun posters and avatars use the same route.
@immutable
class OmoNetworkImage extends ImageProvider<OmoNetworkImage> {
  const OmoNetworkImage(this.url, this.referrer, this.network);
  final String url;
  final Uri referrer;
  final Future<OmoNetworkContext?> network;

  Future<ui.Codec> _decode(Uint8List bytes, ImageDecoderCallback decode) async {
    // Inspect the payload, since some CDNs label their SVG placeholder JPEG.
    final prefix = String.fromCharCodes(bytes.take(4096));
    if (RegExp(r'<svg(?:\s|>)', caseSensitive: false).hasMatch(prefix)) {
      throw const UnsupportedVideoImageContent();
    }
    final codec = await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    ImageRecoveryHub.instance.noteSuccessfulRequest(
      imageHost: Uri.tryParse(url)?.host ?? '',
    );
    return codec;
  }

  @override
  Future<OmoNetworkImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
    OmoNetworkImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1);
  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final context = await network;
    final uri = Uri.parse(url);
    final headers = {'Referer': referrer.toString()};
    if (context != null) {
      try {
        return await _decode(
          await context.bytes(uri, headers: headers),
          decode,
        );
      } catch (error) {
        if (kDebugMode) {
          debugPrint(
            'Omo image ${uri.host}: ${error is HttpException ? error.message : error.runtimeType}',
          );
        }
        rethrow;
      }
    }
    // Unsupported systems retain the existing app-wide network behavior.
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 20));
      headers.forEach(request.headers.set);
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final bytes = await consolidateHttpClientResponseBytes(
        response,
      ).timeout(const Duration(seconds: 20));
      return await _decode(bytes, decode);
    } finally {
      client.close(force: true);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is OmoNetworkImage &&
      other.url == url &&
      other.referrer == referrer &&
      identical(other.network, network);
  @override
  int get hashCode => Object.hash(url, referrer, network);
}
