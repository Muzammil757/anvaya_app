// worksheet_screen.dart
//
// ANVAYA — Worksheet Mode: an offline-first practice-sheet dashboard.
//
// 100% OFFLINE: no Gemini/network calls anywhere in this file.
//
// THREE INDEPENDENT SECTIONS:
//  1. Needs-Practice unit cards — every word on these comes from the
//     on-device `vocabulary` SQLite table via
//     [DatabaseService.getItemsForPractice], the exact same flag a teacher
//     toggles from a Lecture Mode card's phonetics pill or an Interactive
//     Classroom Scene hotspot (both call [DatabaseService.toggleNeedsPractice]
//     on that same table). Opening this screen fresh — or pulling to
//     refresh — re-reads that table, so a word flagged moments ago in
//     Lecture Mode shows up here immediately.
//  2. Standard offline topic templates (Addition, Subtraction, Shapes &
//     Patterns) — generated entirely on-device from simple local logic
//     (see _standardTopics' generators), not tied to any flagged word.
//  3. Recent Worksheets — a small local history of generated sheets (both
//     kinds above), persisted in SharedPreferences so teachers can
//     re-preview or re-export a past sheet without regenerating it. This
//     is genuinely ephemeral per-device UI history, unlike needs-practice
//     state, so SharedPreferences is the right tool for it specifically.
//
// STRUCTURE:
//  - WorksheetScreen: the dashboard — a plain title (no clickable "hub"
//    card), then the three sections above.
//  - _UnitWorksheetScreen: Preview/View for a word-based sheet — "Match
//    the Following" (numbered Ol Chiki left column, lettered Hindi-meaning
//    right column, shuffled once) and "Trace & Write" (one outlined
//    tracing word + two blank practice lines per word) — plus Print /
//    Export to PDF.
//  - _TopicWorksheetScreen: Preview/View for a standard topic sheet — a
//    numbered list of fill-in-the-blank prompts — plus Print / Export.
//  - _WorksheetPdfPreviewScreen: a thin wrapper around `printing`'s
//    PdfPreview widget, which already provides Print + Share actions.
//
// Word-based PDF generation embeds the local NotoSansDevanagari /
// NotoSansOlChiki TTF assets directly (see _loadTtfFont) so Hindi and Ol
// Chiki both render correctly in the exported PDF — entirely on-device.
// Topic sheets contain no Hindi/Ol Chiki text, so they skip font loading.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../theme/app_theme.dart';
import '../services/archive_log_service.dart';
import '../services/database_service.dart';

// =============================================================================
// Shared helpers & small data models
// =============================================================================

/// Friendly display titles for known unit_name values, in the prominence
/// order they should appear — "Our School" (where the Interactive
/// Classroom Scene's hotspots live) first, per the current focus on Unit 1.
/// Any unit_name not listed here still shows up, just with an
/// auto-numbered generic title, so a future unit never silently
/// disappears from this dashboard.
const List<MapEntry<String, String>> _knownUnitTitles = [
  MapEntry('Our School', 'Unit 1: Classroom Basics'),
  MapEntry('Numbers', 'Unit 2: Numbers & Objects'),
];

/// A lightweight, DB-independent word pair — used by both a freshly
/// generated unit worksheet and a replayed "Recent Worksheets" snapshot,
/// so the preview screen never needs to know which source it came from.
class _PracticeWord {
  const _PracticeWord({required this.santali, required this.hindi});

  final String santali;
  final String hindi;

  factory _PracticeWord.fromVocabularyItem(VocabularyItem item) =>
      _PracticeWord(santali: item.santaliText, hindi: item.hindiText);

  factory _PracticeWord.fromJson(Map<String, dynamic> json) => _PracticeWord(
        santali: json['santali'] as String? ?? '',
        hindi: json['hindi'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'santali': santali, 'hindi': hindi};
}

/// One unit's worth of needs-practice words, for the dashboard's live cards.
class _UnitGroup {
  const _UnitGroup({
    required this.unitName,
    required this.title,
    required this.items,
  });

