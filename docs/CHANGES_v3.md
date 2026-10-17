# CheraSakhi v3: Tour Wallet auto-split & settle

Applies on top of **v2** (`cherasakhi_v2_quiz_access.patch`). Nothing existing was rewritten;
the original cash-ledger view is still there, one tap away.

```bash
cd kuri_collective
patch -p1 --dry-run < cherasakhi_v3_auto_split.patch
patch -p1 < cherasakhi_v3_auto_split.patch
firebase deploy --only firestore:rules,storage
```

## How the maths works
- `per-person share = total of all bills ÷ active participants`, calculated in **integer paise**.
  ₹20,000 ÷ 21 = ₹952.38. The 2 leftover paise go to the two earliest joiners, so the shares add up
  to exactly ₹20,000.
- `net = paid upfront − share`: positive is green **തിരികെ ലഭിക്കണം (Gets back)**, negative is red
  **നൽകാൻ ബാക്കി (Owes)**, and within ±₹1 is grey **തീർപ്പാക്കി (Settled)**.
- Everything is **recalculated from the raw entries on every change** (new bill, someone joins or is
  removed, a payment is recorded). Old bills are never edited, and all balances always add up to ₹0.
- If the trip also uses pool contributions or handovers from the original ledger, they're folded in.
  Money given into the pool counts as paid, and pool cash someone is still holding counts against
  them. In a bills-only trip this is exactly `bills paid − share`.
- The **settle-up plan** matches the biggest debtor with the biggest creditor, which needs at most
  (people − 1) payments. *Mark paid* records the payment as a handover, so both balances go to zero.

Checked scenarios (same vectors in `test/split_engine_test.dart`):
| Case | Result |
|---|---|
| 20 people, ₹20,000 bus paid by A | ₹1,000 each; A gets back ₹19,000 |
| 21st person joins | ₹952.38 / ₹952.39 each (Σ = ₹20,000); A gets back ₹19,047.61; newcomer owes ₹952.38 |
| Removed participant who paid ₹1,000 | Keeps the credit, no share |
| Contributions to a holder who pays from the pool | Reconciles; plan "H → A ₹400, H → B ₹100" |

## Files
**New**
- `domain/split/split_engine.dart`: pure engine (paise split, net balances, settle-up plan)
- `domain/split/trip_participant.dart`
- `data/event_split_repository.dart`: participants, join, include/exclude, delete bill
- `presentation/controllers/event_split_controller.dart`: **StateNotifier** that listens to
  participants, bills, contributions and handovers and recalculates on every change. It also
  explains what changed ("Fathima joined · share ₹1,000 → ₹952.38"), handles the actions, and
  builds the WhatsApp summary.
- `presentation/widgets/event_split_dashboard.dart`: **Event Expense Dashboard**
- `presentation/widgets/participants_sheet.dart`, `split_expense_sheet.dart`, `split_format.dart`
- `test/split_engine_test.dart`

**Edited (targeted)**
- `event_detail_screen.dart`: *Split & settle | Cash ledger* toggle, an *Add bill* button for
  participants, and two new admin menu items
- `event_models.dart` + `firestore_events_repository.dart`: `EventExpense.createdBy`
- `firestore.rules`: participants (admin manages, members can join themselves); active
  participants can add bills and delete their own
- `storage.rules`: registered members can upload bill photos
- `README.md`, `docs/firestore_schema.json`

## Things to know
- **Not compiled here**, because the Flutter SDK can't be downloaded in this workspace. The engine
  maths was run in a JavaScript port with the same scenarios. Run `flutter analyze` and `flutter test`.
- **Bill photos on the web/PWA:** the existing upload code in `firestore_events_repository.dart`
  reads files from disk, which browsers can't do. It works on Android and iOS. Bills without a photo
  work everywhere.
- **Equal split only.** "Only the 12 who had lunch" isn't supported yet, but the engine can take a
  per-bill participant list later without changing the balances screen.
- Members can't remove themselves from a trip, since that raises everyone else's share. The admin does it.
