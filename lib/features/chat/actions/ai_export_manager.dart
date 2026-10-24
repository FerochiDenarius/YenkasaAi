import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'ai_response_formatter.dart';
import 'ai_response_models.dart';

enum AiResponseExportFormat { txt, markdown, pdf, docx }

class AiShareManager {
  const AiShareManager();

  Future<void> shareResponse(BuildContext context, AiResponseSnapshot snapshot) async {
    final text = AiResponseFormatter.shareText(snapshot.responseText);
    await SharePlus.instance.share(ShareParams(text: text, subject: responseSubject(snapshot)));
  }
}

class AiExportManager {
  const AiExportManager();

  Future<void> exportResponse(
    BuildContext context,
    AiResponseSnapshot snapshot, {
    required AiResponseExportFormat format,
  }) async {
    switch (format) {
      case AiResponseExportFormat.txt:
        await _exportTextLike(
          snapshot,
          filename: _filename(snapshot, 'txt'),
          mimeType: 'text/plain',
          content: AiResponseFormatter.plainText(snapshot.responseText),
        );
        return;
      case AiResponseExportFormat.markdown:
        await _exportTextLike(
          snapshot,
          filename: _filename(snapshot, 'md'),
          mimeType: 'text/markdown',
          content: snapshot.responseText,
        );
        return;
      case AiResponseExportFormat.pdf:
        await _exportPdf(snapshot);
        return;
      case AiResponseExportFormat.docx:
        throw UnsupportedError('DOCX export is planned but not implemented yet.');
    }
  }

  Future<void> _exportTextLike(
    AiResponseSnapshot snapshot, {
    required String filename,
    required String mimeType,
    required String content,
  }) async {
    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(_decorateExport(snapshot, content))),
      name: filename,
      mimeType: mimeType,
    );
    await SharePlus.instance.share(
      ShareParams(files: [file], subject: responseSubject(snapshot), text: responseSubject(snapshot)),
    );
  }

  Future<void> _exportPdf(AiResponseSnapshot snapshot) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('YenkasaAI Response Export')),
          pw.Paragraph(text: responseSubject(snapshot)),
          pw.SizedBox(height: 12),
          pw.Text(snapshot.responseText),
        ],
      ),
    );

    final bytes = await document.save();
    final file = XFile.fromData(
      bytes,
      name: _filename(snapshot, 'pdf'),
      mimeType: 'application/pdf',
    );
    await SharePlus.instance.share(
      ShareParams(files: [file], subject: responseSubject(snapshot), text: responseSubject(snapshot)),
    );
  }

  String _decorateExport(AiResponseSnapshot snapshot, String content) {
    final buffer = StringBuffer()
      ..writeln('YenkasaAI Response Export')
      ..writeln('Generated: ${snapshot.timestamp.toIso8601String()}')
      ..writeln('Audience: ${snapshot.audience}')
      ..writeln('Model: ${snapshot.model ?? 'unknown'}')
      ..writeln('Conversation: ${snapshot.conversationReference ?? 'unknown'}')
      ..writeln()
      ..write(content.trim());
    return buffer.toString();
  }

  String _filename(AiResponseSnapshot snapshot, String extension) {
    final timestamp = snapshot.timestamp.toIso8601String().replaceAll(':', '-');
    final model = (snapshot.model ?? 'response').replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'yenkasa_ai_${model}_$timestamp.$extension';
  }

}

String responseSubject(AiResponseSnapshot snapshot) {
  return 'YenkasaAI Response${snapshot.model != null ? ' • ${snapshot.model}' : ''}';
}