  final String unitName;
  final String title;
  final List<VocabularyItem> items;
}

/// Groups flagged items by their `unit_name`, ordered per
/// [_knownUnitTitles] first, then any other unit encountered — labelled
/// "Unit N: `unit_name`" — in the order the query returned them.
List<_UnitGroup> _groupByUnit(List<VocabularyItem> items) {
  final byUnit = <String, List<VocabularyItem>>{};
  for (final item in items) {
    byUnit.putIfAbsent(item.unitName, () => []).add(item);
  }

  final groups = <_UnitGroup>[];
  for (final known in _knownUnitTitles) {
    final unitItems = byUnit.remove(known.key);
    if (unitItems != null && unitItems.isNotEmpty) {
      groups.add(_UnitGroup(unitName: known.key, title: known.value, items: unitItems));
    }
  }

  var nextAutoNumber = _knownUnitTitles.length + 1;
  for (final entry in byUnit.entries) {
    if (entry.value.isEmpty) continue;
    groups.add(
      _UnitGroup(
        unitName: entry.key,
        title: 'Unit $nextAutoNumber: ${entry.key}',
        items: entry.value,
      ),
    );
    nextAutoNumber++;
  }
  return groups;
}

/// A standard, non-word-based practice template — generated entirely
/// on-device, no needs-practice data involved.
class _TopicTemplate {
  const _TopicTemplate({
    required this.title,
    required this.icon,
    required this.color,
    required this.generator,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> Function() generator;
}

List<String> _generateAdditionProblems() {
  final rand = Random();
  return List.generate(8, (_) {
    final a = 1 + rand.nextInt(20);
    final b = 1 + rand.nextInt(20);
    return '$a + $b = ______';
  });
}

List<String> _generateSubtractionProblems() {
  final rand = Random();
  return List.generate(8, (_) {
    var a = 1 + rand.nextInt(20);
    var b = 1 + rand.nextInt(20);
    if (b > a) {
      final t = a;
      a = b;
      b = t;
    }
    return '$a - $b = ______';
  });
}

const List<String> _shapePatternPrompts = [
  '● ▲ ● ▲ ● ______',
  '■ ■ ● ■ ■ ● ______',
  '★ ● ★ ● ★ ______',
  '▲ ▲ ■ ▲ ▲ ■ ______',
  '● ★ ■ ● ★ ■ ______',
];

final List<_TopicTemplate> _standardTopics = [
  _TopicTemplate(
    title: 'Addition (1–20)',
    icon: Icons.add_circle_outline_rounded,
    color: AppTheme.skyAccent,
    generator: _generateAdditionProblems,
  ),
  _TopicTemplate(
    title: 'Subtraction',
    icon: Icons.remove_circle_outline_rounded,
    color: AppTheme.lavenderAccent,
    generator: _generateSubtractionProblems,
  ),
  _TopicTemplate(
    title: 'Shapes & Patterns',
    icon: Icons.category_rounded,
    color: AppTheme.saffron,
    generator: () => List<String>.from(_shapePatternPrompts),
  ),
];

/// A saved entry in the "Recent Worksheets" history — either a word-based
/// unit sheet ([words] populated) or a standard topic sheet ([prompts]
/// populated) — persisted as-generated so re-opening it later always shows
/// exactly what was produced at that moment, even if the underlying
/// needs-practice flags have since changed.
class _SavedWorksheet {
  const _SavedWorksheet({
    required this.title,
    required this.kind,
    required this.timestamp,
    this.words = const [],
    this.prompts = const [],
  });

  final String title;

  /// 'unit' or 'topic'.
  final String kind;
  final DateTime timestamp;
  final List<_PracticeWord> words;
  final List<String> prompts;

  factory _SavedWorksheet.fromJson(Map<String, dynamic> json) {
    return _SavedWorksheet(
      title: json['title'] as String? ?? '',
      kind: json['kind'] as String? ?? 'unit',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      words: (json['words'] as List<dynamic>? ?? [])
          .map((e) => _PracticeWord.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      prompts: (json['prompts'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'kind': kind,
        'timestamp': timestamp.toIso8601String(),
        'words': words.map((w) => w.toJson()).toList(),
        'prompts': prompts,
      };
}

/// Shared card decoration: white surface, 20px radius, soft ambient
/// shadow — the app's standard card look.
BoxDecoration get _cardDecoration => BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
      boxShadow: AppTheme.softShadow,
    );

/// Loads a .ttf font's bytes from assets for embedding into a PDF. Returns
/// null (letting the caller decide how to warn the user) if the asset is
/// missing, rather than failing silently.
Future<pw.Font?> _loadTtfFont(String assetPath) async {
  try {
    final ByteData fontData = await rootBundle.load(assetPath);
    return pw.Font.ttf(fontData);
  } catch (e) {
    debugPrint('Font could not be loaded from $assetPath: $e');
    return null;
  }
}

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

// =============================================================================
// WorksheetScreen — the Dashboard
// =============================================================================

class WorksheetScreen extends StatefulWidget {
  const WorksheetScreen({super.key});

  @override
  State<WorksheetScreen> createState() => _WorksheetScreenState();
}

class _WorksheetScreenState extends State<WorksheetScreen> {
  static const _recentPrefsKey = 'anvaya_worksheet_recent_v1';
  static const _maxRecent = 10;

  bool _isLoadingPractice = true;
  List<_UnitGroup> _unitGroups = [];
  final Set<String> _expandedUnits = {};
  List<_SavedWorksheet> _recentWorksheets = [];

  @override
  void initState() {
    super.initState();
    _loadRecentWorksheets();
    _loadPracticeItems();
  }

  Future<void> _loadPracticeItems() async {
    setState(() => _isLoadingPractice = true);
    final items = await DatabaseService.getItemsForPractice();
    if (!mounted) return;
    setState(() {
      _unitGroups = _groupByUnit(items);
      _isLoadingPractice = false;
    });
  }

  Future<void> _loadRecentWorksheets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_recentPrefsKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final loaded = decoded
            .map((e) => _SavedWorksheet.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (mounted) setState(() => _recentWorksheets = loaded);
      }
    } catch (e) {
      debugPrint('WorksheetScreen: could not load recent worksheets: $e');
    }
  }

  Future<void> _saveRecentWorksheets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_recentWorksheets.map((w) => w.toJson()).toList());
      await prefs.setString(_recentPrefsKey, encoded);
    } catch (e) {
      debugPrint('WorksheetScreen: could not save recent worksheets: $e');
    }
  }

