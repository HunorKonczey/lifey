import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/core/auth/current_roles_provider.dart';
import 'package:lifey/features/auth/application/auth_controller.dart';
import 'package:lifey/features/auth/domain/auth_user.dart';

/// Stands in for the real controller so these tests don't need storage or a
/// network — the roles themselves come from the JWT either way.
class _FakeAuthController extends AuthController {
  _FakeAuthController(this._user);

  final AuthUser? _user;

  @override
  Future<AuthUser?> build() async => _user;
}

ProviderContainer _containerFor(AuthUser? user) {
  final container = ProviderContainer(
    overrides: [authControllerProvider.overrideWith(() => _FakeAuthController(user))],
  );
  addTearDown(container.dispose);
  return container;
}

AuthUser _user(List<String> roles) => AuthUser(
      id: 7,
      email: 'user@example.com',
      roles: roles,
    );

void main() {
  Future<ProviderContainer> ready(AuthUser? user) async {
    final container = _containerFor(user);
    await container.read(authControllerProvider.future);
    return container;
  }

  test('a plain client is not a trainer', () async {
    final container = await ready(_user(['ROLE_USER']));

    expect(container.read(isTrainerProvider), isFalse);
    expect(container.read(currentUserIdProvider), 7);
  });

  test('a trainer is recognised', () async {
    final container = await ready(_user(['ROLE_USER', 'ROLE_TRAINER']));

    expect(container.read(isTrainerProvider), isTrue);
  });

  test('a dual-role account is a trainer *and* keeps its client identity', () async {
    // The case that decides the mixed conversation list: being a trainer is
    // additive, it never replaces being a user.
    final container = await ready(_user(['ROLE_USER', 'ROLE_TRAINER']));

    expect(container.read(currentRolesProvider), contains('ROLE_USER'));
    expect(container.read(isTrainerProvider), isTrue);
  });

  test('a super admin without ROLE_TRAINER is not treated as one', () async {
    final container = await ready(_user(['ROLE_USER', 'ROLE_SUPER_ADMIN']));

    expect(container.read(isTrainerProvider), isFalse);
  });

  test('an empty roles claim is handled, not assumed', () async {
    final container = await ready(_user([]));

    expect(container.read(currentRolesProvider), isEmpty);
    expect(container.read(isTrainerProvider), isFalse);
  });

  test('signed out means no roles and no user id', () async {
    final container = await ready(null);

    expect(container.read(currentRolesProvider), isEmpty);
    expect(container.read(isTrainerProvider), isFalse);
    expect(container.read(currentUserIdProvider), isNull);
  });
}
