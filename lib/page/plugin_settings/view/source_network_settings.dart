import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/source_network_policy.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/network/routing_rules_page.dart';
import 'package:zephyr/widgets/toast.dart';

class SourceNetworkSettingsTile extends StatelessWidget {
  const SourceNetworkSettingsTile({
    super.key,
    required this.source,
    this.advanced = false,
  });
  final String source;
  final bool advanced;

  @override
  Widget build(BuildContext context) => !SourceNetworkPolicies.supports(source)
      ? const SizedBox.shrink()
      : TouchHoverIntent(
          identity: (source, advanced),
          builder: (context, hover) => ListTile(
            hoverColor: hover.hoverColor(),
            leading: const Icon(Icons.public_outlined),
            title: Text(advanced ? t.omoNetwork.title : t.routingRules.title),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                settings: RouteSettings(
                  name: advanced
                      ? 'breeze.source.network'
                      : 'breeze.routing.rules',
                ),
                builder: (_) => advanced
                    ? SourceNetworkSettingsPage(source: source)
                    : RoutingRulesPage(source: source),
              ),
            ),
          ),
        );
}

class SourceNetworkSettingsPage extends StatefulWidget {
  const SourceNetworkSettingsPage({
    super.key,
    required this.source,
    this.sourceName,
  });
  final String source;
  final String? sourceName;

  @override
  State<SourceNetworkSettingsPage> createState() =>
      _SourceNetworkSettingsPageState();
}

class _SourceNetworkSettingsPageState extends State<SourceNetworkSettingsPage> {
  final _address = TextEditingController();
  SourceNetworkMode _mode = SourceNetworkMode.inherit;
  bool _socks = false, _loading = true, _saving = false;
  String? _loadError, _saveError;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final value = await SourceNetworkPolicies.read(widget.source);
      if (!mounted) return;
      setState(() {
        _mode = value.mode;
        _socks = value.socks;
        _address.text = value.address;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadError = t.omoNetwork.readFailed;
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_loading || _saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await SourceNetworkPolicies.save(
        widget.source,
        SourceNetworkPreference(
          mode: _mode,
          address: _address.text,
          socks: _socks,
        ),
      );
      final actual = await SourceNetworkPolicies.read(widget.source);
      if (actual.mode != _mode ||
          actual.address != _address.text.trim() ||
          actual.socks != _socks) {
        throw StateError('Source network preference was not saved');
      }
      if (mounted) {
        showSuccessToast(t.omoNetwork.saved, context: context);
        Navigator.of(context).pop();
      }
    } on FormatException {
      if (mounted) setState(() => _saveError = t.omoNetwork.invalidAddress);
    } catch (_) {
      if (mounted) setState(() => _saveError = t.omoNetwork.saveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Widget _group(BuildContext context, Widget child) =>
      SettingSection(hasLeading: false, children: [child]);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SettingPageShell(
      title: t.omoNetwork.title,
      grouped: true,
      actions: [
        TextButton(
          onPressed: _loading || _saving || _loadError != null ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(t.common.save),
        ),
      ],
      child: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadError!),
                    TextButton(onPressed: _load, child: Text(t.common.retry)),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: 24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  if (widget.sourceName?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Text(
                        widget.sourceName!,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  _group(
                    context,
                    Column(
                      children: [
                        for (final mode in SourceNetworkMode.values) ...[
                          if (mode != SourceNetworkMode.values.first)
                            const Divider(height: 1, indent: 16, endIndent: 16),
                          TouchHoverIntent(
                            identity: (widget.source, mode),
                            builder: (context, hover) => ListTile(
                              hoverColor: hover.hoverColor(),
                              minTileHeight: 62,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              title: Text(switch (mode) {
                                SourceNetworkMode.inherit =>
                                  t.omoNetwork.inherit,
                                SourceNetworkMode.system => t.omoNetwork.system,
                                SourceNetworkMode.proxy => t.omoNetwork.proxy,
                              }),
                              subtitle: Text(switch (mode) {
                                SourceNetworkMode.inherit =>
                                  t.omoNetwork.inheritHint,
                                SourceNetworkMode.system =>
                                  t.omoNetwork.systemHint,
                                SourceNetworkMode.proxy =>
                                  t.omoNetwork.proxyHint,
                              }),
                              trailing: SizedBox(
                                width: 24,
                                child: _mode == mode
                                    ? Icon(
                                        Icons.check_rounded,
                                        color: colors.primary,
                                      )
                                    : null,
                              ),
                              selected: _mode == mode,
                              onTap: _saving
                                  ? null
                                  : () => setState(() {
                                      _mode = mode;
                                      _saveError = null;
                                    }),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_mode == SourceNetworkMode.proxy) ...[
                    _group(
                      context,
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(
                                  value: false,
                                  label: Text('HTTP'),
                                ),
                                ButtonSegment(
                                  value: true,
                                  label: Text('SOCKS5'),
                                ),
                              ],
                              selected: {_socks},
                              onSelectionChanged: _saving
                                  ? null
                                  : (value) =>
                                        setState(() => _socks = value.single),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              key: const ValueKey('source-network-address'),
                              controller: _address,
                              enabled: !_saving,
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.done,
                              autocorrect: false,
                              enableSuggestions: false,
                              decoration: InputDecoration(
                                labelText: t.omoNetwork.address,
                                hintText: '127.0.0.1:1082',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_saveError != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Text(
                        _saveError!,
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                    child: Text(
                      t.omoNetwork.applyHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  SettingDetailsNotes(
                    sectionTitle: t.omoNetwork.title,
                    details: {'': t.omoNetwork.scopeHint},
                  ),
                ],
              ),
      ),
    );
  }
}
