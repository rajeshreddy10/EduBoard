import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

/// Centralized image source resolver.
///
/// EduBoard stores image sources from many origins:
///   - raw URLs           https://... / http://...
///   - Firebase Storage   gs://bucket/path/... (and https download URLs)
///   - inline Base64      data:image/png;base64,.....
///   - bundled assets     assets/...
///   - null / empty / malformed values
///
/// `NetworkImage`/`Image.network` explode with
/// "Invalid argument(s): No host specified in URI: data:image/png;base64,..."
/// for Base64 sources. Route **every** image through [EduImage] /
/// [resolveImageProvider] instead so the rendering engine only ever receives
/// providers it can actually resolve.
enum EduImageKind {
  base64,
  http,
  firebaseStorage,
  asset,
  file,
  empty,
  unknown,
}

class EduImageResolver {
  EduImageResolver._();

  static final Map<String, Uint8List> _base64Cache = <String, Uint8List>{};

  /// Classifies an image source string.
  static EduImageKind kindOf(String? source) {
    final src = source?.trim() ?? '';
    if (src.isEmpty) return EduImageKind.empty;

    // Inline Base64 data URI ("data:image/png;base64,....").
    if (src.startsWith('data:image/') || src.startsWith('data:application/octet-stream;base64,')) {
      return EduImageKind.base64;
    }

    if (src.startsWith('gs://') ||
        src.startsWith('firebasestorage://') ||
        src.startsWith('firebase-storage')) {
      return EduImageKind.firebaseStorage;
    }

    if (src.startsWith('fbres://') || src.startsWith('/firebasestorage/')) {
      return EduImageKind.firebaseStorage;
    }

    if (src.startsWith('file://') || src.startsWith('/data/user/')) {
      return EduImageKind.file;
    }

    if (src.startsWith('http://') || src.startsWith('https://')) {
      // Firebase Storage download URLs are plain https — plain http handles them.
      return EduImageKind.http;
    }

    if (src.startsWith('assets/')) {
      return EduImageKind.asset;
    }

    // Bare Base64 string without the data: prefix (some backend serializers
    // emit raw base64 payloads).
    if (_looksLikeBase64(src)) {
      return EduImageKind.base64;
    }

    return EduImageKind.unknown;
  }

  /// Heuristic for raw (unprefixed) Base64 image payloads: long strings made
  /// exclusively of Base64 alphabet characters with valid padding.
  static bool _looksLikeBase64(String src) {
    if (src.length < 512) return false; // Don't mistake file names/tokens.
    final compact = src.replaceAll(RegExp(r'\s'), '');
    if (compact.length != src.length) return false;
    return RegExp(r'^[A-Za-z0-9+/]+={0,2}$').hasMatch(compact) && compact.length % 4 == 0;
  }

  /// Extracts Base64 bytes from a data-URI or raw Base64 payload.
  static Uint8List? decodeBase64(String source) {
    try {
      final cached = _base64Cache[source];
      if (cached != null) return cached;

      String payload = source;
      int commaIndex = payload.indexOf(',');
      if (commaIndex != -1) {
        // Keep a small header sanity check: data:image/...;base64,
        payload = payload.substring(commaIndex + 1);
      } else if (!_looksLikeBase64(payload)) {
        return null;
      }

      final clean = payload.replaceAll(RegExp(r'\s'), '');
      if (clean.isEmpty) return null;
      final bytes = base64Decode(clean);
      if (bytes.isEmpty) return null;

      // Guard memory usage: cap the inline cache at 32 decoded images.
      if (_base64Cache.length > 32) {
        _base64Cache.remove(_base64Cache.keys.first);
      }
      _base64Cache[source] = bytes;
      return bytes;
    } catch (e, stack) {
      debugPrint('[EduImageResolver] Base64 decode failed: $e\n$stack');
      return null;
    }
  }

  static bool isBase64Image(String? source) =>
      kindOf(source) == EduImageKind.base64;

