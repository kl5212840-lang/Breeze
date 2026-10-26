import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/comic_read/bloc/page_bloc.dart';
import 'package:zephyr/util/error_filter.dart';

class ComicErrorWidget extends StatelessWidget {
  final PageState state;
  final PageEvent event;

  const ComicErrorWidget({super.key, required this.state, required this.event});

  @override
  Widget build(BuildContext context) {
    logger.w('Reader load failed: ${state.errorMessage}');
    final localMissing = state.errorMessage.toLowerCase().contains(
      'no element',
    );
    final message = localMissing
        ? t.reader.chapterNotDownloaded
        : userFacingErrorMessage(state.errorMessage);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SourceBackButton(onPressed: () => context.pop()),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_outlined, size: 42),
                      const SizedBox(height: 16),
                      Text(
                        message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: () => context.pop(),
                            child: Text(t.common.back),
                          ),
                          if (!localMissing) ...[
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: () =>
                                  context.read<PageBloc>().add(event),
                              child: Text(t.common.retry),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
