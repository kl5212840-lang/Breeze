import 'package:material_ui/material_ui.dart';

class BookshelfHeaderSlots {
  const BookshelfHeaderSlots({
    required this.subtitle,
    required this.identity,
    required this.controls,
    required this.more,
    required this.selection,
  });

  final String subtitle;
  final Object? identity;
  final List<Widget> controls;
  final Widget? more, selection;
}

/// Connects the active collection to the host's two rows. Pane updates only
/// rebuild the header slots, keeping the PageViews and their contents stable.
class BookshelfHeaderController extends ChangeNotifier {
  int _generation = 0;
  bool _disposed = false;
  Object? _owner;
  BookshelfHeaderSlots? _slots;

  int get generation => _generation;
  BookshelfHeaderSlots? get slots => _slots;

  // The host calls this as part of its own state update before rebuilding.
  void changePane() {
    _generation++;
    _owner = null;
    _slots = null;
  }

  bool isCurrent(int generation) => !_disposed && generation == _generation;

  void _publish(int generation, Object owner, BookshelfHeaderSlots slots) {
    if (!isCurrent(generation)) return;
    _owner = owner;
    _slots = slots;
    notifyListeners();
  }

  void _clear(int generation, Object owner) {
    if (!isCurrent(generation) || _owner != owner) return;
    _owner = null;
    _slots = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class BookshelfHeaderPublisher extends StatefulWidget {
  const BookshelfHeaderPublisher({
    super.key,
    required this.controller,
    required this.generation,
    required this.slots,
    required this.child,
  });

  final BookshelfHeaderController controller;
  final int generation;
  final BookshelfHeaderSlots slots;
  final Widget child;

  @override
  State<BookshelfHeaderPublisher> createState() =>
      _BookshelfHeaderPublisherState();
}

class _BookshelfHeaderPublisherState extends State<BookshelfHeaderPublisher> {
  @override
  void initState() {
    super.initState();
    _publishAfterBuild();
  }

  @override
  void didUpdateWidget(BookshelfHeaderPublisher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _clearAfterBuild(oldWidget);
    _publishAfterBuild();
  }

  void _publishAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller._publish(widget.generation, this, widget.slots);
      }
    });
  }

  void _clearAfterBuild(BookshelfHeaderPublisher publisher) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      publisher.controller._clear(publisher.generation, this);
    });
  }

  @override
  void dispose() {
    _clearAfterBuild(widget);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
