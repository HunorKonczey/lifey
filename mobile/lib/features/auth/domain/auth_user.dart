import '../../../core/network/jwt_decoder.dart';

/// The signed-in user, derived from the access token's claims
/// (sub/email/firstName/lastName/roles).
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.roles,
    this.firstName,
    this.lastName,
  });

  final int id;
  final String email;
  final String? firstName;
  final String? lastName;
  final List<String> roles;

  factory AuthUser.fromAccessToken(String accessToken) {
    final claims = decodeJwtPayload(accessToken);
    return AuthUser(
      id: int.parse(claims['sub'] as String),
      email: claims['email'] as String,
      firstName: claims['firstName'] as String?,
      lastName: claims['lastName'] as String?,
      roles: (claims['roles'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
    );
  }
}
