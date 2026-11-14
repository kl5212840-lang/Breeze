import 'dart:async';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widget_previews.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search/widget/search_field_decoration.dart';
import 'package:zephyr/page/search/widget/search_keyboard.dart';
import 'package:zephyr/page/search/widget/search_tool_glyph.dart';

class SearchQueryField extends StatefulWidget {
  const SearchQueryField({
    super.key,
    required this.query,
    this.queryRevision = 0,
    this.onSubmitted,
    this.onChanged,
    this.onTap,
    this.onClear,
    this.autoExpand = false,
    this.hintText,
    this.semanticLabel,
    this.focusNode,
    this.closeOnSubmit = true,
    this.inline = false,
    this.showSubmit = false,
    this.leadingControl,
    this.leadingControlWidth = 44,
  });

  final String query;
  final int queryRevision;
  final FutureOr<void> Function(String query)? onSubmitted;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final bool autoExpand;
  final String? hintText;
  final String? semanticLabel;

  /// Dedicated search pages edit in place; compact entries may open an overlay.
  final bool inline, showSubmit;
  final Widget? leadingControl;
  final double leadingControlWidth;

  /// 外部传入的焦点节点。提供后父级可主动聚焦/失焦（如弹窗关闭后恢复键盘）；
  /// 不提供则内部自建自管。
  final FocusNode? focusNode;

  /// 提交（回车）后是否收起浮层。搜索页保持默认 true；
  /// 书架这种希望回车后继续改词的场景传 false。
  final bool closeOnSubmit;

  @override
  State<SearchQueryField> createState() => _SearchQueryFieldState();
}