  /// Synchronously resolves a source into an ImageProvider.
  ///
  /// Returns `null` when the source cannot be resolved synchronously
  /// (empty, malformed, or `gs://` URIs that need an async metadata lookup) —
  /// callers must then render their own fallback instead.
  static ImageProvider? resolveImageProvider(String? source) {
    switch (kindOf(source)) {
      case EduImageKind.base64:
        final bytes = decodeBase64(source!);
        return bytes == null ? null : MemoryImage(bytes);
      case EduImageKind.http:
        final uri = Uri.tryParse(source!);
        if (uri == null || uri.host.isEmpty) return null;
        return NetworkImage(uri.toString());
      case EduImageKind.asset:
        return AssetImage(source!);
      case EduImageKind.empty:
      case EduImageKind.file:
      case EduImageKind.firebaseStorage:
      case EduImageKind.unknown:
        return null;
    }
  }

  /// Asynchronously resolves `gs://` Firebase Storage refs into HTTPS
  /// providers. Anything that resolves synchronously is returned immediately.
  static Future<ImageProvider?> resolveProviderAsync(String? source) async {
    final kind = kindOf(source);
    if (kind == EduImageKind.firebaseStorage) {
      try {
        final src = source!;
        final ref =
            FirebaseStorage.instance.refFromURL(src.startsWith('gs://') ? src : 'gs://$src');
        final url = await ref.getDownloadURL();
        final uri = Uri.tryParse(url);
        if (uri == null || uri.host.isEmpty) return null;
        return NetworkImage(uri.toString());
      } catch (e) {
        debugPrint('[EduImageResolver] Storage resolve failed: $e');
        return null;
      }
    }
    if (kind == EduImageKind.file) {
      try {
        final path = source!.startsWith('file://')
            ? Uri.tryParse(source)!.toFilePath()
            : source;
        return AssetImage(path);
      } catch (_) {
        return null;
      }
    }
    return resolveImageProvider(source);
  }

  /// Uploads inline Base64 payloads stored in user profile docs to Firebase
  /// Storage and returns a stable download URL.
  ///
  /// Some older records store avatars as Base64 directly in Firestore, which
  /// bloats document size and breaks host-based URL lookups. Uploading them
  /// once and saving the download URL repairs the record at the source.
  static Future<String?> migrateBase64ToStorage(
    String payload, {
    String? storagePath,
    String mimeType = 'image/png',
  }) async {
    final bytes = decodeBase64(payload);
    if (bytes == null) return null;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || !payload.startsWith('data:image/')) return null;
      final path = storagePath ??
          'users/${user.uid}/avatars/avatar_${DateTime.now().millisecondsSinceEpoch}.png';
      final ref = FirebaseStorage.instance.ref(path);
      await ref.putData(
        bytes,
        SettableMetadata(contentType: mimeType),
      );
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      debugPrint('[EduImageResolver] Storage migration skipped: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[EduImageResolver] Storage migration failed: $e');
      return null;
    }
  }
}

/// Base64-safe, network-safe image widget with a graceful fallback UI.
///
/// Drop-in replacement for `Image.network(...)` / bare `NetworkImage(...)`
/// usage. Base64 payloads render through `Image.memory`, `gs://` refs through
/// Firebase Storage, everything else through the network stack, and any
/// failure degrades to [fallback] (or a neutral placeholder) instead of
/// crashing with a codec/URI exception.
class EduImage extends StatelessWidget {
  final String? source;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? placeholderColor;
  final IconData placeholderIcon;
  final Widget? fallback;

  const EduImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholderColor,
    this.placeholderIcon = Icons.image_outlined,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final kind = EduImageResolver.kindOf(source);

