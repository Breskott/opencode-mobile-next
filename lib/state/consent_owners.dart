import 'package:shared_preferences/shared_preferences.dart';

import 'in_flow_consent.dart';
import 'mobile_download_consent.dart';
import 'repeated_permission_consent.dart';

/// The one owner per saved server of its in-flow consents (P6.7): the
/// answers asked once at the moment they matter ([InFlowConsent]) and the
/// "Always allow this" invitation history ([RepeatedPermissionConsent]).
///
/// Every place that asks (the phone server's first start, the notification
/// question in a conversation, a permission's third identical ask) and the
/// Settings page that shows the answers share these instances, so a claim
/// made in one is seen by the others at once.
/// [ConnectionController.deleteProfileAndLocalData] calls [closeProfile]
/// before its `oc.*.<profileId>` sweep, so a write in flight cannot bring a
/// deleted server's answers back.
abstract final class ConsentOwners {
  static final _inFlow = Expando<Map<String, Future<InFlowConsent>>>(
    'in-flow-consent',
  );
  static final _loaded = Expando<Map<String, InFlowConsent>>(
    'in-flow-consent-loaded',
  );
  static final _repeated = Expando<Map<String, RepeatedPermissionConsent>>(
    'repeated-permission-consent',
  );
  static final _invited = Expando<Map<String, Set<String>>>(
    'always-allow-invited',
  );

  static final _mobile = Expando<Map<String, Future<MobileDownloadConsent>>>(
    'mobile-download-consent',
  );
  static final _mobileLoaded = Expando<Map<String, MobileDownloadConsent>>(
    'mobile-download-consent-loaded',
  );

  static Future<MobileDownloadConsent> mobileDownloads(
    SharedPreferences prefs,
    String profileId,
  ) {
    final futures = _mobile[prefs] ??= {};
    return futures.putIfAbsent(profileId, () async {
      try {
        final consent = await MobileDownloadConsent.load(
          prefs,
          profileId: profileId,
        );
        (_mobileLoaded[prefs] ??= {})[profileId] = consent;
        return consent;
      } catch (_) {
        futures.remove(profileId);
        rethrow;
      }
    });
  }

  static MobileDownloadConsent? mobileDownloadsLoaded(
    SharedPreferences prefs,
    String profileId,
  ) => _mobileLoaded[prefs]?[profileId];

  /// [profileId]'s in-flow consents. Throws a content-free [StateError]
  /// when its storage cannot be read; the next call tries again.
  static Future<InFlowConsent> inFlow(
    SharedPreferences prefs,
    String profileId,
  ) {
    final futures = _inFlow[prefs] ??= {};
    return futures.putIfAbsent(profileId, () async {
      try {
        final consent = await InFlowConsent.load(prefs, profileId: profileId);
        (_loaded[prefs] ??= {})[profileId] = consent;
        return consent;
      } catch (_) {
        futures.remove(profileId);
        rethrow;
      }
    });
  }

  /// [profileId]'s in-flow consents when already loaded, for synchronous
  /// reads (whether a question is still owed); null before [inFlow] ran.
  static InFlowConsent? inFlowLoaded(
    SharedPreferences prefs,
    String profileId,
  ) => _loaded[prefs]?[profileId];

  /// [profileId]'s "Always allow this" invitation history.
  static RepeatedPermissionConsent repeated(
    SharedPreferences prefs,
    String profileId,
  ) => (_repeated[prefs] ??= {}).putIfAbsent(
    profileId,
    () => RepeatedPermissionConsent(prefs, profileId: profileId),
  );

  /// Requests whose invitation is showing now, by `sessionID/requestID`,
  /// so a card rebuilt for the same request keeps its invitation (the
  /// history answers a replayed request with "not again").
  static Set<String> invitedRequests(
    SharedPreferences prefs,
    String profileId,
  ) => (_invited[prefs] ??= {}).putIfAbsent(profileId, () => <String>{});

  /// Closes [profileId]'s owners and drains their writes, BEFORE the
  /// profile deletion sweep removes their keys.
  static Future<void> closeProfile(
    SharedPreferences prefs,
    String profileId,
  ) async {
    _invited[prefs]?.remove(profileId);
    _mobileLoaded[prefs]?.remove(profileId);
    final mobile = _mobile[prefs]?.remove(profileId);
    if (mobile != null) {
      try {
        await (await mobile).close();
      } catch (_) {
        // A failed load created no writable owner.
      } finally {
        _mobileLoaded[prefs]?.remove(profileId);
      }
    }
    _loaded[prefs]?.remove(profileId);
    final inFlow = _inFlow[prefs]?.remove(profileId);
    final repeated = _repeated[prefs]?.remove(profileId);
    if (inFlow != null) {
      try {
        await (await inFlow).close();
      } catch (_) {
        // Nothing was loaded, so nothing can be written.
      }
    }
    await repeated?.close();
  }
}
