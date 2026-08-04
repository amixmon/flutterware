import 'package:flutter/material.dart';

enum CodeLanguage {
  dart('Dart'),
  kotlin('Kotlin'),
  java('Java'),
  json('JSON'),
  yaml('YAML'),
  xml('XML'),
  markdown('Markdown'),
  shell('Shell'),
  web('Web'),
  plainText('Plain text');

  const CodeLanguage(this.label);

  final String label;

  static CodeLanguage fromPath(String path) {
    final name = path.toLowerCase();
    final extension = name.contains('.') ? name.split('.').last : '';
    return switch (extension) {
      'dart' => dart,
      'kt' || 'kts' || 'gradle' => kotlin,
      'java' => java,
      'json' => json,
      'yaml' || 'yml' => yaml,
      'xml' => xml,
      'md' => markdown,
      'sh' || 'bash' => shell,
      'html' || 'css' || 'js' || 'ts' => web,
      _ => plainText,
    };
  }
}

class SyntaxTextEditingController extends TextEditingController {
  SyntaxTextEditingController({required this.language, super.text});

  final CodeLanguage language;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final colors = Theme.of(context).colorScheme;
    final base = style ?? DefaultTextStyle.of(context).style;
    final matches = _tokens(text, language);
    if (matches.isEmpty) return TextSpan(style: base, text: text);
    final children = <InlineSpan>[];
    var offset = 0;
    for (final token in matches) {
      if (token.start > offset) {
        children.add(TextSpan(text: text.substring(offset, token.start)));
      }
      children.add(
        TextSpan(
          text: text.substring(token.start, token.end),
          style: switch (token.kind) {
            _TokenKind.keyword => TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.w600,
            ),
            _TokenKind.string => TextStyle(color: colors.tertiary),
            _TokenKind.comment => TextStyle(
              color: colors.onSurfaceVariant.withValues(alpha: .78),
              fontStyle: FontStyle.italic,
            ),
            _TokenKind.number => TextStyle(color: colors.secondary),
            _TokenKind.annotation => TextStyle(color: colors.error),
            _TokenKind.markup => TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.w500,
            ),
          },
        ),
      );
      offset = token.end;
    }
    if (offset < text.length) {
      children.add(TextSpan(text: text.substring(offset)));
    }
    return TextSpan(style: base, children: children);
  }
}

class AppCodeEditor extends StatelessWidget {
  const AppCodeEditor({
    super.key,
    required this.controller,
    required this.readOnly,
  });

  final TextEditingController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerLowest,
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        expands: true,
        maxLines: null,
        minLines: null,
        keyboardType: TextInputType.multiline,
        textAlignVertical: TextAlignVertical.top,
        autocorrect: false,
        enableSuggestions: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        style: TextStyle(
          color: colors.onSurface,
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.45,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
        ),
      ),
    );
  }
}

enum _TokenKind { keyword, string, comment, number, annotation, markup }

class _CodeToken {
  const _CodeToken(this.start, this.end, this.kind);

  final int start;
  final int end;
  final _TokenKind kind;
}

