# Valet changelog

## Unreleased

- Chat has four levels: everything, summaries (the default: one line per visit, like `Sold 11 grey items for 38s, repaired for 17s.`), problems only, or nothing. Problems such as a repair you cannot afford show even when the rest is quiet. If you had turned chat off, you get problems only.
- `/valet last` shows what Valet did at the last merchant, mailbox and request of each kind this session, and what it left alone and why.
- Optional: accept group invites from friends, Battle.net friends and guildmates. Works together with declining strangers.
- A sell list per character: `/valet sell` and shift-click an item to have it sold at every merchant too, whatever its quality. Tally's keep list still wins. `/valet selllist` shows the list.
- Mail: optionally delete the letters Valet emptied when they have no text, and choose whose mail to take from (everyone, auction house and friends, or auction house only). One summary per visit, and items that could not be taken are named.
- Optional: release your spirit automatically after dying in a battleground (never anywhere else, and not when you could raise yourself).
- Optional: accept quests and turn in finished ones. Quests with several rewards to choose from, or a cost to turn in, wait for you; a single reward is taken unless you turn that off.
- Optional: accept quests shared by group members, friends and guildmates.
- Optional: click through gossip that has only one option and no quests (never the innkeeper's home, a spirit healer or a talent reset, and never in dungeons or raids).
- Restocking per character: `/valet restock [Rough Arrow] 800` keeps that many in your bags, bought at any merchant that sells it after selling and repairing. Never below your money reserve, never more than your bags hold.
- A **Train all** button at class and profession trainers (or `/valet train`): learns every available skill, cheapest first, never below your money reserve and never a new profession.
- Optional: skip cinematics and movies that already played on one of your characters, like the race intro of your next character. Anything Valet has not seen plays.
- Presets: Conservative, Convenient and Hands off, at the top of the settings page or with `/valet preset`. Each shows what it changes before flipping anything, and every switch stays editable.
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
