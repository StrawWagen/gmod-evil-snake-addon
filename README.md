# Evil snake

> A long snake for Garry's Mod that eats people and gets bigger.

It hunts NPCs and players, holds them half in its mouth for a bit, then pulls them down. You can watch them bulge all the way to the tail. Every meal makes it longer and fatter, and it learns from the minds of whatever it eats. It also picks up on how players get away from it, and gets better at stopping exactly that once it eats them.

## Needs

- [Syhgma's Evil API](https://github.com/xandwrp/gmod-evil-api)

Optional:

- Evil Crawling Thing, for propellor mode
- Evil Fungus, so it smears fungus behind it after crawling through some

## Spawning

Entities > Syhgma's Evil Entities > Evil snake.

## What it does

- Slithers on a physics chain that drapes over ledges, coils up and pushes off itself
- Climbs walls and ceilings, and wraps around corners
- Grabbed players can mash jump to break free
- Tongue mode, it lashes out and reels people in
- Propellor mode, a crawler hops on its head and spins its legs and the snake flies after you
- Can be shot, blown up and set on fire anywhere along the body, with its own health, armor and damage settings
- Stomach window from the context menu, lists everyone it ate and what they gave it

## Settings

Spawn menu > Utilities > Syhgma's Evil Entities > Evil snake (superadmins), or the convars. They all start with `evil_snake_`. Presets: chill, normal, aggressive, unhinged.

## Commands

Superadmin only.

- `evil_snake_mind` prints what every snake has eaten and learned
- `evil_snake_feed <kind> [count]` feeds every snake straight to digested
- `evil_snake_follow` makes every snake crawl after wherever you aim
