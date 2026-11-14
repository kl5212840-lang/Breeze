import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/routing/plugin_routing_rules.dart';
import 'package:zephyr/network/routing/routing_domain_catalog.dart';
import 'package:zephyr/network/routing/routing_saved_rules.dart';
import 'package:zephyr/network/routing/routing_domain_scanner.dart';
import 'package:crypto/crypto.dart';
import 'package:zephyr/network/routing/routing_observed_media.dart';
import 'package:zephyr/network/routing/routing_config_inspection.dart';
import 'package:zephyr/network/routing/routing_generation_records.dart';
import 'package:zephyr/network/routing/routing_plugin_discovery.dart';
import 'package:zephyr/network/routing/routing_probe_session.dart';
import 'package:zephyr/page/video/api_video_browser.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/network/routing/routing_rule_output.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/network/routing_config_export.dart';
import 'package:zephyr/widgets/action_feedback.dart';

// Fixed routing actions belong to the page, not a translucent overlay.
// Resolve disabled colors against this opaque footer before painting them.
ButtonStyle _routingActionStyle(BuildContext context) {
  final theme = Theme.of(context), colors = theme.colorScheme;
  final surface = theme.scaffoldBackgroundColor;
  return FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(48),
    backgroundColor: colors.primary,
    disabledBackgroundColor: Color.alphaBlend(
      colors.onSurface.withValues(alpha: .12),
      surface,
    ),
    disabledForegroundColor: Color.alphaBlend(
      colors.onSurface.withValues(alpha: .38),
      surface,
    ),
  );
}

class _RoutingActionFooter extends StatelessWidget {
  const _RoutingActionFooter({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('routing-action-footer'),
    color: Theme.of(context).scaffoldBackgroundColor,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: child,
      ),
    ),
  );
}

Future<XFile?> _chooseRoutingConfiguration() => openFile();

String _routingEvidenceStamp(RoutingPlan plan, Set<String> ids) => jsonEncode({
  for (final id in (ids.toList()..sort()))
    id: {
      'scanned': (plan.scannedDomains[id] ?? const []).toList()..sort(),
      'declared': plan.customSources[id]?.domains ?? const <String>[],
    },
});

String _routingPluginStamp(
  RoutingPluginDiscovery discovery,
  List<RoutingSource> sources,
) => jsonEncode({
  for (final source in sources)
    source.id: {
      'installed': discovery.isInstalled(source.id),
      'name': discovery
          .installedSources()
          .where((value) => value.id == source.id)
          .firstOrNull
          ?.name,
      'script': sha256
          .convert(
            utf8.encode(
              PluginRegistryService.I.getByUuid(source.id)?.originScript ?? '',
            ),
          )
          .toString(),
      'routing': PluginRegistryService.I.getCachedPluginInfo(
        source.id,
      )?['routing'],
    },
});

class RoutingConfigurationActions {
  const RoutingConfigurationActions({
    this.chooseFile = _chooseRoutingConfiguration,
  });
  final Future<XFile?> Function() chooseFile;
}

class RoutingRulesPage extends StatefulWidget {
  const RoutingRulesPage({
    super.key,
    this.source,
    this.discovery = const RoutingPluginDiscovery(),
    this.configurationActions = const RoutingConfigurationActions(),
    this.probeFactory,
  });
  final String? source;
  final RoutingPluginDiscovery discovery;
  final RoutingConfigurationActions configurationActions;
  final RoutingProbeSession Function(String source)? probeFactory;
  @override
  State<RoutingRulesPage> createState() => _RoutingRulesPageState();
}

class _RoutingRulesPageState extends State<RoutingRulesPage> {
  RoutingPlan? _catalog;
  List<RoutingGenerationRecord> _records = [];
  bool _recordsFailed = false;
  final Set<String> _selected = {};
  bool _busy = false, _failed = false;
  String? _error;
  StreamSubscription<void>? _changes;