    Widget content;
    switch (kind) {
      case EduImageKind.base64:
        final bytes = EduImageResolver.decodeBase64(source!);
        content = bytes == null
            ? _buildFallback(context)
            : Image.memory(
                bytes,
                fit: fit,
                width: width,
                height: height,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => _buildFallback(context),
              );
        break;
      case EduImageKind.http:
        content = Image.network(
          source!,
          fit: fit,
          width: width,
          height: height,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : _buildPlaceholder(context),
          errorBuilder: (_, __, ___) => _buildFallback(context),
        );
        break;
      case EduImageKind.firebaseStorage:
      case EduImageKind.file:
        content = _AsyncResolvedImage(
          source: source,
          fit: fit,
          onFallback: _buildFallback(context),
          onLoading: _buildPlaceholder(context),
        );
        break;
      case EduImageKind.empty:
      case EduImageKind.unknown:
      case EduImageKind.asset:
        content = _AssetOrFallback(source: kind == EduImageKind.asset ? source : null, fallback: _buildFallback(context));
        break;
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: content);
    }
    return content;
  }

  Widget _buildPlaceholder(BuildContext context) {
    final color = placeholderColor ??
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.10);
    return Container(
      width: width,
      height: height,
      color: color,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 22,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  Widget _buildFallback(BuildContext context) {
    if (fallback != null) return fallback!;
    return Container(
      width: width,
      height: height,
      color: placeholderColor ?? Colors.transparent,
      child: Center(
        child: Icon(
          placeholderIcon,
          size: 24,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

/// Resolves slow sources (`gs://`, `file://`) in a future.
class _AsyncResolvedImage extends StatefulWidget {
  final String? source;
  final BoxFit fit;
  final Widget onFallback;
  final Widget onLoading;

  const _AsyncResolvedImage({
    required this.source,
    required this.fit,
    required this.onFallback,
    required this.onLoading,
  });

  @override
  State<_AsyncResolvedImage> createState() => _AsyncResolvedImageState();
}

class _AsyncResolvedImageState extends State<_AsyncResolvedImage> {
  ImageProvider? _provider;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _AsyncResolvedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _failed = false;
      _provider = null;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final provider = await EduImageResolver.resolveProviderAsync(widget.source);
    if (!mounted) return;
    setState(() {
      if (provider == null) {
        _failed = true;
      } else {
        _provider = provider;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.onFallback;
    final provider = _provider;
    if (provider == null) return widget.onLoading;
    return Image(
      image: provider,
      fit: widget.fit,
      errorBuilder: (_, __, ___) => widget.onFallback,
    );
  }
}

class _AssetOrFallback extends StatelessWidget {
  final String? source;
  final Widget fallback;

  const _AssetOrFallback({required this.source, required this.fallback});

  @override
  Widget build(BuildContext context) {
    if (source == null) return fallback;
    return Image.asset(source!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => fallback);
  }
}

/// Avatar widget that renders **any** avatar source (Base64, HTTP, Firebase
/// Storage, URL from Firestore, or null) and gracefully falls back to the
/// user's initials. Never crashes on malformed sources.
class EduAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const EduAvatar({
    super.key,
    required this.imageUrl,
    required this.name,
    this.radius = 22,
    this.backgroundColor,
    this.foregroundColor,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'EB';
    if (parts.length == 1) {
      final first = parts.first;
      final alpha = RegExp(r'[A-Za-z]').firstMatch(first);
      return alpha != null ? alpha.group(0)!.toUpperCase() : 'EB';
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? colorScheme.primary.withValues(alpha: 0.25);
    final fg = foregroundColor ?? colorScheme.primary;

    final initials = CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: Text(
        _initials,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.75,
          letterSpacing: 0.5,
        ),
      ),
    );

    final kind = EduImageResolver.kindOf(imageUrl);
    if (kind == EduImageKind.empty || kind == EduImageKind.unknown) {
      return initials;
    }

    if (kind == EduImageKind.base64) {
      final bytes = EduImageResolver.decodeBase64(imageUrl!);
      if (bytes == null) return initials;
      return CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        foregroundImage: MemoryImage(bytes),
        onForegroundImageError: (_, __) {},
        child: initials,
      );
    }

    if (kind == EduImageKind.http) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        child: ClipOval(
          child: Image.network(
            imageUrl!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => initials,
          ),
        ),
      );
    }

    // Firebase Storage / file:// handled async.
    return EduImage(
      source: imageUrl,
      fit: BoxFit.cover,
      width: radius * 2,
      height: radius * 2,
      fallback: ClipOval(child: initials),
      borderRadius: BorderRadius.circular(radius),
    );
  }
}