class _SearchQueryFieldState extends State<SearchQueryField>
    with WidgetsBindingObserver, AutoRouteAwareStateMixin<SearchQueryField> {
  final _targetKey = GlobalKey();
  late final TextEditingController _controller;
  FocusNode? _internalFocusNode;

  /// 外部节点优先，兼顾节点替换：widget.focusNode 变化时下次访问自动切换，
  /// 内部节点只在真正使用过时才创建、dispose 时只释放内部节点。
  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());
  OverlayEntry? _overlayEntry;
  OverlayState? _overlayState;
  Timer? _autoExpandFallbackTimer;
  bool _isExpanded = false;

  /// 最近一次读到的所在 tab 是否活跃。切 tab 时本页不卸载、
  /// 收不到路由回调：桌面端 IndexedStack 只翻转 Visibility
  /// （见 SDK IndexedStack 的 _VisibilityScope），移动端 tab 则被
  /// Offstage 藏起并关掉 TickerMode。任一变假都算切走；
  /// null 表示还没读到过。
  bool? _lastTabActive;

  /// 新路由盖住本页时焦点被抢走（如搜索页输入框 autofocus），
  /// 失焦即收起浮层，否则返回后旧浮层悬在新页上层。
  /// 书架回车（closeOnSubmit=false）焦点不动，不受影响。
  FocusNode? _listenedFocusNode;
  VoidCallback? _focusLossListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = TextEditingController(text: widget.query);
    if (widget.autoExpand) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _prepareAutoExpand();
      });
    }
  }

  /// Sources can use plain Navigator routes inside the application's router.
  /// Subscribe only when BOTH scopes exist; a router observer alone doesn't
  /// make a MaterialPageRoute an AutoRoutePage.
  @override
  void didChangeDependencies() {
    if (context.findAncestorWidgetOfExactType<RouteDataScope>() != null &&
        context.findAncestorWidgetOfExactType<RouterScope>() != null) {
      super.didChangeDependencies();
    }
    // 切 tab 时本页不卸载、收不到路由回调：桌面端 IndexedStack 翻转
    // Visibility，移动端 Offstage 关掉 TickerMode。任一变假都算切走，
    // 此时收起浮层并失焦。切回时不自动重开，等用户再点搜索框。
    final tabActive =
        TickerMode.valuesOf(context).enabled && Visibility.of(context);
    if (_lastTabActive == true && !tabActive) {
      _cancelPendingExpand();
      _hideOverlay();
      if (widget.inline) _focusNode.unfocus();
    }
    _lastTabActive = tabActive;
  }

  @override
  void didUpdateWidget(covariant SearchQueryField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isExpanded &&
        (oldWidget.query != widget.query ||
            oldWidget.queryRevision != widget.queryRevision)) {
      _setControllerText(widget.query);
    }
    if (!oldWidget.autoExpand && widget.autoExpand) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _prepareAutoExpand();
      });
    }
  }

  /// 浮层打开时监听文本框失焦：被新路由抢走焦点即收起。
  /// 用 listener 而不用 Focus 包一层——Focus 会新建 scope 并把
  /// 同一个 FocusNode 当子节点挂进去，框架断言 child != parent 直接炸。
  void _watchFocusLoss() {
    final node = _focusNode;
    if (_listenedFocusNode == node) {
      return;
    }
    _unwatchFocusLoss();
    _listenedFocusNode = node;
    _focusLossListener = () {
      if (!node.hasFocus && _isExpanded && mounted) {
        // 失焦可能是焦点树整体拆掉（如路由 pop 过程中的 unfocus），
        // 直接 dismiss 会在 frame 回调里二次触焦点导致断言；
        // 排到下一帧，真切页才收，假抖动回来还展开着。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_isExpanded || _focusNode.hasFocus) {
            return;
          }
          _dismissOverlay();
        });
      }
    };
    node.addListener(_focusLossListener!);
  }

  void _unwatchFocusLoss() {
    final node = _listenedFocusNode;
    final listener = _focusLossListener;
    _listenedFocusNode = null;
    _focusLossListener = null;
    if (node != null && listener != null) {
      node.removeListener(listener);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelPendingExpand();
    _removeOverlay();
    _unwatchFocusLoss();
    _controller.dispose();
    _internalFocusNode?.dispose();
    _internalFocusNode = null;
    super.dispose();
  }

  void _setControllerText(String value) {
    if (_controller.text == value) {
      return;
    }
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  Animation<double>? _routeAnimation;
  AnimationStatusListener? _routeAnimationListener;

  void _cancelPendingExpand() {
    _autoExpandFallbackTimer?.cancel();
    _autoExpandFallbackTimer = null;
    if (_routeAnimation != null && _routeAnimationListener != null) {
      _routeAnimation!.removeStatusListener(_routeAnimationListener!);
      _routeAnimation = null;
      _routeAnimationListener = null;
    }
  }

  void _prepareAutoExpand() {
    if (!mounted ||
        !widget.autoExpand ||
        widget.onTap != null ||
        _isExpanded ||
        _lastTabActive == false) {
      return;
    }
    final route = ModalRoute.of(context);
    final animation = route is PageRoute ? route.animation : null;
    if (animation == null || animation.isCompleted) {
      _openOverlayWhenReady();
      return;
    }

    _routeAnimation = animation;
    _routeAnimationListener = (status) {
      if (status != AnimationStatus.completed ||
          !mounted ||
          _lastTabActive == false) {
        return;
      }
      animation.removeStatusListener(_routeAnimationListener!);
      _routeAnimation = null;
      _routeAnimationListener = null;
      _openOverlayWhenReady();
    };
    animation.addStatusListener(_routeAnimationListener!);

    // A route can finish between the isCompleted check and addStatusListener.
    // Keep the original post-transition behavior, but do not leave the field
    // collapsed if that status change was missed by the listener.
    _autoExpandFallbackTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted || _isExpanded || _lastTabActive == false) {
        return;
      }
      animation.removeStatusListener(_routeAnimationListener!);
      _routeAnimation = null;
      _routeAnimationListener = null;
      _openOverlayWhenReady();
    });
  }

  @override
  void didPushNext() {
    super.didPushNext();
    // 被新路由盖住（push 输入页）：收起浮层，不向父级回写。
    // 浮层挂 tab 内 Overlay 时新页盖住它不可见，但返回时旧浮层还在；
    // 不收的话回来就悬在新页上层。提交已在 push 前写过 cubit，
    // 回写只会把残留半截输入经防抖盖回去。
    _cancelPendingExpand();
    _hideOverlay();
    if (widget.inline) _focusNode.unfocus();
  }

  @override
  void didPop() {
    super.didPop();
    // 本页自己被 pop（如搜索页返回键）：收起浮层。
    // dispose 要等转场结束才跑，不手动关会有残留帧。
    _cancelPendingExpand();
    _hideOverlay();
    if (widget.inline) _focusNode.unfocus();
  }

  @override
  void didPopNext() {
    super.didPopNext();
    // A dialog returning over a dedicated input page must not summon the
    // keyboard while the user is managing history. Inline inputs focus once
    // on entry, then follow explicit taps and the normal focus lifecycle.
    if (!widget.autoExpand || widget.inline) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lastTabActive == false) {
        return;
      }
      _prepareAutoExpand();
    });
  }

  void _openOverlayWhenReady() {
    if (!mounted || _isExpanded || _lastTabActive == false) {
      return;
    }
    if (widget.inline) {
      _cancelPendingExpand();
      _requestKeyboard();
      return;
    }
    if (_targetRenderBox == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openOverlayWhenReady();
      });
      return;
    }
    _autoExpandFallbackTimer?.cancel();
    _autoExpandFallbackTimer = null;
    _openOverlay();
  }

  void _openOverlay() {
    if (_isExpanded || _lastTabActive == false) {
      return;
    }
    // 点框重开浮层时以外部 query 对齐：展开期间 didUpdateWidget 故意不同步
    // controller，点历史等方式提交后 controller 会落后；重开时补对齐一次。
    // 初次 autoExpand 是 no-op。
    _setControllerText(widget.query);
    _overlayState = Overlay.of(context, rootOverlay: false);
    setState(() {
      _isExpanded = true;
    });
    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    _overlayState!.insert(_overlayEntry!);
    _watchFocusLoss();
    _requestKeyboard();
  }

  void _requestKeyboard() => requestSearchKeyboard(
    _focusNode,
    isCurrent: () =>
        mounted &&
        _lastTabActive != false &&
        (widget.inline || _isExpanded) &&
        ModalRoute.of(context)?.isCurrent != false,
  );

  void _removeOverlay() {
    _unwatchFocusLoss();
    _focusNode.unfocus();
    _overlayEntry?.remove();
    _overlayEntry = null;
    _overlayState = null;
    _isExpanded = false;
  }

  /// 只收视觉浮层，不向父级回写。路由切换（didPushNext/didPop）用：
  /// 提交已在 push 前把 cubit 写成新词，回写只会把残留旧词排上防抖、
  /// 返回后盖掉新词。
  void _hideOverlay() {
    if (!_isExpanded) {
      return;
    }
    _removeOverlay();
    if (mounted) {
      setState(() {});
    }
  }

  RenderBox? get _targetRenderBox {
    final renderObject = _targetKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject;
    }
    return null;
  }

  @override
  void didChangeMetrics() {
    _overlayEntry?.markNeedsBuild();
  }

  Widget _buildOverlay(BuildContext context) {
    // 所在 tab 切走后 State 的 didChangeDependencies 不一定再跑，
    // 但 overlay entry 的 builder 在重建时会重跑；看到 tab 不活跃
    // 就排队收起并返回空占位，不再把输入框画到别的 tab 上层。
    if (_lastTabActive == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _cancelPendingExpand();
          _hideOverlay();
        }
      });
      return const SizedBox.shrink();
    }
    final target = _targetRenderBox;
    final overlayRenderObject = _overlayState?.context.findRenderObject();
    if (target == null ||
        overlayRenderObject is! RenderBox ||
        !overlayRenderObject.hasSize) {
      return const SizedBox.shrink();
    }

    final targetOffset =
        target.localToGlobal(Offset.zero) -
        overlayRenderObject.localToGlobal(Offset.zero);
    final overlaySize = overlayRenderObject.size;
    // Keep the expanded field at its intended width. During a route/keyboard
    // transition the target can briefly report a position near the right edge;
    // shrinking to the remaining space made its row overflow on iPhone.
    final width = math.max(
      1.0,
      math.min(target.size.width, overlaySize.width - 16.0),
    );
    final maxLeft = math.max(8.0, overlaySize.width - width - 8.0);
    final left = targetOffset.dx.clamp(8.0, maxLeft).toDouble();
    final top = targetOffset.dy.clamp(0.0, overlaySize.height).toDouble();
    final maxHeight = math.max(1.0, overlaySize.height - top - 8.0);

    return Positioned(
      left: left,
      top: top,
      width: width,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          clipBehavior: Clip.none,
          child: _buildExpandedField(context),
        ),
      ),
    );
  }

  void _closeOverlay() {
    if (!_isExpanded) {
      return;
    }
    widget.onChanged?.call(_controller.text);
    _removeOverlay();
    if (mounted) {
      setState(() {});
    }
  }

  /// 用户主动关浮层（点 ×/关闭、点外部）：同时取消待触发的 autoExpand，
  /// 否则 600ms 兜底定时器会在路由动画后把浮层又弹出来。
  void _dismissOverlay() {
    _cancelPendingExpand();
    _closeOverlay();
  }

  void _submit() {
    final query = _controller.text;
    _cancelPendingExpand();
    if (widget.closeOnSubmit) {
      _removeOverlay();
      if (mounted) {
        setState(() {});
      }
    } else {
      // 保持展开：只刷新浮层内的清空/关闭按钮状态，焦点不动，键盘不收。
      _overlayEntry?.markNeedsBuild();
    }
    widget.onSubmitted?.call(query);
  }

  void _clear() {
    if (_controller.text.isEmpty) {
      return;
    }
    _controller.clear();
    // 清空也是关键词变化，同步给父级，否则列表还按旧词过滤。
    widget.onChanged?.call('');
    widget.onClear?.call();
    _overlayEntry?.markNeedsBuild();
  }

  Widget _buildCollapsedField(BuildContext context) {
    final isEmpty = widget.query.isEmpty;
    return Semantics(
      button: true,
      label: widget.semanticLabel ?? widget.hintText ?? t.search.title,
      child: SearchFieldSurface(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap ?? _openOverlay,
            borderRadius: searchFieldRadius(context),
            child: InputDecorator(
              isEmpty: isEmpty,
              decoration: searchFieldDecoration(
                context,
                hintText: widget.hintText ?? t.search.searchHint,
                suffixIcon: !isEmpty && widget.onClear != null
                    ? IconButton(
                        tooltip: t.common.clear,
                        onPressed: widget.onClear,
                        icon: const SearchToolGlyph(SearchTool.clear, size: 20),
                      )
                    : null,
              ),
              child: Text(
                isEmpty ? '' : widget.query,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedField(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;
    return TextFieldTapRegion(
      // Selection handles and the editing menu remain inside the field group.
      onTapOutside: (_) => _dismissOverlay(),
      child: Material(
        color: Colors.transparent,
        child: SearchFieldSurface(
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onTapAlwaysCalled: true,
            onTap: _requestKeyboard,
            autofocus: true,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.search,
            minLines: 1,
            maxLines: usesSystemSearchSurface(context) ? 1 : 6,
            inputFormatters: [FilteringTextInputFormatter.singleLineFormatter],
            textAlignVertical: TextAlignVertical.center,
            onChanged: (value) {
              widget.onChanged?.call(value);
              _overlayEntry?.markNeedsBuild();
            },
            onSubmitted: (_) => _submit(),
            decoration: searchFieldDecoration(
              context,
              hintText: widget.hintText ?? t.search.searchHint,
              prefixIcon: IconButton(
                tooltip: t.search.title,
                onPressed: hasText ? _submit : null,
                icon: const SearchToolGlyph(SearchTool.search, size: 22),
              ),
              suffixIcon: IconButton(
                tooltip: hasText ? t.common.clear : t.common.close,
                icon: SearchToolGlyph(
                  hasText ? SearchTool.clear : SearchTool.close,
                  size: 20,
                ),
                onPressed: hasText ? _clear : _dismissOverlay,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.inline) {
      final leading = widget.leadingControl;
      final field = SearchFieldSurface(
        child: TextField(
          key: _targetKey,
          controller: _controller,
          focusNode: _focusNode,
          onTapAlwaysCalled: true,
          onTap: () {
            widget.onTap?.call();
            _requestKeyboard();
          },
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.search,
          textAlignVertical: TextAlignVertical.center,
          inputFormatters: [FilteringTextInputFormatter.singleLineFormatter],
          decoration: searchFieldDecoration(
            context,
            hintText: widget.hintText ?? t.search.searchHint,
            prefixIcon: leading != null
                ? SizedBox(width: widget.leadingControlWidth, height: 48)
                : widget.showSubmit
                ? ValueListenableBuilder(
                    valueListenable: _controller,
                    builder: (_, value, _) => IconButton(
                      tooltip: t.videoSearch.submit,
                      icon: const SearchToolGlyph(SearchTool.search, size: 20),
                      onPressed: value.text.trim().isEmpty
                          ? null
                          : () => widget.onSubmitted?.call(_controller.text),
                    ),
                  )
                : null,
            suffixIcon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (_, value, _) => value.text.isEmpty
                  ? const SizedBox(width: 44)
                  : IconButton(
                      tooltip: t.common.clear,
                      onPressed: _clear,
                      icon: const SearchToolGlyph(SearchTool.clear, size: 20),
                    ),
            ),
          ),
          onChanged: widget.onChanged,
          onSubmitted: (value) => widget.onSubmitted?.call(value),
        ),
      );
      if (leading == null) return field;
      return Stack(
        children: [
          field,
          // An interactive native control belongs outside the editor's clip.
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            width: widget.leadingControlWidth,
            child: Center(child: leading),
          ),
        ],
      );
    }
    return SizedBox(key: _targetKey, child: _buildCollapsedField(context));
  }
}

@Preview(name: 'Search query field', group: 'Search')
Widget searchQueryFieldPreview() {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SearchQueryField(
            query: 'parody.chou kag...',
            hintText: 'Search...',
            onSubmitted: _previewNoop,
          ),
        ),
      ),
    ),
  );
}

void _previewNoop(String _) {}
