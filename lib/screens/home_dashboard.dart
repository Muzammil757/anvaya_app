import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/archive_log_service.dart';
import '../theme/app_theme.dart';
import '../widgets/curriculum_progress_card.dart';
import 'lecture_mode_screen.dart';
import 'qna_screen.dart';
import 'teacher_auth_screen.dart';
import 'teacher_vault_screen.dart';
import 'worksheet_screen.dart';

/// The landing screen for the ANVAYA platform.
///
/// ANVAYA is the overarching offline-first platform shell; "Class 3 Math"
/// (in Hindi / Santali) is surfaced here as the currently active learning
/// module via the context selector and Action Centre. A 3-destination
/// bottom nav (Home / Teacher Space / Archive) switches between the Home
/// dashboard, the Teacher Resource Vault of curriculum/digital-resource
/// shortcuts, and the Archive of logged classroom activity. A drawer
/// (hamburger menu, top-left) holds account-level actions — My Students
/// (stub) and Log Out.
class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  int _navIndex = 0;

  /// Bumped every time the Archive tab is selected, so [_ArchiveVaultTab]
  /// (kept alive offstage by [IndexedStack] rather than rebuilt from
  /// scratch) knows to re-fetch its activity logs — otherwise it would
  /// only ever show whatever was logged before its very first visit this
  /// session.
  int _archiveRefreshTick = 0;

  void _onDestinationSelected(int index) {
    setState(() {
      _navIndex = index;
      if (index == 2) _archiveRefreshTick++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ANVAYA',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: _AirGappedChip()),
          ),
        ],
      ),
      drawer: const _AccountDrawer(),
      body: IndexedStack(
        index: _navIndex,
        children: [
          const _HomeTab(),
          const TeacherVaultScreen(),
          _ArchiveVaultTab(refreshTick: _archiveRefreshTick),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_copy_rounded),
            label: 'Teacher Space',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_rounded),
            label: 'Archive',
          ),
        ],
      ),
    );
  }
}

/// The hamburger-menu drawer: a header showing the signed-in teacher's
/// name (persisted at login — see teacher_auth_screen.dart), "My
/// Students" (a stub for now), and "Log Out".
class _AccountDrawer extends StatefulWidget {
  const _AccountDrawer();

  @override
  State<_AccountDrawer> createState() => _AccountDrawerState();
}

class _AccountDrawerState extends State<_AccountDrawer> {
  String? _teacherName;

  @override
  void initState() {
    super.initState();
    _loadTeacherName();
  }

  Future<void> _loadTeacherName() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _teacherName = prefs.getString('teacherName'));
  }

  // BUG FIX: the ListTile used to pop (close) the Drawer *before* calling
  // this method, so by the time the user finished interacting with the
  // AlertDialog below, the Drawer's own `context` had already been
  // disposed — the isLoggedIn write still ran, but the final
  // `context.mounted` guard then silently skipped navigation. The Drawer
  // is no longer closed early; it now stays open underneath the dialog
  // (an open drawer behind a modal dialog renders fine) and is swept away
  // naturally by pushAndRemoveUntil's route-history clear below, so
  // `context` stays valid for the whole flow.
  Future<void> _confirmLogOut(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              // 1. Await the SharedPreferences update.
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isLoggedIn', false);

              // 2. Pop the dialog itself.
              if (context.mounted) Navigator.of(context).pop();

              // 3. Clear the entire routing stack and push the login
              // screen — this also removes the Drawer along with the
              // rest of HomeDashboard's route, so there's nothing left
              // to manually close.
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const TeacherAuthScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppTheme.actionCentreDark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: AppTheme.lavenderAccent,
                    child: Icon(Icons.person_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _teacherName?.isNotEmpty == true ? _teacherName! : 'Teacher',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Class 3 • Bridge Module',
                    style: TextStyle(fontSize: 12.5, color: Colors.white70),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.people, color: AppTheme.textPrimary),
              title: const Text('My Students'),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Feature coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.roseAccent),
              title: const Text('Log Out', style: TextStyle(color: AppTheme.roseAccent)),
              // Deliberately does NOT close the Drawer first — see
              // _confirmLogOut's doc comment for why that was the actual
              // navigation bug.
              onTap: () => _confirmLogOut(context),
            ),
          ],
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
/// await every push into Lecture Mode and refresh itself on return.
class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  /// Shared destination for both the Action Centre's "Resume Unit" button
  /// and the "Lecture Mode" classroom card below — both now open the same
  /// subject-segregated LectureModeScreen (Math / Language tabs). The old
  /// per-unit LectureScreen/LectureProgress "resume exactly where I left
  /// off" flow has been retired; LectureModeScreen always opens fresh on
  /// its Math tab.
  Future<void> _openLectureMode() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LectureModeScreen()),
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
            const SizedBox(height: 16),
            const CurriculumProgressCard(),
            const SizedBox(height: 24),
            const _SectionLabel('ACTION CENTRE'),
            const SizedBox(height: 10),
            _ActionCentreCard(onResume: _openLectureMode),
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
                      onTap: _openLectureMode,
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

