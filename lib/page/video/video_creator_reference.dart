/// A role-specific identity and the destinations actually supplied by the site.
/// Names and avatar URLs are display data; neither establishes identity.
class VideoCreatorReference {
  const VideoCreatorReference({
    required this.name,
    required this.role,
    required this.entityKey,
    this.profileUrl,
    this.nameSearchUrl,
    this.avatarUrl,
    this.pages = const {},
    this.artistId,
    this.profileId,
  });

  final String name;
  final String role;
  final String entityKey;
  final String? artistId;
  final String? profileId;
  final Uri? profileUrl;
  final Uri? nameSearchUrl;
  final Uri? avatarUrl;
  final Map<String, Uri> pages;

  /// The avatar opens the real profile, never a synthesized name search.
  Uri? get destination => profileUrl;

  static final _profilePath = RegExp(r'^/user/([0-9]+)/?$');
  static final _digits = RegExp(r'^[0-9]+$');
  static const _roles = {'artist', 'uploader', 'publicUser'};
  static const _searchFields = {
    'query',
    'genre',
    'type',
    'sort',
    'date',
    'duration',
    'tags[]',
    'broad',
    'year',
    'month',
    'page',
  };
  static const _pageFields = {'page', 'sort', 'view'};

  static VideoCreatorReference? fromWire(
    Map<String, dynamic> raw,
    Uri origin, {
    String role = 'artist',
  }) {
    if (!_roles.contains(role) || !_secure(origin)) return null;
    final declaredRole = raw['role']?.toString();
    if (declaredRole != null && declaredRole != role) return null;
    final name = (raw['name'] ?? raw['title'])?.toString().trim() ?? '';
    if (name.isEmpty) return null;

    final explicitProfile = _target(raw['profileUrl'], origin);
    final legacy = _target(raw['url'] ?? raw['pageUrl'], origin);
    final profile =
        _profile(explicitProfile, origin) ??
        (raw['profileUrl'] == null ? _profile(legacy, origin) : null);
    final profileId = profile == null
        ? null
        : _profilePath.firstMatch(profile.path)!.group(1);
    final declaredProfileId = _id(raw['profileId']);
    if (declaredProfileId != null &&
        profileId != null &&
        declaredProfileId != profileId) {
      return null;
    }
    final artistId = role == 'artist' ? _id(raw['artistId']) : null;
    final key = switch (role) {
      'artist' when artistId != null => 'artist:$artistId',
      'artist' when profileId != null => 'artist-profile:$profileId',
      'uploader' when profileId != null => 'uploader-profile:$profileId',
      'publicUser' when profileId != null => 'public-user:$profileId',
      _ => '',
    };
    final search =
        _search(_target(raw['nameSearchUrl'], origin), origin) ??
        (raw['nameSearchUrl'] == null ? _search(legacy, origin) : null);
    final avatar = _target(raw['avatarUrl'] ?? raw['coverUrl'], origin);
    final candidatePages = raw['pages'];
    final pages = <String, Uri>{};
    if (candidatePages is Map && profile != null) {
      for (final entry in candidatePages.entries) {
        final target = _target(entry.value, origin);
        if (target != null && _ownedPage(target, profile)) {
          pages[entry.key.toString()] = target;
        }
      }
    }
    return VideoCreatorReference(
      name: name.length > 120 ? name.substring(0, 120) : name,
      role: role,
      entityKey: key,
      artistId: artistId,
      profileId: profileId,
      profileUrl: profile,
      nameSearchUrl: search,
      avatarUrl: avatar != null && _secure(avatar) && !_privateQuery(avatar)
          ? avatar
          : null,
      pages: Map.unmodifiable(pages),
    );
  }

