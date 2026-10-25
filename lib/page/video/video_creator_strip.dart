import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_thumbnail.dart';

class VideoCreatorStrip extends StatelessWidget {
  const VideoCreatorStrip({
    super.key,
    required this.creators,
    required this.page,
    required this.onOpen,
  });
  final List<Map<String, dynamic>> creators;
  final Uri page;
  final ValueChanged<Uri> onOpen;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        t.videoCommunity.followedCreators,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 84 + MediaQuery.textScalerOf(context).scale(36),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: creators.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final creator = creators[index];
            final target = Uri.tryParse(creator['pageUrl']?.toString() ?? '');
            return SizedBox(
              width: 88,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: target == null ? null : () => onOpen(target),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: VideoThumbnail(
                            url: creator['coverUrl']?.toString() ?? '',
                            referrer: page,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        creator['title']?.toString() ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 24),
    ],
  );
}