/// Dark "Action Centre" card — a quick-launch entry point into Lecture
/// Mode's subject-segregated LectureModeScreen (Math / Language tabs).
class _ActionCentreCard extends StatelessWidget {
  const _ActionCentreCard({required this.onResume});

  final Future<void> Function() onResume;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // Trimmed from all(20)/14/6/18 spacing so this card sits comfortably
      // above the Classroom Modes stack without pushing it into extra
      // scrolling on a standard tablet viewport.
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
          const SizedBox(height: 10),
          const Text(
            'Current Focus',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Math & Language',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Bilingual Lecture Mode • Chant & Q&A Practice',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onResume,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Resume Unit'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
              ),
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

/// The "Archive / Vault" destination: a true offline classroom activity
/// log. Each entry summarises what's actually happened on-device (lecture
/// delivery progress, generated worksheets, interactive session queries),
/// read live from [ArchiveLogService] — rather than a static mock list —
/// so it reflects real teacher activity. Tapping any entry opens a
/// read-only review bottom sheet listing that section's actual recent log
/// entries; nothing here redirects elsewhere.
class _ArchiveVaultTab extends StatefulWidget {
  const _ArchiveVaultTab({required this.refreshTick});

  /// Bumped by [_HomeDashboardState] each time this tab is selected —
  /// [IndexedStack] keeps this widget alive offstage rather than disposing
  /// it, so without this signal it would never know to re-fetch after its
  /// first load.
  final int refreshTick;

