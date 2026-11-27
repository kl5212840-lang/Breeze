import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../test_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/plugin_account_authentication.dart';
import 'package:zephyr/service/plugin_account_profiles.dart';

const _copySource = PluginAccountAuthenticationService.copy;
const _copyRejected = PluginLoginRequiredException(
  UnauthorizedPayload(
    pluginId: _copySource,
    message: 'Fixture account rejected',
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestObjectBoxHelper.setUpTestObjectBox();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  test('a declared fresh identity reader can verify a new plugin without a source adapter', () async {
    const source = '91bf813e-eec4-4489-8e2d-f5ff7281453e';
    await PluginRegistryService.I.init();
    final now = DateTime.utc(2026);
    await PluginRegistryService.I.upsert(PluginInfo(
      uuid: source,
      version: 'fixture',
      originScript: 'synthetic-plugin',
      insertedAt: now,
      updatedAt: now,
      isEnabled: true,
      isDeleted: false,
      debug: false,
      lastLoadSuccess: true,
      getInfoJson: jsonEncode({
        'accountIdentity': {'version': 1, 'readFn': 'readAccountIdentity'},
      }),
    ));
    var verifyFresh = false;
    final service = PluginAccountAuthenticationService(source, call: (fn, _) async {
      expect(fn, 'readAccountIdentity');
      return {
        'data': {
          'available': verifyFresh,
          'accountId': 'account-fixture-42',
          'name': 'Declared member',
        },
      };
    });
    expect(service.hasApiVerification, isTrue);
    await expectLater(service.verify(), throwsA(isA<PluginAccountSwitchFailed>()));
    verifyFresh = true;
    expect((await service.verify()).serverIdentity, 'account-fixture-42');
    expect(PluginAccountIdentities.current(source)?.label, 'Declared member');
  });
  test('an unrelated plugin authorization error leaves the current account verified', () async {
    const rejected = PluginLoginRequiredException(
      UnauthorizedPayload(pluginId: 'other-source', message: 'Other account'),
    );
    const receipt = PluginAccountAuthentication(serverIdentity: 'same-account');
    final generation = pluginSessionWriteFence.generation(_copySource);
    PluginAccountIdentities.confirm(_copySource, receipt, generation: generation);
    final service = PluginAccountAuthenticationService(_copySource, call: (_, _) async => throw rejected);
    await expectLater(service.verify(), throwsA(same(rejected)));
    expect(parseUnauthorizedPayload(rejected, fallbackPluginId: _copySource), isNull);
    expect(PluginAccountIdentities.current(_copySource), same(receipt));
    pluginSessionWriteFence.advance(_copySource);
  });
  test('wrapped legacy errors from another source never request sign-in', () {
    final service = PluginAccountAuthenticationService(_copySource);
    expect(
      () => service.fromServerResponse({
        'data': {
          'title': '登录已失效',
          'lines': [
            '[bundle:fixture.cjs] Error: {"type":"unauthorized","source":"different-plugin"}',
          ],
        },
      }),
      throwsA(isA<PluginAccountSwitchFailed>()),
    );
  });
  test('a legacy display card by itself cannot confirm a saved session', () async {
    const source = '5ee50423-f3b9-4eb4-a9a6-ddd4001a5280';
    final profile = PluginAccountProfile(
      id: 'fixture',
      revision: 1,
      deleted: false,
      identity: 'fixture-user',
      bundle: const {
        'auth.username': 'fixture-user',
        'auth.token': 'fixture-session',
      },
    );
    replaceActivePluginAccount(source, profile.bundle);
    final auth = PluginAccountAuthenticationService(source, call: (fn, _) async {
      expect(fn, 'getUserInfoBundle');
      return {
        'scheme': {'type': 'userInfo'},
        'data': {
          'title': 'fixture-user',
          'avatar': {'id': 'avatar'},
        },
      };
    });
    await expectLater(auth.authenticate(profile), throwsA(isA<PluginAccountNeedsLogin>()));
    await expectLater(
      auth.verifyNativeLogin(
        {'data': {'ok': true}},
        account: 'fixture-user',
        previousSession: auth.legacySession(),
      ),
      throwsA(isA<PluginAccountNeedsLogin>()),
    );
    expect(PluginAccountIdentities.current(source), isNull);
  });
  test(
    'JM requires real useredit response rather than its cached account card',
    () async {
      var fresh = false;
      final calls = <String>[];
      final service = PluginAccountAuthenticationService(
        PluginAccountAuthenticationService.jm,
        call: (fn, values) async {
          calls.add(fn);
          return {
            'data': {
              'accountId': '42',
              'nickname': 'JM member',
              if (fresh) 'profileDataSource': 'serverUserEdit',
            },
          };
        },
      );
      await expectLater(
        service.verify(),
        throwsA(isA<PluginAccountSwitchFailed>()),
      );
      fresh = true;
      expect((await service.verify()).serverIdentity, '42');
      expect(calls, everyElement('getUserProfileDetails'));
    },
  );
  test(
    'JM verification resumes after the API endpoint update settles',
    () async {
      const source = PluginAccountAuthenticationService.jm;
      final calls = <String>[];
      final service = PluginAccountAuthenticationService(
        source,
        call: (function, _) async {
          calls.add(function);
          return {
            'data': {
              'accountId': '42',
              'nickname': 'Fixture member',
              'profileDataSource': 'serverUserEdit',
            },
          };
        },
      );
      final update = beginPluginEndpointUpdate(source)!;
      try {
        await expectLater(
          service.verify(),
          throwsA(isA<PluginSessionChanged>()),
        );
        expect(calls, isEmpty);
      } finally {
        finishPluginEndpointUpdate(source, update, refreshSettings: false);
      }
      expect((await service.verify()).serverIdentity, '42');
      expect(calls, ['getUserProfileDetails']);
    },
  );
  test(
    'Copy expired token uses only its declared form and confirms member/info identity',
    () async {
      var loggedIn = false;
      final calls = <String>[];
      final service = PluginAccountAuthenticationService(
        PluginAccountAuthenticationService.copy,
        call: (fn, values) async {
          calls.add(fn);
          if (fn == 'getUserInfoBundle') {
            if (!loggedIn) throw _copyRejected;
            return {
              'data': {
                'extern': {'userId': 'copy-42', 'username': 'Copy member'},
              },
            };
          }
          if (fn == 'getLoginBundle')
            return {
              'scheme': {
                'fields': [
                  {'key': 'username', 'kind': 'text'},
                  {'key': 'password', 'kind': 'password'},
                ],
                'action': {'fnPath': 'loginWithPassword'},
              },
            };
          expect(fn, 'loginWithPassword');
          expect(values['username'], 'member');
          expect(values['password'], 'synthetic-secret');
          expect(values['values'], {
            'username': 'member',
            'password': 'synthetic-secret',
          });
          loggedIn = true;
          return {'ok': true};
        },
      );
      final proof = await service.authenticate(
        const PluginAccountProfile(
          id: 'fixture',
          revision: 1,
          deleted: false,
          identity: 'member',
          bundle: {
            'auth.username': 'member',
            'auth.password': 'synthetic-secret',
          },
        ),
      );
      expect(proof.serverIdentity, 'copy-42');
      expect(calls, [
        'getUserInfoBundle',
        'getLoginBundle',
        'loginWithPassword',
        'getUserInfoBundle',
      ]);
      expect('$proof', isNot(contains('synthetic')));
    },
  );
  test(
    'Copy renews a saved login after a legacy 401 envelope and retries only the identity read',
    () async {
      var reads = 0, submits = 0;
      final service = PluginAccountAuthenticationService(
        _copySource,
        call: (fn, values) async {
          if (fn == 'getUserInfoBundle') {
            switch (++reads) {
              case 1:
                return {'status': 401, 'data': {'available': false}};
              case 2:
                throw StateError('Fixture network request timed out');
              default:
                return {
                  'data': {
                    'extern': {'userId': 'copy-fixture-id', 'username': 'Saved member'},
                  },
                };
            }
          }
          if (fn == 'getLoginBundle') {
            return {
              'scheme': {
                'submitFnPath': 'loginWithPassword',
                'fields': [
                  {'key': 'username', 'kind': 'text'},
                  {'key': 'password', 'kind': 'password'},
                ],
              },
            };
          }
          expect(fn, 'loginWithPassword');
          expect(values['savedCredentialOrigin'], 'https://api.copy202602.com');
          submits++;
          return {'data': {'username': 'fixture-member'}};
        },
      );
      final proof = await service.authenticate(const PluginAccountProfile(
        id: 'copy-fixture',
        revision: 1,
        deleted: false,
        identity: 'fixture-member',
        serverIdentity: 'copy-fixture-id',
        bundle: {
          'account.credentials': {
            'version': 1,
            'deleted': false,
            'account': 'fixture-member',
            'password': 'synthetic-only',
            'origin': 'https://api.copy202602.com',
          },
        },
      ));
      expect(proof.serverIdentity, 'copy-fixture-id');
      expect((reads, submits), (3, 1));
    },
  );
  test(
    'Copy saved login preserves failures without submitting credentials',
    () async {
      const profile = PluginAccountProfile(
        id: 'fixture',
        revision: 1,
        deleted: false,
        identity: 'member',
        bundle: {
          'auth.username': 'member',
          'auth.password': 'synthetic-secret',
        },
      );
      for (final failure in [
        StateError('Synthetic network request timed out'),
        StateError('HTTP 403 Forbidden'),
        null, // Successful transport with an invalid identity envelope.
      ]) {
        final calls = <String>[];
        final service = PluginAccountAuthenticationService(
          _copySource,
          call: (function, _) async {
            calls.add(function);
            if (failure != null) throw failure;
            return {'data': {}};
          },
        );
        await expectLater(
          service.authenticate(profile),
          throwsA(
            failure == null ? isA<PluginAccountSwitchFailed>() : same(failure),
          ),
        );
        expect(calls, ['getUserInfoBundle']);
      }
    },
  );
  test(
    'captcha or unknown required fields never get fabricated; unsupported plugins need real login',
    () async {
      var submitted = false;
      final service = PluginAccountAuthenticationService(
        PluginAccountAuthenticationService.copy,
        call: (fn, values) async {
          if (fn == 'getUserInfoBundle') throw _copyRejected;
          if (fn == 'getLoginBundle')
            return {
              'scheme': {
                'fields': [
                  {'key': 'username', 'kind': 'text'},
                  {'key': 'captcha', 'kind': 'captcha-image'},
                ],
                'action': {'fnPath': 'loginWithPassword'},
              },
            };
          submitted = true;
          return {};
        },
      );
      await expectLater(
        service.authenticate(
          const PluginAccountProfile(
            id: 'fixture',
            revision: 1,
            deleted: false,
            identity: 'member',
            bundle: {
              'auth.username': 'member',
              'auth.password': 'synthetic-secret',
            },
          ),
        ),
        throwsA(isA<PluginAccountNeedsLogin>()),
      );
      expect(submitted, isFalse);
      final unknown = PluginAccountAuthenticationService(
        'unknown',
        call: (_, _) async => throw StateError('must not guess a method'),
      );
      await expectLater(
        unknown.verify(),
        throwsA(isA<PluginAccountNeedsLogin>()),
      );
    },
  );
  test(
    'Bika and Copy verified summary retains original portrait path and public fields',
    () {
      for (final source in [
        PluginAccountAuthenticationService.copy,
        PluginAccountAuthenticationService.bika.first,
      ]) {
        final proof = PluginAccountAuthenticationService(source)
            .fromServerResponse({
              'data': {
                'avatar': {
                  'id': '42',
                  'url': 'https://images.example/avatar.jpg',
                  'path': 'user/42/avatar.jpg',
                },
                'lines': ['Member', 'Lv.4', 'Experience 100/200', 'Checked in'],
                'extern': {
                  'name': 'Member',
                  'username': 'Member',
                  'userId': '42',
                  'email': 'member@example.test',
                  'level': 4,
                  'token': 'must-not-project',
                },
              },
            });
        final display = proof.toUserInfo();
        expect((display['avatar'] as Map)['path'], 'user/42/avatar.jpg');
        expect(
          (display['avatar'] as Map)['url'],
          'https://images.example/avatar.jpg',
        );
        expect((display['extern'] as Map)['email'], 'member@example.test');
        expect((display['extern'] as Map).containsKey('token'), isFalse);
        expect(display['lines'], hasLength(4));
      }
    },
  );
  test(
    'JM only adds stored public summary after fresh matching server identity',
    () async {
      var cachedId = '42';
      final service = PluginAccountAuthenticationService(
        PluginAccountAuthenticationService.jm,
        call: (fn, _) async => fn == 'getUserProfileDetails'
            ? {
                'data': {
                  'accountId': '42',
                  'nickname': 'Fresh nickname',
                  'profileDataSource': 'serverUserEdit',
                },
              }
            : {
                'data': {
                  'available': true,
                  'avatar': {
                    'id': cachedId,
                    'url': 'https://images.example/jm.jpg',
                    'path': 'photo.jpg',
                  },
                  'lines': ['Stored name · coins 10', 'Lv.4'],
                  'extern': {'uid': cachedId, 'coin': 10},
                },
              },
      );
      var proof = await service.verify(includeSummary: true);
      expect(proof.serverIdentity, '42');
      expect(proof.label, 'Fresh nickname');
      expect((proof.toUserInfo()['avatar'] as Map)['path'], 'photo.jpg');
      expect(
        proof.publicSummary['profileDataSource'],
        'verifiedIdentityStoredSummary',
      );
      expect(proof.publicSummary['lines'], contains('Lv.4'));
      cachedId = 'other-account';
      proof = await service.verify(includeSummary: true);
      expect(proof.avatarUrl, isEmpty);
      expect(proof.publicSummary['lines'], isEmpty);
    },
  );

  test(
    'JM signed portrait stays in its fresh receipt but not its portable summary',
    () async {
      const request =
          'https://images.example/jm.jpg?signature=private-image-token';
      final service = PluginAccountAuthenticationService(
        PluginAccountAuthenticationService.jm,
        call: (fn, _) async => fn == 'getUserProfileDetails'
            ? {
                'data': {
                  'accountId': '42',
                  'nickname': 'Member',
                  'profileDataSource': 'serverUserEdit',
                },
              }
            : {
                'data': {
                  'available': true,
                  'avatar': {
                    'id': '42',
                    'url': request,
                    'path': 'jm.jpg?signature=private-image-token',
                  },
                  'extern': {'uid': '42'},
                },
              },
      );
      final proof = await service.verify(includeSummary: true);
      expect(proof.requestAvatarUrl, request);
      expect(proof.atOrigin('https://site.example').requestAvatarUrl, request);
      expect(proof.avatarUrl, isEmpty);
      expect(proof.publicSummary['avatar'], {'id': '42'});
      expect(proof.toUserInfo()['avatar'], {'id': '42'});
      final portable = PluginAccountProfile(
        id: 'portrait-fixture',
        revision: 1,
        deleted: false,
        identity: 'member',
        avatarUrl: proof.avatarUrl,
        bundle: const {'auth.account': 'member'},
      );
      expect(
        portable.toJson().toString(),
        isNot(contains('private-image-token')),
      );
      expect(
        proof.publicSummary.toString(),
        isNot(contains('private-image-token')),
      );
    },
  );
  test(
    'runtime portrait retains signed HTTPS parameters without accepting unsafe URLs',
    () {
      final service = PluginAccountAuthenticationService(
        PluginAccountAuthenticationService.copy,
      );
      for (final url in [
        'https://images.example/photo.jpg?signature=private-image-token',
        'http://images.example/photo.jpg',
        'https://member:secret@images.example/photo.jpg',
        'https://images.example/photo.jpg#private-image-token',
      ]) {
        final proof = service.fromServerResponse({
          'data': {
            'extern': {'userId': 'copy-42'},
            'avatar': {
              'url': url,
              'path': 'photo%3Fsignature=private-image-token',
            },
          },
        });
        expect(
          proof.requestAvatarUrl,
          url == 'https://images.example/photo.jpg?signature=private-image-token'
              ? url
              : isEmpty,
        );
        expect(proof.avatarUrl, isEmpty);
        expect(proof.toUserInfo()['avatar'], {'id': 'copy-42'});
      }
    },
  );
}
