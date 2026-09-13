# E7 reader preferences and Arabic readiness

Finish line: Files offers a remembered source-first order without hiding any entries, and file/chat/review readers share a remembered code-wrap preference, with localized reader controls, RTL chrome and LTR technical content.

Non-goals: alter server ordering contracts, translate source content, or add settings toolbars to every file format. Findings: FILES-08, REVIEW-08, E7.

## Changed journeys

- Files → search field's File order action → Source first / Default order. Source first stably moves recognized generated/cache folders and generated outputs behind other entries. It never removes entries; the server's relative order stays intact within each group. Normal order restores the exact returned sequence. Deleted-file review entries, search and folder retry keep their existing behavior.
- A wrap choice in a code block, its full-screen snapshot, a unified diff or a focused source reader is shared with other readers of that profile. Before the first explicit choice, each existing compact/wide default is preserved. Split diff keeps its side-by-side horizontal canvas and hides the inapplicable wrap action.
- Choices are saved as `oc.readerPreferences.<profileId>`. Failed saves keep the last displayed choice and report failure. Profiles have independent choices; null-profile previews are ephemeral. Profile deletion must drain accepted reader writes before the existing generic preference sweep.
- Focused source rows now grow with font scale and wrapping, while target-line navigation uses measured row heights. Review's horizontal width follows its longest source line instead of clipping content at a fixed 760px canvas. Horizontal code navigation starts from the left in RTL; labels and controls keep the user's reading direction. Selection actions reflow at narrow widths.
- Files and review authored prose, errors, symbol kinds, status labels, selection summaries, action menus and preview notices use localization keys. Source, paths, filenames, MIME values, server errors and Git patch syntax remain original. Existing localized PDF, SVG and delimited-table controls were retained.

## Integration contract

Owned `lib/ui/widgets/reader_preferences.dart` exports:

```dart
ReaderPreferencesScope({
  required String? profileId,
  required SharedPreferences prefs,
  required Widget child,
})
```

Install this around MaterialApp's builder child (above its Navigator) with the active profile ID and `controller.store.prefs`.

Owned `lib/state/reader_preferences.dart` exports `ReaderPreferencesStore.drain(String profileId)`. Await this alongside existing pending-store drains before `ConnectionController._deleteProfileAndLocalData` computes `scopedKeys`. The coordinator owns these two app/controller integration edits.

## Localization

New Arabic keys are in [messages_ar.json](messages_ar.json); root merges them with the complete existing corpus. A separate Arabic corpus worker reviewed this fragment read-only; count grammar and shared Git terminology were corrected. No credentials, server configuration responses or Mobbin data were read for this slice.

## Evidence

Source and fixtures prepared; focused checks await the shared serial slot. No passing-check or runtime claim yet. The new [reader test file](../../../test/reader_preferences_test.dart) covers persistence, deletion, held saves, storage refusal, profile switching, source ordering and reopening, shared wrap with a pushed snapshot, RTL review selection and focused source at 320dp/2.5x text.

Optional capture output: `READER_CAPTURE_DIR=/absolute/output flutter test --concurrency=1 test/reader_preferences_test.dart`. Fixture captures currently exercise RTL geometry with English text; complete Arabic app/corpus verification belongs to the integrated candidate.
