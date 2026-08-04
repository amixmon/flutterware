import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../runtime/platform_actions.dart';
import '../../../ui/theme/app_tokens.dart';
import '../../../ui/widgets/app_button.dart';
import '../../../ui/widgets/app_section_card.dart';
import '../../../ui/widgets/flutterware_logo.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const repositoryUrl = 'https://github.com/amixmon/flutterware';
  static const issuesUrl = '$repositoryUrl/issues';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About Flutterware')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pageHorizontal,
            AppSpacing.xl,
            AppSizes.pageHorizontal,
            AppSpacing.xxl,
          ),
          children: [
            Center(
              child: Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: .2),
                  ),
                ),
                child: const Center(child: FlutterwareLogo(size: 72)),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Flutterware',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Flutter development, completely on Android.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: const [
                Chip(label: Text('Version 1.0.0')),
                Chip(label: Text('ARM64')),
                Chip(label: Text('Local-first')),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            const AppSectionCard(
              title: 'What it does',
              subtitle:
                  'Flutterware is a lightweight visual IDE and build environment designed to run directly on modern Android devices.',
              leading: Icon(Icons.auto_awesome_rounded),
              child: Column(
                children: [
                  _AboutFeature(
                    icon: Icons.widgets_outlined,
                    title: 'Visual Flutter editor',
                    detail:
                        'Compose pages and nested widgets with drag and drop.',
                  ),
                  _AboutFeature(
                    icon: Icons.account_tree_outlined,
                    title: 'Page-scoped logic',
                    detail:
                        'Connect events and actions without leaving the device.',
                  ),
                  _AboutFeature(
                    icon: Icons.offline_bolt_outlined,
                    title: 'On-device build pipeline',
                    detail:
                        'Resolve packages, compile Dart, package, sign and install APKs locally.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.fieldGap),
            AppSectionCard(
              title: 'Open development',
              subtitle:
                  'Flutterware grows through testing, ideas, bug reports and code contributions from the community.',
              leading: const Icon(Icons.groups_2_outlined),
              child: Column(
                children: [
                  AppButton(
                    label: 'Collaborate on GitHub',
                    leadingIcon: Icons.code_rounded,
                    trailingIcon: Icons.open_in_new_rounded,
                    onPressed: () => _open(context, repositoryUrl),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Report an issue',
                    variant: AppButtonVariant.outlined,
                    leadingIcon: Icons.bug_report_outlined,
                    trailingIcon: Icons.open_in_new_rounded,
                    onPressed: () => _open(context, issuesUrl),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SelectableText(
                    repositoryUrl,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Built with Flutter • Powered by Dart, Android SDK and open tooling',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    try {
      await PlatformActions.openExternalUrl(url);
    } on PlatformException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not open the link')),
      );
    }
  }
}

class _AboutFeature extends StatelessWidget {
  const _AboutFeature({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                detail,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
