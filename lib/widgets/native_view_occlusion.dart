import 'package:cupertino_ui/cupertino_ui.dart' as ios;
import 'package:flutter/cupertino.dart' as flutter_ios;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

const _preserveDownloadComposition = bool.fromEnvironment(
  'BREEZE_DOWNLOAD_COMPOSITION_TRIAL',
  defaultValue: true,
);

bool _preserveDownloadUnderlay(
  Route<dynamic>? source,
  Route<dynamic>? destination,
) {
  if (!_preserveDownloadComposition ||
      defaultTargetPlatform != TargetPlatform.iOS) {
    return false;
  }
  final sourceName = source?.settings.name;
  final destinationName = destination?.settings.name;
  return sourceName == 'NavigationBar' &&
      (destinationName == 'breeze.download.settings' ||
          destinationName == 'breeze.download.video-work' ||
          destinationName == 'breeze.download.comic-chapters');
}

Map<String, Object?> _nativeAncestry(
  RenderUiKitView render, {
  String owner = 'unobserved',
}) {
  final clips = <Map<String, Object?>>[];
  var wrapped = false;
  var viewType = 'unobserved';
  final creator = render.debugCreator;
  if (creator is DebugCreator) {
    void inspect(Widget widget) {
      if (widget is UiKitView &&
          RegExp(r'^[A-Za-z0-9_.-]{1,120}$').hasMatch(widget.viewType)) {
        viewType = widget.viewType;
      }
    }

    inspect(creator.element.widget);
    creator.element.visitAncestorElements((element) {
      inspect(element.widget);
      return viewType == 'unobserved';
    });
  }
  RenderObject descendant = render;
  var ancestor = render.parent;
  for (var depth = 0; ancestor != null && depth < 128; depth++) {
    if (!wrapped && ancestor is _NativeViewPaintBox) {
      wrapped = true;
      owner = NativeCompositionObserver._routeCategory(
        ancestor.routes.firstOrNull,
      );
    }
    Clip? behavior;
    if (ancestor is RenderClipRRect) behavior = ancestor.clipBehavior;
    if (ancestor is RenderClipRSuperellipse) behavior = ancestor.clipBehavior;
    if (ancestor is RenderClipOval) behavior = ancestor.clipBehavior;
    if (ancestor is RenderClipPath) behavior = ancestor.clipBehavior;
    if (ancestor is RenderPhysicalModel) behavior = ancestor.clipBehavior;
    if (ancestor is RenderPhysicalShape) behavior = ancestor.clipBehavior;
    if (behavior != null && behavior != Clip.none && clips.length < 12) {
      final creator = ancestor.debugCreator;
      final record = <String, Object?>{
        'renderType': ancestor.runtimeType.toString(),
        'widgetType': creator is DebugCreator
            ? creator.element.widget.runtimeType.toString()
            : 'unavailable',
        'clipBehavior': behavior.name,
      };
      try {
        final local = ancestor.describeApproximatePaintClip(descendant);
        final rect = local == null
            ? null
            : MatrixUtils.transformRect(ancestor.getTransformTo(null), local);
        if (rect != null && rect.isFinite)
          record['rect'] = [rect.left, rect.top, rect.width, rect.height];
      } catch (_) {
        record['geometryUnavailable'] = true;
      }
      clips.add(record);
    }
    descendant = ancestor;
    ancestor = ancestor.parent;
  }
  return {
    'viewId': render.viewController.id,
    'ownerRoute': owner,
    'wrapped': wrapped,
    'viewType': viewType,
    'nonRectClips': clips,
  };
}

/// Tracks actual opaque pages, including a popping page until its last frame.
/// It never changes route animations, platform-view state or native materials.
class NativeCompositionObserver extends NavigatorObserver {
  NativeCompositionObserver({
    this.geometryBasedOcclusion = false,
    this.candidateRoutes = const {},
    this.candidateOpaqueDestinations = const {},
    this.diagnostics,
    int diagnosticBudget = 80,
  }) : _diagnosticBudget = diagnosticBudget.clamp(0, 256).toInt();
  // Explicitly bounded trials; no unreviewed route uses this mechanism.
  final Map<String, Set<String>> candidateRoutes;

