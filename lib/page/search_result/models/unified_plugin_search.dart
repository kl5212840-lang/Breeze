import 'package:zephyr/network/http/plugin/unified_plugin_envelope.dart';
import 'package:zephyr/util/json/json_value.dart';

class UnifiedPluginSearchPaging {
  const UnifiedPluginSearchPaging({
    required this.page,
    required this.pages,
    required this.total,
    required this.hasReachedMax,
    this.reportedPage,
    this.hasExplicitContinuation = false,
  });

  final int page;
  final int pages;
  final int total;
  final bool hasReachedMax;
  final int? reportedPage;
  final bool hasExplicitContinuation;

  // A missing stop flag is distinct from a plug-in explicitly advertising
  // another page. Some older plug-ins only report the current and total pages.
  bool canContinueFrom(int currentPage) =>
      !hasReachedMax && (hasExplicitContinuation || pages > currentPage);

  factory UnifiedPluginSearchPaging.fromMap(Map<String, dynamic> map) {
    return UnifiedPluginSearchPaging(
      page: _toInt(map['page'], 1),
      pages: _toInt(map['pages'], 1),
      total: _toInt(map['total'], 0),
      hasReachedMax: map['hasReachedMax'] == true,
      reportedPage: _parseInt(map['page']),
      hasExplicitContinuation: map['hasReachedMax'] == false,
    );
  }
}

class UnifiedPluginSearchItem {
  const UnifiedPluginSearchItem({
    required this.id,
    required this.title,
    required this.data,
    required this.raw,
  });

  final String id;
  final String title;
  final Map<String, dynamic> data;
  final Map<String, dynamic> raw;

  factory UnifiedPluginSearchItem.fromMap(Map<String, dynamic> map) {
    final id = _requireItemText(map['id'], 'id');
    final title = _requireItemText(map['title'], 'title');
    return UnifiedPluginSearchItem(
      id: id,
      title: title,
      data: asJsonMap(map),
      raw: asJsonMap(map['raw']),
    );
  }
}

class UnifiedPluginSearchResponse {
  const UnifiedPluginSearchResponse({
    required this.source,
    required this.extern,
    required this.paging,
    required this.items,
  });

  final String source;
  final Map<String, dynamic> extern;
  final UnifiedPluginSearchPaging paging;
  final List<UnifiedPluginSearchItem> items;

  factory UnifiedPluginSearchResponse.fromMap(Map<String, dynamic> map) {
    requireSuccessfulPluginEnvelope(map, message: '插件搜索返回错误响应');
    if (map['data'] != null && map['data'] is! Map) {
      throw const FormatException('插件搜索结果 data 格式错误');
    }
    final data = asJsonMap(map['data']);
    requireSuccessfulPluginEnvelope(data, message: '插件搜索返回错误响应');
    // Older plugins return items at the root, sometimes alongside data metadata.
    // A present but malformed data.items must not fall back to a second list.
    final body = data.containsKey('items') ? data : map;
    final itemsRaw = body['items'];
    if (itemsRaw is! List) {
      throw const FormatException('插件搜索结果缺少有效的 items 列表');
    }
    final pagingMap = asJsonMap(body['paging']);

    final itemList = itemsRaw.map((item) {
      if (item is! Map) {
        throw const FormatException('插件搜索结果包含无效条目');
      }
      return UnifiedPluginSearchItem.fromMap(asJsonMap(item));
    }).toList();

    return UnifiedPluginSearchResponse(
      source: map['source']?.toString() ?? '',
      extern: asJsonMap(map['extern']),
      paging: UnifiedPluginSearchPaging.fromMap(pagingMap),
      items: itemList,
    );
  }
}

String _requireItemText(dynamic value, String field) {
  if ((value is! String && value is! num) || value.toString().trim().isEmpty) {
    throw FormatException('插件搜索条目缺少有效的 $field');
  }
  return value.toString();
}

int _toInt(dynamic value, int fallback) => _parseInt(value) ?? fallback;

int? _parseInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
