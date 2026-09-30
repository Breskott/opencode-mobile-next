import 'team_project_gateway.dart';

/// Safe public failure: never retains a transport/native cause or payload.
class PhoneEngineException implements Exception {
  const PhoneEngineException(this.code);
  final String code;
  @override
  String toString() => 'PhoneEngineException($code)';
}

/// Authenticated schema-1 identity and the exact commands implemented by daemon.
class PhoneEngineHealth {
  const PhoneEngineHealth({
    required this.profileId,
    required this.engineVersion,
    required this.execution,
    required this.boundary,
    required this.oc1Verified,
    required this.oc2,
    required this.commandActions,
    this.admission = 'unknown',
    this.chatAuthority = 'unknown',
    this.boundaryReason = '',
    this.boundaryTier = 'none',
    this.restartRequired = false,
    this.globalAdmissionAuthority = false,
  });
  final String profileId, engineVersion;
  final bool execution, boundary, oc1Verified, oc2;
  final Set<TeamProjectAction> commandActions;

  /// Admission is separate from supported execution capability.
  final String admission, chatAuthority, boundaryReason;

  /// Signed confinement kind. Older schema-1 engines omit the tier; `none`
  /// then means unreported, while their existing execution flags remain valid.
  final String boundaryTier;
  final bool restartRequired, globalAdmissionAuthority;
  bool get canExecute => execution && boundary && oc1Verified && !oc2;

  factory PhoneEngineHealth.fromJson(Object? value, String expectedProfile) {
    if (value is! Map ||
        value['schemaVersion'] is! int ||
        value['schemaVersion'] != 1) {
      throw const PhoneEngineException('schemaUnsupported');
    }
    if (value['profileId'] != expectedProfile) {
      throw const PhoneEngineException('profileMismatch');
    }
    final flags = value['capabilities'];
    final actions = value['commandActions'];
    final version = value['engineVersion'];
    if (flags is! Map ||
        actions is! List ||
        actions.any((v) => v is! String) ||
        version is! String ||
        version.isEmpty ||
        [
          'execution',
          'boundary',
          'oc1Verified',
          'oc2',
        ].any((k) => flags[k] is! bool)) {
      throw const PhoneEngineException('payloadInvalid');
    }
    const tiers = {'none', 'landlock', 'proot'};
    final topTier = value['boundaryTier'];
    final capabilityTier = flags['boundaryTier'];
    if ((value.containsKey('boundaryTier') && !tiers.contains(topTier)) ||
        (flags.containsKey('boundaryTier') &&
            !tiers.contains(capabilityTier)) ||
        (value.containsKey('boundaryTier') &&
            flags.containsKey('boundaryTier') &&
            topTier != capabilityTier)) {
      throw const PhoneEngineException('payloadInvalid');
    }
    final tier = (topTier ?? capabilityTier ?? 'none') as String;
    return PhoneEngineHealth(
      profileId: expectedProfile,
      boundaryTier: tier,
      engineVersion: version,
      execution: flags['execution'] as bool,
      boundary: flags['boundary'] as bool,
      oc1Verified: flags['oc1Verified'] as bool,
      oc2: flags['oc2'] as bool,
      admission: switch (value['admission']) {
        'idle' ||
        'busy' ||
        'unknown' ||
        'observing' => value['admission'] as String,
        _ => 'unknown',
      },
      chatAuthority: value['chatAuthority'] is String
          ? value['chatAuthority'] as String
          : 'unknown',
      boundaryReason: value['boundaryReason'] is String
          ? value['boundaryReason'] as String
          : '',
      restartRequired: value['restartRequired'] == true,
      globalAdmissionAuthority: value['globalAdmissionAuthority'] == true,
      commandActions: Set.unmodifiable(
        TeamProjectAction.values.where((a) => actions.contains(a.name)),
      ),
    );
  }
}
