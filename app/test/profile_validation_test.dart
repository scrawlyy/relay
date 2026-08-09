import 'package:flutter_test/flutter_test.dart';
import 'package:relay_app/domain/profile.dart';

void main() {
  Profile validProfile() => Profile(
        id: 'p1',
        name: 'Tokyo',
        protocol: ProxyProtocol.socks5,
        host: 'tokyo.example.com',
        port: 1080,
      );

  group('ProfileValidation', () {
    test('accepts a valid profile', () {
      final result = ProfileValidation.validate(validProfile());
      expect(result.isValid, isTrue);
    });

    test('rejects empty name', () {
      final result =
          ProfileValidation.validate(validProfile().copyWith(name: '  '));
      expect(result.isValid, isFalse);
      expect(result.errors.join(), contains('name'));
    });

    test('rejects a name over 32 chars', () {
      final result =
          ProfileValidation.validate(validProfile().copyWith(name: 'x' * 33));
      expect(result.isValid, isFalse);
    });

    test('rejects invalid host', () {
      for (final bad in ['', 'http://x', 'a..b', '256.1.1.1', '-bad-.com']) {
        final result =
            ProfileValidation.validate(validProfile().copyWith(host: bad));
        expect(result.isValid, isFalse, reason: 'host "$bad" should be invalid');
      }
    });

    test('accepts ipv4, ipv6 and hostname hosts', () {
      for (final good in ['10.0.0.1', '2001:db8::1', 'sub.domain.example']) {
        final result =
            ProfileValidation.validate(validProfile().copyWith(host: good));
        expect(result.isValid, isTrue, reason: 'host "$good" should be valid');
      }
    });

    test('rejects out-of-range ports', () {
      for (final port in [0, 65536, -1]) {
        final result =
            ProfileValidation.validate(validProfile().copyWith(port: port));
        expect(result.isValid, isFalse);
      }
    });
  });

  test('toJson/fromJson round-trips a profile', () {
    final profile = validProfile()
        .copyWith(username: 'alice', createdAt: DateTime.utc(2026, 8, 9));
    final decoded = Profile.fromJson(profile.toJson());
    expect(decoded.id, profile.id);
    expect(decoded.username, 'alice');
    expect(decoded.createdAt, profile.createdAt);
    expect(decoded.password, isNull);
  });
}
