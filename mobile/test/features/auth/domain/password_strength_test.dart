import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/auth/domain/password_strength.dart';

/// The same cases as the web's `passwordStrength.test.ts`: a password must read the same strength on both clients.
void main() {
  test('is empty for nothing and weak below 8 characters', () {
    expect(passwordStrength(''), 0);
    expect(passwordStrength('Ab1!'), 1);
    expect(passwordStrength('Abcdef1'), 1);
  });

  test('an 8-character password is at least acceptable, more with variety and length', () {
    expect(passwordStrength('abcdefgh'), 2);
    expect(passwordStrength('abcdefg1'), 2);
    expect(passwordStrength('Abcdefg1'), 3);
    expect(passwordStrength('Abcdefg1!'), 4);
    expect(passwordStrength('abcdefghijkl'), 2);
    expect(passwordStrength('abcdefghijk1'), 3);
  });

  test('never exceeds four segments', () {
    expect(passwordStrength('Correct-Horse-Battery-9'), 4);
  });

  test('a short password stays weak whatever it holds', () {
    expect(passwordStrength('aA1!aA1'), 1);
  });

  test('an accented letter counts as a symbol, as it does on the web', () {
    // Not in A-Z a-z 0-9, so it earns the symbol point (and "ő" is not an ASCII letter, so no case point).
    expect(passwordStrength('abcdefgő'), 2);
    expect(passwordStrength('Abcdefgő'), 3);
  });

  test('a space is a symbol', () {
    expect(passwordStrength('Abcdef g'), 3);
  });

  test('the minimum length is the one the form enforces', () {
    expect(passwordMinLength, 8);
  });
}
