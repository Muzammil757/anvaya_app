// worksheet_screen.dart
//
// ANVAYA — Worksheet Mode (Pair 3) — CORRECTED VERSION
//
// This file is fully self-contained. It does NOT depend on Lecture Mode,
// QnA Mode, main.dart, or any global app theme/navigation.
//
// To use it from the dashboard:
//   Navigator.push(context, MaterialPageRoute(builder: (_) => const WorksheetScreen()));
//
// Fixes applied in this version:
//  1. Hindi text in the PDF now uses an embedded Devanagari font
//     (previously used the default PDF font, which has no Devanagari glyphs).
//  2. Added an in-app PDF preview screen (via `printing`'s PdfPreview widget)
//     with built-in print + share actions, instead of only sharePdf().
//  3. Font-loading failures are now surfaced to the user via a SnackBar
//     instead of being silently swallowed.
//  4. Everything remains 100% offline — JSON and both fonts load from
//     local Flutter assets only.
//
// UI THEME POLISH:
//  5. Replaced hardcoded Material colors with design system tokens from
//     AppTheme: near-white background, white cards with 20px radius and
//     a soft ambient shadow, and rose container/accent tokens for the
//     header and key accents. PDF output styling is untouched — this pass
//     only covers the on-screen widget tree.

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../theme/app_theme.dart';

/// Simple data model for a single worksheet question.
class WorksheetQuestion {
  final int questionNumber;
  final String questionHindi;
  final String questionSantali;
  final bool santaliVerified;
  final String visualHint;

  WorksheetQuestion({
    required this.questionNumber,
    required this.questionHindi,
    required this.questionSantali,
    required this.santaliVerified,
    required this.visualHint,
  });

  factory WorksheetQuestion.fromJson(Map<String, dynamic> json) {
    return WorksheetQuestion(
      questionNumber: json['question_number'] as int,
      questionHindi: json['question_hindi'] as String,
      questionSantali: json['question_santali'] as String,
      santaliVerified: (json['santali_verified'] as bool?) ?? false,
      visualHint: json['visual_hint'] as String,
    );
  }
}

class WorksheetScreen extends StatefulWidget {
  const WorksheetScreen({super.key});

  @override
  State<WorksheetScreen> createState() => _WorksheetScreenState();
}

class _WorksheetScreenState extends State<WorksheetScreen> {
  // ---- Loading state ----
  bool _isLoading = true;
  String? _errorMessage;

  // ---- Worksheet content (filled in after JSON loads) ----
  String _worksheetTitle = 'Jharkhand Primary FLN Practice Sheet';
  String _classLevel = 'Class 3';
  String _subject = 'Mathematics';
  String _lesson = 'Addition up to 20';
  List<WorksheetQuestion> _questions = [];

  // ---- PDF generation state ----
  bool _isPreparingPdf = false;

  @override
  void initState() {
    super.initState();
    _loadWorksheetContent();
  }

  /// Loads and parses assets/data/worksheet_content.json
  Future<void> _loadWorksheetContent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final String jsonString =
          await rootBundle.loadString('assets/data/worksheet_content.json');
      final Map<String, dynamic> data = jsonDecode(jsonString);
      final List<dynamic> rawQuestions = data['questions'] as List<dynamic>;

      setState(() {
        _worksheetTitle =
            data['worksheet_title'] as String? ?? _worksheetTitle;
        _classLevel = data['class_level'] as String? ?? _classLevel;
        _subject = data['subject'] as String? ?? _subject;
        _lesson = data['lesson'] as String? ?? _lesson;
        _questions = rawQuestions
            .map((q) => WorksheetQuestion.fromJson(q as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Could not load worksheet content. Please check that '
            'assets/data/worksheet_content.json exists and is registered '
            'in pubspec.yaml.\n\nDetails: $e';
      });
    }
  }

  /// Loads a .ttf font's bytes from assets for embedding into the PDF.
  /// Returns null (and lets the caller decide how to warn the user) if the
  /// asset is missing, rather than failing silently.
  Future<pw.Font?> _loadTtfFont(String assetPath) async {
    try {
      final ByteData fontData = await rootBundle.load(assetPath);
      return pw.Font.ttf(fontData);
    } catch (e) {
      debugPrint('Font could not be loaded from $assetPath: $e');
      return null;
    }
  }