  /// Explicit full-screen task destinations shared by arbitrary callers.
  /// This only admits a destination to the existing coverage checks: it must
  /// still be opaque, have a usable solid rectangle, and fully cover a control.
  /// Empty by default; unrelated and translucent routes retain their layers.
  final Set<String> candidateOpaqueDestinations;

  /// Use actual opaque page coverage across the owning Navigator hierarchy.
  /// Names remain available for bounded legacy fixtures, not app correctness.
  final bool geometryBasedOcclusion;

  /// Optional bounded, content-free observations. A sink must not mutate UI.
  /// No diagnostics are emitted unless a caller explicitly supplies this sink.
  final void Function(Map<String, Object?> sample)? diagnostics;
  int _diagnosticBudget;
  int _diagnosticEpoch = 0;
  int _sceneAuditEpoch = -1;
  final _sceneAuditPhases = <String>{};
  static final _owners = Expando<NativeCompositionObserver>();
  final _routes = <PageRoute<dynamic>>[];
  final _externalRoutes = <PageRoute<dynamic>>{};
  final _changes = _CompositionChanges();

  /// Shared, explicitly admitted tasks may be pushed inside a tab's ordinary
  /// Navigator, which does not inherit the root observer. Register only that
  /// destination with an existing ancestor observer; keep navigation ownership
  /// and native State unchanged. Route completion removes this registration.
  static void observeSharedDestination(
    BuildContext context,
    PageRoute<dynamic> destination,
  ) {
    var source = ModalRoute.of(context);
    final visited = <ModalRoute<dynamic>>{};
    while (source != null && visited.add(source)) {
      final owner = source.navigator;
      final observer = owner == null ? null : _owners[owner];
      if (observer != null &&
          (observer.geometryBasedOcclusion ||
              observer.candidateOpaqueDestinations.contains(
                destination.settings.name,
              ))) {
        observer._add(destination, claimOwner: false);
        return;
      }
      source = owner == null ? null : ModalRoute.of(owner.context);
    }
  }

