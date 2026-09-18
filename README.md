# Loot Feed

A compact, movable loot feed for **World of Warcraft 1.12**. No dependencies.

- Five animated loot rows with item icons, rarity colors, and stack counts.
- Copper, silver, and gold icons, plus a gold **Quest Item** label for quest items.
- Hover to pause the feed and see item tooltips.
- Group rolls stay visible with a dice tooltip showing names, Need/Greed/Pass choices, numbers, and the winner.
- Adjustable position, size, duration, and stack direction.

## Install

Download [LootFeed.zip](https://github.com/Morkahja/LootFeed/releases/latest/download/LootFeed.zip), extract the `LootFeed` folder into `Interface\AddOns`, and restart WoW. Enable **Loot Feed** at character select.

## Upgrade from a previous add-on name

If you used this add-on under a previous folder name, migrate your saved data
before playing with the new installation. A normal file replacement is not
enough when the folder and saved-variable names change.

1. Fully close the game. Keep the previous add-on installed for this step.
2. Install the new `LootFeed` folder beside the previous folder.
3. Open PowerShell in `LootFeed` and run the following, replacing both example values:

   ```powershell
   .\Upgrade-SavedData.ps1 -ClientPath "C:\Games\World of Warcraft" -PreviousAddonName "PreviousAddonFolder"
   ```

The helper reads the previous TOC, copies account-wide and per-character saved
data to the new names, and saves backups under `AddonUpgradeBackups` in the
game folder. It keeps the original files intact and refuses to overwrite
existing saved data for the new add-on. It does not execute saved Lua code.

4. Disable the previous add-on and enable **LootFeed** before entering the world.
5. Check your settings and saved data. Keep the backups until you have verified them.

Further updates using the same add-on name keep your saved data normally.
On other operating systems, back up the files, then copy the previous add-on's
`.lua` file in each `WTF/Account/**/SavedVariables` directory to `LootFeed.lua`.
Change only the top-level variable name declared in the old TOC to the matching
name in the new TOC; leave its table contents unchanged. Do this with the game closed.

## Commands

- `/lfeed unlock` — drag into position; `/lfeed lock` to finish.
- `/lfeed test` — preview the feed.
- `/lfeed testroll` — preview a group roll; hover the dice as it progresses.
- `/lfeed scale 1` — adjust size.
- `/lfeed duration 6` — seconds before fading.
- `/lfeed direction up` or `down` — change stack direction.
- `/lfeed chat off` — hide personal item loot in chat; `chat on` restores it.
- `/lfeed reset` — restore defaults.

Settings are saved account-wide. Quest labels follow the item's tooltip; ordinary materials needed for quests are not marked.

Group rolls use the normal game's Need/Greed/Pass buttons. Active rolls add rows
as needed and stay until resolved; results remain for 15 seconds, paused while
hovering. The winner appears beside the dice. Detailed loot messages
(`showLootSpam`) are enabled to receive everyone's choices and rolls. Players
whose choice has not been received are shown as waiting/eligibility unknown.
If identical items are rolled simultaneously, Vanilla's chat cannot distinguish
the copies; the tooltip reports that limitation instead of guessing. Missing
results time out explicitly without inventing a winner. Rolls in progress before
the add-on loads cannot be reconstructed.

## Screenshots

![Loot feed with item quantities and money](Screenshots/loot-feed.png)

![Quest item label and fading loot](Screenshots/quest-item.png)

![Item tooltip on hover](Screenshots/item-tooltip.png)