  /// Builds the full A4 bilingual PDF as bytes, entirely on-device.
  /// Used by both the preview screen and (if you ever need it) direct export.
  ///
  /// NOTE: PDF output styling is intentionally left as-is (untouched by the
  /// UI theme polish pass) — the printing package uses its own `pw.*` widget
  /// set, which is separate from the on-screen Material theme.
  Future<Uint8List> _buildPdfBytes() async {
    final pdfDoc = pw.Document();

    // Load both required fonts. If either is missing, we still generate the
    // PDF (so the demo doesn't hard-crash) but warn the user afterwards.
    final devanagariFont =
        await _loadTtfFont('assets/fonts/NotoSansDevanagari-Regular.ttf');
    final olChikiFont =
        await _loadTtfFont('assets/fonts/NotoSansOlChiki-Regular.ttf');

    if ((devanagariFont == null || olChikiFont == null) && mounted) {
      final missing = [
        if (devanagariFont == null) 'Hindi (Devanagari)',
        if (olChikiFont == null) 'Santali (Ol Chiki)',
      ].join(' and ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Warning: $missing font not found in assets/fonts/. '
            'That text may show as boxes in the PDF.',
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
    }

    pdfDoc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // ---- Title block ----
          pw.Text(
            _worksheetTitle,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            '$_classLevel | $_subject',
            style: const pw.TextStyle(fontSize: 14),
            textAlign: pw.TextAlign.center,
          ),
          pw.Text(
            'Lesson: $_lesson',
            style: const pw.TextStyle(fontSize: 14),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 16),

          // ---- Name / Date line ----
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Name: ______________________'),
              pw.Text('Date: ______________________'),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(thickness: 1),
          pw.SizedBox(height: 12),

          // ---- Questions ----
          for (final q in _questions) ...[
            pw.Text(
              '${q.questionNumber}. ${q.visualHint}',
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),

            pw.Text('Hindi:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(
              q.questionHindi,
              style: pw.TextStyle(
                fontSize: 13,
                // FIX: Hindi now explicitly uses the embedded Devanagari font.
                font: devanagariFont,
              ),
            ),
            pw.SizedBox(height: 6),

            pw.Text('Santali:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(
              q.questionSantali,
              style: pw.TextStyle(
                fontSize: 13,
                font: olChikiFont,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Answer: __________________'),
            pw.SizedBox(height: 14),
            pw.Divider(thickness: 0.5),
            pw.SizedBox(height: 14),
          ],
        ],
      ),
    );

    return pdfDoc.save();
  }

  /// Opens the in-app preview screen. The preview screen itself provides
  /// print and share buttons (built into `printing`'s PdfPreview widget),
  /// so this single action covers "Preview / Print / Share".
  Future<void> _openPdfPreview() async {
    setState(() => _isPreparingPdf = true);
    try {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _WorksheetPdfPreviewScreen(
            buildPdf: _buildPdfBytes,
            fileName: 'anvaya_worksheet_class3_addition.pdf',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isPreparingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.roseContainer,
        foregroundColor: AppTheme.roseAccent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Worksheet Mode',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: BackButton(
          color: AppTheme.roseAccent,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.roseAccent),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.roseAccent),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadWorksheetContent,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLessonInfoCard(),
          const SizedBox(height: 16),
          ..._questions.map(_buildQuestionCard),
          const SizedBox(height: 24),
          _buildExportButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Shared card decoration: white surface, 20px radius, soft ambient
  /// shadow — per the design system, in place of the old `Card(elevation: 2,
  /// borderRadius: 12)` look.
  BoxDecoration get _cardDecoration => BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      );

  Widget _buildLessonInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _classLevel,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _subject,
            style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            _lesson,
            style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(WorksheetQuestion q) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question ${q.questionNumber}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // Visual hint — wrapped in a scroll-safe container to avoid
          // overflow on narrow screens with longer hint strings.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.skyContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              q.visualHint,
              style: const TextStyle(fontSize: 18, color: AppTheme.textPrimary),
              textAlign: TextAlign.center,
              softWrap: true,
            ),
          ),
          const SizedBox(height: 12),

          const Text(
            'Hindi:',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.roseAccent),
          ),
          const SizedBox(height: 2),
          Text(
            q.questionHindi,
            style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),

          const Text(
            'Santali:',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.mintAccent),
          ),
          const SizedBox(height: 2),
          Text(
            q.questionSantali,
            style: const TextStyle(
              fontSize: 15,
              fontFamily: 'NotoSansOlChiki',
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 14),

          const Text(
            'Answer: __________________',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isPreparingPdf ? null : _openPdfPreview,
        icon: _isPreparingPdf
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.picture_as_pdf),
        label: Text(
          _isPreparingPdf ? 'Preparing PDF...' : 'Export / Print Bilingual PDF',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.roseAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

/// A small dedicated preview screen. Uses `printing`'s built-in PdfPreview
/// widget, which already provides Print and Share actions in its app bar —
/// this satisfies "preview + print + share" with one simple, reliable
/// widget instead of custom-built buttons for each action.
class _WorksheetPdfPreviewScreen extends StatelessWidget {
  final Future<Uint8List> Function() buildPdf;
  final String fileName;

  const _WorksheetPdfPreviewScreen({
    required this.buildPdf,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.roseContainer,
        foregroundColor: AppTheme.roseAccent,
        elevation: 0,
        title: const Text('Worksheet Preview'),
      ),
      body: PdfPreview(
        // Called by PdfPreview whenever it needs the PDF bytes
        // (initial render, and again if the user changes print settings).
        build: (format) => buildPdf(),
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: fileName,
      ),
    );
  }
}
