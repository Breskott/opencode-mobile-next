# Screen standard

Every screen in the app follows this. Items marked **[auto]** are checked by a test on every catalog rebuild. A build that breaks one of them is flagged on `/status.json` and in the gallery.

The size limits apply to a phone at 412×915 with text size 1.0.

## 1. One job per screen
- The title names the job.
- There is at most **one** main action. It is a filled button, visible without scrolling. **[auto]**
- Every brief starts with two things: the screen's job in one sentence, and a **cut list** of what to remove. A brief is never only additions.

## 2. Content budget
- **First view:** at most **7 items** (rows, cards or blocks) before you scroll. **[auto]**
- **A row** has a title and **at most one** supporting line, so **at most 2 lines of text** in the first view. A third line belongs on the detail page. **[auto]**
- **Each fact once:**
  - Never repeat the connection name, the state or the plan within one item.
  - Show a state as a pill **or** as a line, never both.
- **Pills** only for exceptions: near limit, out, needs you. A normal state has no pill.
- **At most 3 text sizes** per screen: title, body and caption. **[auto]**
- **At most one bold text per row.**
- **Explanations:** at most one per screen, at most 2 lines. Anything longer goes behind "Learn more" or the Details fold.
- **Technical text** (ids, paths, versions, hosts) appears only inside `KitDetailsFold`.

## 3. Show more one tap away
- The list shows each thing's state plus the one action for it. The detail page shows the full picture. The Details fold holds the technical facts.
- Rare settings go at the bottom or on a sub-page, never in the first view.

## 4. Colour
- The accent colour is for the main action and for amounts that are fine. Amber means "needs you" only. **Red is never used. [auto]**
- Cards only for things you tap. A group of settings is one section, not a card per row.

## 5. Nothing cut off
- No clipped or "…" text in any state, in English or Arabic, at text size 1.0 or 2.0. **[auto]**
- No overflow stripes. **[auto]**

## 6. States every screen has in the catalog
- loading
- empty
- typical
- many items or long text
- needs setup or needs you
- error or offline

Each of them is also checked in dark mode, in Arabic, and at text size 2.0.

## 7. How a screen gets built
1. **Reference:** 2–3 real apps showing the same kind of screen (Mobbin).
2. **Mock:** the screen in the catalog with fake data, or an HTML mock. You approve the mock before any app code changes.
3. **Build** to the mock.
4. **Check:** the catalog screenshots against the approved mock, plus the **[auto]** checks. Only then does an APK go to you.
