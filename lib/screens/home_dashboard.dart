import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'lecture_screen.dart';
import 'qna_screen.dart';
import 'worksheet_screen.dart';

/// The landing screen for the ANVAYA platform.
///
/// ANVAYA is the overarching offline-first platform shell; "Class 3 Math"
/// (in Hindi / Santali) is surfaced here as the currently active learning
/// module via the context selector and Action Centre. A 2-destination
/// bottom nav switches between the Home dashboard and the Archive / Vault
/// of previously cached materials.
class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const _DashboardHeader(),
      body: IndexedStack(
        index: _navIndex,
        children: const [
          _HomeTab(),
          _ArchiveVaultTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (index) => setState(() => _navIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_rounded),
            label: 'Archive / Vault',
          ),
        ],
      ),
    );
  }
}

/// Custom app bar: a brand icon tile pinned left, a centered ANVAYA
/// title/subtitle block, and the Air-Gapped badge pinned right, all inside
/// one evenly padded row — built by hand (rather than [AppBar]'s
/// leading/title/actions slots) so the 20/14 padding applies uniformly and
/// the icon tile never brushes the screen edge.
class _DashboardHeader extends StatelessWidget implements PreferredSizeWidget {
  const _DashboardHeader();

  @override
  Size get preferredSize => const Size.fromHeight(78);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.lavenderContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: AppTheme.lavenderAccent,
                  size: 20,
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'ANVAYA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '• FLN Offline Sync • Ready',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const _AirGappedChip(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small pill in the AppBar signalling the device is offline / air-gapped.
class _AirGappedChip extends StatelessWidget {
  const _AirGappedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.mintContainer,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 15,
            color: AppTheme.mintAccent,
          ),
          const SizedBox(width: 6),
          Text(
            'Air-Gapped',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 12.5,
                  color: AppTheme.mintAccent,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

/// The primary "Home" destination: greeting, context selector, Action
/// Centre, and the vertical stack of classroom mode cards.
///
/// Stateful (rather than the stateless tab it used to be) purely so it can
/// await every push into Lecture Mode and refresh itself on return — that's
/// what lets the Action Centre's "Current Active Unit" title and "Card X of
/// 5" subtitle reflect [LectureProgress] immediately, however the teacher
/// got there (the Action Centre's own Resume button, or the Lecture Mode
/// card below).
class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  Future<void> _openLecture() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LectureScreen()),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _WelcomeCard(),
            const SizedBox(height: 20),
            const _ContextSelectorBar(),
            const SizedBox(height: 28),
            const _SectionLabel('ACTION CENTRE'),
            const SizedBox(height: 12),
            _ActionCentreCard(onResume: _openLecture),
            const SizedBox(height: 28),
            const _SectionLabel('CLASSROOM MODES'),
            const SizedBox(height: 12),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ClassroomModeCard(
                      title: 'Lecture Mode',
                      subtitle: 'Bilingual Audio Slides',
                      icon: Icons.slideshow_rounded,
                      containerColor: AppTheme.mintContainer,
                      accentColor: AppTheme.mintAccent,
                      onTap: _openLecture,
                    ),
                    const SizedBox(height: 16),
                    _ClassroomModeCard(
                      title: 'Interactive Mode',
                      subtitle: 'Deliver & log daily tasks in Santali',
                      icon: Icons.record_voice_over_rounded,
                      containerColor: AppTheme.lavenderContainer,
                      accentColor: AppTheme.lavenderAccent,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const QnAScreen()),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ClassroomModeCard(
                      title: 'Worksheet Engine',
                      subtitle: 'Offline Bilingual PDF Generator',
                      icon: Icons.description_rounded,
                      containerColor: AppTheme.roseContainer,
                      accentColor: AppTheme.roseAccent,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const WorksheetScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Top clean-white welcome card with greeting, initiative sub-row, and the
/// offline / air-gapped status badge.
class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard();

  @override
  Widget build(BuildContext context) {
    // width: double.infinity keeps the greeting card full-width on tablets,
    // matching the Action Centre card below it (Card otherwise shrink-wraps
    // to its widest child's intrinsic width).
    return SizedBox(
      width: double.infinity,
      child: Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Namaste, Teacher',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Multilingual Foundational Learning Platform',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: AppTheme.mintContainer,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.mintAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '100% Offline • Air-Gapped',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.mintAccent,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Horizontal pill-tag metadata badges identifying the active curriculum,
/// class/module, and language pairing.
class _ContextSelectorBar extends StatelessWidget {
  const _ContextSelectorBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: const [
          _ContextPill(label: 'NIPUN Bharat FLN', selected: true),
          SizedBox(width: 10),
          _ContextPill(label: 'Class 3 • Bridge Module'),
          SizedBox(width: 10),
          _ContextPill(label: 'English ⇄ Santali (Ol Chiki)'),
        ],
      ),
    );
  }
}

class _ContextPill extends StatelessWidget {
  const _ContextPill({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppTheme.lavenderAccent : AppTheme.surface,
        borderRadius: BorderRadius.circular(30),
        border: selected
            ? null
            : Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.2)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : AppTheme.textPrimary,
        ),
      ),
    );
  }
}