  @override
  State<_ArchiveVaultTab> createState() => _ArchiveVaultTabState();
}

class _ArchiveVaultTabState extends State<_ArchiveVaultTab> {
  bool _isLoading = true;
  List<ActivityLogEntry> _lectureLogs = [];
  List<ActivityLogEntry> _worksheetLogs = [];
  List<ActivityLogEntry> _interactiveLogs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void didUpdateWidget(covariant _ArchiveVaultTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshTick != oldWidget.refreshTick) {
      _loadLogs();
    }
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      ArchiveLogService.getRecentActivitiesByType(ArchiveLogService.typeLecture),
      ArchiveLogService.getRecentActivitiesByType(ArchiveLogService.typeWorksheet),
      ArchiveLogService.getRecentActivitiesByType(ArchiveLogService.typeInteractive),
    ]);
    if (!mounted) return;
    setState(() {
      _lectureLogs = results[0];
      _worksheetLogs = results[1];
      _interactiveLogs = results[2];
      _isLoading = false;
    });
  }

  String _subtitleFor(List<ActivityLogEntry> logs, String noun) {
    if (logs.isEmpty) return 'No activity logged yet';
    return '${logs.length} $noun${logs.length == 1 ? '' : 's'} logged • Last: ${_formatLogTimestamp(logs.first.timestamp)}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadLogs,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : Column(
                          children: [
                            _VaultItem(
                              icon: Icons.fact_check_rounded,
                              iconColor: AppTheme.mintAccent,
                              iconBackground: AppTheme.mintContainer,
                              title: 'Lecture Delivery Registry',
                              subtitle: _subtitleFor(_lectureLogs, 'session'),
                              onTap: () => _showActivityLog(
                                context,
                                header: 'Lecture Delivery Registry',
                                logs: _lectureLogs,
                                emptyMessage: 'No lecture sessions logged today.',
                                icon: Icons.menu_book_rounded,
                                color: AppTheme.mintAccent,
                              ),
                            ),
                            const Divider(height: 40),
                            _VaultItem(
                              icon: Icons.picture_as_pdf_rounded,
                              iconColor: AppTheme.roseAccent,
                              iconBackground: AppTheme.roseContainer,
                              title: 'Generated Offline Worksheets',
                              subtitle: _subtitleFor(_worksheetLogs, 'worksheet'),
                              onTap: () => _showActivityLog(
                                context,
                                header: 'Generated Offline Worksheets',
                                logs: _worksheetLogs,
                                emptyMessage: 'No worksheets generated yet.',
                                icon: Icons.picture_as_pdf_rounded,
                                color: AppTheme.roseAccent,
                              ),
                            ),
                            const Divider(height: 40),
                            _VaultItem(
                              icon: Icons.record_voice_over_rounded,
                              iconColor: AppTheme.lavenderAccent,
                              iconBackground: AppTheme.lavenderContainer,
                              title: 'Interactive Session Activity',
                              subtitle: _subtitleFor(_interactiveLogs, 'activity'),
                              onTap: () => _showActivityLog(
                                context,
                                header: 'Interactive Session Activity',
                                logs: _interactiveLogs,
                                emptyMessage: 'No interactive activity logged yet.',
                                icon: Icons.chat_bubble_outline_rounded,
                                color: AppTheme.lavenderAccent,
                              ),
                            ),
                          ],
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

/// Formats a log entry's timestamp as "Today, 8:20 PM" (same calendar day)
/// or "22 Sep • 8:20 PM" (any earlier day).
String _formatLogTimestamp(DateTime dt) {
  final now = DateTime.now();
  final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
  var hour12 = dt.hour % 12;
  if (hour12 == 0) hour12 = 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final amPm = dt.hour < 12 ? 'AM' : 'PM';
  final time = '$hour12:$minute $amPm';
  if (isToday) return 'Today, $time';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${dt.day} ${months[dt.month - 1]} • $time';
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
    // isScrollControlled + an explicit max-height let this sheet grow with
    // its content up to a cap, rather than being squeezed into the
    // default ~half-screen allowance a non-scroll-controlled sheet gets —
    // that mismatch (unbounded Column vs. a shorter-than-content sheet)
    // was the actual cause of the previous bottom overflow.
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
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
              // The drag handle + header above stay fixed; only the
              // (potentially long) item list scrolls, capped by the
              // ConstrainedBox above instead of overflowing past it.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Opens the review sheet for one Archive / Vault section, listing its
/// actual logged entries (most recent first — [ArchiveLogService] already
/// returns them in that order) or [emptyMessage] when nothing has
/// happened in that category yet.
Future<void> _showActivityLog(
  BuildContext context, {
  required String header,
  required List<ActivityLogEntry> logs,
  required String emptyMessage,
  required IconData icon,
  required Color color,
}) {
  return _showVaultReviewSheet(
    context,
    header: header,
    children: logs.isEmpty
        ? [
            Text(
              emptyMessage,
              style: const TextStyle(
                fontSize: 13.5,
                fontStyle: FontStyle.italic,
                color: AppTheme.textSecondary,
              ),
            ),
          ]
        : [
            for (var i = 0; i < logs.length; i++) ...[
              _ActivityLogRow(entry: logs[i], icon: icon, color: color),
              if (i != logs.length - 1) const SizedBox(height: 16),
            ],
          ],
  );
}

/// One logged activity's row inside a review sheet: icon, title, optional
/// details line, and a formatted timestamp.
class _ActivityLogRow extends StatelessWidget {
  const _ActivityLogRow({
    required this.entry,
    required this.icon,
    required this.color,
  });

  final ActivityLogEntry entry;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (entry.details != null && entry.details!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  entry.details!,
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                _formatLogTimestamp(entry.timestamp),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
