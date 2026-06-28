# TODO

Running todo list for the project. Add new items under the appropriate section;
move finished items to **Done** with the date.

## Open

### Content

- [ ] **Convert all Persian (Solar Hijri / Jalali) calendar dates to Gregorian.**
  Sweep every chapter for Persian-calendar dates and record the Gregorian
  equivalent alongside each one. The author dates and the per-session delivery
  dates use the Iranian Solar Hijri calendar (months: Farvardin, Ordibehesht,
  … Aban …), which maps cleanly to a fixed Gregorian day.
  - Known so far:
    - Author's Introduction: **3 Aban 1353 SH = Friday, 25 October 1974**
      (the AIM English edition prints this converted date; our edition keeps the
      Persian original).
    - Session delivery dates appear in `book_en/sessions/session_NN.md` headers
      (e.g. session 1: "28 Shahrivar 1353 / 2 Ramadan 1394") — these pair a Solar
      Hijri date with a lunar Hijri (Ramadan) date; verify/convert each.
  - Scope: find the rest, convert, and decide how to present (keep Persian +
    add Gregorian in a note, vs. convert in place). Keep terminology consistent.

## Done