List<_CodeToken> _tokens(String source, CodeLanguage language) {
  if (source.isEmpty || language == CodeLanguage.plainText) return const [];
  final keywords = switch (language) {
    CodeLanguage.dart => _dartKeywords,
    CodeLanguage.kotlin => _kotlinKeywords,
    CodeLanguage.java => _javaKeywords,
    CodeLanguage.json => const ['true', 'false', 'null'],
    CodeLanguage.yaml => const ['true', 'false', 'null', 'yes', 'no'],
    CodeLanguage.shell => const [
      'if',
      'then',
      'else',
      'elif',
      'fi',
      'for',
      'while',
      'in',
      'do',
      'done',
      'case',
      'esac',
      'function',
      'exit',
      'export',
      'local',
    ],
    CodeLanguage.web => const [
      'const',
      'let',
      'var',
      'function',
      'return',
      'if',
      'else',
      'for',
      'while',
      'class',
      'import',
      'export',
      'async',
      'await',
      'true',
      'false',
      'null',
    ],
    _ => const <String>[],
  };
  final keywordPattern = keywords.isEmpty
      ? r'(?!x)x'
      : '\\b(?:${keywords.map(RegExp.escape).join('|')})\\b';
  final hashComment =
      language == CodeLanguage.yaml || language == CodeLanguage.shell
      ? r'|#[^\n]*'
      : '';
  final markup = switch (language) {
    CodeLanguage.xml ||
    CodeLanguage.web => r'<!--[\s\S]*?-->|</?[A-Za-z][^>]*>',
    CodeLanguage.markdown =>
      r'^#{1,6}[^\n]*|`{1,3}[^`\n]+`{1,3}|\*\*[^\n*]+\*\*',
    _ => r'(?!x)x',
  };
  final expression = RegExp(
    '($markup)|(/\\*[\\s\\S]*?\\*/|//[^\\n]*$hashComment)|'
    r'''("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')|'''
    '(@[A-Za-z_]\\w*)|($keywordPattern)|'
    r'\b(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?)\b',
    multiLine: true,
  );
  return expression
      .allMatches(source)
      .map((match) {
        final value = match.group(0)!;
        final kind = match.group(1) != null
            ? _TokenKind.markup
            : match.group(2) != null
            ? _TokenKind.comment
            : match.group(3) != null
            ? _TokenKind.string
            : match.group(4) != null
            ? _TokenKind.annotation
            : keywords.contains(value)
            ? _TokenKind.keyword
            : _TokenKind.number;
        return _CodeToken(match.start, match.end, kind);
      })
      .toList(growable: false);
}

const _dartKeywords = [
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'base',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'deferred',
  'do',
  'dynamic',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'interface',
  'is',
  'late',
  'library',
  'mixin',
  'new',
  'null',
  'of',
  'on',
  'operator',
  'part',
  'required',
  'rethrow',
  'return',
  'sealed',
  'set',
  'show',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'typedef',
  'var',
  'void',
  'when',
  'while',
  'with',
  'yield',
];

const _kotlinKeywords = [
  'as',
  'break',
  'class',
  'continue',
  'do',
  'else',
  'false',
  'for',
  'fun',
  'if',
  'in',
  'interface',
  'is',
  'null',
  'object',
  'package',
  'return',
  'super',
  'this',
  'throw',
  'true',
  'try',
  'typealias',
  'val',
  'var',
  'when',
  'while',
  'by',
  'catch',
  'constructor',
  'delegate',
  'dynamic',
  'field',
  'file',
  'finally',
  'get',
  'import',
  'init',
  'param',
  'property',
  'receiver',
  'set',
  'setparam',
  'where',
  'actual',
  'abstract',
  'annotation',
  'companion',
  'const',
  'crossinline',
  'data',
  'enum',
  'expect',
  'external',
  'final',
  'infix',
  'inline',
  'inner',
  'internal',
  'lateinit',
  'noinline',
  'open',
  'operator',
  'out',
  'override',
  'private',
  'protected',
  'public',
  'reified',
  'sealed',
  'suspend',
  'tailrec',
  'vararg',
];

const _javaKeywords = [
  'abstract',
  'assert',
  'boolean',
  'break',
  'byte',
  'case',
  'catch',
  'char',
  'class',
  'const',
  'continue',
  'default',
  'do',
  'double',
  'else',
  'enum',
  'extends',
  'false',
  'final',
  'finally',
  'float',
  'for',
  'goto',
  'if',
  'implements',
  'import',
  'instanceof',
  'int',
  'interface',
  'long',
  'native',
  'new',
  'null',
  'package',
  'private',
  'protected',
  'public',
  'return',
  'short',
  'static',
  'strictfp',
  'super',
  'switch',
  'synchronized',
  'this',
  'throw',
  'throws',
  'transient',
  'true',
  'try',
  'void',
  'volatile',
  'while',
];
