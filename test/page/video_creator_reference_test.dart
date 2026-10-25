import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/video_creator_reference.dart';

void main() {
  final origin = Uri.parse('https://hanime1.me/');
  VideoCreatorReference? parse(
    Map<String, dynamic> raw, {
    String role = 'artist',
  }) => VideoCreatorReference.fromWire(raw, origin, role: role);

  test('same name and avatar do not establish a shared artist identity', () {
    final a = parse({
      'name': 'Same',
      'profileUrl': '/user/11',
      'avatarUrl': '/avatar.png',
    })!;
    final b = parse({
      'name': 'Same',
      'profileUrl': '/user/22',
      'avatarUrl': '/avatar.png',
    })!;
    expect(a.entityKey, 'artist-profile:11');
    expect(b.entityKey, 'artist-profile:22');
    expect(a.avatarUrl, b.avatarUrl);
    expect(a.artistId, isNull);
  });

  test('real artist and profile IDs may differ within the observed row', () {
    final ref = parse({
      'name': 'Artist',
      'artistId': '99',
      'profileId': '11',
      'profileUrl': '/user/11',
    })!;
    expect(ref.entityKey, 'artist:99');
    expect(ref.profileId, '11');
    expect(ref.artistId, '99');
    expect(ref.destination, origin.resolve('/user/11'));
    expect(
      parse({'name': 'Wrong', 'profileId': '22', 'profileUrl': '/user/11'}),
      isNull,
    );
  });

  test(
    'name search without identity stays unresolved and never gains a profile',
    () {
      final ref = parse({
        'title': 'Name',
        'url': '/search?query=Actual&genre=Type',
        'entityKey': 'artist:invented',
        'profileId': '11',
      })!;
      expect(ref.entityKey, isEmpty);
      expect(ref.profileId, isNull);
      expect(ref.destination, isNull);
      expect(
        ref.nameSearchUrl,
        origin.resolve('/search?query=Actual&genre=Type'),
      );
      expect(ref.contains(origin.resolve('/user/11')), isFalse);
      final identifiedWithoutProfile = parse({
        'name': 'Name',
        'artistId': '99',
      })!;
      expect(identifiedWithoutProfile.entityKey, 'artist:99');
      expect(identifiedWithoutProfile.destination, isNull);
    },
  );

  test('roles remain separate even with the same real profile', () {
    final artist = parse({'name': 'Person', 'profileUrl': '/user/11'})!;
    final uploader = parse({
      'name': 'Person',
      'profileUrl': '/user/11',
      'artistId': '99',
    }, role: 'uploader')!;
    final user = parse({
      'name': 'Person',
      'profileUrl': '/user/11',
    }, role: 'publicUser')!;
    expect({
      artist.entityKey,
      uploader.entityKey,
      user.entityKey,
    }, hasLength(3));
    expect(uploader.entityKey, 'uploader-profile:11');
    expect(uploader.artistId, isNull);
    expect(user.entityKey, 'public-user:11');
    expect(
      parse({
        'name': 'Person',
        'role': 'artist',
        'profileUrl': '/user/11',
      }, role: 'uploader'),
      isNull,
    );
  });

  test(
    'identity targets reject foreign origins, credentials and private queries',
    () {
      for (final target in [
        'http://hanime1.me/user/11',
        'https://other.test/user/11',
        'https://secret@hanime1.me/user/11',
        'https://hanime1.me:8443/user/11',
        '/user/11?email=private',
        '/user/11#secret',
        '/user/not-an-id',
        '/user/11/edit',
      ]) {
        final ref = parse({'name': 'Person', 'profileUrl': target})!;
        expect(ref.destination, isNull, reason: target);
        expect(ref.entityKey, isEmpty, reason: target);
      }
      for (final target in [
        '/search?query=Name&_token=private',
        '/search?query=Name&email=private',
        '/search?query=',
        'https://other.test/search?query=Name',
      ]) {
        expect(
          parse({'name': 'Person', 'nameSearchUrl': target})!.nameSearchUrl,
          isNull,
          reason: target,
        );
      }
    },
  );

  test('only supplied pages under this real owner are accepted', () {
    final ref = parse({
      'name': 'Artist',
      'profileUrl': '/user/11',
      'pages': {
        'works': '/user/11/uploaded?sort=latest',
        'playlists': '/user/11/playlists',
        'other': '/user/22/uploaded',
        'private': '/user/11/edit',
        'secret': '/user/11/uploaded?token=private',
        'foreign': 'https://other.test/user/11/uploaded',
      },
    })!;
    expect(ref.pages.keys, unorderedEquals(['works', 'playlists']));
    expect(
      ref.contains(origin.resolve('/user/11/uploaded?sort=latest&page=2')),
      isTrue,
    );
    expect(
      ref.contains(origin.resolve('/user/11/uploaded?sort=oldest')),
      isFalse,
    );
    expect(ref.contains(origin.resolve('/user/11/uploaded')), isFalse);
    expect(ref.contains(origin.resolve('/user/11/playlists/42')), isFalse);
    expect(ref.contains(origin.resolve('/user/22/uploaded')), isFalse);
    final noPages = parse({'name': 'Artist', 'profileUrl': '/user/11'})!;
    expect(noPages.contains(origin.resolve('/user/11/uploaded')), isFalse);
    final updated = noPages.withPages({
      'works': origin.resolve('/user/11/uploaded'),
      'other': origin.resolve('/user/22/uploaded'),
    });
    expect(updated.pages.keys, ['works']);
    expect(
      updated.contains(origin.resolve('/user/11/uploaded?page=3')),
      isTrue,
    );
    expect(noPages.pages, isEmpty);
  });

  test('observed name-search aliases preserve every non-paging field', () {
    final ref = parse({
      'name': 'Artist',
      'profileUrl': '/user/11',
      'nameSearchUrl': '/search?query=Actual&genre=Type&tags[]=one&tags[]=two',
    })!;
    expect(
      ref.contains(
        origin.resolve(
          '/search?page=2&genre=Type&query=Actual&tags[]=one&tags[]=two',
        ),
      ),
      isTrue,
    );
    for (final target in [
      '/search?query=Actual',
      '/search?query=Actual&genre=Other&tags[]=one&tags[]=two',
      '/search?query=Actual&genre=Type&tags[]=one',
      '/search?query=Actual&genre=Type&tags[]=two&tags[]=one',
      '/search?query=Actual&genre=Type&tags[]=one&tags[]=two&sort=latest',
      '/search?query=Actual&genre=Type&tags[]=one&tags[]=two&token=private',
    ]) {
      expect(ref.contains(origin.resolve(target)), isFalse, reason: target);
    }
  });
}