  Future<void> _addRecentWorksheet(_SavedWorksheet worksheet) async {
    setState(() {
      _recentWorksheets.insert(0, worksheet);
      if (_recentWorksheets.length > _maxRecent) {
        _recentWorksheets = _recentWorksheets.sublist(0, _maxRecent);
      }
    });
    await _saveRecentWorksheets();
  }

  void _toggleExpanded(String unitName) {
    setState(() {
      if (_expandedUnits.contains(unitName)) {
        _expandedUnits.remove(unitName);
      } else {
        _expandedUnits.add(unitName);
      }
    });
  }

  Future<void> _openUnitWorksheet(_UnitGroup group) async {
    final words = group.items.map(_PracticeWord.fromVocabularyItem).toList();
    await _addRecentWorksheet(
      _SavedWorksheet(title: group.title, kind: 'unit', timestamp: DateTime.now(), words: words),
    );
    await ArchiveLogService.logActivity(
      type: ArchiveLogService.typeWorksheet,
      title: group.title,
      details: '${words.length} word${words.length == 1 ? '' : 's'} • Match & Trace sheet generated',
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _UnitWorksheetScreen(title: group.title, words: words)),
    );
  }

  Future<void> _openTopicWorksheet(_TopicTemplate template) async {
    final prompts = template.generator();
    await _addRecentWorksheet(
      _SavedWorksheet(title: template.title, kind: 'topic', timestamp: DateTime.now(), prompts: prompts),
    );
    await ArchiveLogService.logActivity(
      type: ArchiveLogService.typeWorksheet,
      title: template.title,
      details: '${prompts.length} practice prompt${prompts.length == 1 ? '' : 's'} generated',
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _TopicWorksheetScreen(title: template.title, prompts: prompts)),
    );
  }

  Future<void> _reopenRecent(_SavedWorksheet w) async {
    if (w.kind == 'unit') {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _UnitWorksheetScreen(title: w.title, words: w.words)),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _TopicWorksheetScreen(title: w.title, prompts: w.prompts)),
      );
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
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoadingPractice ? null : _loadPracticeItems,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadPracticeItems,
          color: AppTheme.roseAccent,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildDashboardTitle(),
              const SizedBox(height: 20),
              _buildSectionHeading('Needs Practice — By Unit'),
              const SizedBox(height: 10),
              _buildUnitSection(),
              const SizedBox(height: 26),
              _buildSectionHeading('Standard Practice Templates'),
              const SizedBox(height: 10),
              _buildStandardTopicsSection(),
              const SizedBox(height: 26),
              _buildSectionHeading('Recent Worksheets'),
              const SizedBox(height: 10),
              _buildRecentWorksheetsSection(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Plain page title — deliberately not a card, not tappable. Requirement:
  /// no confusing generic clickable "hub" card at the top of the screen.
  Widget _buildDashboardTitle() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Worksheet Dashboard',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
        ),
        SizedBox(height: 4),
        Text(
          'Offline practice sheets, generated on-device.',
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildSectionHeading(String label) {
    return Text(
      label,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
    );
  }

  Widget _buildUnitSection() {
    if (_isLoadingPractice) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: AppTheme.roseAccent)),
      );
    }

    if (_unitGroups.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration,
        child: const Text(
          'No words flagged for practice yet. Tap the "Needs Practice" star on '
          'a word in Lecture Mode or the Interactive Classroom Scene — it will '
          'appear here, grouped by unit.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
      );
    }

    return Column(
      children: [
        for (final group in _unitGroups) ...[
          _UnitPracticeCard(
            group: group,
            expanded: _expandedUnits.contains(group.unitName),
            onToggleExpanded: () => _toggleExpanded(group.unitName),
            onGenerate: () => _openUnitWorksheet(group),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildStandardTopicsSection() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final topic in _standardTopics)
          SizedBox(
            width: 172,
            child: _StandardTopicCard(
              template: topic,
              onTap: () => _openTopicWorksheet(topic),
            ),
          ),
      ],
    );
  }

  Widget _buildRecentWorksheetsSection() {
    if (_recentWorksheets.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration,
        child: const Text(
          'Generated worksheets will appear here so you can quickly re-open '
          'or re-export them without generating again.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
      );
    }

    return Column(
      children: [
        for (final w in _recentWorksheets) ...[
          _RecentWorksheetTile(worksheet: w, onTap: () => _reopenRecent(w)),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// One unit's card on the dashboard: title + explicit "N words flagged for
/// practice" count, an expandable list of the flagged words as chips, and
/// a dedicated green "Generate" button on the right side of the header.
class _UnitPracticeCard extends StatelessWidget {
  const _UnitPracticeCard({
    required this.group,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onGenerate,
  });

  final _UnitGroup group;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final count = group.items.length;
    return Container(
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onToggleExpanded,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$count word${count == 1 ? '' : 's'} flagged for practice',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                                ),
                              ),
                              Icon(
                                expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                size: 18,
                                color: AppTheme.textSecondary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: onGenerate,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('Generate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.mintAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in group.items) _PracticeWordChip(item: item),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PracticeWordChip extends StatelessWidget {
  const _PracticeWordChip({required this.item});

  final VocabularyItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.mintContainer,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.santaliText,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'NotoSansOlChiki', color: AppTheme.textPrimary),
          ),
          const SizedBox(width: 6),
          Text(
            '(${item.hindiText})',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// A compact, single-tap card for a standard offline topic template.
class _StandardTopicCard extends StatelessWidget {
  const _StandardTopicCard({required this.template, required this.onTap});

  final _TopicTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: template.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(template.icon, color: template.color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                template.title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    'Generate',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: template.color),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: template.color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentWorksheetTile extends StatelessWidget {
  const _RecentWorksheetTile({required this.worksheet, required this.onTap});

  final _SavedWorksheet worksheet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUnit = worksheet.kind == 'unit';
    final count = isUnit ? worksheet.words.length : worksheet.prompts.length;
    final noun = isUnit ? 'word' : 'item';
    return Container(
      decoration: _cardDecoration,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.roseContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isUnit ? Icons.menu_book_rounded : Icons.calculate_rounded,
                  color: AppTheme.roseAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worksheet.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_relativeTime(worksheet.timestamp)} • $count $noun${count == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _UnitWorksheetScreen — Preview/View mode + Print/Export
// =============================================================================

/// The generated practice sheet for one unit: "Match the Following" (Ol
/// Chiki numbered left column, shuffled Hindi-meaning lettered right
/// column) and "Trace & Write" (one outlined tracing word + two blank
/// lines per item), plus a Print / Export to PDF action.
///
/// Takes a plain title + word list rather than a live [_UnitGroup] /
/// [VocabularyItem], so it works identically whether launched from a fresh
/// generation or replayed from "Recent Worksheets".
///
/// The shuffle for "Match the Following" is computed once in [initState]
/// so the on-screen preview and the exported PDF always show the exact
/// same letter order.
class _UnitWorksheetScreen extends StatefulWidget {
  const _UnitWorksheetScreen({required this.title, required this.words});

  final String title;
  final List<_PracticeWord> words;

  @override
  State<_UnitWorksheetScreen> createState() => _UnitWorksheetScreenState();
}

class _UnitWorksheetScreenState extends State<_UnitWorksheetScreen> {
  late final List<_PracticeWord> _shuffledForMatching;
  bool _isPreparingPdf = false;

  @override
  void initState() {
    super.initState();
    _shuffledForMatching = List<_PracticeWord>.from(widget.words)..shuffle();
  }

  List<_PracticeWord> get _words => widget.words;

  Future<Uint8List> _buildPdfBytes() async {
    final pdfDoc = pw.Document();

    final devanagariFont = await _loadTtfFont('assets/fonts/NotoSansDevanagari-Regular.ttf');
    final olChikiFont = await _loadTtfFont('assets/fonts/NotoSansOlChiki-Regular.ttf');

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
          pw.Text(
            'ANVAYA Practice Sheet',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            widget.title,
            style: const pw.TextStyle(fontSize: 14),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 16),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Name: ______________________'),
              pw.Text('Date: ______________________'),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(thickness: 1),
          pw.SizedBox(height: 16),

          pw.Text('Match the Following', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < _words.length; i++)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 10),
                        child: pw.Row(
                          children: [
                            pw.Text('${i + 1}. ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            pw.Text(_words[i].santali, style: pw.TextStyle(font: olChikiFont, fontSize: 16)),
                            pw.SizedBox(width: 10),
                            pw.Text('[   ]'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < _shuffledForMatching.length; i++)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 10),
                        child: pw.Row(
                          children: [
                            pw.Text(
                              '${String.fromCharCode(65 + i)}. ',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                            pw.Expanded(
                              child: pw.Text(
                                _shuffledForMatching[i].hindi,
                                style: pw.TextStyle(font: devanagariFont, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Divider(thickness: 0.5),
          pw.SizedBox(height: 16),

          pw.Text('Trace & Write', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          for (final word in _words) ...[
            pw.Row(
              children: [
                pw.Text(
                  word.santali,
                  style: pw.TextStyle(font: olChikiFont, fontSize: 22, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(width: 10),
                pw.Text('(${word.hindi})', style: pw.TextStyle(font: devanagariFont, fontSize: 12)),
              ],
            ),
            pw.SizedBox(height: 6),
            for (var i = 0; i < 2; i++)
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 6),
                height: 20,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
                ),
              ),
            pw.SizedBox(height: 8),
          ],
        ],
      ),
    );

    return pdfDoc.save();
  }

  Future<void> _openPdfPreview() async {
    setState(() => _isPreparingPdf = true);
    try {
      if (!mounted) return;
      await ArchiveLogService.logActivity(
        type: ArchiveLogService.typeWorksheet,
        title: widget.title,
        details: '${_words.length} word${_words.length == 1 ? '' : 's'} • Exported to PDF for print/share',
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _WorksheetPdfPreviewScreen(
            buildPdf: _buildPdfBytes,
            fileName: 'anvaya_practice_${widget.title.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_').toLowerCase()}.pdf',
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
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        leading: BackButton(
          color: AppTheme.roseAccent,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 20),
                    _buildSectionLabel('Match the Following', Icons.compare_arrows_rounded),
                    const SizedBox(height: 10),
                    _buildMatchTheFollowing(),
                    const SizedBox(height: 24),
                    _buildSectionLabel('Trace & Write', Icons.edit_note_rounded),
                    const SizedBox(height: 10),
                    for (final word in _words) _buildTraceRow(word),
                  ],
                ),
              ),
            ),
            _buildExportButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ANVAYA Practice Sheet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            widget.title,
            style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(child: Text('Name: ______________________', style: TextStyle(color: AppTheme.textPrimary))),
            ],
          ),
          const SizedBox(height: 6),
          const Row(
            children: [
              Expanded(child: Text('Date: ______________________', style: TextStyle(color: AppTheme.textPrimary))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.roseAccent),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
      ],
    );
  }

  Widget _buildMatchTheFollowing() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ol Chiki', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                const SizedBox(height: 10),
                for (var i = 0; i < _words.length; i++) _buildMatchLeftRow(i + 1, _words[i]),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: (_words.length * 44).toDouble().clamp(44, 400), color: AppTheme.background),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Meaning', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                const SizedBox(height: 10),
                for (var i = 0; i < _shuffledForMatching.length; i++)
                  _buildMatchRightRow(String.fromCharCode(65 + i), _shuffledForMatching[i]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchLeftRow(int number, _PracticeWord word) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('$number.', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              word.santali,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'NotoSansOlChiki', color: AppTheme.textPrimary),
            ),
          ),
          Container(
            width: 34,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.mintAccent, width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchRightRow(String letter, _PracticeWord word) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$letter.', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              word.hindi,
              style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTraceRow(_PracticeWord word) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                word.santali,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'NotoSansOlChiki',
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 1.1
                    ..color = AppTheme.mintAccent,
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '(${word.hindi})',
                  style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < 2; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              height: 26,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.3))),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExportButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox(
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
            _isPreparingPdf ? 'Preparing PDF...' : 'Print / Export to PDF',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.roseAccent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _TopicWorksheetScreen — standard topic sheet Preview/View + Print/Export
// =============================================================================

/// A simple numbered list of fill-in-the-blank prompts for a standard
/// offline topic (Addition, Subtraction, Shapes & Patterns). No Hindi/Ol
/// Chiki content, so its PDF skips font embedding entirely.
class _TopicWorksheetScreen extends StatefulWidget {
  const _TopicWorksheetScreen({required this.title, required this.prompts});

  final String title;
  final List<String> prompts;

  @override
  State<_TopicWorksheetScreen> createState() => _TopicWorksheetScreenState();
}

class _TopicWorksheetScreenState extends State<_TopicWorksheetScreen> {
  bool _isPreparingPdf = false;

  Future<Uint8List> _buildPdfBytes() async {
    final pdfDoc = pw.Document();

    pdfDoc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            'ANVAYA Practice Sheet',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 6),
          pw.Text(widget.title, style: const pw.TextStyle(fontSize: 14), textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Name: ______________________'),
              pw.Text('Date: ______________________'),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(thickness: 1),
          pw.SizedBox(height: 16),
          for (var i = 0; i < widget.prompts.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 14),
              child: pw.Text('${i + 1}.   ${widget.prompts[i]}', style: const pw.TextStyle(fontSize: 16)),
            ),
        ],
      ),
    );

    return pdfDoc.save();
  }

  Future<void> _openPdfPreview() async {
    setState(() => _isPreparingPdf = true);
    try {
      if (!mounted) return;
      await ArchiveLogService.logActivity(
        type: ArchiveLogService.typeWorksheet,
        title: widget.title,
        details: '${widget.prompts.length} prompt${widget.prompts.length == 1 ? '' : 's'} • Exported to PDF for print/share',
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _WorksheetPdfPreviewScreen(
            buildPdf: _buildPdfBytes,
            fileName: 'anvaya_practice_${widget.title.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_').toLowerCase()}.pdf',
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
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        leading: BackButton(
          color: AppTheme.roseAccent,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: _cardDecoration,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ANVAYA Practice Sheet',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(widget.title, style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
                          const SizedBox(height: 12),
                          const Text('Name: ______________________', style: TextStyle(color: AppTheme.textPrimary)),
                          const SizedBox(height: 6),
                          const Text('Date: ______________________', style: TextStyle(color: AppTheme.textPrimary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (var i = 0; i < widget.prompts.length; i++) _buildPromptRow(i + 1, widget.prompts[i]),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
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
                    _isPreparingPdf ? 'Preparing PDF...' : 'Print / Export to PDF',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.roseAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptRow(int number, String prompt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: _cardDecoration,
      child: Row(
        children: [
          Text('$number.', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
          const SizedBox(width: 10),
          Text(prompt, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}

/// A small dedicated preview screen. Uses `printing`'s built-in PdfPreview
/// widget, which already provides Print and Share actions in its app bar —
/// this satisfies "preview + print + share" with one simple, reliable
/// widget instead of custom-built buttons for each action. Entirely local:
/// sharing hands the PDF bytes to the OS share sheet / a local printer, no
/// network call is involved.
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
