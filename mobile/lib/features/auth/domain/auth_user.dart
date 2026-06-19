import '../../../core/network/jwt_decoder.dart';

/// The signed-in user, derived from the access token's claims (sub/email/roles).
class AuthUser {
  const AuthUser({required this.id, required this.email, required this.roles});

  final int id;
  final String email;
  final List<String> roles;

  factory AuthUser.fromAccessToken(String accessToken) {
    final claims = decodeJwtPayload(accessToken);
    return AuthUser(
      id: int.parse(claims['sub'] as String),
      email: claims['email'] as String,
      roles: (claims['roles'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
    );
  }
}