  @override
  void initState() {
    super.initState();
    _changes = widget.discovery.changes.listen((_) {
      if (mounted) {
        setState(
          () => _selected.retainAll(_sources().map((s) => s.id).toSet()),
        );
      }
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  List<RoutingSource> _sources() {
    final catalog = _catalog;
    if (catalog == null) return [];
    final installed = widget.discovery.installedSources();
    final ids = installed.map((s) => s.id).toSet();
    final result = [
      for (final source in installed)
        RoutingSource(
          source.id,
          source.name,
          catalog.sources
                  .where((s) => s.id == source.id)
                  .firstOrNull
                  ?.domains ??
              const [],
        ),
      ...catalog.customSources.values.where(
        (s) => s.fromFile && !ids.contains(s.id),
      ),
    ];
    if (widget.source != null) {
      result.sort(
        (a, b) => a.id == widget.source
            ? -1
            : b.id == widget.source
            ? 1
            : 0,
      );
    }
    return result;
  }

  Future<void> _load() async {
    try {
      final catalog = await RoutingDomainCatalogStore.read();
      if (mounted) {
        setState(() {
          _catalog = catalog;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
    await _loadRecords();
  }

  Future<void> _loadRecords() async {
    try {
      final records = await RoutingGenerationRecords.read();
      if (mounted) {
        setState(() {
          _records = records;
          _recordsFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _recordsFailed = true);
    }
  }

  Future<void> _showRecords() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _loadRecords();
      if (!mounted || _recordsFailed) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _RoutingRecordsPage(
            records: _records,
            actions: widget.configurationActions,
          ),
        ),
      );
      await _loadRecords();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<RoutingPlan> _cacheScan(RoutingSource source) async {
    final saved = await RoutingDomainCatalogStore.saveScannedSource(source);
    if (mounted) setState(() => _catalog = saved);
    return saved;
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await openFile();
      if (file == null) return;
      if (!RegExp(r'\.(cjs|js)$', caseSensitive: false).hasMatch(file.name) ||
          await file.length() > 4 * 1024 * 1024) {
        throw const FormatException('Invalid plugin');
      }
      final source = await widget.discovery.scanFile(
        utf8.decode(await file.readAsBytes()),
        file.name,
      );
      await _cacheScan(source);
    } catch (_) {
      if (mounted) setState(() => _error = t.routingRules.invalidPlugin);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _next() async {
    if (_busy || _selected.isEmpty) return;
    final sources = _sources().where((s) => _selected.contains(s.id)).toList();
    if (sources.isEmpty) return;
    setState(() => _busy = true);
    try {
      final fresh = await RoutingDomainCatalogStore.read();
      if (!mounted) return;
      setState(() => _catalog = fresh);
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _RoutingOptionsPage(
            sources: sources,
            catalog: _catalog!.withAvailableSources(sources),
            discovery: widget.discovery,
            probeFactory: widget.probeFactory,
            onScannedSource: _cacheScan,
          ),
        ),
      );
    } finally {
      await _loadRecords();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = t.routingRules;
    final sources = _sources();
    final allSelected =
        sources.isNotEmpty && _selected.containsAll(sources.map((s) => s.id));
    final installed = sources
        .where((s) => widget.discovery.isInstalled(s.id))
        .toList();
    final imported = sources
        .where((s) => !widget.discovery.isInstalled(s.id))
        .toList();
    Widget rows(List<RoutingSource> entries) => _Group(
      children: [
        for (final source in entries)
          Semantics(
            checked: _selected.contains(source.id),
            child: TouchHoverIntent(
              identity: ValueKey('routing-select:${source.id}'),
              builder: (context, hover) => ListTile(
                hoverColor: hover.hoverColor(),
                key: ValueKey('routing-select:${source.id}'),
                minTileHeight: 60,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                title: Text(source.name),
                selected: _selected.contains(source.id),
                trailing: _SelectionMark(
                  selected: _selected.contains(source.id),
                ),
                onTap: _busy
                    ? null
                    : () => setState(() {
                        if (!_selected.add(source.id)) {
                          _selected.remove(source.id);
                        }
                        _error = null;
                      }),
              ),
            ),
          ),
      ],
    );
    return SettingPageShell(
      title: text.toolTitle,
      child: SafeArea(
        top: false,
        bottom: false,
        child: _failed
            ? Center(
                child: TextButton(
                  onPressed: _load,
                  child: Text(t.common.retry),
                ),
              )
            : _catalog == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: kSettingPagePadding,
                      children: [
                        Text(
                          text.toolIntro,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        TouchHoverIntent(
                          identity: const ValueKey('routing-records'),
                          builder: (context, hover) => ListTile(
                            hoverColor: hover.hoverColor(),
                            key: const ValueKey('routing-records'),
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.history_rounded,
                              size: 22,
                            ),
                            title: Text(text.recordsTitle),
                            subtitle: Text(
                              _recordsFailed
                                  ? text.recordsLoadFailed
                                  : _records.isEmpty
                                  ? text.noRecords
                                  : text.recordsCount(count: _records.length),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                            ),
                            onTap: _busy ? null : _showRecords,
                          ),
                        ),
                        TouchHoverIntent(
                          identity: const ValueKey('import-routing-plugin'),
                          builder: (context, hover) => ListTile(
                            hoverColor: hover.hoverColor(),
                            key: const ValueKey('import-routing-plugin'),
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.file_open_outlined,
                              size: 22,
                            ),
                            title: Text(text.addPlugin),
                            subtitle: Text(text.importHint),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                            ),
                            onTap: _busy ? null : _import,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                text.installed,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            TextButton(
                              key: const ValueKey('routing-select-all'),
                              onPressed: _busy || sources.isEmpty
                                  ? null
                                  : () => setState(() {
                                      if (allSelected) {
                                        _selected.clear();
                                      } else {
                                        _selected.addAll(
                                          sources.map((s) => s.id),
                                        );
                                      }
                                    }),
                              child: Text(
                                allSelected
                                    ? text.deselectAllPlugins
                                    : text.selectAllPlugins,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (installed.isNotEmpty)
                          rows(installed)
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: _Hint(text.noPlugins),
                          ),
                        if (imported.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            text.importedFiles,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 12),
                          rows(imported),
                        ],
                      ],
                    ),
                  ),
                  _RoutingActionFooter(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_error != null) ...[
                          _ErrorText(_error!),
                          const SizedBox(height: 8),
                        ],
                        _Hint(text.selectedPlugins(count: _selected.length)),
                        const SizedBox(height: 8),
                        FilledButton(
                          key: const ValueKey('routing-next'),
                          onPressed: _busy || _selected.isEmpty ? null : _next,
                          style: _routingActionStyle(context),
                          child: Text(text.next),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _RoutingRecordsPage extends StatefulWidget {
  const _RoutingRecordsPage({required this.records, required this.actions});
  final List<RoutingGenerationRecord> records;
  final RoutingConfigurationActions actions;

  @override
  State<_RoutingRecordsPage> createState() => _RoutingRecordsPageState();
}

class _RoutingRecordsPageState extends State<_RoutingRecordsPage> {
  String? _copied, _error;
  String? _inspectionMessage;
  late List<RoutingGenerationRecord> _records = widget.records;
  bool _busy = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _inspect() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _inspectionMessage = null;
    });
    final expected = List<RoutingGenerationRecord>.of(_records);
    try {
      // iOS .conf UTTypes vary; validate bounded contents, not the extension.
      final file = await widget.actions.chooseFile();
      if (file == null || !mounted) return;
      if (await file.length() > 2 * 1024 * 1024) {
        if (mounted) setState(() => _error = t.routingRules.tooLarge);
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 2 * 1024 * 1024) {
        setState(() => _error = t.routingRules.tooLarge);
        return;
      }
      final inspection = inspectRoutingConfiguration(
        utf8.decode(bytes),
        expected,
      );
      final at = DateTime.now().toUtc();
      await RoutingGenerationRecords.applyConfigurationInspection(
        expected: expected,
        recovered: [
          for (final block in inspection.ownedBlocks)
            RoutingGenerationRecord(
              source: block.source,
              route: block.route,
              generatedAt: at,
              origin: RoutingRecordOrigin.configuration,
            ),
        ],
        statuses: inspection.statusBySource.map(
          (id, status) => MapEntry(id, status.name),
        ),
        checkedAt: at,
      );
      final refreshed = await RoutingGenerationRecords.read();
      if (!mounted) return;
      final changedDuringCheck = expected.any((snapshot) {
        final current = refreshed
            .where((r) => r.source.id == snapshot.source.id)
            .firstOrNull;
        return current == null ||
            current.generatedAt != snapshot.generatedAt ||
            current.ruleBlock != snapshot.ruleBlock;
      });
      setState(() {
        _records = refreshed;
        _inspectionMessage = changedDuringCheck
            ? t.routingRules.checkChanged
            : inspection.statusBySource.isEmpty
            ? t.routingRules.checkNoRules
            : t.routingRules.checkFinished;
      });
    } on FormatException {
      if (mounted) setState(() => _error = t.routingRules.checkInvalid);
    } catch (_) {
      if (mounted) setState(() => _error = t.routingRules.checkFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(RoutingGenerationRecord record) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Clipboard.setData(ClipboardData(text: record.ruleBlock));
      if (!mounted) return;
      _timer?.cancel();
      setState(() => _copied = record.source.id);
      showActionFeedback(
        context,
        t.routingRules.copiedRulesCount(count: record.source.domains.length),
      );
      _timer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _copied = null);
      });
    } catch (_) {
      if (mounted) setState(() => _error = t.routingRules.copyFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = t.routingRules;
    final localizations = MaterialLocalizations.of(context);
    return SettingPageShell(
      title: text.recordsTitle,
      child: SafeArea(
        top: false,
        child: ListView(
          padding: kSettingPagePadding,
          children: [
            _Hint(text.recordsHint),
            const SizedBox(height: 12),
            TouchHoverIntent(
              identity: const ValueKey('routing-check-config'),
              builder: (context, hover) => OutlinedButton.icon(
                key: const ValueKey('routing-check-config'),
                onPressed: _busy ? null : _inspect,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fact_check_outlined, size: 20),
                label: Text(_busy ? text.checkWorking : text.checkConfig),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ).copyWith(overlayColor: hover.overlayColor(null)),
              ),
            ),
            const SizedBox(height: 8),
            _Hint(text.checkScope),
            const SizedBox(height: 20),
            if (_error != null) _ErrorText(_error!),
            if (_inspectionMessage != null)
              Semantics(liveRegion: true, child: _Hint(_inspectionMessage!)),
            if (_records.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text(text.noRecords)),
              ),
            for (final record in _records) ...[
              _Group(
                children: [
                  _RoutingDisclosure(
                    key: ValueKey('routing-record:${record.source.id}'),
                    title: Text(record.source.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${record.route == PluginRoute.direct ? text.direct : text.proxy} · ${text.domainCount(count: record.source.domains.length)}',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          switch (record.configurationStatus) {
                            'matching' => text.checkMatching,
                            'missing' => text.checkMissing,
                            'different' => text.checkDifferent,
                            'conflicting' => text.checkConflicting,
                            _ => text.checkNotChecked,
                          },
                          key: ValueKey(
                            'routing-check-status:${record.source.id}',
                          ),
                          style: settingNoteTextStyle(context),
                        ),
                      ],
                    ),
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                    trailingAction: IconButton(
                      key: ValueKey('copy-record:${record.source.id}'),
                      tooltip: text.copyPluginRules,
                      onPressed: _busy ? null : () => _copy(record),
                      icon: Icon(
                        _copied == record.source.id
                            ? Icons.check_rounded
                            : Icons.copy_rounded,
                        size: 20,
                      ),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: [
                      Text(
                        (record.origin == RoutingRecordOrigin.configuration
                            ? text.importedAt
                            : text.generatedAt)(
                          time:
                              '${localizations.formatCompactDate(record.generatedAt.toLocal())} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(record.generatedAt.toLocal()), alwaysUse24HourFormat: true)}',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (record.checkedAt != null) ...[
                        const SizedBox(height: 4),
                        _Hint(
                          text.checkedAt(
                            time:
                                '${localizations.formatCompactDate(record.checkedAt!.toLocal())} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(record.checkedAt!.toLocal()), alwaysUse24HourFormat: true)}',
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      for (final host in record.source.domains)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(host),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.selected});
  final bool selected;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: 24,
      child: AnimatedSwitcher(
        duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 120,
        ),
        child: selected
            ? Icon(
                Icons.check_circle_rounded,
                key: const ValueKey(true),
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              )
            : Container(
                key: const ValueKey(false),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                    width: 1.5,
                  ),
                ),
              ),
      ),
    ),
  );
}

class _RoutingOptionsPage extends StatefulWidget {
  const _RoutingOptionsPage({
    required this.sources,
    required this.catalog,
    required this.discovery,
    required this.onScannedSource,
    this.probeFactory,
  });
  final List<RoutingSource> sources;
  final RoutingPlan catalog;
  final RoutingPluginDiscovery discovery;
  final Future<RoutingPlan> Function(RoutingSource) onScannedSource;
  final RoutingProbeSession Function(String source)? probeFactory;
  @override
  State<_RoutingOptionsPage> createState() => _RoutingOptionsPageState();
}

class _RoutingOptionsPageState extends State<_RoutingOptionsPage> {
  late RoutingPlan _catalog = widget.catalog;
  late final Map<String, TextEditingController> _extras = {
    for (final source in widget.sources)
      source.id: TextEditingController(
        text: widget.catalog.choices.containsKey(source.id)
            ? ''
            : widget.catalog.extraDomains[source.id]?.join('\n') ?? '',
      ),
  };
  late final Map<String, PluginRoute> _routes = {
    for (final s in widget.sources)
      s.id: widget.catalog.choices[s.id] ?? PluginRoute.direct,
  };
  late final Map<String, List<String>> _previousDomains = {
    for (final s in widget.sources) s.id: widget.catalog.domainsFor(s),
  };
  late Future<RoutingSavedSnapshot> _baselineSaved;
  late String _pluginBaseline;
  late Map<String, Set<String>> _draftConfirmed = {
    for (final source in widget.sources)
      source.id: {...?widget.catalog.confirmedDomains[source.id]},
  };
  List<RoutingSource> get _reviewSources => [
    for (final source in widget.sources)
      RoutingSource(
        source.id,
        source.name,
        _catalog.sources
                .where((value) => value.id == source.id)
                .firstOrNull
                ?.domains ??
            source.domains,
        fromFile: source.fromFile,
      ),
  ];
  List<String> _draftPendingFor(RoutingSource source) => _catalog
      .candidatesFor(source)
      .where(
        (host) =>
            !(_draftConfirmed[source.id] ?? const <String>{}).contains(host),
      )
      .toList();
  int _draftIncludedCount(RoutingSource source) {
    final hosts = {
      ...source.domains,
      ..._catalog
          .candidatesFor(source)
          .where(
            (host) =>
                (_draftConfirmed[source.id] ?? const <String>{}).contains(host),
          ),
    };
    for (final line in _extras[source.id]!.text.split('\n')) {
      if (line.trim().isEmpty) continue;
      try {
        final host = normalizeRoutingDomain(line);
        if (isRoutingContentDomain(host)) hosts.add(host);
      } on FormatException {
        /* Invalid draft text is explained at preview. */
      }
    }
    return hosts.length;
  }

  final Set<String> _scanning = {}, _success = {}, _saving = {};
  final Map<String, String> _scanErrors = {};
  final Map<String, Timer> _timers = {};
  bool _busy = false;
  String? _error;
  Map<String, List<RoutingObservedMediaHost>> _observed = {};
  final Map<String, RoutingProbeSession> _probes = {};
  final Set<String> _probeReview = {};
  StreamSubscription<void>? _probeChanges;
  void _probeChanged() {
    if (mounted) setState(() {});
  }

  String _probeLabel(RoutingProbeSession probe) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final result = probe.result;
    if (result?.cancelled == true)
      return zh ? '已取消，保留上次结果' : 'Cancelled; previous results kept';
    if (probe.phase == RoutingProbePhase.committing)
      return zh ? '正在保存结果…' : 'Saving results…';
    if (result == null) {
      return switch (probe.phase) {
        RoutingProbePhase.metadata =>
          zh ? '正在读取插件声明…' : 'Reading source declarations…',
        RoutingProbePhase.catalog => zh ? '正在读取公开列表…' : 'Reading public lists…',
        RoutingProbePhase.details =>
          zh ? '正在读取作品资料…' : 'Reading public details…',
        _ =>
          zh
              ? '已解析线路 ${probe.lines}/${probe.totalLines}'
              : 'Resolved lines ${probe.lines}/${probe.totalLines}',
      };
    }
    if (probe.unsupported > 0 && probe.succeeded <= 1)
      return zh
          ? '未声明主动采样入口，保留静态扫描与访问观察。'
          : 'No active read entry declared; static scanning and visit observations remain available.';
    final lines = probe.totalLines == 0
        ? ''
        : (zh
              ? '；线路 ${probe.lines}/${probe.totalLines}'
              : '; lines ${probe.lines}/${probe.totalLines}');
    final counts = zh
        ? '读取成功 ${probe.succeeded}，失败 ${probe.failed}$lines'
        : 'Reads: ${probe.succeeded} succeeded, ${probe.failed} failed$lines';
    return probe.failed > 0 || probe.unsupported > 0
        ? '$counts${zh ? '，未完成部分保留旧结果。' : '; previous results kept for incomplete reads.'}'
        : counts;
  }

  Future<void> _updateDomains(RoutingSource source) async {
    if (_busy || _scanning.isNotEmpty || _saving.isNotEmpty) return;
    if (!widget.discovery.isInstalled(source.id) ||
        (widget.probeFactory == null &&
            PluginRegistryService.I.getByUuid(source.id) == null)) {
      await _scan(source);
      return;
    }
    final previousCandidates = _catalog.candidatesFor(source).toSet();
    final previousObserved =
        _observed[source.id]?.map((row) => row.host).toSet() ?? <String>{};
    final probe =
        widget.probeFactory?.call(source.id) ??
        RoutingProbeSession(source: source.id);
    _probes.remove(source.id)?.dispose();
    _probes[source.id] = probe;
    probe.addListener(_probeChanged);
    setState(() {
      _scanning.add(source.id);
      _scanErrors.remove(source.id);
      _success.remove(source.id);
    });
    RoutingSource? scanned;
    try {
      try {
        scanned = await widget.discovery.scanInstalled(source);
      } catch (_) {}
      final result = await probe.run();
      if (!mounted ||
          result.cancelled ||
          !widget.discovery.isInstalled(source.id))
        return;
      if (scanned != null && scanned.domains.isNotEmpty) {
        await widget.onScannedSource(
          RoutingSource(
            source.id,
            source.name,
            {
              if (!result.complete)
                ...(_catalog.scannedDomains[source.id] ?? const <String>[])
                    .where((host) => !previousObserved.contains(host)),
              ...scanned.domains,
            }.toList()..sort(),
            fromFile: source.fromFile,
          ),
        );
      }
      await _refreshObserved();
      if (mounted &&
          _catalog
              .candidatesFor(source)
              .any((host) => !previousCandidates.contains(host))) {
        setState(() => _probeReview.add(source.id));
      }
      if (mounted && result.complete) setState(() => _success.add(source.id));
    } catch (_) {
      if (mounted)
        setState(() => _scanErrors[source.id] = t.routingRules.scanFailed);
    } finally {
      if (mounted) setState(() => _scanning.remove(source.id));
    }
  }

  Future<void> _refreshObserved() async {
    final fresh = (await RoutingDomainCatalogStore.read()).withAvailableSources(
      widget.sources,
    );
    final evidence = await RoutingObservedMediaDomains.read();
    if (mounted)
      setState(() {
        _catalog = fresh;
        _observed = evidence;
      });
  }

  String? _observedLabel(String source, String host) =>
      _observed[source]?.any(
            (row) =>
                row.host == host &&
                (row.evidence.contains('requested') ||
                    row.evidence.contains('response')),
          ) ==
          true
      ? t.routingRules.runtimeObserved
      : null;

  String? _observedAtFor(String source) {
    final rows = _observed[source];
    if (rows == null || rows.isEmpty) return null;
    final latest = rows
        .map((row) => row.lastSeen)
        .reduce((a, b) => a.isAfter(b) ? a : b)
        .toLocal();
    final format = MaterialLocalizations.of(context);
    return t.routingRules.runtimeObservedAt(
      time:
          '${format.formatShortDate(latest)} ${format.formatTimeOfDay(TimeOfDay.fromDateTime(latest))}',
    );
  }

  @override
  void initState() {
    super.initState();
    _baselineSaved = RoutingSavedRulesStore.read();
    _pluginBaseline = _routingPluginStamp(widget.discovery, widget.sources);

    unawaited(_refreshObserved());
    unawaited(_scanMissing());
    _probeChanges = widget.discovery.changes.listen((_) {
      for (final entry in _probes.entries) {
        if (!widget.discovery.isInstalled(entry.key))
          entry.value.cancel();
        else
          entry.value.invalidateIfChanged();
      }
    });
  }

  @override
  void dispose() {
    _probeChanges?.cancel();
    for (final probe in _probes.values) {
      probe.removeListener(_probeChanged);
      probe.dispose();
    }
    for (final controller in _extras.values) {
      controller.dispose();
    }
    for (final timer in _timers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  Future<void> _scanMissing() async {
    for (final source in widget.sources) {
      if (!mounted) return;
      if (_catalog.domainsFor(source).isEmpty &&
          (_catalog.scannedDomains[source.id] ?? const []).isEmpty &&
          widget.discovery.isInstalled(source.id)) {
        await _scan(source);
      }
    }
  }

  Future<void> _scan(RoutingSource source) async {
    if (_scanning.contains(source.id) || _saving.contains(source.id) || _busy)
      return;
    _timers.remove(source.id)?.cancel();
    setState(() {
      _scanning.add(source.id);
      _success.remove(source.id);
      _scanErrors.remove(source.id);
    });
    try {
      // Refresh also gathers fresh playback observations, even if static
      // extraction is unchanged, empty, unavailable, or later fails.
      await _refreshObserved();
      RoutingSource? updated;
      if (widget.discovery.isInstalled(source.id)) {
        updated = await widget.discovery.scanInstalled(source);
      } else {
        final file = await openFile();
        if (file == null) return;
        if (await file.length() > 4 * 1024 * 1024 ||
            !RegExp(r'\.(cjs|js)$', caseSensitive: false).hasMatch(file.name)) {
          throw const FormatException();
        }
        updated = await widget.discovery.scanFile(
          utf8.decode(await file.readAsBytes()),
          file.name,
        );
        if (updated.id != source.id &&
            !(updated.id.startsWith('file:') &&
                source.id.startsWith('file:') &&
                updated.name == source.name)) {
          if (mounted) {
            setState(() => _scanErrors[source.id] = t.routingRules.wrongPlugin);
          }
          return;
        }
      }
      if (updated.domains.isEmpty &&
          (_catalog.scannedDomains[source.id] ?? const []).isEmpty) {
        if (mounted)
          setState(() => _scanErrors[source.id] = t.routingRules.scanEmpty);
        return;
      }
      RoutingPlan saved;
      try {
        // Save before displaying success, even when the user has already gone
        // back. This read-only scan is not a generation or a policy change.
        saved = await widget.onScannedSource(
          RoutingSource(
            source.id,
            source.name,
            updated.domains,
            fromFile: source.fromFile,
          ),
        );
      } catch (_) {
        if (mounted)
          setState(() => _scanErrors[source.id] = t.routingRules.saveFailed);
        return;
      }
      final evidence = await RoutingObservedMediaDomains.read();
      if (!mounted) return;
      setState(() {
        _catalog = saved;
        _observed = evidence;
        _success.add(source.id);
      });
      _timers[source.id] = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _success.remove(source.id));
      });
    } catch (_) {
      if (mounted) {
        setState(() => _scanErrors[source.id] = t.routingRules.scanFailed);
      }
    } finally {
      if (mounted) setState(() => _scanning.remove(source.id));
    }
  }

  void _confirmDomain(RoutingSource source, String host, bool value) {
    if (_busy || _scanning.contains(source.id)) return;
    setState(() {
      final selected = _draftConfirmed.putIfAbsent(source.id, () => {});
      value ? selected.add(host) : selected.remove(host);
    });
  }

  Future<void> _generate() async {
    if (_busy || _scanning.isNotEmpty || _saving.isNotEmpty) return;
    if (_probeReview.isNotEmpty) {
      setState(() {
        _probeReview.clear();
        _error = t.routingRules.runtimeChanged;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final fresh = (await RoutingDomainCatalogStore.read())
          .withAvailableSources(widget.sources);
      final evidence = await RoutingObservedMediaDomains.read();
      if (!mounted) return;
      final changed = widget.sources.any(
        (source) =>
            jsonEncode(_catalog.scannedDomains[source.id] ?? const []) !=
            jsonEncode(fresh.scannedDomains[source.id] ?? const []),
      );
      setState(() {
        _catalog = fresh;
        _observed = evidence;
      });
      if (changed) {
        setState(() => _error = t.routingRules.runtimeChanged);
        return;
      }
      if (_routingPluginStamp(widget.discovery, widget.sources) !=
          _pluginBaseline) {
        throw RoutingCatalogChanged();
      }
      var plan = RoutingPlan(
        choices: fresh.choices,
        extraDomains: fresh.extraDomains,
        customSources: fresh.customSources,
        scannedDomains: fresh.scannedDomains,
        confirmedDomains: {
          for (final entry in _draftConfirmed.entries)
            entry.key:
                entry.value
                    .where(
                      (host) => (fresh.scannedDomains[entry.key] ?? const [])
                          .contains(host),
                    )
                    .toList()
                  ..sort(),
        },
      );
      for (final source in _reviewSources) {
        final extras = _extras[source.id]!.text
            .split('\n')
            .where((s) => s.trim().isNotEmpty)
            .map(normalizeRoutingDomain)
            .toSet()
            .toList();
        if (extras.length > 100 ||
            extras.any((host) => !isRoutingContentDomain(host))) {
          throw const FormatException();
        }
        plan = plan.withSource(source.id, _routes[source.id]!, extras);
        if (plan.domainsFor(source).isEmpty) {
          setState(
            () => _error = t.routingRules.missingPluginDomains(
              plugin: source.name,
            ),
          );
          return;
        }
      }
      final ids = widget.sources.map((s) => s.id).toSet();
      final selected = plan.onlySources(ids);
      selectedRoutingRuleBlocks(selected, ids);
      final baseline = await _baselineSaved;
      final evidenceStamp = _routingEvidenceStamp(
        await RoutingDomainCatalogStore.readEvidence(),
        ids,
      );
      final pluginStamp = _routingPluginStamp(widget.discovery, widget.sources);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _RoutingResultPage(
            sources: widget.sources,
            plan: selected,
            previousDomains: _previousDomains,
            expectedRevisions: baseline.revisions,
            validateFresh: () async {
              final current = await RoutingDomainCatalogStore.readEvidence();
              if (_routingEvidenceStamp(current, ids) != evidenceStamp ||
                  _routingPluginStamp(widget.discovery, widget.sources) !=
                      pluginStamp) {
                throw RoutingCatalogChanged();
              }
            },
            onSaved: (saved) async {
              final current = await RoutingDomainCatalogStore.read();
              if (mounted)
                setState(() {
                  _baselineSaved = Future.value(saved);
                  _catalog = current;
                  for (final source in widget.sources) {
                    _draftConfirmed[source.id] = {};
                    _extras[source.id]?.clear();
                  }
                });
            },
          ),
        ),
      );
    } on RoutingCatalogChanged {
      await _refreshObserved();
      if (mounted) setState(() => _error = t.routingRules.runtimeChanged);
    } on RoutingConflict catch (e) {
      if (mounted) {
        setState(() => _error = t.routingRules.conflict(domain: e.domain));
      }
    } on FormatException {
      if (mounted) setState(() => _error = t.routingRules.invalidDomains);
    } catch (_) {
      if (mounted) setState(() => _error = t.routingRules.saveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = t.routingRules;
    return Stack(
      children: [
        SettingPageShell(
          title: text.accessTitle,
          child: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: kSettingPagePadding,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      Text(
                        text.selectedPlugins(count: widget.sources.length),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      _Hint(text.accessIntro),
                      const SizedBox(height: 8),
                      _Hint(text.runtimeSamplingHint),
                      const SizedBox(height: 12),
                      for (final source in _reviewSources) ...[
                        _Group(
                          children: [
                            _RoutingDisclosure(
                              key: ValueKey('routing-domains:${source.id}'),
                              title: Text(
                                source.name,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              subtitle: Text(
                                _draftPendingFor(source).isEmpty
                                    ? text.domainCount(
                                        count: _draftIncludedCount(source),
                                      )
                                    : text.domainReviewCount(
                                        included: _draftIncludedCount(source),
                                        pending: _draftPendingFor(
                                          source,
                                        ).length,
                                      ),
                              ),
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                16,
                              ),
                              expandedCrossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              trailingAction: IconButton(
                                key: ValueKey('routing-refresh:${source.id}'),
                                tooltip: _success.contains(source.id)
                                    ? text.scanDone
                                    : widget.discovery.isInstalled(source.id)
                                    ? text.scan
                                    : text.updatePluginFile,
                                onPressed:
                                    _busy ||
                                        _scanning.contains(source.id) ||
                                        _saving.contains(source.id)
                                    ? null
                                    : () => _updateDomains(source),
                                constraints: const BoxConstraints(
                                  minWidth: 44,
                                  minHeight: 44,
                                ),
                                icon: SizedBox.square(
                                  dimension: 20,
                                  child: _scanning.contains(source.id)
                                      ? const CircularProgressIndicator(
                                          strokeWidth: 2,
                                        )
                                      : Icon(
                                          _success.contains(source.id)
                                              ? Icons.check_rounded
                                              : Icons.refresh_rounded,
                                          size: 20,
                                        ),
                                ),
                              ),
                              children: [
                                if (source.domains.isNotEmpty) ...[
                                  Text(
                                    text.presetDomains,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  SelectableText(
                                    source.domains.join('\n'),
                                    key: ValueKey(
                                      'routing-default-domains:${source.id}',
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(height: 1.35),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                if (_catalog
                                    .candidatesFor(source)
                                    .isNotEmpty) ...[
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        '${text.extractedDomains} · ${_catalog.candidatesFor(source).length}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                      Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          TextButton(
                                            key: ValueKey(
                                              'routing-candidates-all:${source.id}',
                                            ),
                                            onPressed:
                                                _busy ||
                                                    _scanning.contains(
                                                      source.id,
                                                    )
                                                ? null
                                                : () => setState(() {
                                                    _draftConfirmed[source
                                                        .id] = _catalog
                                                        .candidatesFor(source)
                                                        .toSet();
                                                  }),
                                            child: Text(t.common.selectAll),
                                          ),
                                          TextButton(
                                            key: ValueKey(
                                              'routing-candidates-clear:${source.id}',
                                            ),
                                            onPressed:
                                                _busy ||
                                                    _scanning.contains(
                                                      source.id,
                                                    )
                                                ? null
                                                : () => setState(() {
                                                    _draftConfirmed[source.id] =
                                                        {};
                                                  }),
                                            child: Text(
                                              t.bookshelf.deselectAll,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  for (final host in _catalog.candidatesFor(
                                    source,
                                  ))
                                    TouchHoverIntent(
                                      identity: ValueKey(
                                        'routing-confirm:${source.id}:$host',
                                      ),
                                      builder: (context, hover) => CheckboxListTile(
                                        key: ValueKey(
                                          'routing-confirm:${source.id}:$host',
                                        ),
                                        hoverColor: hover.hoverColor(),
                                        minTileHeight: 48,
                                        minVerticalPadding: 4,
                                        horizontalTitleGap: 8,
                                        dense: true,
                                        titleAlignment:
                                            ListTileTitleAlignment.center,
                                        contentPadding: EdgeInsets.zero,
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        title: Text(
                                          host,
                                          softWrap: true,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                        subtitle:
                                            _observedLabel(source.id, host) ==
                                                null
                                            ? null
                                            : Text(
                                                _observedLabel(
                                                  source.id,
                                                  host,
                                                )!,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                        value:
                                            (_draftConfirmed[source.id] ??
                                                    const <String>{})
                                                .contains(host),
                                        onChanged:
                                            _busy ||
                                                _scanning.contains(source.id) ||
                                                _saving.contains(source.id)
                                            ? null
                                            : (value) => _confirmDomain(
                                                source,
                                                host,
                                                value == true,
                                              ),
                                      ),
                                    ),
                                  if (_observedAtFor(source.id)
                                      case final observedAt?)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        observedAt,
                                        key: ValueKey(
                                          'routing-observed-at:${source.id}',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                ],
                                Text(
                                  text.extraDomains,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  key: ValueKey('routing-extra:${source.id}'),
                                  controller: _extras[source.id],
                                  onChanged: (_) => setState(() {}),
                                  minLines: 2,
                                  maxLines: 6,
                                  enabled:
                                      !_busy &&
                                      !_scanning.contains(source.id) &&
                                      !_saving.contains(source.id),
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  keyboardType: TextInputType.multiline,
                                  decoration: InputDecoration(
                                    hintText: text.extraHint,
                                    hintMaxLines: 2,
                                    isDense: true,
                                    filled: true,
                                    fillColor: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    contentPadding: const EdgeInsets.all(12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outlineVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_probes[source.id] case final probe?)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _probeLabel(probe),
                                        key: ValueKey(
                                          'routing-probe-status:${source.id}',
                                        ),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ),
                                    if (_scanning.contains(source.id))
                                      TextButton(
                                        key: ValueKey(
                                          'routing-probe-cancel:${source.id}',
                                        ),
                                        onPressed: probe.canCancel
                                            ? probe.cancel
                                            : null,
                                        child: Text(t.common.cancel),
                                      ),
                                  ],
                                ),
                              ),
                            if (_scanErrors.containsKey(source.id))
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  8,
                                ),
                                child: _ErrorText(_scanErrors[source.id]!),
                              ),
                            SettingChoiceTile<PluginRoute>(
                              title: text.ruleAccess,
                              enabled: !_busy,
                              value: _routes[source.id]!,
                              items: {
                                PluginRoute.direct: text.direct,
                                PluginRoute.proxy: text.proxy,
                              },
                              onChanged: _busy
                                  ? (_) {}
                                  : (value) => setState(
                                      () => _routes[source.id] = value,
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
                _RoutingActionFooter(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        _ErrorText(_error!),
                        const SizedBox(height: 8),
                      ],
                      FilledButton(
                        key: const ValueKey('routing-generate'),
                        onPressed:
                            _busy || _scanning.isNotEmpty || _saving.isNotEmpty
                            ? null
                            : _generate,
                        style: _routingActionStyle(context),
                        child: Text(_busy ? t.common.loading : text.generate),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final probe in _probes.values)
          if (probe.browser case final browser?)
            Positioned.fill(child: ApiVideoBrowserHost(session: browser)),
      ],
    );
  }
}

class _RoutingResultPage extends StatefulWidget {
  const _RoutingResultPage({
    required this.sources,
    required this.plan,
    required this.previousDomains,
    required this.expectedRevisions,
    required this.validateFresh,
    required this.onSaved,
  });
  final List<RoutingSource> sources;
  final RoutingPlan plan;
  final Map<String, List<String>> previousDomains;
  final Map<String, int> expectedRevisions;
  final Future<void> Function() validateFresh;
  final Future<void> Function(RoutingSavedSnapshot) onSaved;
  @override
  State<_RoutingResultPage> createState() => _RoutingResultPageState();
}

class _RoutingResultPageState extends State<_RoutingResultPage> {
  String? _copied, _copyMessage, _error;
  bool _busy = false;
  bool _saved = false, _historyFailed = false;

  Future<void> _recordSaved() async {
    try {
      await RoutingGenerationRecords.record(
        widget.plan,
        widget.sources.map((source) => source.id),
      );
      if (mounted) setState(() => _historyFailed = false);
    } catch (_) {
      if (mounted) setState(() => _historyFailed = true);
    }
  }

  Future<void> _saveRules() async {
    if (_busy || _saved) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await RoutingSavedRulesStore.save(
        plan: widget.plan,
        sources: widget.sources,
        expectedRevisions: widget.expectedRevisions,
        validateFresh: widget.validateFresh,
      );
      // The explicit snapshot is authoritative. A history write is independent.
      if (mounted) setState(() => _saved = true);
      await _recordSaved();
      try {
        await widget.onSaved(saved);
      } catch (_) {
        if (mounted) setState(() => _historyFailed = true);
      }
    } on RoutingSavedRulesChanged {
      if (mounted) setState(() => _error = t.routingRules.runtimeChanged);
    } on RoutingCatalogChanged {
      if (mounted) setState(() => _error = t.routingRules.runtimeChanged);
    } catch (_) {
      if (mounted) setState(() => _error = t.routingRules.saveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Timer? _timer;
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy(
    String text,
    String key, {
    int? ruleCount,
    int? domainCount,
  }) async {
    if (_busy) return;
    _timer?.cancel();
    setState(() {
      _busy = true;
      _error = null;
      _copied = null;
      _copyMessage = null;
    });
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      _timer?.cancel();
      setState(() {
        _copied = key;
        _copyMessage = domainCount != null
            ? t.routingRules.copiedDomainsCount(count: domainCount)
            : ruleCount == null
            ? t.routingRules.copiedDomain
            : t.routingRules.copiedRulesCount(count: ruleCount);
      });
      _timer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _copied = null;
            _copyMessage = null;
          });
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = t.routingRules.copyFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = t.routingRules;
    final ids = widget.sources.map((s) => s.id).toSet();
    final selectedRules = widget.plan.onlySources(ids).rules;
    return SettingPageShell(
      title: text.outputTitle,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: kSettingPagePadding,
                children: [
                  Text(
                    text.domainSummary(
                      plugins: widget.sources.length,
                      domains: widget.plan.rules.length,
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _Hint(text.outputIntro),
                  const SizedBox(height: 20),
                  for (final source in widget.sources) ...[
                    _Group(
                      children: [
                        _RoutingDisclosure(
                          key: ValueKey('routing-result:${source.id}'),
                          title: Text(
                            source.name,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          subtitle: Text(
                            '${widget.plan.choices[source.id] == PluginRoute.direct ? text.direct : text.proxy} \u00b7 ${text.domainCount(count: widget.plan.domainsFor(source).length)}',
                          ),
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          expandedCrossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          trailingAction: IconButton(
                            key: ValueKey('copy-routing-plugin:${source.id}'),
                            tooltip: text.copyPluginRules,
                            onPressed: _busy
                                ? null
                                : () => _copy(
                                    selectedRoutingRuleBlocks(widget.plan, [
                                      source.id,
                                    ]),
                                    source.id,
                                    ruleCount: widget.plan
                                        .domainsFor(source)
                                        .length,
                                  ),
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            icon: Icon(
                              _copied == source.id
                                  ? Icons.check_rounded
                                  : Icons.copy_rounded,
                              size: 20,
                            ),
                          ),
                          children: [
                            for (final host in widget.plan.domainsFor(source))
                              ListTile(
                                minTileHeight: 48,
                                contentPadding: const EdgeInsets.only(
                                  left: 16,
                                  right: 8,
                                ),
                                title: Text(
                                  host,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                trailing: TouchHoverIntent(
                                  identity: host,
                                  builder: (context, hover) {
                                    const style = ButtonStyle();
                                    return IconButton(
                                      style: style.copyWith(
                                        overlayColor: hover.overlayColor(
                                          style.overlayColor,
                                        ),
                                      ),
                                      tooltip: text.copyDomain,
                                      onPressed: _busy
                                          ? null
                                          : () => _copy(host, host),
                                      constraints: const BoxConstraints(
                                        minWidth: 44,
                                        minHeight: 44,
                                      ),
                                      icon: Icon(
                                        _copied == host
                                            ? Icons.check_rounded
                                            : Icons.copy_outlined,
                                        size: 20,
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 4),
                  _Group(
                    children: [
                      _RoutingDisclosure(
                        key: const ValueKey('routing-use-help'),
                        title: Text(text.toolHowTo),
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            text.toolAddHelp,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(height: 1.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            text.toolUpdateHelp,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(height: 1.5),
                          ),
                          const SizedBox(height: 12),
                          _Hint(text.toolRemoveHelp),
                          const SizedBox(height: 16),
                          Text(
                            text.ruleFormatTitle,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          _Hint(text.ruleFormatHint),
                          const SizedBox(height: 8),
                          _Hint(text.policyNameHint),
                          const SizedBox(height: 8),
                          _Hint(text.sharedHint),
                          const SizedBox(height: 16),
                          Text(
                            text.shadowrocketExample,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          _Hint(text.shadowrocketAdd),
                          const SizedBox(height: 8),
                          _Hint(text.shadowrocketApply),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Group(
                    children: [
                      TouchHoverIntent(
                        identity: const ValueKey('merge-routing-config'),
                        builder: (context, hover) => ListTile(
                          hoverColor: hover.hoverColor(),
                          key: const ValueKey('merge-routing-config'),
                          leading: const Icon(
                            Icons.description_outlined,
                            size: 24,
                          ),
                          title: Text(text.mergeConfig),
                          subtitle: Text(text.toolMergeHint),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          minTileHeight: 64,
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                          ),
                          onTap: _busy
                              ? null
                              : () => Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) => _RoutingExportPage(
                                      plan: widget.plan,
                                      selection: ids,
                                      previousDomains: widget.previousDomains,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Group(
                    children: [
                      _RoutingDisclosure(
                        key: const ValueKey('routing-neko-help'),
                        title: Text(text.nekoTitle),
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          12,
                        ),
                        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Hint(text.nekoHelp),
                          const SizedBox(height: 8),
                          for (final route in [
                            PluginRoute.direct,
                            PluginRoute.proxy,
                          ])
                            if (selectedRules.containsValue(route))
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TouchHoverIntent(
                                  identity: ValueKey('neko:${route.name}'),
                                  builder: (context, hover) => TextButton.icon(
                                    key: ValueKey(
                                      'copy-neko-domains:${route.name}',
                                    ),
                                    style:
                                        TextButton.styleFrom(
                                          minimumSize: const Size(44, 48),
                                        ).copyWith(
                                          overlayColor: hover.overlayColor(
                                            null,
                                          ),
                                        ),
                                    onPressed: _busy
                                        ? null
                                        : () => _copy(
                                            selectedNekoBoxDomains(
                                              widget.plan,
                                              ids,
                                              route: route,
                                            ),
                                            'neko:${route.name}',
                                            domainCount: selectedRules.values
                                                .where(
                                                  (value) => value == route,
                                                )
                                                .length,
                                          ),
                                    icon: Icon(
                                      _copied == 'neko:${route.name}'
                                          ? Icons.check_rounded
                                          : Icons.copy_rounded,
                                      size: 20,
                                    ),
                                    label: Text(
                                      route == PluginRoute.direct
                                          ? text.copyNekoDirect
                                          : text.copyNekoProxy,
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            _RoutingActionFooter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    _ErrorText(_error!),
                    const SizedBox(height: 8),
                  ],
                  Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      ExcludeSemantics(
                        child: Opacity(
                          opacity: 0,
                          child: _Hint(text.outputActivation),
                        ),
                      ),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _copyMessage ?? text.outputActivation,
                          key: const ValueKey('routing-copy-feedback'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: _copyMessage == null
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant
                                    : Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_saved)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _historyFailed
                            ? (Localizations.localeOf(context).languageCode ==
                                      'zh'
                                  ? '规则已保存，记录暂未更新。'
                                  : 'Rules saved; the history could not be updated.')
                            : t.common.saved,
                        key: const ValueKey('routing-save-feedback'),
                      ),
                    ),
                  if (_historyFailed)
                    TextButton(
                      onPressed: _busy ? null : _recordSaved,
                      child: Text(t.common.retry),
                    ),
                  FilledButton.icon(
                    key: const ValueKey('save-routing-rules'),
                    onPressed: _busy || _saved ? null : _saveRules,
                    icon: Icon(
                      _saved ? Icons.check_rounded : Icons.save_outlined,
                    ),
                    label: Text(_saved ? t.common.saved : t.common.save),
                    style: _routingActionStyle(context),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('copy-routing-block'),
                    onPressed: _busy
                        ? null
                        : () => _copy(
                            selectedRoutingRuleBlocks(widget.plan, ids),
                            'all',
                            ruleCount: widget.sources.fold<int>(
                              0,
                              (sum, source) =>
                                  sum + widget.plan.domainsFor(source).length,
                            ),
                          ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: Icon(
                      _copied == 'all'
                          ? Icons.check_rounded
                          : Icons.copy_rounded,
                      size: 20,
                    ),
                    label: Text(text.copyRules),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutingDisclosure extends StatefulWidget {
  const _RoutingDisclosure({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.tilePadding,
    this.childrenPadding,
    this.expandedCrossAxisAlignment,
    this.trailingAction,
  });

  final Widget title;
  final Widget? subtitle;
  final List<Widget> children;
  final EdgeInsetsGeometry? tilePadding, childrenPadding;
  final CrossAxisAlignment? expandedCrossAxisAlignment;
  final Widget? trailingAction;

  @override
  State<_RoutingDisclosure> createState() => _RoutingDisclosureState();
}

class _RoutingDisclosureState extends State<_RoutingDisclosure> {
  bool _expanded = false;
  int _expansionEpoch = 0;

  @override
  Widget build(BuildContext context) {
    // Like settings help, disclosure state belongs only to the visible route.
    // Reset ExpansionTile's own state too, rather than merely its chevron.
    if ((ModalRoute.isCurrentOf(context) == false || !TickerMode.of(context)) &&
        _expanded) {
      _expanded = false;
      _expansionEpoch++;
    }
    return ExpansionTile(
      key: ValueKey(_expansionEpoch),
      initiallyExpanded: false,
      title: widget.title,
      subtitle: widget.subtitle,
      tilePadding: widget.tilePadding,
      childrenPadding: widget.childrenPadding,
      expandedCrossAxisAlignment: widget.expandedCrossAxisAlignment,
      onExpansionChanged: (value) => setState(() => _expanded = value),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.trailingAction != null) widget.trailingAction!,
          ExcludeSemantics(
            child: AnimatedRotation(
              turns: _expanded ? .25 : 0,
              duration: Duration(
                milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 180,
              ),
              child: const Icon(Icons.chevron_right_rounded, size: 20),
            ),
          ),
        ],
      ),
      children: widget.children,
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Text(
    message,
    style: TextStyle(color: Theme.of(context).colorScheme.error),
  );
}

class _RoutingExportPage extends StatefulWidget {
  const _RoutingExportPage({
    required this.plan,
    required this.selection,
    required this.previousDomains,
  });
  final RoutingPlan plan;
  final Set<String> selection;
  final Map<String, List<String>> previousDomains;
  @override
  State<_RoutingExportPage> createState() => _RoutingExportPageState();
}

class _RoutingExportPageState extends State<_RoutingExportPage> {
  String? _copy, _message, _fileName;
  bool _busy = false, _saved = false;

  Future<void> _choose() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      // No extension filter: .conf has inconsistent UTType mappings on iOS.
      // Validate the contents instead, without reading an unbounded file.
      final file = await openFile();
      if (file == null) return;
      if (mounted) {
        setState(() {
          _copy = null;
          _fileName = null;
          _saved = false;
        });
      }
      if (await file.length() > 2 * 1024 * 1024) {
        if (mounted) setState(() => _message = t.routingRules.tooLarge);
        return;
      }
      final original = utf8.decode(await file.readAsBytes());
      final copy = mergeSelectedRoutingRules(
        original,
        widget.plan,
        widget.selection,
        previousDomains: widget.previousDomains,
      );
      if (mounted) {
        setState(() {
          _copy = copy;
          _fileName = file.name;
          _saved = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _message = t.routingRules.invalidConfig);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_copy == null || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final saved = await saveRoutingConfigCopy(
        _copy!,
        dark: Theme.of(context).brightness == Brightness.dark,
      );
      if (mounted) {
        setState(() {
          _saved = saved;
          _message = saved
              ? t.routingRules.copySaved
              : t.routingRules.saveCancelled;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _message = t.routingRules.exportFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = t.routingRules;
    return PopScope(
      canPop: !_busy,
      child: SettingPageShell(
        title: text.prepareTitle,
        child: SafeArea(
          top: false,
          child: ListView(
            padding: kSettingPagePadding,
            children: [
              Text(
                text.prepareIntro,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _Hint(text.confFormatHint),
              const SizedBox(height: 20),
              _RoutingDisclosure(
                tilePadding: EdgeInsets.zero,
                title: Text(text.shadowrocketExample),
                childrenPadding: const EdgeInsets.only(bottom: 16),
                children: [_Hint(text.stepOne)],
              ),
              if (_copy != null) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.task_alt_rounded),
                  title: Text(text.configReady),
                  subtitle: Text(_fileName ?? ""),
                ),
                _Hint(text.configPreserved),
                const SizedBox(height: 12),
                _Hint(text.configPrivate),
              ],
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    _message!,
                    style: TextStyle(
                      color: _saved
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              if (_busy) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
                _Hint(text.busy),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: FilledButton(
                  onPressed: _busy
                      ? null
                      : _saved
                      ? () => Navigator.of(context).pop()
                      : _copy == null
                      ? _choose
                      : _save,
                  child: Text(
                    _saved
                        ? t.common.done
                        : _copy == null
                        ? text.chooseConfig
                        : text.saveCopy,
                  ),
                ),
              ),
              if (_copy != null)
                TextButton(
                  onPressed: _busy ? null : _choose,
                  child: Text(text.chooseAnother),
                ),
              _Hint(text.profileRetention),
              const SizedBox(height: 12),
              if (_saved) ...[
                Text(
                  text.applyHelp,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(text.stepThree),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Text(
    value,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
          children[i],
        ],
      ],
    ),
  );
}
