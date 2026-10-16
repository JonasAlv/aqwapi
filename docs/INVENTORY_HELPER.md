# Cross-container inventory helper

The feature branch now exposes a first-pass helper at `Bot.InvHelper` / `invHelper`, implemented in `src/com/aqwapi/scripting/InventoryHelper.hx`.

## API

```haxe
// Single item, name or ID:
invHelper.check("Item Name", 2);
Bot.InvHelper.Check(12345, 1, true);

// List checks:
invHelper.hasAll(["Item A", "Item B"], 1, true);
invHelper.hasAny([12345, 23456], 1, false);
```

PascalCase aliases (`Check`, `HasAll`, `HasAny`) are provided for Skua-style scripts; lower-camel aliases are available for native Haxe scripts.

## Behavior

- Checks temporary inventory, normal inventory, house inventory, and bank.
- When `moveToInventory=true`, a banked item is queued through the existing `InventoryManager.ensureUnbanked`; `check` remains false until the requested quantity is actually in normal inventory (or another eligible container already satisfies the check).
- When `moveToInventory=false`, a sufficient bank quantity counts as available.
- Empty lists return true for both `hasAll` and `hasAny`, matching the current Skua helper's empty-sequence behavior.
- House inventory is treated as a valid prerequisite source, matching Skua's helper pattern; it is not automatically moved into normal inventory.
- The existing combat and quest managers are not changed by this helper.

## Known differences / validation

- This is a first-pass Haxe helper, not yet exact semantic parity for every Skua edge case. In particular, Skua's `HasAll` can return true immediately after queuing bank withdrawals; this implementation returns false until the needed items are actually available, which is safer for prerequisite workflows but should be treated as a deliberate semantic difference.
- Bank quantity lookup was extended to read dictionary-backed `bankItems` as well as `BankArray` / `items`.
- Runtime verification is required for bank loading, delayed withdrawal, duplicate items across containers, partial quantities, and inventory-full cases.
- The current environment has no Haxe compiler and cannot clone GitHub repositories, so this addition is not compile-tested here.
