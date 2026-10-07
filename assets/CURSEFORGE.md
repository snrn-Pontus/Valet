# SNRN Valet

**Set and forget chores: sell greys, repair, collect your mail, and no more duel or guild spam.**

Valet sells your grey items and repairs your gear when you talk to a merchant, collects your mail at a mailbox, declines duel requests, guild invites and guild charters, and clicks through popups that never needed a question. Tick what you want once on the settings page and forget it.

## What's new

- **0.3.0**: Accept and turn in quests, skip one-option gossip, restock items at merchants, a Train all button at trainers, skip cinematics you have seen, and presets.
- **0.2.0**: A sell list, mail cleanup and a sender filter, accepting invites from friends, auto-release in battlegrounds, quieter chat and `/valet last`.
- **0.1.0**: First release.

Full history on the Changelog tab of each file.

## What you get

- **Sell greys** at any merchant, with the total in chat. Grey quest items and greys on Tally's keep list stay.
- **Sell list** per character: anything you add with `/valet sell` is sold too, whatever its quality.
- **Repair** everything after the greys are sold, optionally from guild funds.
- **Collect mail**: the gold from every letter, and optionally the items until your bags are full. Choose whose mail to take from, and optionally delete the empty letters. Cash on delivery mail is left alone.
- **Decline** duel requests, guild invites and guild charters, and optionally group invites from strangers.
- Optionally **accept** group invites from friends and guildmates.
- Optionally **release** your spirit automatically in battlegrounds.
- **Confirm** Bind on Pickup loot when you are solo.
- Optionally **accept** resurrections and summons.
- Optionally **accept and turn in quests**, and accept quests shared by people you know. Quests with rewards to choose from wait for you.
- Optionally **skip gossip** that has only one way forward, like the flight master or vendor you came for.
- **Restock** per character: keep a set number of arrows, food or reagents in your bags, bought at any merchant that sells them.
- **Train all**: one button at the trainer learns everything available, cheapest first, never below your money reserve.
- Optionally **skip cinematics** and movies one of your characters has already seen.
- **Presets**: Conservative, Convenient and Hands off, each showing what it changes first.
- **Quiet chat**: one summary line per visit by default, or everything, problems only, or nothing.
- Hold Shift as a merchant, mailbox or other interaction opens and Valet leaves that visit alone.

## Setup

Nothing to do. Selling, repairing, collecting gold from the mail and declining duels, guild invites and charters are on from the start. Change anything under **Settings > AddOns > Valet** (or `/valet`).

## Works with a controller

Every popup Valet answers is one less trip with the gamepad cursor. The Settings page is built so WoW: Forever's gamepad cursor never touches it, which avoids the client freezing when Settings is closed with the controller.

## Slash commands

```
/valet          open the settings
/valet status   list what is turned on
/valet last     what Valet did lately, and what it left alone
/valet sell     always sell an item; again to stop
/valet selllist list the items you always sell
/valet restock  keep an item stocked: /valet restock [item] 200
/valet train    at a trainer: learn everything available
/valet preset   show or apply a preset
/valet help     all commands
```

## Notes

- Built for **World of Warcraft: Forever**. It only uses standard merchant, mail, quest, trainer, social and popup APIs, so it should also work on other clients that have them.

## Part of the SNRN family

- **[SNRN Tally](https://www.curseforge.com/wow/addons/snrn-tally-bag-ammo-counter)**: free bag slots and ammo on the gamepad HUD. Greys you keep with Tally are not sold by Valet.
- **[SNRN Rummage](https://www.curseforge.com/wow/addons/snrn-rummage)**: one action slot per item type that always uses the best food, drink, potion, bandage or quest item in your bags.
- **[SNRN Backhand](https://www.curseforge.com/wow/addons/snrn-backhand)**: four extra action slots for your controller's rear paddles, built into Forever's native crossbar.
- **[SNRN Grimoire](https://www.curseforge.com/wow/addons/snrn-grimoire)**: one command lays out an Affliction Warlock on Forever's gamepad crossbar and Backhand's paddles.

## Reporting problems

Run `/valet status` and include the output with your report, plus what Valet did or did not do and where (merchant, mailbox, quest giver, trainer or popup).
