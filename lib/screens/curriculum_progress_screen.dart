// curriculum_progress_screen.dart
//
// ANVAYA — Curriculum Progress.
//
// Two tabs (Math / Language), each a vertically scrolling list of 4 weeks.
// Weeks 1-2 carry interactive checkboxes a teacher can tick off in class;
// weeks 3-4 are locked (grayed out + padlock) since that content isn't
// unlocked yet.
//
// PERSISTENCE: checkbox state is a Map<String, bool> keyed by a stable
// per-topic SharedPreferences key (see _keyMathWeek1Table4 etc.), loaded
// in _loadProgress on init and written immediately on every toggle via
// _toggleTopic — genuinely ephemeral per-device UI state (not curriculum
// truth), matching the SharedPreferences convention already used for
// qna_screen.dart's instruction board and worksheet_screen.dart's recent
// worksheets. A future SQLite-backed
// DatabaseService.toggleCurriculumProgress(...) call would only need to
// replace _loadProgress/_toggleTopic's bodies.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

class CurriculumProgressScreen extends StatefulWidget {
  const CurriculumProgressScreen({super.key});

  @override
  State<CurriculumProgressScreen> createState() => _CurriculumProgressScreenState();
}

class _CurriculumProgressScreenState extends State<CurriculumProgressScreen> {
  // --- Math tab — Week 1 & 2 topic keys ------------------------------------
  static const _keyMathWeek1Table4 = 'curriculum_math_week1_table4';
  static const _keyMathWeek1Table5 = 'curriculum_math_week1_table5';
  static const _keyMathWeek2Table6 = 'curriculum_math_week2_table6';
  static const _keyMathWeek2Table7 = 'curriculum_math_week2_table7';

  // --- Language tab — Week 1 & 2 topic keys --------------------------------
  static const _keyLangWeek1OurSchool = 'curriculum_lang_week1_our_school';
  static const _keyLangWeek1Days = 'curriculum_lang_week1_days';
  static const _keyLangWeek2Family = 'curriculum_lang_week2_family';
  static const _keyLangWeek2Colors = 'curriculum_lang_week2_colors';

  static const _allKeys = [
    _keyMathWeek1Table4,
    _keyMathWeek1Table5,
    _keyMathWeek2Table6,
    _keyMathWeek2Table7,
    _keyLangWeek1OurSchool,
    _keyLangWeek1Days,
    _keyLangWeek2Family,
    _keyLangWeek2Colors,
  ];

