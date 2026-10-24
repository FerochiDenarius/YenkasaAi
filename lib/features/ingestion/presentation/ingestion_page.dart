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
  List<_SelectedIngestionFile> _selectedFiles = const [];
  int _uploadedBytes = 0;
  int _uploadTotalBytes = 0;

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
      _selectedFiles = const [];
      _uploadedBytes = 0;
      _uploadTotalBytes = 0;
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

      final selectedFiles = usableFiles
          .map(
            (file) =>
                _SelectedIngestionFile(name: file.name, sizeBytes: file.size),
          )
          .toList(growable: false);
      setState(() {
        _selectedFiles = selectedFiles;
        _uploadTotalBytes = selectedFiles.fold<int>(
          0,
          (total, file) => total + file.sizeBytes,
        );
      });

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

      final uploadResult = await ref
          .read(aiApiServiceProvider)
          .uploadKnowledgePdfs(
            files: multipartFiles,
            onSendProgress: (sent, total) {
              if (!mounted) return;
              setState(() {
                _uploadedBytes = sent;
                if (total > 0) {
                  _uploadTotalBytes = total;
                }
              });
            },
          );

      if (!mounted) return;
      setState(() {
        _lastResult = uploadResult;
        _isUploading = false;
        if (_uploadTotalBytes > 0) {
          _uploadedBytes = _uploadTotalBytes;
        }
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
                  if (_selectedFiles.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _UploadProgressPill(
                      isUploading: _isUploading,
                      uploadedBytes: _uploadedBytes,
                      totalBytes: _uploadTotalBytes,
                      selectedFileCount: _selectedFiles.length,
                      selectedBytes: _selectedFiles.fold<int>(
                        0,
                        (total, file) => total + file.sizeBytes,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final file in _selectedFiles)
                          _FileSizePill(file: file),
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

class _SelectedIngestionFile {
  const _SelectedIngestionFile({required this.name, required this.sizeBytes});

  final String name;
  final int sizeBytes;
}

class _UploadProgressPill extends StatelessWidget {
  const _UploadProgressPill({
    required this.isUploading,
    required this.uploadedBytes,
    required this.totalBytes,
    required this.selectedFileCount,
    required this.selectedBytes,
  });

  final bool isUploading;
  final int uploadedBytes;
  final int totalBytes;
  final int selectedFileCount;
  final int selectedBytes;

  @override
  Widget build(BuildContext context) {
    final effectiveTotal = totalBytes > 0 ? totalBytes : selectedBytes;
    final progress = effectiveTotal <= 0
        ? 0.0
        : (uploadedBytes / effectiveTotal).clamp(0.0, 1.0);
    final percent = (progress * 100).round();
    final statusLabel = isUploading
        ? 'Uploading $percent%'
        : percent >= 100
        ? 'Upload complete'
        : 'Ready to upload';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.cyanAccent.withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUploading
                          ? Icons.cloud_upload_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 18,
                      color: Colors.cyanAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusLabel,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '$selectedFileCount file${selectedFileCount == 1 ? '' : 's'} • ${_formatBytes(selectedBytes)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress == 0 && isUploading ? null : progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatBytes(uploadedBytes)} uploaded of ${_formatBytes(effectiveTotal)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.64),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileSizePill extends StatelessWidget {
  const _FileSizePill({required this.file});

  final _SelectedIngestionFile file;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.picture_as_pdf_rounded, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              file.name,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatBytes(file.sizeBytes),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }
  final decimals = value >= 10 || unitIndex == 0 ? 0 : 1;
  return '${value.toStringAsFixed(decimals)} ${units[unitIndex]}';
}
