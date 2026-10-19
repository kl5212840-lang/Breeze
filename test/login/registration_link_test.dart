import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/login/registration_link.dart';

void main() {
  test('accepts a normal HTTPS registration page', () {
    final uri = validatedRegistrationUri(
      'https://2026copy.com/web/login/?url=person%2Fhome',
    );
    expect(uri?.host, '2026copy.com');
    expect(uri?.path, '/web/login/');
  });

  test('rejects insecure and malformed registration links', () {
    expect(validatedRegistrationUri(null), isNull);
    expect(validatedRegistrationUri('http://example.com/register'), isNull);
    expect(validatedRegistrationUri('javascript:alert(1)'), isNull);
    expect(validatedRegistrationUri('https://user:pass@example.com'), isNull);
    expect(validatedRegistrationUri('https:///register'), isNull);
  });
}
