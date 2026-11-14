import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_header_slots.dart';

/// Page-level arrangement actions join the active pane's one More menu.
/// The owner validates captured medium/mode before committing a menu result.
class BookshelfActionsScope extends InheritedWidget {
  const BookshelfActionsScope({
    super.key,
    required this.video,
    required this.mode,
    required this.sort,
    required this.onSort,
    required this.onManageSources,
    this.header,
    this.headerGeneration = 0,
    this.canUseHeader,
    required super.child,
  });
  final bool video;
  final ShelfPageMode mode;
  final String sort;
  final ValueChanged<String>? onSort;
  final VoidCallback? onManageSources;
  final BookshelfHeaderController? header;
  final int headerGeneration;
  final bool Function()? canUseHeader;

  static BookshelfActionsScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BookshelfActionsScope>();

  static BookshelfActionsScope? forPane(
    BuildContext context, {
    required bool video,
    required ShelfPageMode mode,
  }) {
    final scope = of(context);
    return scope?.video == video && scope?.mode == mode ? scope : null;
  }

  Map<String, String> get sortOptions => {
    '__sort.dd': switch (mode) {
      ShelfPageMode.favorite => t.bookshelf.ordering.recentFavorites,
      ShelfPageMode.history =>
        video
            ? t.bookshelf.ordering.recentWatching
            : t.bookshelf.ordering.recentReading,
      ShelfPageMode.download =>
        video
            ? t.bookshelf.ordering.recentExports
            : t.bookshelf.ordering.recentDownloads,
    },
    '__sort.da': switch (mode) {
      ShelfPageMode.favorite => t.bookshelf.ordering.oldFavorites,
      ShelfPageMode.history =>
        video
            ? t.bookshelf.ordering.oldWatching
            : t.bookshelf.ordering.oldReading,
      ShelfPageMode.download =>
        video
            ? t.bookshelf.ordering.oldExports
            : t.bookshelf.ordering.oldDownloads,
    },
    if (!video && mode != ShelfPageMode.history) ...{
      '__sort.vd': t.bookshelf.ordering.recentReading,
      '__sort.va': t.bookshelf.ordering.oldReading,
    },
  };

  Map<String, String> get options => {
    if (onSort != null) ...sortOptions,
    if (onManageSources != null) '__sources': t.bookshelf.sourceLabels,
  };

  bool handle(String action) {
    if (action == '__sources') {
      onManageSources?.call();
      return true;
    }
    if (sortOptions.containsKey(action)) {
      onSort?.call(action.substring('__sort.'.length));
      return true;
    }
    return false;
  }

  @override
  bool updateShouldNotify(BookshelfActionsScope oldWidget) =>
      oldWidget.video != video ||
      oldWidget.mode != mode ||
      oldWidget.sort != sort ||
      oldWidget.header != header ||
      oldWidget.headerGeneration != headerGeneration ||
      oldWidget.canUseHeader != canUseHeader ||
      oldWidget.onSort != onSort ||
      oldWidget.onManageSources != onManageSources;
}
