import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kPasscodeHash = 'me_mine_passcode_sha256';

final FlutterSecureStorage passcodeSecureStorage = FlutterSecureStorage();

Future<void> writePasscodeHash(String hash) async {
  await passcodeSecureStorage.write(key: _kPasscodeHash, value: hash);
}

Future<String?> readPasscodeHash() =>
    passcodeSecureStorage.read(key: _kPasscodeHash);

Future<void> clearPasscodeHash() async {
  await passcodeSecureStorage.delete(key: _kPasscodeHash);
}
