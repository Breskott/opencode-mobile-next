import 'setup_contract.dart';

/// Where the app gets its one [SetupEngine]. The engine work replaces the
/// default with the real channel-backed engine; tests set [engine] to a fake.
class PhoneSetup {
  PhoneSetup._();

  static SetupEngine? _engine;

  static SetupEngine get engine =>
      _engine ?? (throw StateError('The phone setup engine is not wired yet'));

  static set engine(SetupEngine value) => _engine = value;
}
