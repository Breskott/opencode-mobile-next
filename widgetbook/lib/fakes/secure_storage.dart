import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// In-memory stand-in for the Keystore, so the catalog never touches the
/// browser's crypto storage (which needs a secure origin). Only the calls the
/// profile store makes are answered.
class MemorySecureStorage implements FlutterSecureStorage {
  final _values = <String, String>{};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final args = invocation.namedArguments;
    final key = args[#key] as String?;
    switch (invocation.memberName) {
      case #read:
        return Future<String?>.value(_values[key]);
      case #readAll:
        return Future<Map<String, String>>.value(Map.of(_values));
      case #write:
        final value = args[#value] as String?;
        if (value == null) {
          _values.remove(key);
        } else {
          _values[key!] = value;
        }
        return Future<void>.value();
      case #delete:
        _values.remove(key);
        return Future<void>.value();
      case #deleteAll:
        _values.clear();
        return Future<void>.value();
      case #containsKey:
        return Future<bool>.value(_values.containsKey(key));
    }
    return super.noSuchMethod(invocation);
  }
}
