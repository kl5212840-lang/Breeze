import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

/// A separate information target keeps the row's existing open and select
/// gestures while giving abbreviated fields a readable, untruncated view.
class DetailedMetadata extends StatelessWidget {
  const DetailedMetadata({
    super.key,
    required this.title,
    required this.fields,
    required this.child,
    this.additional,
  });

  final String title;
  final List<({String label, String value})> fields;
  final WidgetBuilder? additional;
  final Widget child;
  static double actionExtentOf(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.android ? 48 : 44;

  Future<void> _open(BuildContext context) => showVideoTaskSheet<void>(
    context: context,
    systemStyle: AppInterfaceStyleScope.usesSystem(context),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.download.workDetails,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: t.common.close,
                  onPressed: Navigator.of(context).pop,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                for (final field in fields)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (field.label.isNotEmpty)
                          Text(
                            field.label,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        Text(
                          field.value,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                if (additional case final builder?) builder(context),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => fields.isEmpty && additional == null
      ? child
      : Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: child),
            IconButton(
              tooltip: t.download.workDetails,
              onPressed: () => _open(context),
              constraints: BoxConstraints.tightFor(
                width: actionExtentOf(context),
                height: actionExtentOf(context),
              ),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.standard,
              icon: const Icon(Icons.info_outline, size: 19),
            ),
          ],
        );
}