/// Small uppercase section heading used above Action Centre / Classroom
/// Modes.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: AppTheme.textSecondary,
      ),
    );
  }
}

/// Dark "Action Centre" card surfacing the currently active Lecture Mode
/// unit — title and card position both read live from [LectureProgress],
/// so this reflects wherever the teacher last left off.
class _ActionCentreCard extends StatelessWidget {
  const _ActionCentreCard({required this.onResume});

  final Future<void> Function() onResume;

  @override
  Widget build(BuildContext context) {
    final unit = LectureProgress.unit;
    final cardNumber = LectureProgress.cardIndex + 1;
    final totalCards = unit.cards.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.actionCentreDark,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.mintAccent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              'Pre-synced & Ready',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.mintAccent.withValues(alpha: 0.95),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Current Active Unit',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            unit.titleEnglish,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Resume Unit • Card $cardNumber of $totalCards',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onResume,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Resume Unit'),
            ),
          ),
        ],
      ),
    );
  }
}

/// One medium, comfortably-sized card in the vertical "Classroom Modes"
/// stack: a leading colour-accented icon square, title/subtitle, and a
/// subtle trailing chevron.
class _ClassroomModeCard extends StatelessWidget {
  const _ClassroomModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.containerColor,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color containerColor;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: SizedBox(
            height: 118,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: accentColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: accentColor.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Archive / Vault" destination: pre-cached classroom assets available
/// without a network connection.
/// The "Archive / Vault" destination: a true offline classroom activity
/// log. Each entry summarises what's actually happened on-device (lecture
/// delivery progress, generated worksheets, interactive session queries)
/// rather than a static list of cached files — tapping any entry opens a
/// read-only review bottom sheet; nothing here redirects elsewhere.
class _ArchiveVaultTab extends StatelessWidget {
  const _ArchiveVaultTab();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Offline Archive & Vault',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'A log of classroom activity delivered entirely offline',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _VaultItem(
                      icon: Icons.fact_check_rounded,
                      iconColor: AppTheme.mintAccent,
                      iconBackground: AppTheme.mintContainer,
                      title: 'Lecture Delivery Registry',
                      subtitle: '1 of 2 Units Completed • 8 Total Cards Taught',
                      onTap: () => _showLectureDeliveryLog(context),
                    ),
                    const Divider(height: 40),
                    _VaultItem(
                      icon: Icons.picture_as_pdf_rounded,
                      iconColor: AppTheme.roseAccent,
                      iconBackground: AppTheme.roseContainer,
                      title: 'Generated Offline Worksheets',
                      subtitle:
                          '2 Practice Sheets compiled for print/distribution',
                      onTap: () => _showWorksheetExportLog(context),
                    ),
                    const Divider(height: 40),
                    _VaultItem(
                      icon: Icons.record_voice_over_rounded,
                      iconColor: AppTheme.lavenderAccent,
                      iconBackground: AppTheme.lavenderContainer,
                      title: 'Interactive Session Activity',
                      subtitle: '3 Audio & Translation Queries Logged',
                      onTap: () => _showInteractiveSessionLog(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One tappable row inside the Archive / Vault tab: an icon, title/
/// subtitle, and a trailing "Review" pill — tapping anywhere on the row
/// opens the matching review bottom sheet.
class _VaultItem extends StatelessWidget {
  const _VaultItem({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.lavenderContainer,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'Review',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.lavenderAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared chrome for every Vault review sheet: a drag handle, a bold
/// header, and whatever detail rows the caller supplies.
Future<void> _showVaultReviewSheet(
  BuildContext context, {
  required String header,
  required List<Widget> children,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text(
              header,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    ),
  );
}

/// Item 1: reviews per-unit lecture delivery progress.
Future<void> _showLectureDeliveryLog(BuildContext context) {
  return _showVaultReviewSheet(
    context,
    header: 'Curriculum Delivery Status',
    children: const [
      _DeliveryStatusRow(
        unitTitle: 'Numbers 1 to 5',
        status: 'Completed (5/5 Cards)',
        icon: Icons.check_circle_rounded,
        color: AppTheme.mintAccent,
      ),
      SizedBox(height: 14),
      _DeliveryStatusRow(
        unitTitle: 'Our School',
        status: 'In Progress (3/5 Cards)',
        icon: Icons.schedule_rounded,
        color: Color(0xFFB07D0F),
      ),
    ],
  );
}

/// Item 2: reviews the offline-generated worksheet PDFs.
Future<void> _showWorksheetExportLog(BuildContext context) {
  return _showVaultReviewSheet(
    context,
    header: 'Generated PDF Sheets',
    children: const [
      _WorksheetLogRow(
        label: 'Class 3 Numbers 1-5 Ol Chiki Tracing Sheet • PDF',
      ),
      SizedBox(height: 12),
      _WorksheetLogRow(
        label: 'School Objects Bilingual Matching Sheet • PDF',
      ),
      SizedBox(height: 16),
      Text(
        'Stored in local tablet downloads directory.',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          color: AppTheme.textSecondary,
        ),
      ),
    ],
  );
}

/// Item 3: reviews recent Interactive Mode voice/translation queries.
Future<void> _showInteractiveSessionLog(BuildContext context) {
  return _showVaultReviewSheet(
    context,
    header: 'Recent Voice & Translation Activity',
    children: const [
      _InteractiveLogRow(text: "Query: 'How to say Book?' -> ᱯᱩᱛᱷᱤ (Puthi)"),
      SizedBox(height: 10),
      _InteractiveLogRow(
        text: "Query: 'Teacher in Santali' -> ᱢᱟᱪᱮᱛ (Machet)",
      ),
      SizedBox(height: 16),
      _StatusBadge(label: 'Cached locally • Pending Cluster Sync'),
    ],
  );
}

/// One unit's row in the Lecture Delivery review sheet.
class _DeliveryStatusRow extends StatelessWidget {
  const _DeliveryStatusRow({
    required this.unitTitle,
    required this.status,
    required this.icon,
    required this.color,
  });

  final String unitTitle;
  final String status;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                unitTitle,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                status,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One PDF entry's row in the Worksheet Export review sheet.
class _WorksheetLogRow extends StatelessWidget {
  const _WorksheetLogRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.picture_as_pdf_rounded,
          color: AppTheme.roseAccent,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// One query's row in the Interactive Session review sheet.
class _InteractiveLogRow extends StatelessWidget {
  const _InteractiveLogRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.chat_bubble_outline_rounded,
          color: AppTheme.lavenderAccent,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// A small pill used to surface a sync/caching status inside a review
/// sheet.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.skyContainer,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 14, color: AppTheme.skyAccent),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.skyAccent,
            ),
          ),
        ],
      ),
    );
  }
}
