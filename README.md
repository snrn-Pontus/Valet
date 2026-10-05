# Valet

Small chores done for you. Valet sells your grey items and repairs your gear at a merchant, turns away duel requests, guild invites and guild charters, and clicks through a few popups that never needed a question. Tick what you want once and forget it.

Valet is part of the SNRN addon family, next to [Backhand](https://github.com/snrn-Pontus/Backhand), [Rummage](https://github.com/snrn-Pontus/Rummage), [Tally](https://github.com/snrn-Pontus/Tally) and [Grimoire](https://github.com/snrn-Pontus/Grimoire).

Built for **World of Warcraft: Forever** (Interface 16001). It only uses standard merchant, social and popup APIs, so it should also work on other clients that have them. Every chore that answers a popup is especially welcome with a controller, where each popup means moving the gamepad cursor.

## What it does

| Chore | Default | Does |
| --- | --- | --- |
| Sell grey items | On | Sells every grey item in your bags when you talk to a merchant |
| Repair all gear | On | Repairs everything at a merchant that can repair, after the greys are sold |
| Use guild funds for repairs | Off | Pays from the guild bank when your rank allows it and the guild covers the whole bill |
| Decline duel requests | On | Declines every duel request |
| Decline guild invites | On | Declines every guild invite |
| Close guild charters | On | Closes a guild or arena charter someone offers you to sign; your own still opens |
| Decline group invites from strangers | Off | Declines invites from anyone who is not a friend, Battle.net friend or guildmate |
| Confirm Bind on Pickup loot when solo | On | Picks up Bind on Pickup loot without the warning when you are not in a group |
| Accept resurrection | Off | Accepts right away, unless the player casting it is in combat |
| Accept summons | Off | Accepts right away when you are out of combat |
| Say in chat what Valet did | On | One line per sale total, repair, declined request and accepted popup |

### Selling and repairing

- Greys are sold one at a time, a moment apart, so the server does not drop sales. Chat shows the count and the total.
- Grey quest items and anything the merchant will not buy are never sold. Greys you keep with [Tally](https://github.com/snrn-Pontus/Tally) (`/tally keep`) are not sold either.
- Sold items can be bought back from the merchant's Buyback tab until you log out.
- Repairs wait until the greys are sold, so their money helps pay the bill.
- Hold **Shift** while opening a merchant to skip selling and repairing for that visit.

### Requests and popups

- The client can block guild invites on its own (Settings > Social), but not duels or charters. Valet declines all three and says who sent them.
- Bind on Pickup loot is only confirmed when you are solo, where it can only go to you. In a group you are still asked.

## Settings

Settings > AddOns > Valet, or `/valet`. With a controller, use the mouse there: like the other SNRN addons, the page stays out of the gamepad cursor's reach because Forever freezes when Settings is closed after the cursor has been inside an addon page.

## Commands

```
/valet          open the settings
/valet status   list what is turned on
/valet help     list the commands
```

## License

MIT.
