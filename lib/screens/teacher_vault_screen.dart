// teacher_vault_screen.dart
//
// ANVAYA — Teacher Resource Vault: a clean, organized dashboard of
// curriculum and digital-resource shortcuts, reached from the bottom
// navigation bar. Deliberately a stark white background (rather than the
// app's usual soft off-white AppTheme.background) so this reads as a
// distinct, document-forward "vault" space.
//
// Body-content only — no Scaffold/AppBar of its own. HomeDashboard's
// bottom nav hosts this as an IndexedStack tab alongside _HomeTab and
// _ArchiveVaultTab, both of which are likewise body-only under the
// dashboard's single shared _DashboardHeader; giving this screen its own
// AppBar too would stack two headers when embedded.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/topic_card.dart';
import 'lesson_plan_screen.dart';
import 'resource_list_screen.dart';

class TeacherVaultScreen extends StatefulWidget {
  const TeacherVaultScreen({super.key});

  @override
  State<TeacherVaultScreen> createState() => _TeacherVaultScreenState();
}

class _TeacherVaultScreenState extends State<TeacherVaultScreen> {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Teacher Resource Vault',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Curriculum guides and digital classroom resources',
              style: TextStyle(fontSize: 13.5, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('CURRICULUM'),
            TopicCard(
              title: 'Lesson Plans',
              subtitle: 'Weekly curriculum guides',
              icon: Icons.menu_book_rounded,
              iconColor: AppTheme.lavenderAccent,
              iconBackground: AppTheme.lavenderContainer,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LessonPlanScreen()),
              ),
            ),
            const SizedBox(height: 28),
            _buildSectionHeader('DIGITAL RESOURCES'),
            TopicCard(
              title: 'Snap & Save TLMs',
              subtitle: 'Photos of physical models',
              icon: Icons.camera_alt_rounded,
              iconColor: AppTheme.roseAccent,
              iconBackground: AppTheme.roseContainer,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ResourceListScreen(title: 'Snap & Save')),
              ),
            ),
            const SizedBox(height: 14),
            TopicCard(
              title: 'Video Modules',
              subtitle: 'Recorded lessons',
              icon: Icons.video_library_rounded,
              iconColor: AppTheme.skyAccent,
              iconBackground: AppTheme.skyContainer,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ResourceListScreen(title: 'Video Modules')),
              ),
            ),
            const SizedBox(height: 14),
            TopicCard(
              title: 'Audio Rhymes',
              subtitle: 'Local language memos',
              icon: Icons.music_note_rounded,
              iconColor: AppTheme.mintAccent,
              iconBackground: AppTheme.mintContainer,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ResourceListScreen(title: 'Audio Rhymes')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Colors.grey,
        ),
      ),
    );
  }
}
