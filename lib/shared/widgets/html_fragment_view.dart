import 'dart:convert';

import 'package:flutter/foundation.dart' show TargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';

/// Whether HTML fragments should be rendered via WebView on [platform].
///
/// Linux has no WebView implementation (webview_flutter supports
/// Android/iOS/macOS; webview_windows covers Windows) — fall back to the
/// native StyledDivBlockMd renderer there. Also excluded on the web
/// (kIsWeb) and fuchsia where PlatformView WebView is not available.
bool shouldUseWebViewForHtml(TargetPlatform platform) {
  if (kIsWeb) return false;
  return platform != TargetPlatform.linux && platform != TargetPlatform.fuchsia;
}

/// Compose the full HTML document for a fragment (pure, sync — testable).
///
/// [template] is the fragment.html template with `{{...}}` placeholders.
/// [fragmentHtml] is the raw `<div style="...">...</div>` block, embedded
/// base64-encoded so Chinese text survives UTF-8 round-trip and the fragment
/// cannot break out of the script/style context.
String composeFragmentDocument({
  required String template,
  required String fragmentHtml,
  required ColorScheme cs,
  required double fontSize,
  required double lineHeight,
  required Color bubbleBackground,
}) {
  return template
      .replaceAll(
        '{{FRAGMENT_BASE64}}',
        base64Encode(utf8.encode(fragmentHtml)),
      )
      .replaceAll('{{BACKGROUND}}', _toCssHex(bubbleBackground))
      .replaceAll('{{ON_SURFACE}}', _toCssHex(cs.onSurface))
      .replaceAll('{{ON_SURFACE_VARIANT}}', _toCssHex(cs.onSurfaceVariant))
      .replaceAll('{{PRIMARY}}', _toCssHex(cs.primary))
      .replaceAll('{{OUTLINE_VARIANT}}', _toCssHex(cs.outlineVariant))
      .replaceAll('{{BASE_FONT_SIZE}}', fontSize.toStringAsFixed(1))
      .replaceAll('{{LINE_HEIGHT}}', lineHeight.toStringAsFixed(2));
}

/// Build the fragment document from the bundled template (async, context-aware).
Future<String> buildFragmentDocument({
  required BuildContext context,
  required String fragmentHtml,
  required double fontSize,
  required double lineHeight,
}) async {
  final cs = Theme.of(context).colorScheme;
  final template = await rootBundle.loadString('assets/html/fragment.html');
  return composeFragmentDocument(
    template: template,
    fragmentHtml: fragmentHtml,
    cs: cs,
    fontSize: fontSize,
    lineHeight: lineHeight,
    bubbleBackground: cs.surfaceContainerLow,
  );
}

/// Renders an HTML fragment (a complete `<div style="...">...</div>` block)
/// inside a height-adaptive WebView.
///
/// The WebView engine parses the fragment's own inline CSS (flex/grid/border
/// directions etc.), matching the Markdown Preview. A JS bridge reports the
/// content height via [FragmentBridge] channel; link taps are forwarded to
/// [onLinkTap].
class HtmlFragmentView extends StatefulWidget {
  const HtmlFragmentView({
    super.key,
    required this.fragmentHtml,
    this.fontSize = 15.7,
    this.lineHeight = 1.5,
    this.onLinkTap,
  });

  final String fragmentHtml;
  final double fontSize;
  final double lineHeight;

  /// Forwarded for any `<a href>` tap inside the fragment.
  final void Function(String url)? onLinkTap;

  @override
  State<HtmlFragmentView> createState() => _HtmlFragmentViewState();
}

class _HtmlFragmentViewState extends State<HtmlFragmentView> {
  WebViewController? _controller;
  double _height = 48;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('FragmentBridge', onMessageReceived: _onMessage);
    _load();
  }

  Future<void> _load() async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final doc = await buildFragmentDocument(
      context: context,
      fragmentHtml: widget.fragmentHtml,
      fontSize: widget.fontSize,
      lineHeight: widget.lineHeight,
    );
    if (!mounted || _controller != controller) return;
    _loaded = true;
    await controller.loadHtmlString(doc);
  }

  void _onMessage(JavaScriptMessage message) {
    try {
      final obj = jsonDecode(message.message) as Map<String, dynamic>;
      final type = obj['type'] as String?;
      if (type == 'height') {
        final value = (obj['value'] as num?)?.toDouble();
        if (value != null && value > 0 && value != _height && mounted) {
          setState(() => _height = value);
        }
      } else if (type == 'link') {
        final href = obj['href'] as String?;
        if (href != null && href.isNotEmpty) {
          widget.onLinkTap?.call(href);
        }
      }
    } catch (_) {
      // Ignore malformed bridge messages.
    }
  }

  @override
  void didUpdateWidget(HtmlFragmentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fragmentHtml != oldWidget.fragmentHtml && _loaded) {
      _load(); // Content changed during streaming — reload once.
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return SizedBox(width: double.infinity, height: _height);
    }
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerLow,
      width: double.infinity,
      child: SizedBox(
        height: _height,
        child: WebViewWidget(controller: controller),
      ),
    );
  }
}

String _toCssHex(Color c) {
  int to255(double v) => (v * 255.0).round().clamp(0, 255);
  final a = to255(c.a).toRadixString(16).padLeft(2, '0').toUpperCase();
  final r = to255(c.r).toRadixString(16).padLeft(2, '0').toUpperCase();
  final g = to255(c.g).toRadixString(16).padLeft(2, '0').toUpperCase();
  final b = to255(c.b).toRadixString(16).padLeft(2, '0').toUpperCase();
  return '#$r$g$b$a';
}
