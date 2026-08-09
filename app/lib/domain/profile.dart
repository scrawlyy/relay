/// A user-configured proxy profile.
library;

enum ProxyProtocol { socks5, http }

class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.protocol,
    required this.host,
    required this.port,
    this.username,
    this.password,
    this.createdAt,
  });

  final String id;
  final String name;
  final ProxyProtocol protocol;
  final String host;
  final int port;
  final String? username;
  final String? password;
  final DateTime? createdAt;

  Profile copyWith({
    String? id,
    String? name,
    ProxyProtocol? protocol,
    String? host,
    int? port,
    String? username,
    String? password,
    bool clearPassword = false,
    DateTime? createdAt,
  }) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username != null ? username : this.username,
      password: clearPassword
          ? null
          : (password ?? this.password),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get displayHost => port == 0 ? host : '$host:$port';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'protocol': protocol.name,
        'host': host,
        'port': port,
        'username': username,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        name: json['name'] as String,
        protocol:
            ProxyProtocol.values.byName(json['protocol'] as String? ?? 'socks5'),
        host: json['host'] as String,
        port: (json['port'] as num?)?.toInt() ?? 0,
        username: json['username'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );
}

class ProfileValidation {
  const ProfileValidation(this.errors);

  final List<String> errors;

  bool get isValid => errors.isEmpty;

  factory ProfileValidation.validate(Profile profile) {
    final errors = <String>[];

    final name = profile.name.trim();
    if (name.isEmpty) {
      errors.add('Give this profile a name');
    } else if (name.length > 32) {
      errors.add('Name must be 32 characters or fewer');
    }

    if (!_isValidHost(profile.host.trim())) {
      errors.add('Enter a valid IP address or hostname');
    }

    if (profile.port < 1 || profile.port > 65535) {
      errors.add('Port must be between 1 and 65535');
    }

    final username = profile.username?.trim() ?? '';
    if (username.isNotEmpty && username.length > 64) {
      errors.add('Username is too long');
    }
    if (profile.password != null && profile.password!.length > 128) {
      errors.add('Password is too long');
    }

    return ProfileValidation(errors);
  }
}

final _hostPattern = RegExp(
  r'^(?=.{1,253}\.?$)((?!-)[A-Za-z0-9-]{1,63}(?<!-)\.)+[A-Za-z]{2,63}$',
);

bool _isValidHost(String host) {
  if (host.isEmpty) return false;
  if (_hostPattern.hasMatch(host)) return true;
  // IPv4
  final ipv4 = host.split('.');
  if (ipv4.length == 4 &&
      ipv4.every((part) =>
          part.isNotEmpty &&
          part.length <= 3 &&
          int.tryParse(part) != null &&
          int.parse(part) >= 0 &&
          int.parse(part) <= 255)) {
    return true;
  }
  // IPv6 (plain)
  if (host.contains(':')) {
    final candidate = host.startsWith('[') && host.endsWith(']')
        ? host.substring(1, host.length - 1)
        : host;
    final parts = candidate.split(':');
    if (parts.length >= 2 && parts.length <= 8) {
      for (final part in parts) {
        if (part.isEmpty || part.length > 4) continue;
        if (int.tryParse(part, radix: 16) == null) return false;
      }
      return true;
    }
  }
  return false;
}
