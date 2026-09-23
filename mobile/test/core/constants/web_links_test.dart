import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/constants/web_links.dart';

/// The base is a `--dart-define` (`WEB_BASE_URL`) so it can follow the
/// deployment; these pin the default and the paths hung off it.

void main() {
  test('programs open on the deployed web app by default', () {
    expect(WebLinks.adminPrograms, 'https://lifey-theta.vercel.app/admin/programs');
    expect(WebLinks.adminProgram(12), 'https://lifey-theta.vercel.app/admin/programs/12');
  });

  test('billing and the legal pages share the same base', () {
    expect(WebLinks.adminBilling, 'https://lifey-theta.vercel.app/admin/billing');
    expect(WebLinks.terms('hu'), 'https://lifey-theta.vercel.app/hu/legal/terms');
    expect(WebLinks.privacy('en'), 'https://lifey-theta.vercel.app/en/legal/privacy');
  });

  test('an unsupported locale falls back to the site default', () {
    expect(WebLinks.terms('de'), contains('/hu/legal/terms'));
  });
}
