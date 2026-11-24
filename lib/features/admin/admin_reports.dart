import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../common/widgets.dart';

/// Reports: date-filtered complaint list + CSV and PDF export.
class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() =>
      _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  DateTime? _from;
  DateTime? _to;
  String? _status;
  bool _busy = false;

  Future<List<Complaint>> _load() {
    final user = ref.read(sessionProvider);
    final deptId =
        user?.isSuperAdmin == true ? null : user?.departmentId;
    return ref.read(repositoryProvider).getComplaints(
          departmentId: deptId,
          status: _status,
          from: _from,
          to: _to,
        );
  }

  Future<void> _saveFile(String fileName, Uint8List bytes) async {
    if (kIsWeb) {
      await FilePicker.platform.saveFile(
        fileName: fileName,
        bytes: bytes,
      );
      if (mounted) showSnack(context, 'Report downloaded.');
      return;
    }
    final dir = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    if (mounted) showSnack(context, 'Saved to ${file.path}');
  }

  Future<void> _exportCsv() async {
    setState(() => _busy = true);
    try {
      final list = await _load();
      final rows = <List<dynamic>>[
        [
          'Complaint ID',
          'Title',
          'Category',
          'Department',
          'Priority',
          'Status',
          'Anonymous',
          'Submitted',
          'Resolved'
        ],
      ];
      final depts = await ref.read(repositoryProvider).getDepartments();
      final names = {for (final d in depts) d.id: d.name};
      for (final c in list) {
        rows.add([
          c.trackingId,
          c.title,
          c.category,
          names[c.departmentId] ?? '',
          c.priority,
          c.status,
          c.isAnonymous ? 'Yes' : 'No',
          formatDateTime(c.createdAt),
          c.resolvedAt == null ? '' : formatDateTime(c.resolvedAt!),
        ]);
      }
      final csv = const ListToCsvConverter().convert(rows);
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      await _saveFile(
          'vsit-complaints-$stamp.csv', Uint8List.fromList(csv.codeUnits));
    } catch (e) {
      if (mounted) {
        showSnack(context, e.toString().replaceFirst('Exception: ', ''),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(repositoryProvider);
      final list = await _load();
      final stats = await repo.getStats();
      final byCategory = await repo.getComplaintsByCategory();
      final depts = await repo.getDepartments();
      final names = {for (final d in depts) d.id: d.name};

      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          header: (ctx) => pw.Text(
            'VSIT Complaint Box — Complaints Report',
            style: pw.TextStyle(
                fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          footer: (ctx) => pw.Text(
            'Generated ${formatDateTime(DateTime.now())} • Page ${ctx.pageNumber}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
          ),
          build: (ctx) => [
            pw.Text(
                'Total: ${list.length} complaints in the selected period • '
                'Resolved: ${stats.resolved} • '
                'Pending: ${stats.pending} • '
                'Resolution rate: ${stats.resolutionPercent.toStringAsFixed(0)}% • '
                'Avg resolution: ${stats.avgResolutionHours.toStringAsFixed(1)} hours',
                style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 12),
            pw.Text('Complaints by category',
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: ['Category', 'Count'],
              data: byCategory.entries
                  .map((e) => [e.key, e.value.toString()])
                  .toList(),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Complaints',
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: ['ID', 'Title', 'Category', 'Dept', 'Priority', 'Status'],
              data: list
                  .map((c) => [
                        c.trackingId,
                        c.title.length > 32
                            ? '${c.title.substring(0, 32)}…'
                            : c.title,
                        c.category,
                        names[c.departmentId] ?? '',
                        c.priority,
                        c.status,
                      ])
                  .toList(),
            ),
          ],
        ),
      );
      final bytes = await doc.save();
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      await _saveFile('vsit-complaints-$stamp.pdf', bytes);
    } catch (e) {
      if (mounted) {
        showSnack(context, e.toString().replaceFirst('Exception: ', ''),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reports',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text(
            'Filter complaints and export them as CSV or PDF for college records.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2025),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null) {
                    setState(() {
                      _from = picked.start;
                      _to = picked.end.add(const Duration(days: 1));
                    });
                  }
                },
                icon: const Icon(Icons.date_range),
                label: Text(_from == null
                    ? 'Date range'
                    : '${formatDate(_from!)} – ${formatDate(_to!)}'),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    ...statusLabels.entries.map((e) => DropdownMenuItem(
                        value: e.key, child: Text(e.value))),
                  ],
                  onChanged: (v) => setState(() => _status = v),
                ),
              ),
              if (_from != null || _status != null)
                TextButton(
                  onPressed: () => setState(() {
                    _from = null;
                    _to = null;
                    _status = null;
                  }),
                  child: const Text('Clear filters'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _exportCsv,
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Export CSV'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _exportPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Export PDF'),
                ),
              ),
            ],
          ),
          const SectionTitle('Preview'),
          FutureBuilder<List<Complaint>>(
            future: _load(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return const EmptyState(
                  icon: Icons.description_outlined,
                  title: 'No complaints in this range',
                  subtitle: 'Adjust the filters to see results.',
                );
              }
              return Column(
                children: [
                  Text('${list.length} complaint(s) match the filters.',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  ...list.take(10).map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ComplaintCard(complaint: c),
                      )),
                  if (list.length > 10)
                    Text('…and ${list.length - 10} more in the export.',
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
