import '../../l10n/app_localizations.dart';
import 'setup_contract.dart';
import 'setup_engine.dart';

/// Where the app gets its one [SetupEngine]: the channel-backed engine
/// (setup_engine.dart) unless a test sets [engine] to a fake.
class PhoneSetup {
  PhoneSetup._();

  static SetupEngine? _engine;

  static SetupEngine get engine => _engine ??= ChannelSetupEngine();

  static set engine(SetupEngine value) => _engine = value;

  /// Called by the app shell once it can start and connect to the in-app
  /// server: the engine's last step goes through [finisher], and its words
  /// follow the app's own language choice ([strings]).
  static void attach({
    required SetupFinisher finisher,
    AppLocalizations Function()? strings,
  }) {
    final current = engine;
    if (current is! ChannelSetupEngine) return;
    current.finisher = finisher;
    if (strings != null) current.strings = strings;
  }
}