  /// Every topic defaults to false — nothing starts pre-checked — until
  /// [_loadProgress] fills in whatever was actually saved last session.
  final Map<String, bool> _progress = {for (final key in _allKeys) key: false};

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = {for (final key in _allKeys) key: prefs.getBool(key) ?? false};
    if (!mounted) return;
    setState(() => _progress.addAll(loaded));
  }

  /// Flips [key]'s value (from its known [currentValue]), reflects it
  /// immediately in the UI, and persists it — a teacher ticking a box in
  /// class doesn't lose that the moment they leave the screen.
  Future<void> _toggleTopic(String key, bool currentValue) async {
    final next = !currentValue;
    setState(() => _progress[key] = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, next);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      // initialIndex defaults to 0, so the screen opens on the Math tab.
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Curriculum Progress'),
          bottom: TabBar(
            labelColor: AppTheme.lavenderAccent,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.lavenderAccent,
            labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: 'Math'),
              Tab(text: 'Language'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _buildMathTab(),
              _buildLanguageTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMathTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _buildUnlockedWeekCard(
          title: 'Week 1',
          rows: [
            _CheckableTopicRow(
              label: '4 Table',
              checked: _progress[_keyMathWeek1Table4] ?? false,
              onChanged: (_) => _toggleTopic(_keyMathWeek1Table4, _progress[_keyMathWeek1Table4] ?? false),
            ),
            _CheckableTopicRow(
              label: '5 Table',
              checked: _progress[_keyMathWeek1Table5] ?? false,
              onChanged: (_) => _toggleTopic(_keyMathWeek1Table5, _progress[_keyMathWeek1Table5] ?? false),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildUnlockedWeekCard(
          title: 'Week 2',
          rows: [
            _CheckableTopicRow(
              label: '6 Table',
              checked: _progress[_keyMathWeek2Table6] ?? false,
              onChanged: (_) => _toggleTopic(_keyMathWeek2Table6, _progress[_keyMathWeek2Table6] ?? false),
            ),
            _CheckableTopicRow(
              label: '7 Table',
              checked: _progress[_keyMathWeek2Table7] ?? false,
              onChanged: (_) => _toggleTopic(_keyMathWeek2Table7, _progress[_keyMathWeek2Table7] ?? false),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildLockedWeekCard(title: 'Week 3', topics: const ['8 Table', '9 Table']),
        const SizedBox(height: 14),
        _buildLockedWeekCard(title: 'Week 4', topics: const ['10 Table', 'Mixed Tables Review']),
      ],
    );
  }

  Widget _buildLanguageTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _buildUnlockedWeekCard(
          title: 'Week 1',
          rows: [
            _CheckableTopicRow(
              label: 'Our School',
              checked: _progress[_keyLangWeek1OurSchool] ?? false,
              onChanged: (_) => _toggleTopic(_keyLangWeek1OurSchool, _progress[_keyLangWeek1OurSchool] ?? false),
            ),
            _CheckableTopicRow(
              label: 'Days of the Week',
              checked: _progress[_keyLangWeek1Days] ?? false,
              onChanged: (_) => _toggleTopic(_keyLangWeek1Days, _progress[_keyLangWeek1Days] ?? false),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildUnlockedWeekCard(
          title: 'Week 2',
          rows: [
            _CheckableTopicRow(
              label: 'Family Members',
              checked: _progress[_keyLangWeek2Family] ?? false,
              onChanged: (_) => _toggleTopic(_keyLangWeek2Family, _progress[_keyLangWeek2Family] ?? false),
            ),
            _CheckableTopicRow(
              label: 'Colors',
              checked: _progress[_keyLangWeek2Colors] ?? false,
              onChanged: (_) => _toggleTopic(_keyLangWeek2Colors, _progress[_keyLangWeek2Colors] ?? false),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildLockedWeekCard(title: 'Week 3', topics: const ['Fruits & Vegetables', 'Body Parts']),
        const SizedBox(height: 14),
        _buildLockedWeekCard(title: 'Week 4', topics: const ['Festivals & Culture', 'Weather & Seasons']),
      ],
    );
  }

  /// An unlocked week's card: a title followed by one interactive,
  /// tappable [_CheckableTopicRow] per topic. Built from a plain
  /// [Container] rather than the themed [Card] — a soft mint tint plus a
  /// subtle border gives it a "pop" against the background instead of
  /// blending into the near-white page like a bare white Card does.
  Widget _buildUnlockedWeekCard({required String title, required List<Widget> rows}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.mintContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.mintAccent.withValues(alpha: 0.25), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            ...rows,
          ],
        ),
      ),
    );
  }

  /// A locked week's card: plain (non-interactive) topic labels, no
  /// checkboxes, the whole card dimmed via [Opacity] with a padlock badge
  /// overlaid — visually distinct from "unlocked but not done".
  ///
  /// Wrapped in `SizedBox(width: double.infinity, ...)` because [Stack]
  /// loosens the width constraint it hands to its non-positioned children
  /// (the dimmed [Card] here) and then sizes itself to fit them — without
  /// this, the Stack (and the card inside it) shrink-wraps to the card's
  /// own intrinsic content width instead of filling the row, which is
  /// exactly why these cards previously rendered squished/centered
  /// instead of stretching full-width like the unlocked cards above.
  Widget _buildLockedWeekCard({required String title, required List<String> topics}) {
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            for (final topic in topics) ...[
              Text(
                topic,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );

    return SizedBox(
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: 0.5, child: card),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.textPrimary.withValues(alpha: 0.85),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

/// One interactive, tappable topic row with a checkbox — the whole row
/// (not just the checkbox glyph) is the tap target, via [InkWell], so it's
/// comfortably large for a tablet interface. Ticking it also swaps the
/// trailing status icon to a filled green checkmark, and strikes through
/// the label, so "done" reads clearly at a glance.
class _CheckableTopicRow extends StatelessWidget {
  const _CheckableTopicRow({
    required this.label,
    required this.checked,
    required this.onChanged,
  });

  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(!checked),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Transform.scale(
                scale: 1.25,
                child: Checkbox(
                  value: checked,
                  activeColor: Colors.green,
                  onChanged: (value) => onChanged(value ?? false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    decoration: checked ? TextDecoration.lineThrough : TextDecoration.none,
                    decorationColor: AppTheme.textSecondary,
                  ),
                ),
              ),
              Icon(
                checked ? Icons.check_circle : Icons.circle_outlined,
                color: checked ? Colors.green : AppTheme.textSecondary.withValues(alpha: 0.35),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
