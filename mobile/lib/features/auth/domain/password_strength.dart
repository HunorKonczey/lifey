/// How far past the one hard requirement a password is - the register form's strength meter (LIF-157).
///
/// The same rules as the web's `passwordStrength` (`web/src/features/auth/passwordStrength.ts`), so a password reads the same
/// strength on both clients: four segments, and never a rule the backend does not have - the only requirement is 8 characters.
///
/// Points: 8+ characters, 12+ characters, upper and lower case, a digit, a symbol. Under 8 characters the password is weak
/// (1) whatever else it has; from 8 up, the segments are the points earned, at least 2 and at most 4. Nothing typed is 0.
const passwordMinLength = 8;

int passwordStrength(String password) {
  if (password.isEmpty) return 0;
  if (password.length < passwordMinLength) return 1;
  final points = [
    true,
    password.length >= 12,
    RegExp('[a-z]').hasMatch(password) && RegExp('[A-Z]').hasMatch(password),
    RegExp(r'\d').hasMatch(password),
    RegExp('[^A-Za-z0-9]').hasMatch(password),
  ].where((earned) => earned).length;
  return points.clamp(2, 4);
}
