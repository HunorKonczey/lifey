import 'package:flutter_test/flutter_test.dart';
import 'package:lifey/features/settings/domain/user_settings.dart';

/// "Show when I'm online" (LIF-153): visible unless somebody said otherwise.
void main() {
  Map<String, dynamic> json({Object? online = 'absent'}) => {
        'unitSystem': 'METRIC',
        'theme': 'SYSTEM',
        'language': 'SYSTEM',
        if (online != 'absent') 'chatOnlineVisible': online,
      };

  test('a server that predates the switch says nothing, which is visible', () {
    expect(UserSettings.fromJson(json()).chatOnlineVisible, isTrue);
    expect(const UserSettings.defaults().chatOnlineVisible, isTrue);
  });

  test('an explicit off is kept, goes back out, and copyWith flips it without touching anything else', () {
    final hidden = UserSettings.fromJson(json(online: false));

    expect(hidden.chatOnlineVisible, isFalse);
    expect(hidden.toJson()['chatOnlineVisible'], isFalse);
    expect(hidden.copyWith(chatOnlineVisible: true).chatOnlineVisible, isTrue);
    expect(hidden.copyWith(chatPushEnabled: false).chatOnlineVisible, isFalse);
  });
}
