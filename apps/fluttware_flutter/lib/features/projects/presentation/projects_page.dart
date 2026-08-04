import 'dart:convert';

import 'package:flutter/material.dart';

import '../../about/presentation/about_page.dart';
import '../../build/presentation/runtime_build_sheet.dart';
import '../../editor/presentation/editor_page.dart';
import '../../../runtime/runtime_controller.dart';
import '../../../ui/widgets/flutterware_logo.dart';
import '../data/project_repository.dart';
import '../domain/demo_project_template.dart';
import '../domain/project_summary.dart';
import 'new_project_page.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _repository = const ProjectRepository();
  final _projects = <ProjectSummary>[];

  int _selectedDestination = 0;
  String _query = '';
  bool _loadingProjects = true;
  String? _creatingTemplateId;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    try {
      final projects = await _repository.list();
      if (!mounted) return;
      setState(() {
        _projects
          ..clear()
          ..addAll(projects);
        _loadingProjects = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingProjects = false);
    }
  }

  List<ProjectSummary> get _visibleProjects {
    final normalized = _query.trim().toLowerCase();
    final projects = normalized.isEmpty
        ? List<ProjectSummary>.of(_projects)
        : _projects
              .where(
                (project) =>
                    project.name.toLowerCase().contains(normalized) ||
                    project.packageName.toLowerCase().contains(normalized),
              )
              .toList();

    projects.sort((a, b) {
      if (a.pinned == b.pinned) return a.name.compareTo(b.name);
      return a.pinned ? -1 : 1;
    });
    return projects;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _FlutterwareDrawer(onDestinationSelected: _openDrawerDestination),
      body: SafeArea(
        bottom: false,
        child: _selectedDestination == 0
            ? _projectsView(context)
            : _TemplatesPage(
                creatingTemplateId: _creatingTemplateId,
                onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
                onOpenTemplate: (template) => _createDemoProject(template),
                onRunTemplate: (template) =>
                    _createDemoProject(template, run: true),
              ),
      ),
      floatingActionButton: _selectedDestination == 0
          ? FloatingActionButton.extended(
              onPressed: _createProject,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New project'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedDestination,
        onDestinationSelected: (index) {
          setState(() => _selectedDestination = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Projects',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_mosaic_outlined),
            selectedIcon: Icon(Icons.auto_awesome_mosaic_rounded),
            label: 'Templates',
          ),
        ],
      ),
    );
  }

  Widget _projectsView(BuildContext context) {
    final projects = _visibleProjects;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Open menu',
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  autocorrect: false,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search projects',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (query) => setState(() => _query = query),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'Sort projects',
                onPressed: _showSortOptions,
                icon: const Icon(Icons.sort_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadProjects,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  sliver: SliverToBoxAdapter(child: _toolchainCard(context)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Projects',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        Text(
                          '${projects.length}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_loadingProjects)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (projects.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyProjects(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
                    sliver: SliverList.builder(
                      itemCount: projects.length,
                      itemBuilder: (context, index) => _ProjectTile(
                        project: projects[index],
                        position: _positionFor(index, projects.length),
                        onOpen: () => _openProject(projects[index]),
                        onOptions: () => _showProjectOptions(projects[index]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _toolchainCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: RuntimeController.instance,
      builder: (context, _) {
        final runtime = RuntimeController.instance.snapshot;
        return Card(
          color: colors.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colors.secondary,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(Icons.memory_rounded, color: colors.onSecondary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        runtime.busy ? runtime.message : 'On-device runtime',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        runtime.busy
                            ? '${(runtime.progress * 100).round()}% complete'
                            : 'ARM64 • Flutter debug pipeline',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                if (runtime.busy)
                  const SizedBox.square(
                    dimension: 26,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                else
                  const Icon(Icons.offline_bolt_rounded),
              ],
            ),
          ),
        );
      },
    );
  }

  _TilePosition _positionFor(int index, int length) {
    if (length == 1) return _TilePosition.only;
    if (index == 0) return _TilePosition.first;
    if (index == length - 1) return _TilePosition.last;
    return _TilePosition.middle;
  }

  Future<void> _createProject() async {
    final project = await Navigator.of(context).push<ProjectSummary>(
      MaterialPageRoute(builder: (_) => const NewProjectPage()),
    );
    if (!mounted || project == null) return;
    setState(() => _projects.insert(0, project));
    await _openProject(project);
  }

  Future<void> _createDemoProject(
    DemoProjectTemplate template, {
    bool run = false,
  }) async {
    if (_creatingTemplateId != null) return;
    setState(() => _creatingTemplateId = template.id);

    try {
      final storedProjects = await _repository.list();
      final usedIds = storedProjects.map((project) => project.id).toSet();
      var projectId = template.id;
      var copyNumber = 2;
      while (usedIds.contains(projectId)) {
        projectId = '${template.id}_${copyNumber++}';
      }
      final packageSuffix = projectId == template.id
          ? ''
          : projectId.substring(template.id.length).replaceAll('_', '');
      final project = await _repository.create(
        id: projectId,
        name: template.name,
        packageName: '${template.packageName}$packageSuffix',
        color: template.color,
      );
      await _repository.writeDesign(id: project.id, design: template.design);
      await _repository.writeLogic(
        id: project.id,
        content: const JsonEncoder.withIndent(' ').convert(template.logic),
      );
      if (!mounted) return;
      setState(() {
        _projects.insert(0, project);
        _creatingTemplateId = null;
      });

      if (run) {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => RuntimeBuildSheet(project: project),
        );
      } else {
        await _openProject(project);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _creatingTemplateId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create demo project: $error')),
      );
    }
  }

  void _openDrawerDestination(String destination) {
    Navigator.pop(context);
    if (destination == 'About') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const AboutPage()));
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$destination is coming next.')));
  }

  Future<void> _openProject(ProjectSummary project) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => EditorPage(project: project)),
    );
    await _loadProjects();
  }

  void _showProjectOptions(ProjectSummary project) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(project.name),
                subtitle: Text(project.packageName),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(
                  project.pinned
                      ? Icons.push_pin_outlined
                      : Icons.push_pin_rounded,
                ),
                title: Text(project.pinned ? 'Unpin project' : 'Pin project'),
                onTap: () {
                  Navigator.pop(context);
                  final index = _projects.indexOf(project);
                  setState(() {
                    _projects[index] = project.copyWith(
                      pinned: !project.pinned,
                    );
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: const Text('Project settings'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.archive_rounded),
                title: const Text('Export project'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Delete project',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _projects.remove(project));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Sort projects'),
                subtitle: Text('Pinned projects always appear first'),
              ),
              ListTile(
                leading: const Icon(Icons.sort_by_alpha_rounded),
                title: const Text('Name'),
                trailing: const Icon(Icons.check_rounded),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.schedule_rounded),
                title: const Text('Last modified'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _TilePosition { only, first, middle, last }

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({
    required this.project,
    required this.position,
    required this.onOpen,
    required this.onOptions,
  });

  final ProjectSummary project;
  final _TilePosition position;
  final VoidCallback onOpen;
  final VoidCallback onOptions;

  BorderRadius get _borderRadius => switch (position) {
    _TilePosition.only => BorderRadius.circular(22),
    _TilePosition.first => const BorderRadius.vertical(
      top: Radius.circular(22),
    ),
    _TilePosition.middle => BorderRadius.zero,
    _TilePosition.last => const BorderRadius.vertical(
      bottom: Radius.circular(22),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: colors.surfaceContainer,
        borderRadius: _borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          onLongPress: onOptions,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Row(
              children: [
                SizedBox(
                  width: 58,
                  height: 58,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.none,
                      children: [
                        if (project.iconBytes == null)
                          const Center(child: FlutterwareLogo(size: 44))
                        else
                          Image.memory(
                            project.iconBytes!,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                        if (project.pinned)
                          const Positioned(
                            right: 5,
                            top: 5,
                            child: Icon(
                              Icons.push_pin_rounded,
                              color: Colors.black87,
                              size: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        project.packageName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        project.modifiedLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Project options',
                  onPressed: onOptions,
                  icon: const Icon(Icons.more_vert_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FlutterwareDrawer extends StatelessWidget {
  const _FlutterwareDrawer({required this.onDestinationSelected});

  final ValueChanged<String> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return NavigationDrawer(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 16, 20),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(child: FlutterwareLogo(size: 36)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Flutterware',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 8, 16, 4),
          child: Text('Workspace'),
        ),
        ListTile(
          leading: const Icon(Icons.memory_rounded),
          title: const Text('Toolchains'),
          subtitle: const Text('Flutter • Android • ARM64'),
          onTap: () => onDestinationSelected('Toolchains'),
        ),
        ListTile(
          leading: const Icon(Icons.inventory_2_outlined),
          title: const Text('Pub packages'),
          onTap: () => onDestinationSelected('Pub packages'),
        ),
        ListTile(
          leading: const Icon(Icons.terminal_rounded),
          title: const Text('Build logs'),
          onTap: () => onDestinationSelected('Build logs'),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 18, 16, 4),
          child: Text('Application'),
        ),
        ListTile(
          leading: const Icon(Icons.settings_rounded),
          title: const Text('Settings'),
          onTap: () => onDestinationSelected('Settings'),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline_rounded),
          title: const Text('About'),
          onTap: () => onDestinationSelected('About'),
        ),
      ],
    );
  }
}

class _TemplatesPage extends StatelessWidget {
  const _TemplatesPage({
    required this.creatingTemplateId,
    required this.onOpenMenu,
    required this.onOpenTemplate,
    required this.onRunTemplate,
  });

  final String? creatingTemplateId;
  final VoidCallback onOpenMenu;
  final ValueChanged<DemoProjectTemplate> onOpenTemplate;
  final ValueChanged<DemoProjectTemplate> onRunTemplate;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Open menu',
                  onPressed: onOpenMenu,
                  icon: const Icon(Icons.menu_rounded),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Templates',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              tabs: [
                Tab(text: 'Demo apps'),
                Tab(text: 'Building blocks'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _DemoTemplatesList(
                  creatingTemplateId: creatingTemplateId,
                  onOpenTemplate: onOpenTemplate,
                  onRunTemplate: onRunTemplate,
                ),
                const _BuildingBlocksPlaceholder(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoTemplatesList extends StatelessWidget {
  const _DemoTemplatesList({
    required this.creatingTemplateId,
    required this.onOpenTemplate,
    required this.onRunTemplate,
  });

  final String? creatingTemplateId;
  final ValueChanged<DemoProjectTemplate> onOpenTemplate;
  final ValueChanged<DemoProjectTemplate> onRunTemplate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(
                  Icons.rocket_launch_rounded,
                  size: 36,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Learn by taking things apart',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Each demo becomes your own editable project. Change its UI, inspect the logic, or build and run it.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...DemoProjectTemplates.all.map(
          (template) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DemoTemplateCard(
              template: template,
              busy: creatingTemplateId == template.id,
              actionsEnabled: creatingTemplateId == null,
              onOpen: () => onOpenTemplate(template),
              onRun: () => onRunTemplate(template),
            ),
          ),
        ),
      ],
    );
  }
}

class _DemoTemplateCard extends StatelessWidget {
  const _DemoTemplateCard({
    required this.template,
    required this.busy,
    required this.actionsEnabled,
    required this.onOpen,
    required this.onRun,
  });

  final DemoProjectTemplate template;
  final bool busy;
  final bool actionsEnabled;
  final VoidCallback onOpen;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final complexity = switch (template.complexity) {
      DemoComplexity.beginner => 'Beginner',
      DemoComplexity.intermediate => 'Intermediate',
      DemoComplexity.advanced => 'Advanced',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Color(template.color).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    _demoIcon(template.iconName),
                    color: Color(template.color),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$complexity • ${template.design.pages.length} page${template.design.pages.length == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: colors.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(template.description),
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: template.highlights
                  .map(
                    (highlight) => Chip(
                      label: Text(highlight),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                      backgroundColor: colors.surfaceContainerHigh,
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: actionsEnabled ? onOpen : null,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Open & edit'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: actionsEnabled ? onRun : null,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(busy ? 'Creating…' : 'Run demo'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildingBlocksPlaceholder extends StatelessWidget {
  const _BuildingBlocksPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.widgets_outlined,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              'Building-block templates',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'Reusable screens and components will live here.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

IconData _demoIcon(String name) => switch (name) {
  'calculate' => Icons.calculate_rounded,
  'task' => Icons.task_alt_rounded,
  'storefront' => Icons.storefront_rounded,
  'account_balance_wallet' => Icons.account_balance_wallet_rounded,
  'travel_explore' => Icons.travel_explore_rounded,
  _ => Icons.apps_rounded,
};

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 58,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          const Text('No matching projects'),
        ],
      ),
    );
  }
}