  /// Paging may change the same observed destination. All other query fields
  /// remain significant, including category, sort and repeated tag values.
  bool contains(Uri uri) {
    if (!_secure(uri) || uri.hasFragment) return false;
    final profile = profileUrl;
    if (profile != null &&
        _profile(uri, profile) != null &&
        _sameDestination(profile, uri)) {
      return true;
    }
    for (final target in pages.values) {
      if (profile != null &&
          _ownedPage(target, profile) &&
          _ownedPage(uri, profile) &&
          _sameDestination(target, uri)) {
        return true;
      }
    }
    final search = nameSearchUrl;
    return search != null &&
        _search(uri, search) != null &&
        _sameDestination(search, uri);
  }

  /// Adds only observed links belonging to this real profile. No child URL is
  /// constructed merely because the site has used that route for someone else.
  VideoCreatorReference withPages(Map<String, Uri> observedPages) {
    final profile = profileUrl;
    return VideoCreatorReference(
      name: name,
      role: role,
      entityKey: entityKey,
      artistId: artistId,
      profileId: profileId,
      profileUrl: profile,
      nameSearchUrl: nameSearchUrl,
      avatarUrl: avatarUrl,
      pages: Map.unmodifiable({
        ...pages,
        if (profile != null)
          for (final entry in observedPages.entries)
            if (_ownedPage(entry.value, profile)) entry.key: entry.value,
      }),
    );
  }

  static String? _id(dynamic value) {
    final text = value?.toString() ?? '';
    return _digits.hasMatch(text) ? text : null;
  }

  static Uri? _target(dynamic value, Uri origin) {
    if (value == null || value.toString().trim().isEmpty) return null;
    try {
      return origin.resolve(value.toString());
    } on FormatException {
      return null;
    }
  }

  static bool _secure(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      (!uri.hasPort || uri.port == 443);

  static bool _sameOrigin(Uri uri, Uri origin) =>
      _secure(uri) && uri.origin == origin.origin && !uri.hasFragment;

  static Uri? _profile(Uri? uri, Uri origin) =>
      uri != null &&
          _sameOrigin(uri, origin) &&
          !uri.hasQuery &&
          _profilePath.hasMatch(uri.path)
      ? uri
      : null;

  static Uri? _search(Uri? uri, Uri origin) =>
      uri != null &&
          _sameOrigin(uri, origin) &&
          uri.path == '/search' &&
          (uri.queryParameters['query']?.trim().isNotEmpty ?? false) &&
          uri.queryParametersAll.keys.every(_searchFields.contains)
      ? uri
      : null;

  static bool _ownedPage(Uri uri, Uri profile) {
    if (!_sameOrigin(uri, profile) ||
        !uri.queryParametersAll.keys.every(_pageFields.contains)) {
      return false;
    }
    final root = profile.path.replaceFirst(RegExp(r'/$'), '');
    final path = uri.path.replaceFirst(RegExp(r'/$'), '');
    return path == root ||
        path == '$root/uploaded' ||
        path == '$root/playlists';
  }

  static bool _privateQuery(Uri uri) => uri.queryParametersAll.keys.any(
    (key) => RegExp(
      r'(token|password|cookie|email|otp|secret|session|csrf)',
      caseSensitive: false,
    ).hasMatch(key),
  );

  static bool _sameDestination(Uri wanted, Uri actual) {
    if (wanted.origin != actual.origin ||
        wanted.path.replaceFirst(RegExp(r'/$'), '') !=
            actual.path.replaceFirst(RegExp(r'/$'), '')) {
      return false;
    }
    final expected = Map<String, List<String>>.from(wanted.queryParametersAll)
      ..remove('page');
    final received = Map<String, List<String>>.from(actual.queryParametersAll)
      ..remove('page');
    if (expected.length != received.length) return false;
    for (final entry in expected.entries) {
      final values = received[entry.key];
      if (values == null || values.length != entry.value.length) return false;
      for (var i = 0; i < values.length; i++) {
        if (values[i] != entry.value[i]) return false;
      }
    }
    return true;
  }
}
