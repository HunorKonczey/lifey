import 'dart:convert';

/// Decodes a JWT's payload claims without verifying the signature. Fine for
/// reading display data (email/roles) client-side — the backend is what
/// actually verifies and enforces the token on every request.
Map<String, dynamic> decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    throw const FormatException('Not a JWT: expected 3 dot-separated parts');
  }
  final normalized = base64Url.normalize(parts[1]);
  final payload = utf8.decode(base64Url.decode(normalized));
  return json.decode(payload) as Map<String, dynamic>;
}