  void _changed() {
    _changes.changed();
    if (diagnostics == null || _diagnosticBudget <= 0) return;
    if (_sceneAuditEpoch != _diagnosticEpoch) {
      _sceneAuditEpoch = _diagnosticEpoch;
      _sceneAuditPhases.clear();
    }
    final phase = _routes
        .map((route) => route.animation?.status.name ?? 'none')
        .join('|');
    if (_sceneAuditPhases.length >= 8 || !_sceneAuditPhases.add(phase)) return;
    final epoch = _diagnosticEpoch;
    void audit(Duration _, {bool followUp = false}) {
      if (epoch != _diagnosticEpoch || _diagnosticBudget <= 0) return;
      final mounted = <Map<String, Object?>>[];
      var mountedCount = 0;
      final painted = <int>{};
      final paintedGeometry = <Map<String, Object?>>[];
      void visitRender(RenderObject render) {
        if (render is RenderUiKitView) {
          mountedCount++;
          if (mounted.length < 128) {
            final ancestors = <RenderObject>{};
            RenderObject? current = render;
            while (current != null && ancestors.length < 256) {
              ancestors.add(current);
              current = current.parent;
            }
            final route = _routes.reversed
                .where(
                  (route) => ancestors.contains(
                    route.subtreeContext?.findRenderObject(),
                  ),
                )
                .firstOrNull;
            mounted.add(_nativeAncestry(render, owner: _routeCategory(route)));
          }
        }
        render.visitChildren(visitRender);
      }

      void visitLayer(Layer layer) {
        if (layer is PlatformViewLayer) {
          painted.add(layer.viewId);
          if (paintedGeometry.length < 128) {
            final ancestors = <Map<String, Object?>>[];
            var parent = layer.parent;
            for (var depth = 0; parent != null && depth < 48; depth++) {
              final clip = parent.describeClipBounds();
              final record = <String, Object?>{
                'type': parent.runtimeType.toString(),
              };
              if (parent is OffsetLayer)
                record['offset'] = [parent.offset.dx, parent.offset.dy];
              if (parent is TransformLayer) {
                final matrix = parent.transform?.storage;
                if (matrix != null && matrix.every((value) => value.isFinite))
                  record['transform'] = matrix.toList();
              }
              if (clip != null && clip.isFinite)
                record['clipRect'] = [
                  clip.left,
                  clip.top,
                  clip.width,
                  clip.height,
                ];
              if (record.length > 1) ancestors.add(record);
              parent = parent.parent;
            }
            final rect = layer.rect;
            paintedGeometry.add({
              'viewId': layer.viewId,
              'rect': [rect.left, rect.top, rect.width, rect.height],
              'ancestorLayers': ancestors,
            });
          }
        }
        if (layer is ContainerLayer) {
          var child = layer.firstChild;
          while (child != null) {
            visitLayer(child);
            child = child.nextSibling;
          }
        }
      }

      for (final view in WidgetsBinding.instance.renderViews) {
        visitRender(view);
        final layer = view.debugLayer;
        if (layer != null) visitLayer(layer);
      }
      final ids = painted.toList()..sort();
      _diagnose({
        'event': 'native-scene-audit',
        'sample': followUp ? 'after-platform-replies' : 'phase-frame',
        'routeEpoch': epoch,
        'phase': phase,
        'mounted': mounted,
        'mountedCount': mountedCount,
        'mountedTruncated': mountedCount > mounted.length,
        'paintedPlatformViews': ids.take(128).toList(),
        'paintedGeometry': paintedGeometry,
        'paintedCount': painted.length,
        'paintedTruncated': painted.length > 128,
      });
      // UiKitView creates its controller asynchronously. A phase's first
      // post-frame snapshot can precede that reply even when the route has
      // reached its final frame. Take one bounded subsequent rendered frame;
      // this is diagnostic-only and keeps the existing event budget.
      if (!followUp && epoch == _diagnosticEpoch && _diagnosticBudget > 0) {
        WidgetsBinding.instance.addPostFrameCallback(
          (time) => audit(time, followUp: true),
        );
        WidgetsBinding.instance.scheduleFrame();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback(audit);
  }

  static String _routeCategory(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name == null) return 'unnamed';
    if (name == '/') return 'root';
    return const {
          'NavigationBar',
          'DiscoverRoute',
          'PluginSettingsRoute',
          'SearchRoute',
          'SourceShellRoute',
          'SourceSettingsHubRoute',
          'GlobalSettingRoute',
          'AppearanceSettingRoute',
          'SyncSettingRoute',
          'breeze.routing.rules',
          'breeze.settings.cover-privacy',
          'breeze.image.editor',
          'breeze.video.bika-detail',
          'breeze.video.omo-detail',
          'breeze.video.library',
          'breeze.video.local',
          'breeze.video.local-history',
          'breeze.video.catalog-content',
          'breeze.video.playback-settings',
          'breeze.source.saved-accounts',
          'breeze.download.comic-chapters',
          'breeze.download.video-work',
          'breeze.download.settings',
        }.contains(name)
        ? name
        : 'other';
  }

  void _diagnose(Map<String, Object?> sample) {
    if (diagnostics == null || _diagnosticBudget <= 0) return;
    _diagnosticBudget--;
    try {
      diagnostics!(Map.unmodifiable(sample));
    } catch (_) {
      /* Observation cannot alter navigation. */
    }
  }

  void _add(Route<dynamic>? route, {int? index, bool claimOwner = true}) {
    if (route is! PageRoute<dynamic> || _routes.contains(route)) return;
    final owner = route.navigator;
    if (owner != null && claimOwner) _owners[owner] = this;
    _routes.insert(index ?? _routes.length, route);
    if (!claimOwner) _externalRoutes.add(route);
    route.animation?.addListener(_changed);
    route.secondaryAnimation?.addListener(_changed);
    route.completed.whenComplete(() => _remove(route));
    _diagnosticEpoch++;
    _diagnose({
      'event': 'route-added',
      'route': _routeCategory(route),
      'tracked': _routes.length,
    });
    _changed();
  }

  void _remove(Route<dynamic>? route) {
    if (route is! PageRoute<dynamic> || !_routes.remove(route)) return;
    _externalRoutes.remove(route);
    route.animation?.removeListener(_changed);
    route.secondaryAnimation?.removeListener(_changed);
    _diagnosticEpoch++;
    _diagnose({
      'event': 'route-removed',
      'route': _routeCategory(route),
      'tracked': _routes.length,
    });
    _changed();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _add(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute is PageRoute<dynamic>
        ? _routes.indexOf(oldRoute)
        : -1;
    _remove(oldRoute);
    _add(newRoute, index: index < 0 ? null : index);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _remove(route);
  }

  // didPop deliberately retains the route: its opaque page is still moving
  // above the source page, and a gesture may also reverse before any pop.
}

class _CompositionChanges extends ChangeNotifier {
  void changed() => notifyListeners();
}

/// Paint culling only for native controls that a later page completely covers.
/// The child stays mounted; visible controls and translucent dialogs paint as
/// usual. Partly covered controls remain an engine-composition boundary.
class NativeViewOcclusion extends StatelessWidget {
  const NativeViewOcclusion({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final routes = <ModalRoute<dynamic>>[];
    var route = ModalRoute.of(context);
    while (route != null && !routes.contains(route)) {
      routes.add(route);
      final navigator = route.navigator;
      route = navigator == null ? null : ModalRoute.of(navigator.context);
    }
    final observers = <NativeCompositionObserver>{};
    for (final route in routes) {
      final navigator = route.navigator;
      final observer = navigator == null
          ? null
          : NativeCompositionObserver._owners[navigator];
      if (observer != null) observers.add(observer);
    }
    if (observers.isEmpty) return child;
    return _NativeViewPaint(
      routes: routes,
      observers: observers.toList(),
      viewport: Offset.zero & MediaQuery.sizeOf(context),
      child: child,
    );
  }
}

class _NativeViewPaint extends SingleChildRenderObjectWidget {
  const _NativeViewPaint({
    required this.routes,
    required this.observers,
    required this.viewport,
    required super.child,
  });
  final List<ModalRoute<dynamic>> routes;
  final List<NativeCompositionObserver> observers;
  final Rect viewport;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _NativeViewPaintBox(routes, observers, viewport);

  @override
  void updateRenderObject(BuildContext context, _NativeViewPaintBox render) {
    render.update(routes, observers, viewport);
  }
}

class _NativeViewPaintBox extends RenderProxyBox {
  _NativeViewPaintBox(this.routes, this.observers, this.viewport);
  List<ModalRoute<dynamic>> routes;
  List<NativeCompositionObserver> observers;
  Rect viewport;
  String? _lastDiagnostic;
  String? _lastCoverageDiagnostic;
  int _diagnosticPaints = 0;

  void _diagnosePaint(
    String decision,
    Rect bounds, {
    Route<dynamic>? source,
    Route<dynamic>? cover,
    Rect? partlyVisibleRect,
    Rect? candidateRect,
  }) {
    if (!observers.any(
      (observer) =>
          observer.diagnostics != null && observer._diagnosticBudget > 0,
    )) {
      return;
    }
    _diagnosticPaints++;
    final ids = <int>[];
    final viewAncestry = <Map<String, Object?>>[];
    void visit(RenderObject render) {
      if (render is RenderUiKitView) {
        final id = render.viewController.id;
        ids.add(id);
        viewAncestry.add(_nativeAncestry(render));
      }
      render.visitChildren(visit);
    }

    if (child != null) visit(child!);
    final sourceCategory = NativeCompositionObserver._routeCategory(source);
    final coverCategory = NativeCompositionObserver._routeCategory(cover);
    final routeEpoch = [
      for (final observer in observers) observer._diagnosticEpoch,
    ];
    final signature =
        '$decision|$sourceCategory|$coverCategory|$ids|${viewport.size}|$routeEpoch|$partlyVisibleRect|$candidateRect|$viewAncestry';
    if (_lastDiagnostic == signature) return;
    _lastDiagnostic = signature;
    final sample = <String, Object?>{
      'event': 'control-paint',
      'decision': decision,
      'source': sourceCategory,
      'cover': coverCategory,
      'platformViews': ids,
      'platformViewAncestry': viewAncestry,
      'paintCount': _diagnosticPaints,
      'routeEpoch': routeEpoch,
      'bounds': [bounds.left, bounds.top, bounds.width, bounds.height],
      'viewport': [viewport.width, viewport.height],
      if (partlyVisibleRect != null)
        'partlyVisibleRect': [
          partlyVisibleRect.left,
          partlyVisibleRect.top,
          partlyVisibleRect.width,
          partlyVisibleRect.height,
        ],
      if (candidateRect != null)
        'candidateRect': [
          candidateRect.left,
          candidateRect.top,
          candidateRect.width,
          candidateRect.height,
        ],
    };
    for (final observer in observers) {
      observer._diagnose(sample);
    }
  }

  void update(
    List<ModalRoute<dynamic>> nextRoutes,
    List<NativeCompositionObserver> nextObservers,
    Rect nextViewport,
  ) {
    if (attached) _listen(false);
    routes = nextRoutes;
    observers = nextObservers;
    viewport = nextViewport;
    if (attached) _listen(true);
    markNeedsPaint();
  }

  void _listen(bool add) {
    for (final observer in observers) {
      if (add) {
        observer._changes.addListener(markNeedsPaint);
      } else {
        observer._changes.removeListener(markNeedsPaint);
      }
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _listen(true);
  }

  @override
  void detach() {
    _listen(false);
    super.detach();
  }

  Rect? _cover(PageRoute<dynamic> route) {
    void observe(String reason, {Rect? rectangle, String? ancestor}) {
      if (!observers.any(
        (observer) =>
            observer.diagnostics != null && observer._diagnosticBudget > 0,
      )) {
        return;
      }
      final sample = <String, Object?>{
        'event': 'candidate-cover',
        'reason': reason,
        'route': NativeCompositionObserver._routeCategory(route),
        'status': route.animation?.status.name,
        'ancestor': ancestor,
        if (rectangle != null)
          'rectangle': [
            rectangle.left,
            rectangle.top,
            rectangle.width,
            rectangle.height,
          ],
      };
      final signature = sample.toString();
      if (_lastCoverageDiagnostic == signature) return;
      _lastCoverageDiagnostic = signature;
      for (final observer in observers) {
        observer._diagnose(sample);
      }
    }

    if (!route.opaque ||
        route.offstage ||
        route.animation?.isDismissed != false) {
      observe('inactive-or-translucent');
      return null;
    }
    final context = route.subtreeContext;
    final box = context?.findRenderObject();
    if (context == null || box is! RenderBox || !box.attached || !box.hasSize) {
      observe('no-laid-out-subtree');
      return null;
    }
    var cupertino = false;
    var solid = true;
    context.visitAncestorElements((element) {
      final widget = element.widget;
      cupertino =
          cupertino ||
          widget is ios.CupertinoPageTransition ||
          widget is ios.CupertinoFullscreenDialogTransition ||
          widget is flutter_ios.CupertinoPageTransition ||
          widget is flutter_ios.CupertinoFullscreenDialogTransition;
      if (widget is FadeTransition && widget.opacity.value < 1 ||
          widget is Opacity && widget.opacity < 1 ||
          widget is ClipRRect && widget.clipBehavior != Clip.none ||
          widget is ClipRSuperellipse && widget.clipBehavior != Clip.none ||
          widget is ClipOval && widget.clipBehavior != Clip.none ||
          widget is ClipPath && widget.clipBehavior != Clip.none ||
          widget is PhysicalModel && widget.clipBehavior != Clip.none ||
          widget is PhysicalShape && widget.clipBehavior != Clip.none) {
        solid = false;
        observe('non-solid-ancestor', ancestor: widget.runtimeType.toString());
      }
      return solid;
    });
    if (!solid ||
        (route.animation?.status != AnimationStatus.completed && !cupertino)) {
      if (solid) observe('unrecognized-moving-transition');
      return null;
    }
    final matrix = box.getTransformTo(null);
    final m = matrix.storage;
    // A rotated or perspective AABB is not a solid coverage rectangle.
    if (m[1] != 0 || m[4] != 0 || m[3] != 0 || m[7] != 0 || m[15] != 1) {
      observe('non-axis-aligned-transform');
      return null;
    }
    var result = MatrixUtils.transformRect(matrix, Offset.zero & box.size);
    RenderObject current = box;
    while (current.parent != null) {
      final parent = current.parent!;
      final clip = parent.describeApproximatePaintClip(current);
      if (clip != null) {
        result = result.intersect(
          MatrixUtils.transformRect(parent.getTransformTo(null), clip),
        );
      }
      current = parent;
    }
    result = result.intersect(viewport);
    observe('solid-rectangle', rectangle: result);
    return result;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final transform = getTransformTo(null);
    final bounds = MatrixUtils.transformRect(
      transform,
      paintBounds,
    ).intersect(viewport);
    if (bounds.isEmpty) {
      for (final source in routes) {
        if (source is! PageRoute<dynamic> ||
            (source.secondaryAnimation?.value ?? 0) <= 0)
          continue;
        final navigator = source.navigator;
        final observer =
            (navigator == null
                ? null
                : NativeCompositionObserver._owners[navigator]) ??
            observers
                .where(
                  (value) =>
                      value.geometryBasedOcclusion &&
                      value._routes.contains(source),
                )
                .firstOrNull;
        if (observer == null) continue;
        final index = observer._routes.indexOf(source);
        if (index < 0) continue;
        for (final candidate in observer._routes.skip(index + 1)) {
          if (routes.contains(candidate)) continue;
          if (observer._externalRoutes.contains(candidate) &&
              !routes.any((route) => route.navigator == candidate.navigator))
            continue;
          if (!observer.geometryBasedOcclusion &&
              observer.candidateRoutes[source.settings.name]?.contains(
                    candidate.settings.name,
                  ) !=
                  true &&
              !observer.candidateOpaqueDestinations.contains(
                candidate.settings.name,
              ))
            continue;
          final cover = _cover(candidate);
          if (cover != null && !cover.isEmpty) {
            // Only route-driven offscreen paint is suppressed. Animation and
            // route-completion listeners invalidate this box on return/cancel;
            // ordinary retained scrolling below keeps its existing behavior.
            _diagnosePaint(
              'covered-offscreen',
              bounds,
              source: source,
              cover: candidate,
              candidateRect: cover,
            );
            return;
          }
        }
      }
      // Scrolling can move a retained repaint boundary without repainting its
      // contents. Keep its platform-view layers even when currently offscreen;
      // otherwise the cached empty layer stays blank when it enters the view.
      // The normal parent clip/compositor owns viewport culling.
      _diagnosePaint('offscreen-retained', bounds);
      super.paint(context, offset);
      return;
    }
    var visible = bounds;
    Route<dynamic>? partialSource, partialCover;
    Rect? partialCandidate;
    for (final source in routes) {
      if (source is! PageRoute<dynamic>) continue;
      final navigator = source.navigator;
      final observer =
          (navigator == null
              ? null
              : NativeCompositionObserver._owners[navigator]) ??
          observers
              .where(
                (value) =>
                    value.geometryBasedOcclusion &&
                    value._routes.contains(source),
              )
              .firstOrNull;
      if (observer == null) continue;
      final index = observer._routes.indexOf(source);
      if (index < 0) continue;
      for (final candidate in observer._routes.skip(index + 1)) {
        // A destination registered from a nested Navigator is also in this
        // control's ancestor chain. It must never occlude its own controls.
        if (routes.contains(candidate)) continue;
        // An externally observed tab page only covers that tab Navigator's
        // contents. Root chrome can paint above it even when their rectangles
        // overlap; a normal root didPush still covers that chrome as usual.
        if (observer._externalRoutes.contains(candidate) &&
            !routes.any((route) => route.navigator == candidate.navigator)) {
          continue;
        }
        final namedPair =
            observer.candidateRoutes[source.settings.name]?.contains(
              candidate.settings.name,
            ) ==
            true;
        final sharedDestination = observer.candidateOpaqueDestinations.contains(
          candidate.settings.name,
        );
        if (!observer.geometryBasedOcclusion &&
            !namedPair &&
            !sharedDestination)
          continue;
        final cover = _cover(candidate);
        if (cover != null &&
            cover.left <= visible.left &&
            cover.top <= visible.top &&
            cover.right >= visible.right &&
            cover.bottom >= visible.bottom) {
          _diagnosePaint(
            'covered',
            bounds,
            source: source,
            cover: candidate,
            candidateRect: cover,
          );
          return;
        }
        if (cover == null || !cover.overlaps(visible)) continue;
        // A sliding opaque page can leave one exposed rectangular strip. Keep
        // painting that actual native material, but exclude its covered area
        // from the scene. Never duplicate one platform view into several clips.
        Rect? remainder;
        if (cover.top <= visible.top && cover.bottom >= visible.bottom) {
          if (cover.left <= visible.left && cover.right < visible.right) {
            remainder = Rect.fromLTRB(
              cover.right,
              visible.top,
              visible.right,
              visible.bottom,
            );
          } else if (cover.right >= visible.right &&
              cover.left > visible.left) {
            remainder = Rect.fromLTRB(
              visible.left,
              visible.top,
              cover.left,
              visible.bottom,
            );
          }
        } else if (cover.left <= visible.left && cover.right >= visible.right) {
          if (cover.top <= visible.top && cover.bottom < visible.bottom) {
            remainder = Rect.fromLTRB(
              visible.left,
              cover.bottom,
              visible.right,
              visible.bottom,
            );
          } else if (cover.bottom >= visible.bottom &&
              cover.top > visible.top) {
            remainder = Rect.fromLTRB(
              visible.left,
              visible.top,
              visible.right,
              cover.top,
            );
          }
        }
        if (remainder != null) {
          visible = remainder;
          partialSource = source;
          partialCover = candidate;
          partialCandidate = cover;
        }
      }
    }
    final matrix = transform.storage;
    if (visible != bounds &&
        matrix[0] != 0 &&
        matrix[5] != 0 &&
        matrix[1] == 0 &&
        matrix[4] == 0 &&
        matrix[3] == 0 &&
        matrix[7] == 0 &&
        matrix[15] == 1) {
      _diagnosePaint(
        'partly-visible',
        bounds,
        source: partialSource,
        cover: partialCover,
        partlyVisibleRect: visible,
        candidateRect: partialCandidate,
      );
      final clip = MatrixUtils.inverseTransformRect(transform, visible);
      if (_preserveDownloadUnderlay(partialSource, partialCover)) {
        // iOS builds its overlay rectangles from raw platform view bounds.
        // Keep the same hard-edged visible strip, but preserve the background
        // outside it so that later Flutter slices can still draw there.
        // Flutter 3.47 preserves that underlay for the superellipse mutator,
        // including a zero-radius shape that still clips to the same rect.
        context.pushClipRSuperellipse(
          needsCompositing,
          offset,
          clip,
          RSuperellipse.fromRectAndRadius(clip, Radius.zero),
          super.paint,
          clipBehavior: Clip.hardEdge,
        );
      } else {
        context.pushClipRect(
          needsCompositing,
          offset,
          clip,
          super.paint,
          clipBehavior: Clip.hardEdge,
        );
      }
      return;
    }
    _diagnosePaint('visible', bounds, source: routes.firstOrNull);
    super.paint(context, offset);
  }
}
