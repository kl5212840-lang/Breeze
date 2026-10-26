import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';

/// Keeps the existing browser covered while verification runs in its own window.
/// Opening that window is always an explicit user action.
class VideoVerificationGate extends StatelessWidget {
  const VideoVerificationGate({
    super.key,
    required this.onVerify,
    this.active = false,
    this.onHelp,
  });

  final VoidCallback onVerify;
  final bool active;
  final VoidCallback? onHelp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : 0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 44,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t.videoPlayback.verificationNote,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: active ? null : onVerify,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox.square(
                              dimension: 20,
                              child: active
                                  ? const ExcludeSemantics(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                t.videoPlayback.verificationWindow,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 32),
                          ],
                        ),
                      ),
                      if (onHelp != null) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: onHelp,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                          ),
                          child: Text(
                            t.videoPlayback.verificationHelp,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
