# Valet changelog

## Unreleased

- Chat has four levels: everything, summaries (the default: one line per visit, like `Sold 11 grey items for 38s, repaired for 17s.`), problems only, or nothing. Problems such as a repair you cannot afford show even when the rest is quiet. If you had turned chat off, you get problems only.
- `/valet last` shows what Valet did at the last merchant, mailbox and request of each kind this session, and what it left alone and why.
- Optional: accept group invites from friends, Battle.net friends and guildmates. Works together with declining strangers.
- A sell list per character: `/valet sell` and shift-click an item to have it sold at every merchant too, whatever its quality. Tally's keep list still wins. `/valet selllist` shows the list.
- Hold Shift as a merchant, mailbox or other interaction opens and Valet leaves that visit alone: one rule for every chore.

## 0.1.0 — First release

Valet is part of the SNRN addon family.

- Sells grey items at a merchant, one per moment so the server does not drop any, and prints the total. Grey quest items, items the merchant will not buy and greys on Tally's keep list stay.
- Repairs all gear at a merchant that can repair, after the greys are sold. Can use guild funds when your rank allows it.
- Takes the gold from your mail when you open a mailbox, and optionally the items until your bags are full. Cash on delivery and Game Master mail are left alone.
- Hold Shift while opening a merchant or mailbox to skip its chores for that visit.
- Declines duel requests and guild invites, and closes guild charters others offer you to sign.
- Optional: decline group invites from anyone who is not a friend or guildmate.
- Confirms Bind on Pickup loot without a popup when you are solo.
- Optional: accept resurrection (unless the caster is in combat) and summons (out of combat).
- Settings > AddOns > Valet, or `/valet`. `/valet status` lists what is on.
