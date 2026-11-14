import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/bika_access_lines.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/util/json/json_value.dart';

/// Both first entry and settings use this exact check/select flow.
class BikaAccessLinesPage extends StatefulWidget {
  const BikaAccessLinesPage({
    super.key,
    required this.source,
    this.call = callBikaAccessLines,
    this.onSelected,
    this.trailing,
  });
  final String source;
  final BikaLineCall call;
  final VoidCallback? onSelected;
  final Widget? trailing;
  @override
  State<BikaAccessLinesPage> createState() => _BikaAccessLinesPageState();
}

class _BikaAccessLinesPageState extends State<BikaAccessLinesPage> {
  String _run = '', _snapshot = '', _current = '', _error = '';
  String _failedBase = '', _savingBase = '';
  bool _cancelled = false;
  List<BikaAccessLine> _lines = [];
  bool _checking = true, _saving = false;
  int _epoch = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  @override
  void dispose() {
    _epoch++;
    if (_run.isNotEmpty) unawaited(_cancel(_run));
    super.dispose();
  }

  Future<void> _cancel(String run) async {
    try {
      await widget.call(widget.source, 'cancelBikaAccessLineCheck', {
        'runId': run,
      });
    } catch (_) {}
  }

  String _text(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  String _failureDetails(Map<String, dynamic> result) {
    final diagnostic = asJsonMap(result['diagnostics']);
    final discovery = asJsonList(diagnostic['discovery']).map(asJsonMap);
    final probes = asJsonList(diagnostic['probes']).map(asJsonMap);
    if (probes.any((row) => row['kind'] == 'transport') ||
        (diagnostic['candidateCount'] == 0 &&
            discovery.any((row) => row['kind'] == 'transport'))) {
      return _text(
        '线路连接未完成，请检查网络后重试。',
        'Could not connect. Check your network and try again.',
      );
    }
    if (probes.any((row) => row['kind'] == 'parse') ||
        discovery.any((row) => row['kind'] == 'parse')) {
      return _text(
        '线路服务响应异常，请稍后重新检测。',
        'The line service returned an unreadable response. Check again later.',
      );
    }
    if (probes.any((row) => row['kind'] == 'http') ||
        discovery.any((row) => row['kind'] == 'http')) {
      return _text(
        '线路暂时无法使用，请稍后重新检测。',
        'The lines are temporarily unavailable. Check again later.',
      );
    }
    return t.sourceShell.bikaAccessEmpty;
  }

  Future<void> _check() async {
    final epoch = ++_epoch;
    final previous = _run;
    final run = BikaAccessLines.nextRunId();
    _run = run;
    if (previous.isNotEmpty) unawaited(_cancel(previous));
    setState(() {
      _checking = true;
      _error = '';
      _failedBase = '';
      _cancelled = false;
      _lines = [];
    });
    try {
      final state = await widget.call(
        widget.source,
        'getBikaAccessLineState',
        {},
      );
      if (!mounted || epoch != _epoch) return;
      _current = state['selected'] == true
          ? state['base']?.toString() ?? ''
          : '';
      final result = await widget.call(widget.source, 'checkBikaAccessLines', {
        'runId': run,
      });
      if (!mounted || epoch != _epoch) return;
      if (result['ok'] != true) throw StateError('Check cancelled');
      setState(() {
        _snapshot = result['snapshot']?.toString() ?? '';
        _lines = asJsonList(
          result['lines'],
        ).map(BikaAccessLine.fromJson).whereType<BikaAccessLine>().toList();
        _checking = false;
        if (_lines.isEmpty) _error = _failureDetails(result);
      });
    } catch (_) {
      if (mounted && epoch == _epoch)
        setState(() {
          _checking = false;
          _error = t.sourceShell.bikaAccessFailed;
        });
    }
  }

  void _stop() {
    _epoch++;
    unawaited(_cancel(_run));
    setState(() {
      _checking = false;
      _cancelled = true;
      _error = t.sourceShell.bikaAccessCancelled;
    });
  }

  Future<void> _select(BikaAccessLine line) async {
    if (_checking || _saving) return;
    final epoch = _epoch;
    setState(() {
      _saving = true;
      _savingBase = line.base;
      _failedBase = '';
      _error = '';
    });
    try {
      final result = await widget.call(widget.source, 'selectBikaAccessLine', {
        'base': line.base,
        'runId': _run,
        'snapshot': _snapshot,
      });
      if (!mounted || epoch != _epoch) return;
      if (result['ok'] != true) {
        setState(() {
          _failedBase = line.base;
          _error = result['reason'] == 'changed'
              ? t.sourceShell.bikaAccessChanged
              : t.sourceShell.bikaAccessSaveFailed;
        });
        return;
      }
      setState(() => _current = line.base);
      BikaAccessLines.selected();
      if (widget.onSelected != null) {
        widget.onSelected!();
      } else {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted && epoch == _epoch)
        setState(() {
          _failedBase = line.base;
          _error = t.sourceShell.bikaAccessSaveFailed;
        });
    } finally {
      if (mounted && epoch == _epoch) setState(() => _saving = false);
    }
  }

  Widget _lineCard(BuildContext context, BikaAccessLine line, int index) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final current = line.base == _current;
    final failed = line.base == _failedBase;
    final saving = _saving && line.base == _savingBase;
    final accent = failed ? colors.error : colors.primary;
    final title = _text('可用节点 ${index + 1}', 'Available node ${index + 1}');
    return Semantics(
      container: true,
      selected: current,
      child: Container(
        key: ValueKey('bika-access-card-${line.host}'),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: current
              ? colors.primaryContainer.withValues(alpha: .35)
              : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: failed || current ? accent : colors.outlineVariant,
            width: failed || current ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 10),
                  child: Icon(
                    failed
                        ? Icons.error_outline
                        : current
                        ? Icons.check_circle_outline
                        : Icons.wifi_rounded,
                    color: accent,
                    size: 24,
                  ),
                ),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              line.host,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  t.sourceShell.bikaAccessLatency(ms: line.elapsedMs),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  failed
                      ? _text('选择失败', 'Selection failed')
                      : current
                      ? t.sourceShell.bikaAccessCurrent
                      : _text('连接正常', 'Reachable'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: failed ? colors.error : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: ValueKey('bika-access-${line.host}'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onPressed: _saving ? null : () => unawaited(_select(line)),
                child: Text(
                  saving
                      ? _text('正在使用此节点…', 'Connecting…')
                      : current
                      ? _text('继续使用', 'Continue')
                      : _text('选择此节点', 'Choose this node'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SourceExperienceBoundary(
    source: widget.source,
    builder: (context) {
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      final animate =
          TickerMode.of(context) && !MediaQuery.disableAnimationsOf(context);
      return PopScope(
        canPop: !_saving,
        child: Scaffold(
          appBar: AppBar(
            leading: _saving
                ? const SizedBox.shrink()
                : const SourceBackButton(),
            title: Text(t.sourceShell.bikaAccessLines),
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              key: const PageStorageKey('bika-access-lines'),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                if (widget.onSelected != null) ...[
                  Text(t.sourceShell.bikaFirstLineNotice),
                  const SizedBox(height: 12),
                ],
                BikaAccessLineArtwork(checking: _checking),
                const SizedBox(height: 12),
                Text(
                  _checking
                      ? t.sourceShell.bikaAccessChecking
                      : _cancelled
                      ? t.sourceShell.bikaAccessCancelled
                      : _lines.isEmpty
                      ? _text('暂时没有可用节点', 'No available nodes')
                      : t.sourceShell.bikaAccessChoose,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _checking
                      ? _text(
                          '正在检查连接，请稍候。',
                          'Checking connections. Please wait.',
                        )
                      : _lines.isEmpty
                      ? _text('重新检测后即可选择节点。', 'Check again to choose a node.')
                      : _text(
                          '选择后会记住此节点，可在设置中更换。',
                          'Your choice is remembered. You can change it in settings.',
                        ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                if (_checking)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: animate
                        ? const LinearProgressIndicator(
                            key: ValueKey('bika-access-check-progress'),
                          )
                        : const Icon(Icons.wifi_find_rounded),
                  ),
                for (var index = 0; index < _lines.length; index++)
                  _lineCard(context, _lines[index], index),
                if (_error.isNotEmpty && !_cancelled)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.error,
                        ),
                      ),
                    ),
                  ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onPressed: _saving
                      ? null
                      : _checking
                      ? _stop
                      : _check,
                  child: Text(
                    _checking
                        ? t.common.cancel
                        : t.sourceShell.bikaAccessCheckAgain,
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(height: 24),
                  widget.trailing!,
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Keeps the existing ten-frame GIF during checks. The completed character
/// gets a short wave/float, then rests; no background polling or endless idle loop.
class BikaAccessLineArtwork extends StatefulWidget {
  const BikaAccessLineArtwork({super.key, required this.checking});
  final bool checking;
  @override
  State<BikaAccessLineArtwork> createState() => _BikaAccessLineArtworkState();
}

class _BikaAccessLineArtworkState extends State<BikaAccessLineArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  Timer? _restTimer;
  bool _settledMotionPlayed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateMotion();
  }

  @override
  void didUpdateWidget(BikaAccessLineArtwork old) {
    super.didUpdateWidget(old);
    if (old.checking != widget.checking) _settledMotionPlayed = false;
    _updateMotion();
  }

  void _updateMotion() {
    final active =
        TickerMode.of(context) && !MediaQuery.disableAnimationsOf(context);
    if (!active) {
      _restTimer?.cancel();
      _controller.stop();
      _controller.value = 0;
    } else if (widget.checking) {
      _restTimer?.cancel();
      if (!_controller.isAnimating) _controller.repeat();
    } else if (!_settledMotionPlayed) {
      _settledMotionPlayed = true;
      _controller.repeat();
      // Two gentle cycles after detection, with no perpetual idle ticker.
      _restTimer = Timer(const Duration(seconds: 8), () {
        _controller.stop();
        _controller.value = 0;
      });
    }
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: 176,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          // The original GIF is 85x85. Reuse the existing 486x700 artwork
          // at its established contain size; the wave still conveys checking.
          child: Image.asset(
            'asset/image/bika_experience/pica_splash_2_5.png',
            height: 158,
            fit: BoxFit.contain,
            cacheHeight: (158 * MediaQuery.devicePixelRatioOf(context))
                .round()
                .clamp(1, 700)
                .toInt(),
          ),
          builder: (context, child) {
            final color = Theme.of(context).colorScheme.primary;
            return Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    key: const ValueKey('bika-access-wave'),
                    painter: _BikaWavePainter(_controller.value, color),
                  ),
                ),
                Transform.translate(
                  offset: Offset(
                    0,
                    math.sin(_controller.value * math.pi * 2) * 3,
                  ),
                  child: child,
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _BikaWavePainter extends CustomPainter {
  const _BikaWavePainter(this.phase, this.color);
  final double phase;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    for (var layer = 0; layer < 2; layer++) {
      final path = Path()..moveTo(0, size.height);
      for (var x = 0.0; x <= size.width; x += 4) {
        path.lineTo(
          x,
          size.height * .78 +
              math.sin(
                    x / math.max(size.width, 1) * math.pi * 2 +
                        phase * math.pi * 2 +
                        layer * math.pi / 2,
                  ) *
                  (8 + layer * 3),
        );
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = color.withValues(alpha: layer == 0 ? .08 : .12),
      );
    }
  }

  @override
  bool shouldRepaint(_BikaWavePainter old) =>
      old.phase != phase || old.color != color;
}

/// Defers construction of account/content consumers until first selection.
class BikaAccessLineGate extends StatefulWidget {
  const BikaAccessLineGate({
    super.key,
    required this.source,
    required this.child,
    this.call = callBikaAccessLines,
  });
  final String source;
  final Widget child;
  final BikaLineCall call;
  @override
  State<BikaAccessLineGate> createState() => _BikaAccessLineGateState();
}

class _BikaAccessLineGateState extends State<BikaAccessLineGate> {
  bool? _ready;
  bool _stateFailed = false;
  int _epoch = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(BikaAccessLineGate old) {
    super.didUpdateWidget(old);
    if (old.source != widget.source) {
      _ready = null;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final epoch = ++_epoch;
    setState(() {
      _stateFailed = false;
      _ready = null;
    });
    try {
      final result = await widget.call(
        widget.source,
        'getBikaAccessLineState',
        {},
      );
      if (result['ok'] == false || result['selected'] is! bool)
        throw StateError('Route state unavailable');
      if (mounted && epoch == _epoch)
        setState(() => _ready = result['selected'] == true);
    } catch (_) {
      if (mounted && epoch == _epoch) setState(() => _stateFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) => _ready == true
      ? widget.child
      : _ready == null
      ? Scaffold(
          appBar: AppBar(
            leading: const SourceBackButton(),
            title: Text(t.sourceShell.bikaAccessLines),
          ),
          body: Center(
            child: _stateFailed
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t.sourceShell.bikaLineStateFailed),
                      TextButton(onPressed: _load, child: Text(t.common.retry)),
                    ],
                  )
                : const CircularProgressIndicator(),
          ),
        )
      : BikaAccessLinesPage(
          source: widget.source,
          call: widget.call,
          onSelected: () => setState(() => _ready = true),
        );
}
