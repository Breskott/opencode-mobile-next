# KitBreadcrumb — API freeze (wave 0)

Unit: `kit-KitBreadcrumb` (wave 1, tier 1c, kind `kit-part`, model sonnet), after kit-KitTappable (C25). Spec: kit-v2.md §5 (files: "the files breadcrumb") and §9.2 (Surfaces), with cut review C36 (`files_screen.dart` → kit-KitBreadcrumb as the file→part edge for its wave-2 unit). The map's rationale for `files` (owner verdict Fix): "One top bar with the folder as title and breadcrumb". Rules: KIT-1, KIT-3, KIT-12, KIT-32, LOOK-6, LOOK-23, LAY-8, LAY-9, LAY-10, LAY-11, A11Y-1, A11Y-4, A11Y-8, COPY-30.

## Purpose

Where you are in a folder tree, and one tap back to any folder above it. It shows the root, the folders below it and the current folder last. When the trail does not fit, the middle folders fold into "…", which opens a menu of them.

## Replaces

- **Map element, 1 on 1 page:** `files#files-breadcrumb` (`kit: none`, `kitGap` `KitBreadcrumb`; note "chips below root only").
- **Code** (`lib/ui/screens/files_screen.dart:884-925`, not in this unit's write set; its wave-2 unit adopts the part):
  - a horizontal `SingleChildScrollView` of an `ActionChip` for the root;
  - an `ActionChip` per ancestor, and a plain `Chip` for the current folder;
  - literal paddings (`symmetric(horizontal: 16)`, `start: 6`).
  - Of the file's G16 baseline this is `ActionChip` 2, `Chip` 1 and `SingleChildScrollView` 1 (of 2).
- **Copy it takes over:** the semantics words `filesProjectRoot`, `filesOpenFolder` and `filesCurrentFolder` get kit equivalents. The Files keys stay until the integrator prunes them (PROC-13).
- **Later candidates, not bound here:** the project folder browser's path (`widgets/folder_browser.dart`), when its unit wants one.

## File

- `lib/ui/kit/kit_breadcrumb.dart` (new): `KitBreadcrumb`.
- Tests: `test/kit/kit_breadcrumb_test.dart`.
- Gallery: `test/goldens/kit/kit_breadcrumb_golden_test.dart`.

## Public API

```dart
/// A folder trail. States: default, collapsed (middle folders behind "…"),
/// root only, truncated names.
class KitBreadcrumb extends StatelessWidget {
  const KitBreadcrumb({
    super.key,
    required this.rootLabel,     // "Project root", or the project's name (shown as written)
    required this.segments,      // folder names below the root, in order; the last is the current folder
    required this.onSelected,    // ValueChanged<int>: -1 = the root, i = segments[i]; never the current one
    this.breadcrumbKey,
    this.crumbKey,               // Key Function(int index)? index -1 is the root; for tests
  });

  final String rootLabel;
  final List<String> segments;
  final ValueChanged<int> onSelected;
  final Key? breadcrumbKey;
  final Key Function(int index)? crumbKey;
}
```

- **The part never builds paths.** The host splits its path and joins `segments.take(i + 1)` in `onSelected`, as Files does today (`_navigateTo(crumbs.take(i).join('/'))`).
- **Collapse rule (structural, not a parameter):**
  - The root, the parent of the current folder and the current folder are always shown.
  - Folders in between are hidden from the outermost inwards until the trail fits its width. The hidden ones become one "…" crumb.
  - A tap on "…" opens `showKitMenu` with the hidden folders, in trail order.
  - Choosing one calls `onSelected` with its index.
- **Kit copy** (ARB, `kit` prefix, en and ar):
  - `kitBreadcrumb` "Folder path" (the container);
  - `kitBreadcrumbOpen` "Open folder {folder}";
  - `kitBreadcrumbOpenRoot` "Open {root}";
  - `kitBreadcrumbCurrent` "Current folder: {folder}";
  - `kitBreadcrumbMore` "{count, plural, =1{1 more folder} other{{count} more folders}}" (the "…" label and its menu's name).

## States

| State | What shows |
|---|---|
| default | root › a › b › current: ancestors are tappable crumbs in `text2`, the current folder in `text1` semibold and not tappable |
| collapsed | root › … › parent › current, with "…" a tappable crumb that opens the hidden folders' menu |
| root only | `segments` empty: the root alone, as the current crumb (not tappable). The host may also hide the part. |
| truncated | a crumb longer than `crumbMaxWidth` keeps its start and end with "…" in the middle (A11Y-8: a name in a list may truncate in the middle); its full name is in its semantics and tooltip. The current folder may use all the room left before it truncates. |

Loading, error, working and answered are the host's (the listing below). There is no disabled state: every ancestor is always reachable, even while the listing loads. KIT-12 doc comment: "States: default, collapsed, root only, truncated".

## Tokens

- **ThemeRoles:** ancestors and "…" `text2`, current `text1`, separators `text3`. The hover fill and focus ring come from `KitTappable` (`accent` 2 px ring, LOOK-6). The part has no chip fills: the crumbs are tertiary text actions (LOOK-23, "no tonal pills").
- **KitText:** `secondary` (14/20) for every crumb. The current crumb is semibold through a `KitText.rich` span weight.
- **KitTokens:**
  - `minTarget` (48: the row height and each crumb's target);
  - `space1` (4: space around separators);
  - `space2` (8: a crumb's horizontal padding);
  - `smallIconSize` (20: the chevron separator, `AppIconography.chevronRight` via `KitIcon`, mirrored);
  - `gutter` (16: the host's rails; the part draws edge to edge within them).
- **New token (pre-wave, `_new-tokens.md`):** `KitTokens.crumbMaxWidth` = 160: the widest an ancestor crumb grows before it truncates in the middle.

## Adaptive

| Window | Behaviour |
|---|---|
| compact | one 48 dp row within the rails. It collapses as the rule says; at 412 dp a typical trail shows root › … › parent › current. |
| medium | the same row, with more folders shown before anything collapses |
| expanded / large | the same; in Files' two-pane layout it sits at the top of the list pane (the host's choice), using that pane's width, not the window's |

- **Short windows:** unchanged (one row).
- **Pointer:** hover fill on crumbs. The tooltip gives a truncated crumb's full name (LAY-11: it repeats the semantics). Right-click has no menu.
- **Keyboard (LAY-10):**
  - each ancestor and "…" is a Tab stop in trail order, and Enter or Space activates it;
  - "…" opens its menu, and the arrow keys move in it (KitMenu);
  - the current crumb is not a Tab stop.

## Accessibility

- **A container node** labelled "Folder path", with children in trail order (A11Y-4):
  - the root: "Open {root}", a button;
  - each ancestor: "Open folder {folder}", a button;
  - "…": "{count} more folders", a button with a pop-up hint;
  - the current crumb: "Current folder: {folder}", selected, not a button.
- **Separators** are excluded from semantics.
- **Targets:** every tappable crumb is at least 48 × 48 dp, and neighbouring targets do not overlap (the separators sit between the 48 dp areas; LAY-9).
- **200 % text:**
  - the row grows to the text's height (never below 48);
  - more folders collapse sooner;
  - a single long current folder wraps to two lines instead of overflowing;
  - no overflow at 320 dp (G6).

## RTL

- **The trail follows the reading direction:** in Arabic the root is at the right and the current folder at the left.
  - This is deliberate. The breadcrumb is navigation (like Back, LAY-8), not a technical value, so it does not use COPY-30's LTR block.
  - The chevrons mirror (`matchTextDirection`).
- **Each folder name** is isolated with `KitBidi.auto` (FSI…PDI), because folders are names the person chose and may mix scripts (COPY-30). A Latin folder inside an Arabic trail keeps its own order.
- **The "…" menu** lists the folders in trail order and is right-aligned in Arabic (KitMenu).

## Motion and haptics

- **No motion:** a new trail replaces the old one at once when the folder changes. A crumb must never be mid-animation when tapped.
- **The "…" menu** opens with KitMenu's own transition.
- **No haptics** (MOT-11).
- **Reduced motion:** settles after one `pump()` (G8).

## Data safety and honest state

- **The trail changes nothing:** `onSelected` asks the host to navigate.
- **The current folder cannot be chosen:** it is not a button, so a tap never triggers a pointless reload.
- **Nothing is hidden without a way to it:** every collapsed folder is in the "…" menu, and every truncated name is complete in semantics and in the tooltip.
- **Names are shown as written** (COPY-2), never shortened by the part except by the middle ellipsis, and never translated.

## Depends on

- **kit-KitTappable** (tier 1b): crumb taps, hover, focus ring and tooltip (C25).
- **kit-KitMenu** (tier 1a): `showKitMenu` for "…", already reached through KitTappable (KitTappable depends on KitMenu). No new edge.
- **kit-KitIcon** (tier 1a): the chevron at 20 dp. Tier 1, so the tier is unchanged.
- **Existing:** `KitText`, `KitTokens`, `ThemeRoles`.
- **Pre-wave seam:** `KitBidi.auto`.

Depended on by: the Files wave-2 unit (C36).

## Tests required

In `test/kit/kit_breadcrumb_test.dart`:

1. **Select:** tapping the root calls `onSelected(-1)`; tapping `segments[1]` calls `onSelected(1)`; tapping the current crumb calls nothing.
2. **Collapse:** with 8 segments at 412 dp, the root, "…", the parent and the current folder are shown. "…" opens a menu listing the hidden folders in order, and choosing the third calls `onSelected` with its index. At 1280 dp all 8 are shown with no "…".
3. **Always kept:** at 320 dp with long names, the root, the parent and the current folder are never hidden, and the current folder wraps rather than overflowing.
4. **Truncation:** a 60-character ancestor truncates in the middle, keeping its start and end, at `crumbMaxWidth`. Its semantics label and tooltip carry the full name.
5. **Semantics:** the container is "Folder path"; the children are in trail order with the labels in Accessibility; the current crumb is selected and not a button; separators are absent.
6. **Keyboard (G14):** Tab visits the root, "…", then the ancestors in order, and skips the current crumb. Enter on an ancestor calls `onSelected`.
7. **RTL:** in Arabic the root is right-most, and the chevrons point left. A Latin folder name keeps its letter order inside the trail (the isolation marks are present in the rendered string).
8. **Targets:** every tappable crumb is at least 48 × 48 dp (`androidTapTargetGuideline`), with no overlapping hit areas.
9. **Overflow and motion:** no overflow at 320, 412, 600, 840 and 1280 at text 1.0, 1.3 and 2.0, LTR and RTL (G6); settles after one `pump()` (G8).

## Galleries required

`test/goldens/kit/kit_breadcrumb_golden_test.dart`, DPR 3, Android. The scene is the breadcrumb under a top bar on `ground`, with a fixture path `lib/ui/screens/settings/advanced` under the root "oc_app".

- **Declared states × dark and light at 412×915:** `default` (3 levels), `collapsed` (7 levels), `root_only`, `truncated` (a long folder name), `focused` (keyboard focus on an ancestor). That is 10 PNGs.
- **Default × dark and light** at 360×800, 915×412, 800×1280, 1280×800 and 1600×1000: 10 PNGs.
- **Text 2.0 and Arabic** (`default`, `collapsed`) at 412×915 and 1280×800, dark. The Arabic fixture mixes an Arabic folder name and Latin ones. That is 8 PNGs.
- **Names:** `kit_breadcrumb_<state>[_ar][_text2][_WxH]_<dark|light>.png`. That is 28 PNGs.

## Non-goals

- **No path parsing or navigation:** the host does both.
- **No editing a path by typing:** that is the folder browser's `KitField`, path mode.
- **No drag and drop onto crumbs.**
- **No top bar:** KitTopBar holds the folder as its title. This part sits under it.
- **No edits to `files_screen.dart`.**

## Open questions

None. The trail follows the reading direction; the reasoning is in RTL above. The coordinator may note it beside COPY-30's LTR rule.
