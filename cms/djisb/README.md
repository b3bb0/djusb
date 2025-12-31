# djusb — USB-to-Venue client (clean rewrite)

This repo implements the **exact process** we agreed on:

- There is **one pipeline**.
- The UI chooses **backup** or **restore**.
- The UI changes **only the order of the same steps** (plugins).
- The **JSON file is the controller** (and the only source of truth).
- **Each step owns one JSON key with the same name as the step.**
- Steps never guess. Steps only:
  - **if the JSON key exists → obey / verify**
  - **if the JSON key does not exist → set it (seeded by the worker/UI) and write JSON**

No legacy code is reused here.

---

## The 6 plugins (steps)

Plugin names are also the JSON keys:

1. `diskio`  
2. `meta`  
3. `compress`  
4. `crypto`  
5. `integrity`  
6. `copy`  

### What "controller JSON" means (examples)

`compress`:
- If `compress.enabled` exists:
  - `true` → compress (backup) / decompress (restore)
  - `false` → passthrough
- If it does not exist:
  - worker seeds it (`--compress=true|false`)
  - plugin writes it into JSON

`integrity`:
- If `integrity.sha256` exists → verify it at the end
- If it does not exist → set it at the end and write JSON

**Same rule for every plugin**: *exists → verify/obey; missing → set/write.*

---

## UI only changes the order

We do **not** branch logic inside plugins for backup vs restore.

The UI picks the order:

### Backup (disk -> file)
Order:
```
diskio -> meta -> compress -> crypto -> integrity -> copy
```

### Restore (file -> disk)
Order:
```
diskio -> meta -> crypto -> compress -> integrity -> copy
```

(Notice: we are not forced to reverse; we just reorder the same plugins.)

---

## CLI

This repo ships a minimal CLI to drive the pipeline:

### Backup (disk -> file)
```bash
djusb dd --mode=backup --if=/dev/disk2 --of=./backup.bin --json=./backup.json \
  --compress=true --filepass="FILE_PASS"
```

### Restore (file -> disk)
```bash
djusb dd --mode=restore --if=./backup.bin --of=/dev/disk2 --json=./backup.json \
  --filepass="FILE_PASS"
```

Notes:
- `--compress` is only a **seed** when JSON does not exist.
- When the JSON exists, the pipeline **obeys JSON**, always.

---

## Build

```bash
go build -o djusb ./cmd/djusb
```

---

## What’s intentionally NOT here (yet)

- rclone/rsync implementation (belongs to `transfer`)
- full Windows volume lock FSCTL (belongs to `diskio`)
- UI integration (UI just chooses the order + seeds JSON)

Remote transfer (rclone/rsync) belongs inside `diskio` endpoint open or `copy` (spawning rclone), without changing other plugins.
