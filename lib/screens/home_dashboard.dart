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
      appBar: AppBar(
        centerTitle: true,
        title: const Text('ANVAYA'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: _AirGappedChip(),
          ),
        ],
      ),
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
class _HomeTab extends StatelessWidget {
  const _HomeTab();

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
            const _ActionCentreCard(),
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
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LectureScreen(),
                        ),
                      ),
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

/// Horizontal pill-tag context selector: Class 3 / Mathematics / Santali.
class _ContextSelectorBar extends StatelessWidget {
  const _ContextSelectorBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: const [
          _ContextPill(label: 'Class 3', selected: true),
          SizedBox(width: 10),
          _ContextPill(label: 'Mathematics'),
          SizedBox(width: 10),
          _ContextPill(label: 'Santali (Ol Chiki)'),
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

/// Dark "Action Centre" card surfacing the currently active learning unit.
class _ActionCentreCard extends StatelessWidget {
  const _ActionCentreCard();

  @override
  Widget build(BuildContext context) {
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
          const Text(
            'Addition & Counting',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LectureScreen()),
              ),
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
              'Pre-cached materials available without a network connection',
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
                      icon: Icons.picture_as_pdf_rounded,
                      iconColor: AppTheme.roseAccent,
                      iconBackground: AppTheme.roseContainer,
                      title: 'Class 3 Addition Practice Sheet',
                      subtitle: 'PDF • 240 KB',
                      trailing: OutlinedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const WorksheetScreen(),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.roseAccent,
                          side: const BorderSide(color: AppTheme.roseAccent),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Preview',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 40),
                    _VaultItem(
                      icon: Icons.audiotrack_rounded,
                      iconColor: AppTheme.mintAccent,
                      iconBackground: AppTheme.mintContainer,
                      title: 'Lesson 1 Counting Audio Pack',
                      subtitle: 'Santali • 4 Clips Cached',
                    ),
                    const Divider(height: 40),
                    _VaultItem(
                      icon: Icons.forum_rounded,
                      iconColor: AppTheme.lavenderAccent,
                      iconBackground: AppTheme.lavenderContainer,
                      title: 'Recent Walkie-Talkie Session',
                      subtitle: '3 Q&A Pairs Cached',
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

/// One row inside the Archive / Vault tab: an icon, title/subtitle, and an
/// optional trailing action.
class _VaultItem extends StatelessWidget {
  const _VaultItem({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
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
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}
