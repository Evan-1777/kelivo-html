import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/shared/widgets/html_fragment_view.dart';
import 'package:Kelivo/shared/widgets/markdown_with_highlight.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import '../../support/business_test_harness.dart';

void main() {
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
<script>var b64 = atob('{{FRAGMENT_BASE64}}');</script>
</body></html>''';

    const fragment =
        '<div style="border-top: 3px solid #2c3e50;"><h4>核心优势</h4>'
        '<p>半导体先进制程</p></div>';

    final cs = ThemeData.light().colorScheme;

    String build() => composeFragmentDocument(
          template: template,
          fragmentHtml: fragment,
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
