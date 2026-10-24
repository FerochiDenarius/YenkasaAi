import 'dart:math' as math;

class AiResponseFormatter {
  const AiResponseFormatter._();

  static String forDisplay(String markdown) {
    final lines = markdown.replaceAll('\r\n', '\n').split('\n');
    final output = <String>[];
    final pathRun = <String>[];
    var inCodeFence = false;

    void flushPathRun() {
      if (pathRun.isEmpty) return;
      if (pathRun.length >= 2) {
        if (output.isNotEmpty && output.last.trim().isNotEmpty) {
          output.add('');
        }
        for (final path in pathRun) {
          final cleanPath = path.trim().replaceAll(RegExp(r'^`|`$'), '');
          output.add('- `$cleanPath`');
        }
        output.add('');
      } else {
        output.add(pathRun.single);
      }
      pathRun.clear();
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('```')) {
        flushPathRun();
        inCodeFence = !inCodeFence;
        output.add(line);
        continue;
      }

      if (!inCodeFence && _looksLikeStandalonePath(trimmed)) {
        pathRun.add(trimmed);
        continue;
      }

      flushPathRun();
      output.add(line);
    }
    flushPathRun();

    return output.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  static bool _looksLikeStandalonePath(String value) {
    if (value.isEmpty) return false;
    if (RegExp(r'^([-*+]|\d+[.)])\s+').hasMatch(value)) return false;
    if (value.endsWith(':')) return false;

    final unquoted = value.replaceAll(RegExp(r'^`|`$'), '');
    if (!unquoted.contains('/') && !unquoted.contains(r'\')) return false;
    if (unquoted.contains('://')) return false;

    final pathShape = RegExp(
      r'^(?:[A-Za-z]:[\\/]|\.{0,2}[\\/]|~[\\/])?[A-Za-z0-9_@.+ -]+(?:[\\/][A-Za-z0-9_@.+() -]+)+[\\/]?$',
    );
    return pathShape.hasMatch(unquoted);
  }

  static String plainText(String markdown) {
    var text = markdown;
    text = text.replaceAllMapped(
      RegExp(r'```(?:[a-zA-Z0-9_+-]+)?\n([\s\S]*?)```'),
      (match) {
        return match.group(1)?.trim() ?? '';
      },
    );
    text = text.replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]+\)'), r'$1');
    text = text.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1');
    text = text.replaceAll(RegExp(r'^\s{0,3}#{1,6}\s+', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^\s{0,3}>\s?', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '• ');
    text = text.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');
    text = text.replaceAll(RegExp(r'(\*\*|__)(.*?)\1'), r'$2');
    text = text.replaceAll(RegExp(r'(\*|_)(.*?)\1'), r'$2');
    text = text.replaceAll(RegExp(r'[`~]'), '');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  static String shareText(String markdown) {
    return markdown.trim();
  }

  static List<String> extractCodeBlocks(String markdown) {
    final blocks = <String>[];
    final regex = RegExp(r'```(?:[a-zA-Z0-9_+-]+)?\n([\s\S]*?)```');
    for (final match in regex.allMatches(markdown)) {
      final block = match.group(1)?.trim();
      if (block != null && block.isNotEmpty) {
        blocks.add(block);
      }
    }
    return blocks;
  }

  static bool isLongResponse(String markdown) {
    return markdown.trim().length > 720 || markdown.split('\n').length > 16;
  }

  static int visibleLineCount(String markdown) {
    return math.max(1, markdown.split('\n').length);
  }
}
