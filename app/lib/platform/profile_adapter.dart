import 'package:vpn_platform/vpn_platform.dart' as vpn;

import '../domain/profile.dart';

/// Adapter between the app's [Profile] domain model and the vpn_platform
/// [vpn.ProxyProfile] contract.
extension ProfileVpnAdapter on Profile {
  vpn.ProxyProfile toVpnProfile() => vpn.ProxyProfile(
        id: id,
        name: name,
        protocol: protocol == ProxyProtocol.socks5
            ? vpn.ProxyProtocol.socks5
            : vpn.ProxyProtocol.http,
        host: host,
        port: port,
        username: username,
        password: password,
      );
}
