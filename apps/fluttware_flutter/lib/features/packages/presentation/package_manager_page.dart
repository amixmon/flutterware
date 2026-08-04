import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../runtime/platform_actions.dart';
import '../../../ui/theme/app_tokens.dart';
import '../../projects/data/project_repository.dart';
import '../../projects/domain/project_configuration.dart';
import '../../projects/domain/project_summary.dart';
import '../data/pub_api_client.dart';
import '../domain/pub_package.dart';

class PackageManagerPage extends StatefulWidget {
  const PackageManagerPage({
    super.key,
    required this.project,
    this.repository = const ProjectRepository(),
    this.client,
  });

  final ProjectSummary project;
  final ProjectRepository repository;
  final PubApiClient? client;

  @override
  State<PackageManagerPage> createState() => _PackageManagerPageState();
}

class _PackageManagerPageState extends State<PackageManagerPage> {
  late final PubApiClient _client = widget.client ?? PubApiClient();
  final _searchController = TextEditingController();
  List<ProjectDependency> _dependencies = const [];
  List<PubPackageSummary> _results = const [];
  Timer? _debounce;
  bool _loadingDependencies = true;
  bool _searching = false;
  int _searchRevision = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDependencies();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDependencies() async {
    try {
      final dependencies = await widget.repository.listDependencies(
        widget.project.id,
      );
      if (!mounted) return;
      setState(() {
        _dependencies = dependencies;
        _loadingDependencies = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingDependencies = false;
        _error = _message(error);
      });
    }
  }

  void _scheduleSearch(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      _searchRevision++;
      setState(() {
        _results = const [];
        _searching = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    final revision = ++_searchRevision;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await _client.search(query);
      if (!mounted || revision != _searchRevision) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (error) {
      if (!mounted || revision != _searchRevision) return;
      setState(() {
        _results = const [];
        _searching = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _showPackage(String name) async {
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final details = await _client.details(name);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final existing = _dependencies
          .where((value) => value.name == name)
          .firstOrNull;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => _PackageDetailsSheet(
          details: details,
          existing: existing,
          onSave: _saveDependency,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      messenger.showSnackBar(SnackBar(content: Text(_message(error))));
    }
  }

  Future<void> _saveDependency(
    PubPackageDetails details,
    String constraint,
  ) async {
    final dependencies = await widget.repository.upsertDependency(
      id: widget.project.id,
      dependency: ProjectDependency(
        name: details.name,
        constraint: constraint,
        compatibility: details.compatibility,
      ),
    );
    if (!mounted) return;
    setState(() => _dependencies = dependencies);
  }

  Future<void> _removeDependency(ProjectDependency dependency) async {
    try {
      final dependencies = await widget.repository.removeDependency(
        id: widget.project.id,
        name: dependency.name,
      );
      if (!mounted) return;
      setState(() => _dependencies = dependencies);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${dependency.name} removed from pubspec.yaml')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_message(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final searching = _searchController.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Package manager')),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              sliver: SliverToBoxAdapter(
                child: SearchBar(
                  controller: _searchController,
                  hintText: 'Search pub.dev packages',
                  leading: const Icon(Icons.search_rounded),
                  trailing: [
                    if (_searching)
                      const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (searching)
                      IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          _scheduleSearch('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {});
                    _scheduleSearch(value);
                  },
                  onSubmitted: _search,
                ),
              ),
            ),
            if (_error != null)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                sliver: SliverToBoxAdapter(
                  child: _MessageCard(
                    icon: Icons.cloud_off_outlined,
                    message: _error!,
                  ),
                ),
              ),
            if (searching) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Pub results',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              if (!_searching && _results.isEmpty && _error == null)
                const SliverToBoxAdapter(
                  child: _MessageCard(
                    icon: Icons.search_off_rounded,
                    message: 'No packages found.',
                  ),
                )
              else
                SliverList.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final package = _results[index];
                    final installed = _dependencies.any(
                      (value) => value.name == package.name,
                    );
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      leading: Icon(
                        installed
                            ? Icons.check_circle_outline_rounded
                            : Icons.inventory_2_outlined,
                      ),
                      title: Text(package.name),
                      subtitle: installed
                          ? const Text('Added to project')
                          : null,
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showPackage(package.name),
                    );
                  },
                ),
            ] else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                sliver: SliverToBoxAdapter(
                  child: _MessageCard(
                    icon: Icons.extension_outlined,
                    message:
                        'Add dependencies from pub.dev. Package code is available to the project; visual controls require a Flutterware adapter.',
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Project packages',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              if (_loadingDependencies)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                )
              else if (_dependencies.isEmpty)
                const SliverToBoxAdapter(
                  child: _MessageCard(
                    icon: Icons.inventory_2_outlined,
                    message: 'No extra packages yet. Search above to add one.',
                  ),
                )
              else
                SliverList.builder(
                  itemCount: _dependencies.length,
                  itemBuilder: (context, index) {
                    final dependency = _dependencies[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: AppSpacing.lg,
                        right: AppSpacing.sm,
                      ),
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(dependency.name),
                      subtitle: Text(
                        '${dependency.constraint} · ${_compatibilityLabel(dependency.compatibility)}',
                      ),
                      onTap: () => _showPackage(dependency.name),
                      trailing: IconButton(
                        tooltip: 'Remove ${dependency.name}',
                        onPressed: () => _removeDependency(dependency),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    );
                  },
                ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          ],
        ),
      ),
    );
  }
}

class _PackageDetailsSheet extends StatefulWidget {
  const _PackageDetailsSheet({
    required this.details,
    required this.onSave,
    this.existing,
  });

  final PubPackageDetails details;
  final ProjectDependency? existing;
  final Future<void> Function(PubPackageDetails details, String constraint)
  onSave;

  @override
  State<_PackageDetailsSheet> createState() => _PackageDetailsSheetState();
}

class _PackageDetailsSheetState extends State<_PackageDetailsSheet> {
  late final _constraintController = TextEditingController(
    text: widget.existing?.constraint ?? '^${widget.details.version}',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _constraintController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final constraint = _constraintController.text.trim();
    if (constraint.isEmpty) {
      setState(() => _error = 'Enter a version constraint.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(widget.details, constraint);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _message(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = widget.details;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              details.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(label: Text(details.compatibilityLabel)),
                Text('Latest ${details.version}'),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              details.description.isEmpty
                  ? 'No package description is available.'
                  : details.description,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _constraintController,
              enabled: details.canAdd && !_saving,
              decoration: InputDecoration(
                labelText: 'Version constraint',
                helperText: 'Written to the project pubspec.yaml',
                errorText: _error,
              ),
            ),
            if (!details.canAdd) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This plugin does not provide an Android implementation.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => PlatformActions.openExternalUrl(
                    'https://pub.dev/packages/${details.name}',
                  ),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('View on Pub'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: details.canAdd && !_saving ? _save : null,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_rounded),
                  label: Text(widget.existing == null ? 'Add' : 'Update'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Card.filled(
    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

String _compatibilityLabel(PackageCompatibility value) => switch (value) {
  PackageCompatibility.pureDart => 'Pure Dart',
  PackageCompatibility.flutter => 'Flutter',
  PackageCompatibility.androidPlugin => 'Android plugin',
  PackageCompatibility.unsupported => 'Unsupported',
  PackageCompatibility.unknown => 'Unknown',
};

String _message(Object error) => switch (error) {
  PlatformException(:final message?) => message,
  PubApiException(:final message) => message,
  _ => error.toString().replaceFirst('Exception: ', ''),
};
