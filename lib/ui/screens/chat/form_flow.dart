import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import '../../../api/models.dart' show ApiException;
import '../../../api2/models.dart' show Api2FormInfo;
import '../../../l10n/app_localizations.dart';
import '../../../state/connection.dart';
import '../../kit/kit_dialog.dart';
import '../../widgets/form_renderer.dart';
import '../../widgets/product_states.dart' show productErrorText;
import '../../widgets/request_routes.dart';

AppLocalizations _chatL10n(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// Answers a form's card shows while they are on their way (STATE-10), or
/// the server's refusal once they were not accepted.
@immutable
class FormAnswerReceipt {
  const FormAnswerReceipt({required this.since, this.error});

  final DateTime since;

  /// The refusal in words; null while the answers are on their way.
  final String? error;

  bool get failed => error != null;
}

/// The one ledger of form answers in flight, keyed by form id: the form's
/// sheet writes it, the form's card in the conversation reads it, so the
/// receipt shows where the request lives (K2 §4.8).
class FormAnswerReceipts extends ChangeNotifier {
  FormAnswerReceipts._();

  static final instance = FormAnswerReceipts._();

  final Map<String, FormAnswerReceipt> _receipts = {};

  FormAnswerReceipt? receiptFor(String formId) => _receipts[formId];

  void _set(String formId, FormAnswerReceipt? receipt) {
    if (receipt == null) {
      if (_receipts.remove(formId) == null) return;
    } else {
      _receipts[formId] = receipt;
    }
    notifyListeners();
  }
}

/// Presents a pending form through the shared form presenter and routes its
/// reply/cancel through the connection's form state, applying the locked
/// error contract (design doc §2):
///
/// - a 400 `FormInvalidAnswerError` (or any other failure) rethrows into the
///   form, which stays open with the message in its error notice, and the
///   card in the conversation shows the refusal;
/// - a 409 `FormAlreadySettledError` closes the form and says, in one alert,
///   that it was answered on another device (nothing was sent from here).
///
/// Draft carry (P7.1): answers are kept per form until they are sent or the
/// form is dismissed, so swipe, back and reopening bring them back; with the
/// connection's profile, typed answers also survive a restart.
Future<void> presentConnectionForm(
  BuildContext context,
  ConnectionController connection,
  Api2FormInfo form,
) async {
  final scope = connection.returnBriefScope;
  bool current() =>
      connection.returnBriefScope == scope &&
      identical(connection.forms[form.id], form);
  if (!current()) return;
  final routes = RequestRoutes(changes: connection, isPending: current);
  final receipts = FormAnswerReceipts.instance;
  final profileId = connection.profile?.id ?? connection.store.activeId;
  var settledElsewhere = false;
  bool answeredElsewhere(Object error) =>
      error is ApiException &&
      (error.errorTag == 'FormAlreadySettledError' ||
          error.errorTag == 'FormNotFoundError');

  try {
    await presentForm(
      context,
      form: form,
      routes: routes,
      profileId: profileId == null || profileId.isEmpty ? null : profileId,
      onSubmit: (answer) async {
        if (!current()) {
          throw StateError(
            _chatL10n(context).chatUiTheFormOrProjectChangedReopenThe,
          );
        }
        receipts._set(form.id, FormAnswerReceipt(since: clock.now()));
        try {
          await connection.replyForm(form.id, answer);
          receipts._set(form.id, null);
        } catch (error) {
          if (answeredElsewhere(error)) {
            receipts._set(form.id, null);
            settledElsewhere = true;
            return;
          }
          receipts._set(
            form.id,
            FormAnswerReceipt(
              since: clock.now(),
              error: productErrorText(error),
            ),
          );
          rethrow;
        }
      },
      onCancel: () async {
        if (!current()) {
          throw StateError(
            _chatL10n(context).chatUiTheFormOrProjectChangedReopenThe,
          );
        }
        try {
          await connection.cancelForm(form.id);
        } catch (error) {
          if (answeredElsewhere(error)) {
            settledElsewhere = true;
            return;
          }
          rethrow;
        }
      },
    );
  } finally {
    routes.close();
  }
  if (settledElsewhere && context.mounted) {
    final l10n = _chatL10n(context);
    await showKitAlert(
      context,
      title: l10n.chatUiAlreadyAnsweredElsewhere,
      body: l10n.formFlowAnsweredElsewhereBody,
      alertKey: const Key('form-answered-elsewhere'),
    );
  }
}
