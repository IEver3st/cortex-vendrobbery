# Cortex Vending Robbery

[![Cortex Vending Robbery](https://raw.githubusercontent.com/IEver3st/gsd-tebex-media/main/heroes/vendrobbery.jpg)](https://gsdmods.com/scripts/cortex-vending-robbery?utm_source=github&utm_medium=readme&utm_campaign=cortex-vending-robbery)

**[Download Latest Release (v1.0.0)](https://github.com/IEver3st/cortex-vendrobbery/releases/latest)** · [Product Page](https://gsdmods.com/scripts/cortex-vending-robbery?utm_source=github&utm_medium=readme&utm_campaign=cortex-vending-robbery) · [All 36 Cortex Scripts](https://gsdmods.com/scripts?utm_source=github&utm_medium=readme&utm_campaign=cortex-vending-robbery) · [Docs](https://gsdmods.com/docs?utm_source=github&utm_medium=readme&utm_campaign=cortex-vending-robbery) · [Discord](https://discord.com/invite/gsdmods)

> **Free direct download — no Tebex checkout or Asset Escrow required.** Download the ready-to-drop `cortex-vendrobbery-1.0.0.zip` from [GitHub Releases](https://github.com/IEver3st/cortex-vendrobbery/releases/latest) and extract `cortex-vendrobbery` into your FiveM `resources/` folder.

Break into a Cortex Vending machine with your own hands. Pick the lock pin by pin or lever the door off its latches, then strip the machine: the bill stacker on the door, the cash box, the stock on the shelves. Everything happens on the machine, close up, with the mouse.

What you take is what the machine really held. A player's machine pays out of its owner's cash box, a Vendex machine pays out of what it actually sold, and the shelves you empty are the shelves the next customer finds.

Free addon for [Cortex Vending](https://gsdmods.com/scripts).

## What a robbery looks like

1. **The lock.** Carry a pick set or a crowbar, face the machine and press **G**.
   - **Pick set (1).** Hold tension with the right mouse button and keep it inside the band (the wheel trims it). Lift a pin with the left button. Only one pin binds at a time, and it lifts heavy. Stop where it bites and hold until it sets. Lift past it and your last two pins drop. Seven pins, and every machine is pinned differently. Picking is quiet.
   - **Crowbar (2).** Set the bar on a latch, pull down and hold it in the band until the latch gives. Three latches. The door alarm always goes off, and the machine takes longer to repair.
2. **Inside.** The door stands open for everyone and the machine is out of order.
   - **Bill stacker.** Grip it and pull it down off the door. Soda and snack machines only.
   - **Cash box.** Pick its four pins or drill the lock. A picked door teaches you the box: its pins are cut like the first four of the door, and your notes (**Tab**) mark where each one sets. Drilling means holding the heat inside the band. Let the bit cool before it snaps.
   - **Shelves.** Hold on a product to keep pulling stock, up to `Config.Takings.shelfItems`.

Mistakes are strikes. Three on the door lock jam it, and only a crowbar opens it after that. Three on the cash box seize it for good. Either way the alarm goes off.

A robbed machine stays open and out of order until the repair timer runs out, or until its owner walks up and pays for a new lock.

## Requirements

- OneSync.
- [`cortex-lib`](https://github.com/IEver3st/cortex-lib/releases/latest), started first.
- `cortex-vending` 1.1.0 or newer (it carries the tamper API this addon uses).
- `ox_inventory`, or a bridge resource named `ox_inventory` that answers its `GetItemCount`, `Items`, `CanCarryItem`, `AddItem`, `RemoveItem` and `Search` exports (Cortex Inventory ships one).
- Optional: `cortex-dispatch` for police alerts. Without it the alert goes to `police:server:policeAlert`.

## Install

1. Put `cortex-vendrobbery` in your resources and `ensure cortex-vendrobbery` after `cortex-lib`, `cortex-vending` and `ox_inventory`.
2. Add the two tools from `install/ox_inventory_items.lua` to `ox_inventory/data/items.lua`. The crowbar is the game's `WEAPON_CROWBAR` and the cash is paid as `money`; change either in `config.lua`.
3. On Cortex Inventory, add `'cortex-vendrobbery'` to the trusted resources list in `config/suite-trust.lua`, or it refuses the item checks and the payout.
4. Cortex Vending only answers resources listed in `Config.Tamper.Allow` in its `shared/config.lua`. `cortex-vendrobbery` is there by default. If you rename this resource, add the new name.
5. Restart the server.

Machines being robbed live in memory. Restarting `cortex-vendrobbery` closes every door and puts every machine back in service. The per-machine cooldown is saved and survives a restart.

## Configuration

Everything is in `config.lua`. A wrong value prints one line in the server console and falls back to its default.

| Setting | What it does |
| --- | --- |
| `Config.Keys.start` | Default key to break in, keep working or repair. Players rebind it under Settings, Key Bindings, FiveM. |
| `Config.Tools` | Item names for the crowbar, pick set and drill. `false` means the tool is not needed. |
| `Config.Targets` | Whether Vendex machines and player machines can be robbed, and whether a player's machine needs its owner online. |
| `Config.Police` | Officers needed on duty, the witness chance when a lock is worked quietly, and where alerts go. |
| `Config.Cooldown` | Minutes between robberies per player and per machine, until a robbed machine repairs itself, the extra time after a crowbar job, until an abandoned attempt resets, and the wait after backing out of a lock you did not open. A player gets five minutes on a lock in all, counted across every try in 15 minutes. Running out counts as a robbery for their cooldown and keeps the machine shut to everyone for `abandonMinutes`. |
| `Config.Strikes` | Mistakes before a lock jams or a cash box seizes. |
| `Config.Pick`, `Config.Pry`, `Config.Drill` | How wide the bands are, how long to hold, and where things break. |
| `Config.Takings` | The share and cap taken from an owner's box, the share and cap of a Vendex machine's sales, the small float a Vendex machine always carries, how the take splits between stacker and box, and the shelf cap. |
| `Config.Repair.ownerCost` | What an owner pays in cash to repair their machine on the spot. |
| `Config.Camera` | Field of view and the work light. |

### Logs

Set a Discord webhook for the audit log in `server.cfg`:

```
set cortex_vendrobbery_webhook "https://discord.com/api/webhooks/..."
```

## Admin

`/vendrob` needs the ACE `command.vendrob`.

- `/vendrob list` lists every machine being worked or waiting for repair.
- `/vendrob reset <machine id|all>` repairs machines and clears their cooldown.
- `/vendrob cooldown <server id>` clears a player's cooldown.

In Cortex Vending, `/vendunhold <machine id>` frees a machine that something left held, and `/vendissues` lists any payout that was never confirmed.

## For developers

The server owns every outcome. A client asks for an action (set a pin, pop a latch, pull the stacker, a second of drilling, a bundle, a product) and the server checks range, routing bucket, the tool in the inventory, the stage, the binding order of the pins, minimum times and a rate limit before it answers.

Cash and stock never move without Cortex Vending. Each take is debited from the machine and logged as open, the item is given, and the log is settled or the take is returned.

## Support

[gsdmods.com](https://gsdmods.com)

## More from Cortex

Cortex Vending Robbery is free and stays free. All 36 Cortex scripts share one free library ([`cortex-lib`](https://github.com/IEver3st/cortex-lib)) and one consistent UI, with native cross-script integrations and zero conflicts.

### Flagship Paid Suites & Scripts

| Police & Tactical | Economy & World | Core UI & Vehicles |
| --- | --- | --- |
| [**Cortex MDT**](https://gsdmods.com/scripts/cortex-mdt?utm_source=github&utm_medium=readme&utm_campaign=cortex-vending-robbery): Full police MDT + Dispatch included free | [**Cortex Banking**](https://gsdmods.com/scripts/cortex-banking?utm_source=github&utm_medium=readme&utm_campaign=cortex-vending-robbery): 4 banks, rebuilt 3D ATMs, cards, credit scores & loans | [**Cortex HUD**](https://gsdmods.com/scripts/cortex-hud?utm_source=github&utm_medium=readme&utm_campaign=cortex-vending-robbery): HUD Studio with three built-in layouts |
| [**Cortex PolCam**](https://gsdmods.com/scripts/cortex-polcam?utm_source=github&utm_medium=readme&utm_campaign=cortex-vending-robbery): FLIR helicopter camera with tracking & ground link | [**Cortex Vending**](https://gsdmods.com/scripts/cortex-vending?utm_source=github&utm_medium=readme&utm_campaign=cortex-vending-robbery): Player-owned vending machines with 105 3D products | [**Cortex Handling**](https://gsdmods.com/scripts/cortex-handling?utm_source=github&utm_medium=readme&utm_campaign=cortex-vending-robbery): Live in-game vehicle handling editor & exporter |
| [**Cortex Dispatch**](https://gsdmods.com/scripts/cortex-dispatch?utm_source=github&utm_medium=readme&utm_campaign=cortex-vending-robbery): Live alerts, unit routing & panic calls | [**Cortex Caseboard**](https://gsdmods.com/scripts/cortex-caseboard?utm_source=github&utm_medium=readme&utm_campaign=cortex-vending-robbery): Detective corkboards with red strings & 18 card types | [**Cortex Multicharacter**](https://gsdmods.com/scripts/cortex-multicharacter?utm_source=github&utm_medium=readme&utm_campaign=cortex-vending-robbery): Character roster, dossier & ID registration |
| [**Cortex Radar**](https://gsdmods.com/scripts/cortex-radar?utm_source=github&utm_medium=readme&utm_campaign=cortex-vending-robbery): Handheld 3D police radar gun | [**Cortex Whiteboard**](https://gsdmods.com/scripts/cortex-whiteboard?utm_source=github&utm_medium=readme&utm_campaign=cortex-vending-robbery): 28 drawable boards with city maps & physics | [**Cortex Rewind**](https://gsdmods.com/scripts/cortex-rewind?utm_source=github&utm_medium=readme&utm_campaign=cortex-vending-robbery): Forza-style vehicle rewind in FiveM |
| [**Cortex Arges**](https://gsdmods.com/scripts/cortex-arges?utm_source=github&utm_medium=readme&utm_campaign=cortex-vending-robbery) · [**Radio**](https://gsdmods.com/scripts/cortex-radio?utm_source=github&utm_medium=readme&utm_campaign=cortex-vending-robbery) · [**SceneKit**](https://gsdmods.com/scripts/cortex-scenekit?utm_source=github&utm_medium=readme&utm_campaign=cortex-vending-robbery) | [**Cortex Computer**](https://gsdmods.com/scripts/cortex-computer?utm_source=github&utm_medium=readme&utm_campaign=cortex-vending-robbery): In-world playable computers & monitors | [**Cortex Chat**](https://gsdmods.com/scripts/cortex-chat?utm_source=github&utm_medium=readme&utm_campaign=cortex-vending-robbery) · [**Spawn**](https://gsdmods.com/scripts/cortex-spawn?utm_source=github&utm_medium=readme&utm_campaign=cortex-vending-robbery) · [**Emote Studio**](https://gsdmods.com/scripts/cortex-emote-studio?utm_source=github&utm_medium=readme&utm_campaign=cortex-vending-robbery) |

### Save with Bundles (One-Time or All-Access)

- [**Cortex Complete**](https://gsdmods.com/scripts/cortex-complete?utm_source=github&utm_medium=readme&utm_campaign=cortex-vending-robbery) — One-time lifetime bundle, no subscription.
- [**Cortex LEO Kit**](https://gsdmods.com/scripts/cortex-leo-kit?utm_source=github&utm_medium=readme&utm_campaign=cortex-vending-robbery) — Complete unified police stack (`MDT`, `Dispatch`, `PolCam`, `Radar`, `ALPR`, `Arges`, `Radio`, `SceneKit`, `Caseboard`, `Whiteboard`, `Flashlight`, `Binoculars`).
- [**Cortex Interface Kit**](https://gsdmods.com/scripts/cortex-interface-kit?utm_source=github&utm_medium=readme&utm_campaign=cortex-vending-robbery) — Complete core UI stack (`HUD`, `Chat`, `Spawn`, `Multicharacter`, `Loading Screen`).
- [**Cortex All-Access**](https://gsdmods.com/scripts/cortex-all-access?utm_source=github&utm_medium=readme&utm_campaign=cortex-vending-robbery) — Every current paid script + every future release on day one.

### All Free Cortex Scripts on GitHub

[`cortex-pause`](https://github.com/IEver3st/cortex-pause) · [`cortex-alpr`](https://github.com/IEver3st/cortex-alpr) · [`cortex-newspaper`](https://github.com/IEver3st/cortex-newspaper) · [`cortex-gunsmith`](https://github.com/IEver3st/cortex-gunsmith) · [`cortex-echo`](https://github.com/IEver3st/cortex-echo) · [`cortex-drone`](https://github.com/IEver3st/cortex-drone) · [`cortex-droneraces`](https://github.com/IEver3st/cortex-droneraces) · [`cortex-thrusters`](https://github.com/IEver3st/cortex-thrusters) · [`cortex-megaphone`](https://github.com/IEver3st/cortex-megaphone) · [`cortex-minigames`](https://github.com/IEver3st/cortex-minigames) · [`cortex-admin`](https://github.com/IEver3st/cortex-admin-releases) · [`cortex-atmrobbery`](https://github.com/IEver3st/cortex-atmrobbery) · [`cortex-vendrobbery`](https://github.com/IEver3st/cortex-vendrobbery) · [`cortex-lib`](https://github.com/IEver3st/cortex-lib)
