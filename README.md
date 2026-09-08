# Octo Loot

A compact, movable loot feed for **OctoWoW / Vanilla WoW 1.12**. No dependencies.

- Five animated loot rows with item icons, rarity colors, and stack counts.
- Copper, silver, and gold icons, plus a gold **Quest Item** label for quest items.
- Hover to pause the feed and see item tooltips.
- Adjustable position, size, duration, and stack direction.

## Install

Download [OctoLoot.zip](https://github.com/Morkahja/OctoLoot/releases/latest/download/OctoLoot.zip), extract the `OctoLoot` folder into `Interface\AddOns`, and restart WoW. Enable **Octo Loot** at character select.

## Commands

- `/oloot unlock` — drag into position; `/oloot lock` to finish.
- `/oloot test` — preview the feed.
- `/oloot scale 1` — adjust size.
- `/oloot duration 6` — seconds before fading.
- `/oloot direction up` or `down` — change stack direction.
- `/oloot chat off` — hide personal item loot in chat; `chat on` restores it.
- `/oloot reset` — restore defaults.

Settings are saved account-wide. Quest labels follow the item's tooltip; ordinary materials needed for quests are not marked.

## Screenshots

![Loot feed with item quantities and money](Screenshots/loot-feed.png)

![Quest item label and fading loot](Screenshots/quest-item.png)

![Item tooltip on hover](Screenshots/item-tooltip.png)
