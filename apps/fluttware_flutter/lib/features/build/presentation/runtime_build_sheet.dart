import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../runtime/runtime_controller.dart';
import '../../../ui/widgets/app_button.dart';
import '../../projects/domain/project_summary.dart';

class RuntimeBuildSheet extends StatefulWidget {
  const RuntimeBuildSheet({
    super.key,
    required this.project,
    this.startBuild = true,
  });

  final ProjectSummary project;
  final bool startBuild;

  @override
  State<RuntimeBuildSheet> createState() => _RuntimeBuildSheetState();
}

class _RuntimeBuildSheetState extends State<RuntimeBuildSheet> {
  final _controller = RuntimeController.instance;
  final _logScroll = ScrollController();
  String? _startError;
  bool _autoInstallStarted = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_runtimeChanged);
    if (widget.startBuild) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  Future<void> _start() async {
    if (_controller.snapshot.busy) return;
    try {
      await _controller.startCreateBuild(
        projectId: widget.project.id,
        projectName: widget.project.name,
        packageName: widget.project.packageName,
      );
    } on PlatformException catch (error) {
      if (mounted) setState(() => _startError = error.message ?? error.code);
    }
  }

  void _runtimeChanged() {
    if (!mounted) return;
    setState(() {});
    final runtime = _controller.snapshot;
    if (widget.startBuild &&
        !_autoInstallStarted &&
        runtime.projectId == widget.project.id &&
        runtime.completed &&
        runtime.apkPath != null) {
      _autoInstallStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _install(auto: true));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScroll.hasClients) {
        _logScroll.animateTo(
          _logScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_runtimeChanged);
    _logScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runtime = _controller.snapshot;
    final failed = runtime.phase == 'failed' || _startError != null;
    final completed = runtime.completed && runtime.apkPath != null;

    return PopScope(
      canPop: true,
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.74,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        completed
                            ? 'APK ready'
                            : 'Building ${widget.project.name}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: runtime.busy ? 'Hide build details' : 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        runtime.busy
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.close_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: runtime.progress),
                  duration: const Duration(milliseconds: 480),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: runtime.progress == 0 ? null : value,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      failed
                          ? Icons.error_rounded
                          : completed
                          ? Icons.check_circle_rounded
                          : Icons.memory_rounded,
                      color: failed
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_startError ?? runtime.message)),
                    Text('${(runtime.progress * 100).round()}%'),
                  ],
                ),
                if (runtime.error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    runtime.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  'Build log',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: runtime.logs.isEmpty
                        ? const Text(
                            'Starting native runtime…',
                            style: TextStyle(fontFamily: 'monospace'),
                          )
                        : ListView.builder(
                            controller: _logScroll,
                            itemCount: runtime.logs.length,
                            itemBuilder: (context, index) => SelectableText(
                              runtime.logs[index],
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (runtime.busy)
                      Expanded(
                        child: AppButton(
                          label: 'Cancel',
                          variant: AppButtonVariant.outlined,
                          leadingIcon: Icons.stop_rounded,
                          onPressed: _controller.cancelBuild,
                        ),
                      )
                    else if (failed)
                      Expanded(
                        child: AppButton(
                          label: 'Try again',
                          variant: AppButtonVariant.outlined,
                          leadingIcon: Icons.refresh_rounded,
                          onPressed: () {
                            setState(() => _startError = null);
                            _start();
                          },
                        ),
                      ),
                    if (completed) ...[
                      Expanded(
                        child: AppButton(
                          label: 'Install & run',
                          trailingIcon: Icons.install_mobile_rounded,
                          onPressed: () => _install(),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _install({bool auto = false}) async {
    try {
      final permissionRequired = await _controller.installAndLaunch();
      if (!mounted) return;
      if (permissionRequired) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Allow installs from Flutterware. Installation will continue automatically when you return.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
      if (auto && mounted) Navigator.pop(context);
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not install APK')),
      );
    }
  }
}
