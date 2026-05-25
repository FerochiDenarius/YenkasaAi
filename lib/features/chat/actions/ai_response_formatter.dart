import 'dart:math' as math;

class AiResponseFormatter {
  const AiResponseFormatter._();

  static String plainText(String markdown) {
    var text = markdown;
    text = text.replaceAllMapped(RegExp(r'```(?:[a-zA-Z0-9_+-]+)?\n([\s\S]*?)```'), (match) {
      return match.group(1)?.trim() ?? '';
    });
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
