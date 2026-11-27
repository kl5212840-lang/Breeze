import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/bookshelf/widgets/filter_scroll_rail.dart';
import 'package:zephyr/page/bookshelf/widgets/filter_sheet_detents.dart';

/// Shared facet chrome and one lazy option viewport. Category changes do not
/// resize the panel; only the host's available space (including keyboard) does.
class FacetFilterBody extends StatefulWidget {
  const FacetFilterBody({
    super.key,
    required this.header,
    required this.controls,
    required this.options,
    required this.footer,
    required this.scrollKey,
    this.hasScope = false,
    this.scrollController,
    this.maxHeight = 600,
  });
  final Widget header, controls, options, footer;
  final Key scrollKey;
  final bool hasScope;
  final double maxHeight;
  final ScrollController? scrollController;
  @override
  State<FacetFilterBody> createState() => _FacetFilterBodyState();
}

class _FacetFilterBodyState extends State<FacetFilterBody> {
  // Reparent the existing chrome/viewport when the keyboard leaves too little
  // room for fixed controls, retaining the field's focus and list's state.
  final _chromeKey = GlobalKey(),
      _viewportKey = GlobalKey(),
      _footerKey = GlobalKey();
  final _ownedScroll = ScrollController();

  @override
  void dispose() {
    _ownedScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ChipTheme(
      data: ChipTheme.of(context).copyWith(
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? colors.primary.withValues(alpha: .55)
                : colors.outlineVariant,
          ),
        ),
      ),
      child: _layout(),
    );
  }

  Widget _layout() => LayoutBuilder(
    builder: (context, bounds) {
      final height = math.max(
        0.0,
        FilterSheetDetents.isActiveOf(context)
            ? bounds.maxHeight
            : math.min(widget.maxHeight, bounds.maxHeight),
      );
      final scale = math.max(1.0, MediaQuery.textScalerOf(context).scale(1));
      // Fixed chrome must leave a usable option hit region; scaled text grows
      // while padding/44pt actions do not multiply with the font scale.
      final minimumFixed = widget.hasScope
          ? 340 + 180 * (scale - 1)
          : 280 + 140 * (scale - 1);
      final compact = height < minimumFixed;
      final chrome = KeyedSubtree(
        key: _chromeKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [widget.header, widget.controls],
        ),
      );
      final footer = KeyedSubtree(key: _footerKey, child: widget.footer);
      final viewport = KeyedSubtree(
        key: widget.scrollKey,
        child: FilterScrollRail(
          controller: widget.scrollController ?? _ownedScroll,
          child: CustomScrollView(
            key: _viewportKey,
            controller: widget.scrollController ?? _ownedScroll,
            primary: false,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
            scrollBehavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            slivers: [
              if (compact) SliverToBoxAdapter(child: chrome),
              widget.options,
              if (compact) SliverToBoxAdapter(child: footer),
            ],
          ),
        ),
      );
      return SizedBox(
        height: height,
        child: compact
            ? viewport
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  chrome,
                  Expanded(child: viewport),
                  const Divider(height: 1),
                  footer,
                ],
              ),
      );
    },
  );
}
