import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../features/chat/data/ai_api_service.dart';
import '../../../services/mock_dashboard_data.dart';

class IngestionPage extends ConsumerStatefulWidget {
  const IngestionPage({super.key});

  @override
  ConsumerState<IngestionPage> createState() => _IngestionPageState();
}

class _IngestionPageState extends ConsumerState<IngestionPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isUploading = false;
  IngestionUploadResult? _lastResult;
  String? _errorMessage;
  List<String> _selectedNames = const [];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPdfs() async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
      _errorMessage = null;
      _lastResult = null;
      _selectedNames = const [];
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        allowMultiple: true,
        withData: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _isUploading = false;
        });
        return;
      }

      final usableFiles = result.files
          .where((file) => (file.path ?? '').isNotEmpty)
          .toList(growable: false);

      if (usableFiles.isEmpty) {
        throw const FormatException('Selected PDF files could not be read.');
      }

      final multipartFiles = <MultipartFile>[];
      for (final file in usableFiles) {
        multipartFiles.add(
          await MultipartFile.fromFile(
            file.path!,
            filename: file.name,
            contentType: DioMediaType('application', 'pdf'),
          ),
        );
      }

      setState(() {
        _selectedNames = usableFiles.map((file) => file.name).toList();
      });

      final uploadResult = await ref
          .read(aiApiServiceProvider)
          .uploadKnowledgePdfs(files: multipartFiles);

      if (!mounted) return;
      setState(() {
        _lastResult = uploadResult;
        _isUploading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              eyebrow: 'Upload & Ingestion',
              title: 'Knowledge ingestion control surface',
              description:
                  'Upload architecture PDFs, moderation docs, or research papers into YenkasaAI so the corpus can answer with fresh project context.',
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: const [
                SizedBox(
                  width: 240,
                  child: MetricCard(
                    label: 'Target collection',
                    value: 'public',
                    note: 'Yenkasa platform knowledge',
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: MetricCard(
                    label: 'Embedding backend',
                    value: 'HF now',
                    note: 'Gemini migration prepared',
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: MetricCard(
                    label: 'Storage path',
                    value: 'GCS',
                    note: 'Snapshot-backed Chroma',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GlassCard(
              strong: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ingestion pipeline',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final stage in ingestionStages) ...[
                    GlassCard(
                      child: Row(
                        children: [
                          StatusChip(
                            label: stage.status,
                            tone: stage.status == 'done'
                                ? StatusTone.success
                                : stage.status == 'active'
                                ? StatusTone.info
                                : StatusTone.warning,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stage.name,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  stage.detail,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _isUploading ? null : _pickAndUploadPdfs,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(
                      _isUploading ? 'Uploading PDFs...' : 'Select PDF files',
                    ),
                  ),
                  if (_selectedNames.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Selected files',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final name in _selectedNames)
                          Chip(
                            avatar: const Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 18,
                            ),
                            label: Text(name),
                          ),
                      ],
                    ),
                  ],
                  if (_lastResult != null) ...[
                    const SizedBox(height: 16),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StatusChip(
                            label: 'uploaded',
                            tone: StatusTone.success,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Accepted ${_lastResult!.accepted} file(s) into ${_lastResult!.targetCollection}.',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Chunks inserted: ${_lastResult!.chunksInserted?.toString() ?? 'pending'}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    GlassCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
