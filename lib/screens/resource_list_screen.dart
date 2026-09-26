// resource_list_screen.dart
//
// ANVAYA — a generic mockup screen for one Digital Resources category
// (Snap & Save TLMs, Video Modules, Audio Rhymes, ...). No real upload
// pipeline exists yet — the Upload sheet's options all resolve to a
// "Feature coming soon!" SnackBar, standing in for a future camera/
// gallery/file-picker integration.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ResourceListScreen extends StatelessWidget {
  const ResourceListScreen({super.key, required this.title});

  final String title;

  void _showUploadSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
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
                'Upload to $title',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 20),
              _buildUploadOption(sheetContext, icon: Icons.photo_camera_rounded, label: 'Camera'),
              const SizedBox(height: 10),
              _buildUploadOption(sheetContext, icon: Icons.photo_library_rounded, label: 'Gallery'),
              const SizedBox(height: 10),
              _buildUploadOption(sheetContext, icon: Icons.insert_drive_file_rounded, label: 'Choose File'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadOption(BuildContext context, {required IconData icon, required String label}) {
    return Material(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Feature coming soon!')),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.lavenderAccent),
              const SizedBox(width: 14),
              Text(
                label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_open_rounded, size: 72, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              const Text(
                'No resources uploaded yet.',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUploadSheet(context),
        icon: const Icon(Icons.upload_rounded),
        label: const Text('Upload'),
      ),
    );
  }
}
