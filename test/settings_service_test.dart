import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:open_library_client/features/profile/settings_service.dart';

void main() {
  test('settings persist per account and publish only after write', () async {
    final factory = newDatabaseFactoryMemory();
    SettingsService service(String id) => SettingsService(
      userId: id,
      openDatabase: () => factory.openDatabase('settings-$id'),
    );
    final first = service('reader-a');
    await first.load();
    expect(first.darkMode, isFalse);
    await first.updateAvatar(Uint8List.fromList([1, 2, 3]));
    await first.saveReaderPosition(
      '/works/OL66554W',
      const ReaderPosition(offset: 420, fontSize: 22),
    );
    await expectLater(
      first.updateAvatar(Uint8List(2 * 1024 * 1024 + 1)),
      throwsArgumentError,
    );
    expect(first.avatarBytes, [1, 2, 3]);
    await first.update(notifications: true, language: 'en', darkMode: true);
    await first.close();
    final reopened = service('reader-a');
    await reopened.load();
    expect(reopened.notifications, isTrue);
    expect(reopened.language, 'en');
    expect(reopened.darkMode, isTrue);
    expect(reopened.avatarBytes, [1, 2, 3]);
    final position = await reopened.loadReaderPosition('/works/OL66554W');
    expect(position?.offset, 420);
    expect(position?.fontSize, 22);
    await reopened.updateAvatar(null);
    expect(reopened.avatarBytes, isNull);
    await reopened.close();
    final other = service('reader-b');
    await other.load();
    expect(other.notifications, isFalse);
    expect(other.language, 'vi');
    expect(other.darkMode, isFalse);
    expect(other.avatarBytes, isNull);
    expect(await other.loadReaderPosition('/works/OL66554W'), isNull);
    await other.close();
  });
}
