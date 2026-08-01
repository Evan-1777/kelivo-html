import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/shared/widgets/html_fragment_view.dart';
import 'package:Kelivo/shared/widgets/markdown_with_highlight.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import '../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('fragment.html bundled asset (regression)', () {
    test('template is bundled, non-empty, with key placeholders', () async {
      final template = await rootBundle.loadString('assets/html/fragment.html');
      expect(template, isNotEmpty);
      expect(template, contains('{{FRAGMENT_BASE64}}'));
      expect(template, contains('{{MARKDOWN_IT_JS}}'));
      expect(template, contains('{{BACKGROUND}}'));
      expect(template, contains('{{LINE_HEIGHT}}'));
      expect(template, contains('{{BASE_FONT_SIZE}}'));
    });

    test('composeFragmentDocument consumes the bundled template fully', () async {
      final template = await rootBundle.loadString('assets/html/fragment.html');
      final cs = ThemeData.light().colorScheme;
      final out = composeFragmentDocument(
        template: template,
        fragmentHtml:
            '<div style="border-top: 3px solid #2c3e50;"><h4>核心优势</h4></div>',
        markdownItJs: '/* md stub */ window.markdownit = function () {};',
        cs: cs,
        fontSize: 15.7,
        lineHeight: 1.5,
        bubbleBackground: const Color(0xFFF7F7F7),
      );
      // No leftover placeholders means every {{...}} was substituted.
      expect(out, isNot(contains('{{')));
      expect(out, contains('id="content"'));
    });
  });

  group('shouldUseWebViewForHtml', () {
    test('returns true on WebView-capable platforms', () {
      expect(shouldUseWebViewForHtml(TargetPlatform.android), isTrue);
      expect(shouldUseWebViewForHtml(TargetPlatform.iOS), isTrue);
      expect(shouldUseWebViewForHtml(TargetPlatform.macOS), isTrue);
      expect(shouldUseWebViewForHtml(TargetPlatform.windows), isTrue);
    });

    test('returns false on Linux (no WebView implementation)', () {
      expect(shouldUseWebViewForHtml(TargetPlatform.linux), isFalse);
    });
  });

  group('composeFragmentDocument', () {
    const template = '''
<!DOCTYPE html><html><head><style>
body { background: {{BACKGROUND}}; color: {{ON_SURFACE}}; }
code { background: {{OUTLINE_VARIANT}}; }
h6 { color: {{ON_SURFACE_VARIANT}}; }
a { color: {{PRIMARY}}; }
font-size: {{BASE_FONT_SIZE}}px; line-height: {{LINE_HEIGHT}};
</style></head><body>
<script>{{MARKDOWN_IT_JS}}</script>
<script>var b64 = atob('{{FRAGMENT_BASE64}}');</script>
</body></html>''';

    const fragment =
        '<div style="border-top: 3px solid #2c3e50;"><h4>核心优势</h4>'
        '<p>半导体先进制程</p></div>';
    const stubMarkdownItJs = '/* md stub */ window.markdownit = function () {};';

    final cs = ThemeData.light().colorScheme;

    String build() => composeFragmentDocument(
          template: template,
          fragmentHtml: fragment,
          markdownItJs: stubMarkdownItJs,
          cs: cs,
          fontSize: 15.7,
          lineHeight: 1.5,
          bubbleBackground: const Color(0xFFF7F7F7),
        );

    test('embeds fragment base64 round-trip, Chinese intact', () {
      final out = build();
      expect(out, isNot(contains('{{FRAGMENT_BASE64}}')));
      // Extract the base64 literal between the atob quotes.
      final start = out.indexOf("atob('") + 6;
      final end = out.indexOf("')", start);
      final b64 = out.substring(start, end);
      final decoded = utf8.decode(base64Decode(b64));
      expect(decoded, fragment);
      expect(decoded, contains('核心优势')); // UTF-8 Chinese survives
    });

    test('injects colors, font size and line height', () {
      final out = build();
      expect(out, contains('#F7F7F7')); // bubble background
      expect(out, contains('15.7px'));
      expect(out, contains('1.50'));
      expect(out, isNot(contains('{{BACKGROUND}}')));
      expect(out, isNot(contains('{{ON_SURFACE}}')));
      expect(out, isNot(contains('{{OUTLINE_VARIANT}}')));
      expect(out, isNot(contains('{{ON_SURFACE_VARIANT}}')));
      expect(out, isNot(contains('{{PRIMARY}}')));
    });

    test('produces offline document with no external URLs', () {
      final out = build();
      expect(out, isNot(contains('http://')));
      expect(out, isNot(contains('https://')));
      expect(out, isNot(contains('cdn.jsdelivr.net')));
    });

    test('injects the markdown-it bundle via {{MARKDOWN_IT_JS}}', () {
      final out = build();
      expect(out, isNot(contains('{{MARKDOWN_IT_JS}}')));
      expect(out, contains(stubMarkdownItJs));
    });
  });

  group('markdown-it fragment rendering pipeline (TASK-005)', () {
    const fragment =
        '<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">'
        '<div style="border-top: 3px solid #2c3e50; padding: 10px;">'
        '<h4 style="margin: 0 0 8px; font-size: 14px; color: #2c3e50;">核心优势</h4>'
        '<ul style="margin: 0; padding-left: 20px;">'
        '<li><b>技术壁垒：</b>半导体先进制程。</li>'
        '</ul>'
        '</div>'
        '</div>';

    test('template declares no runtime external URLs', () async {
      final template = await rootBundle.loadString('assets/html/fragment.html');
      expect(template, isNot(contains('http://')));
      expect(template, isNot(contains('https://')));
      expect(template, isNot(contains('esm.sh')));
      expect(template, isNot(contains('cdn.')));
    });

    test('bundled markdown-it asset is bundled and injectable', () async {
      final bundle =
          await rootBundle.loadString('assets/js/markdown-it.min.js');
      expect(bundle, isNotEmpty);
      expect(bundle.length, greaterThan(10000));
      // UMD global used by the template pipeline.
      expect(bundle, contains('markdownit'));

      final template = await rootBundle.loadString('assets/html/fragment.html');
      final cs = ThemeData.light().colorScheme;
      final out = composeFragmentDocument(
        template: template,
        fragmentHtml: fragment,
        markdownItJs: bundle,
        cs: cs,
        fontSize: 15.7,
        lineHeight: 1.5,
        bubbleBackground: const Color(0xFFF7F7F7),
      );
      expect(out, isNot(contains('{{MARKDOWN_IT_JS}}')));
      expect(out, contains('markdown-it 14.0.0')); // bundle header survived
    });

    test('wires strip-outer-div -> md.render -> rewrap pipeline', () async {
      final template = await rootBundle.loadString('assets/html/fragment.html');
      final cs = ThemeData.light().colorScheme;
      final out = composeFragmentDocument(
        template: template,
        fragmentHtml: fragment,
        markdownItJs: 'window.markdownit = function () {};',
        cs: cs,
        fontSize: 15.7,
        lineHeight: 1.5,
        bubbleBackground: const Color(0xFFF7F7F7),
      );
      // markdown-it configured with HTML passthrough + breaks + linkify.
      expect(
        out,
        contains('window.markdownit({ html: true, breaks: true, linkify: true })'),
      );
      // Outer div style stripped before rendering, re-applied after.
      expect(out, contains('md.render(inner)'));
      expect(out, contains("rendered + '</div>' : rendered"));
      // Fragment with raw markdown markers reaches the page base64-encoded.
      final start = out.indexOf("atob('") + 6;
      final end = out.indexOf("')", start);
      final decoded = utf8.decode(
        base64Decode(out.substring(start, end)),
      );
      expect(decoded, contains('<h4 style='));
      // Bridge channels and height reporting survive.
      expect(out, contains('ResizeObserver'));
      expect(out, contains('FragmentBridge'));
      expect(out, contains('chrome.webview'));
      expect(out, contains('a[href]'));
    });
  });

  group('StyledDivBlockMd native fallback (Linux)', () {
    const gridBlock =
        '<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">'
        '<div style="border-top: 3px solid #2c3e50; padding: 10px; background: #f8f9fa;">'
        '<h4>核心优势</h4><p>技术壁垒</p>'
        '</div>'
        '<div style="border-top: 3px solid #c0392b; padding: 10px; background: #f8f9fa;">'
        '<h4>结构性挑战</h4><p>产业失衡</p>'
        '</div>'
        '</div>';

    Widget harness(String text, {double width = 360}) {
      return ChangeNotifierProvider(
        create: (_) => SettingsProvider(
          businessPreferences: createBusinessTestPreferences(),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: MarkdownWithCodeHighlight(text: text),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders native container cards, no HtmlFragmentView', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      await tester.pumpWidget(harness(gridBlock));
      await tester.pump();

      expect(find.textContaining('核心优势'), findsOneWidget);
      expect(find.textContaining('结构性挑战'), findsOneWidget);
      // WebView path must not be taken on Linux.
      expect(find.byType(HtmlFragmentView), findsNothing);
    });
  });
}
