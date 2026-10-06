# Valet

Small chores done for you. Valet sells your grey items, repairs your gear and restocks what you use at a merchant, empties your mail at a mailbox, accepts and turns in quests, clicks through one-option gossip, turns away duel requests, guild invites and guild charters, and clicks through a few popups that never needed a question. Tick what you want once and forget it.

Valet is part of the SNRN addon family, next to [Backhand](https://github.com/snrn-Pontus/Backhand), [Rummage](https://github.com/snrn-Pontus/Rummage), [Tally](https://github.com/snrn-Pontus/Tally) and [Grimoire](https://github.com/snrn-Pontus/Grimoire).

Built for **World of Warcraft: Forever** (Interface 16001). It only uses standard merchant, mail, social and popup APIs, so it should also work on other clients that have them. Every chore that answers a popup is especially welcome with a controller, where each popup means moving the gamepad cursor.

## What it does

| Chore | Default | Does |
| --- | --- | --- |
| Sell grey items | On | Sells every grey item in your bags when you talk to a merchant |
| Repair all gear | On | Repairs everything at a merchant that can repair, after the greys are sold |
| Use guild funds for repairs | Off | Pays from the guild bank when your rank allows it and the guild covers the whole bill |
| Never spend below | 0 gold | Restocking and Train All stop before your money drops below this |
| Take gold from the mail | On | Takes the gold from every letter when you open a mailbox |
| Take items from the mail | Off | Takes the attached items too, until your bags are full |
| Delete the letters it empties | Off | Deletes a letter Valet emptied once nothing is left to read |
| Take from | Everyone | Everyone, auction house and friends, or auction house only |
| Accept quests | Off | Accepts quests from NPCs, objects and items, and picks them from an NPC's list |
| Turn in finished quests | Off | Hands in finished quests when there is no reward to choose |
| Take a quest's only reward | On | With turn-ins on, also takes a quest's single reward |
| Skip gossip with only one option | Off | Clicks through gossip that has one option and no quests |
| Accept quests shared by people you know | Off | Accepts quests shared by group members, friends and guildmates |
| Decline duel requests | On | Declines every duel request |
| Decline guild invites | On | Declines every guild invite |
| Close guild charters | On | Closes a guild or arena charter someone offers you to sign; your own still opens |
| Accept group invites from friends and guildmates | Off | Joins right away when a friend, Battle.net friend or guildmate invites you |
| Decline group invites from strangers | Off | Declines invites from anyone who is not a friend, Battle.net friend or guildmate |
| Confirm Bind on Pickup loot when solo | On | Picks up Bind on Pickup loot without the warning when you are not in a group |
| Accept resurrection | Off | Accepts right away, unless the player casting it is in combat |
| Accept summons | Off | Accepts right away when you are out of combat |
| Release in battlegrounds | Off | Releases your spirit right after you die in a battleground |
| Skip cinematics you have seen | Off | Stops a cinematic or movie that already played on one of your characters |
| Say in chat | Summaries | Everything, summaries, problems only or nothing; see below |

### Selling and repairing

- Greys are sold one at a time, a moment apart, so the server does not drop sales. Chat shows the count and the total.
- Grey quest items and anything the merchant will not buy are never sold. Greys you keep with [Tally](https://github.com/snrn-Pontus/Tally) (`/tally keep`) are not sold either.
- To sell other items as well, type `/valet sell` and shift-click the item into chat (or give its item ID). It is sold at every merchant from then on, whatever its quality, as long as the merchant buys it and Tally does not keep it. The list is per character: `/valet selllist` shows it, `/valet sell` with the same item takes it off, `/valet sell clear` empties it. Chat says how many greys and how many listed items were sold.
- To keep an item in stock, type `/valet restock`, shift-click the item into chat and add how many to keep: `/valet restock [Rough Arrow] 800`. Every merchant that sells it for gold buys the difference after selling and repairing, one purchase at a time. Items sold in batches are bought a batch at a time, so you may end up a little above the number. Rules are per character: `/valet restock` alone lists them, a count of 0 removes one, `/valet restock clear` removes all.
- Restocking never buys anything you did not list, never pays with tokens or honor, stops when your bags are full and never spends below **Never spend below** (gold, on the settings page). Chat says what was bought and for how much; `/valet last` also says why an item was skipped.
- Sold items can be bought back from the merchant's Buyback tab until you log out.
- Repairs wait until the greys are sold, so their money helps pay the bill.
- Hold **Shift** while opening a merchant to skip selling, repairing and restocking for that visit.

### Mail

- Auction sales, refunds and gold from other players are collected as soon as the inbox loads. Turn on **Take items from the mail** to collect won and expired auctions and items from other players too.
- Cash on delivery mail and mail from a Game Master are never touched; open those yourself.
- Items are taken until your bags are full, and chat says so when some are left. An item the server refuses, like a unique item you already carry, is tried three times and then left.
- Letters with text stay in the inbox after they are emptied; auction house mail disappears on its own. Turn on **Delete the letters it empties** to have Valet delete the others too: only letters it emptied itself this visit, with no text, that the client lets you delete rather than return.
- **Take from** limits whose letters Valet touches: everyone, the auction house plus friends, Battle.net friends and guildmates, or the auction house only. Other letters stay exactly as they are.
- One line per visit sums it up, like `Took 7g 42s and 14 items from 11 letters.` Items the server refuses and full bags are called out separately.
- Hold **Shift** while opening the mailbox to skip it for that visit.

### Quests and gossip

- Valet never chooses for you: a quest with several rewards to pick from, a turn-in that costs money and gossip with two or more options all wait for you.
- Grey (trivial) quests in an NPC's list are not picked up.
- Gossip is only skipped when it has a single option and no quests, and only for Continue pages and the service you came for (flight master, vendor, trainer, banker, battlemaster, guild charter, tabard). Never the innkeeper's "make this inn your home", a spirit healer or a talent reset, and never in dungeons or raids, where a lone option can start an event.
- Shared quests are only accepted from group members, friends, Battle.net friends and guildmates, including escort quests they start. A stranger's quest gets the normal window, even with **Accept quests** on.
- Hold **Shift** as you talk to the NPC to handle the whole conversation yourself.

### Trainers

- A **Train all** button on the trainer window learns everything the trainer lists as available, cheapest first, one at a time. It only acts when you press it (or type `/valet train` at the trainer, handy with a controller). Its tooltip shows how many skills and the total cost.
- It never learns a new profession for you, stops before your money drops below **Never spend below**, and says what it learned and spent, and what is left if the money ran short. Skills hidden by the trainer's filter are not counted.

### Requests and popups

- The client can block guild invites on its own (Settings > Social), but not duels or charters. Valet declines all three and says who sent them.
- Friends, Battle.net friends and guildmates count as trusted. With both invite settings on, their invites are accepted and everyone else's are declined; with only the accept setting on, anyone else still gets the normal popup.
- Releasing is only automatic inside a battleground, never in the open world, dungeons or raids, and not when you could raise yourself with a Soulstone or Reincarnation.
- Bind on Pickup loot is only confirmed when you are solo, where it can only go to you. In a group you are still asked.

### Cinematics

- Valet remembers every movie and in-game cinematic that plays (movies by their ID, cinematics by the spot where they start) on any character. Only those are ever skipped, so something new always plays, including anything that played before Valet was installed. Hold **Shift** as one starts to watch it anyway.

### Hold Shift to do it yourself

One rule covers every chore that acts on something you open: hold **Shift** as the merchant, mailbox or other interaction opens and Valet leaves that visit alone. It only applies to that visit; your settings stay as they are.

### Chat and `/valet last`

Pick how much Valet says in chat:

- **Everything**: every action as it happens, and every chore it left alone and why.
- **Summaries** (default): one line per merchant or mailbox visit and per request, once it is over, like `Sold 11 grey items for 38s, repaired for 17s.`
- **Problems only**: only what needs you, like a repair you cannot afford or bags too full for the mail.
- **Nothing**: not even problems.

Whatever you pick, `/valet last` shows what Valet did at the last merchant, mailbox and request of each kind this session, including what it left alone (Shift held, not enough money, ...). It is handy when chat is quiet, and for bug reports. Nothing of it is saved between sessions.

### Presets

Three starting points, at the top of the settings page or with `/valet preset`:

- **Conservative**: sell greys, repair, and turn away duels, guild invites, charters and the Bind on Pickup popup. Nothing else.
- **Convenient**: Conservative, plus emptying the mail, accepting and turning in quests, and skipping one-option gossip.
- **Hands off**: Convenient, plus invites and shared quests from people you know, resurrections, summons, releasing in battlegrounds and skipping cinematics you have seen.

A preset is not a separate mode: it shows which switches it turns on and off, asks, flips them, and leaves every switch yours to change afterwards. It never touches preferences that are not chores (chat, guild repairs, the money reserve, whose mail to take, stranger invites, deleting letters, taking a quest's only reward), and a chore added in a later version is not switched on by a preset unless that version says so.

## Settings

Settings > AddOns > Valet, or `/valet`. With a controller, use the mouse there: like the other SNRN addons, the page stays out of the gamepad cursor's reach because Forever freezes when Settings is closed after the cursor has been inside an addon page.

## Commands

```
/valet                          open the settings
/valet status                   list what is turned on
/valet last                     what Valet did lately, and what it left alone
/valet sell <item>              always sell an item on this character; again to stop
/valet selllist                 list the items you always sell
/valet restock <item> <count>   keep that many in your bags; 0 to stop
/valet train                    at a trainer: learn everything available
/valet preset [name] [apply]    list the presets, show what one changes, or apply it
/valet help                     list the commands
```

## License

MIT.
