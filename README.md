# lazy

`lazy` is a heavily stripped-down, zero-bloat fork of [rupa/z](https://github.com/rupa/z). It tracks your most-used directories by *frecency* (frequency + recency) so you can jump to them by typing a fragment of the name instead of the full path. Built to match my workflow, currently only supports Bash.

Highly recommended to be used with [HalFrgrd/flyline](https://github.com/HalFrgrd/flyline).

<div align="center">
  <img src="https://github.com/user-attachments/assets/61fadf83-1ccf-4778-a152-d409569841a5" width="700" alt="lazy autocomplete menu">
  <p><em>Flyline's Auto Completion with lazy</em></p>
</div>

This fork extends the exact same concept to **files**, but removes all the clunky manual CLI commands. It is designed to be a completely silent, drop-in background utility that makes your `cd` and your `$EDITOR` incredibly smart.

- Tracks files and directories in **separate datafiles** (`~/.lazydir`, `~/.lazyfile`), so directory and file matching never collide.
- **Ships smart wrappers out of the box** — `cd` falls back to fuzzy directory matching, and your preferred editor falls back to fuzzy file matching.
- **Auto-Privilege Escalation** — The editor wrapper intelligently checks if you have write access to the target file. If you don't, it instantly recognizes the boundary and automatically executes `sudo` or `sudo -e` instead. Zero friction.
- **Smart Environment Sync** — Automatically propagates your preferred editor to `$EDITOR`/`$VISUAL` if they aren't already set, so `sudo -e` (which only ever reads `$SUDO_EDITOR`, `$VISUAL`, or `$EDITOR`) picks up your editor too instead of falling back to its own default. Note: if `$SUDO_EDITOR` is set separately, it takes precedence over this sync, since `sudo -e` checks it first.
- **Continuous Background Pruning** — Dead paths and old history are automatically purged from the database via a background process every time an entry is added, keeping the database perfectly clean with absolutely zero latency to your prompt.
- **Dynamically adapts to your editor** — Whether you use `nvim`, `emacs`, `micro`, or `nano`, the script automatically creates a smart wrapper function matching your editor's name.
- **Instant Tab Completion** — Fuses your frecency history with normal local directory/file completions in a single list. Prioritizes history matches at the top and falls straight through to standard completion if a real path (contains `/`) is typed.
- **Configurable Blacklists** — Exclude specific paths from ever polluting your history using colon-separated Bash globs. By default, safely ignores anything outside your `$HOME` directory (as well as `$HOME` itself).

All credit for the original algorithm, the frecency scoring, and the aging logic goes to [rupa deadwyler](https://github.com/rupa/z), along with [ze.sh](https://github.com/jghub/ze) for the event clock and exponential decay algorithms.

## Who this script is for :)

This tool is built for users who...

- **Want `zoxide` for files** — You love the frictionless, frecency-based jumping of tools like `z` or `zoxide` for directories, and you want that exact same magic for opening your most-used files.
- **Crave workflow QoL** — You want your environment to be smart enough to find the file you need without forcing you to memorize or type out tedious absolute and relative paths.
- **Are tired of `sudo $EDITOR`** — You hate opening a system configuration file, getting a "Permission denied" error on save, and having to back out just to type `sudo !!`. 
- **Prioritize strict security** — You want a robust, secure way to edit system root files. This script automatically invokes `sudo -e` or `sudo` for anything you lack write access to, so you never have to manually type `sudo`.

## Install

Put this in your `.bashrc`

    # 1. Define your editor: nvim, emacs, micro, nano, etc.
    # Don't export! The script does it for you.
    EDITOR=nvim
    
    # 2. Source the script
    . /path/to/lazy

*(Quick note — If you completely forget to set your editor variables, the script will gracefully default to `nano`.)*

Then just use your terminal normally — `cd` around, open a few files — for a day or two to build up the database. 

## Use

There are no clunky `lazy file foo` commands to memorize. Just use your normal commands, and the script handles the rest quietly in the background.

Assuming you set `EDITOR=nvim` (swap `nvim` for `micro`, `emacs`, etc.), here is exactly how the script behaves in every scenario:

| Command Typed | Target Exists? | Write Access? | What happens quietly in the background |
| --- | --- | --- | --- |
| `cd <TAB>` | N/A | N/A | Shows your entire directory history from `.lazydir`. |
| `cd te<TAB>` | N/A | N/A | Fuzzy-matches `te` against your directory history and auto-completes. |
| `cd foo` | No (in `$PWD`) | N/A | Fuzzy-searches `.lazydir` for `foo` and jumps to the best match. |
| `cd foo bar` | Yes/No | N/A | Automatically joins spaces! Safely enters local `foo bar` if it exists, or fuzzy-searches `.lazydir` for `foo*bar` without needing quotes or backslashes. |
| `nvim <TAB>` | N/A | N/A | Shows your entire file history from `.lazyfile`. |
| `nvim te<TAB>` | N/A | N/A | Fuzzy-matches `te` against your file history and auto-completes. |
| `nvim /etc/<TAB>`| N/A | N/A | Detects a slash (`/`) and falls through to normal bash filesystem completion. |
| `nvim foo` | No (in `$PWD`) | N/A | Fuzzy-searches `.lazyfile` for `foo`, resolves the absolute path, and evaluates the rules below. |
| `nvim ./foo.txt` | Yes/No | **Yes** | Bypasses fuzzy search. Opens the file normally as your user. |
| `nvim ~/new/foo.txt` | No | **Yes** | Bypasses fuzzy search. Opens the file normally as your user. |
| `nvim /etc/hosts` | Yes | **No** | Detects lack of permissions, and securely opens using `sudo -e`. |
| `nvim /etc/new/foo.txt`| No | **No** | Detects lack of parent permissions, and securely opens using `sudo nvim`. |
| `nvim fstab ~/.bashrc` | Mixed | Mixed | Sequentially processes each file. Evaluates permissions individually to safely elevate (`sudo -e /etc/fstab`) without breaking local files (`nvim ~/.bashrc`). |

## Tunables

You can override these by exporting them before the `source` line

| Variable | Default | Purpose |
| --- | --- | --- |
| `_LAZY_DIR_DATA` | `~/.lazydir` | directory datafile path |
| `_LAZY_FILE_DATA` | `~/.lazyfile` | file datafile path |
| `_LAZY_LAMBDA` | `0.008` | exponential decay rate for scores |
| `_LAZY_DIR_BLACKLIST` | `!($HOME/*)` | colon-separated glob patterns to ignore for cd |
| `_LAZY_FILE_BLACKLIST`| `!($HOME/*)` | colon-separated glob patterns to ignore for editor |
| `EDITOR` | `$VISUAL`, else `nano` | program used to open matched files |

## How it works

Each line in a datafile is `path|visits|last_tick|score`. Instead of wall-clock time (which breaks if you take a break from coding), `lazy` uses an **[Event Clock](https://github.com/jghub/ze)**—time only moves forward when you execute a command. Every time you visit a path, its score undergoes true **[exponential decay](https://github.com/jghub/ze)** based on how many "ticks" have passed, and then gains a +1 bonus. When querying, the script fast-forwards all scores to the current tick to find the most relevant match. Entries that decay below a score of `0.05` are aggressively auto-pruned, meaning the database perfectly cleans itself!

Files are only added to `~/.lazyfile` when opened through your smart editor wrapper. Files opened by other means won't be tracked.

## Don'ts

- **Don't** source `lazy` in root's `.bashrc`. Running as root means tracking root's own datafiles and dealing with ownership headaches. 
- **Don't** manually run `sudo nvim foo`. Your shell will completely bypass this script's intelligence, skip the frecency database, and break the automation. Just let the wrapper handle the elevation for you natively!

## Have yet to implement
- Editor arguments support
- Safe automatic directory creation

## License

Distributed under the **MIT License**. 

Original `z.sh` was distributed under the WTFPL v2. This fork integrates algorithms from `ze.sh` (MIT License). See [LICENSE](LICENSE) for more information.

## Acknowledgements
* **[rupa deadwyler (z.sh)](https://github.com/rupa/z)** — Creator of the original `z.sh` and the core frecency jumping concept.
* **[Joerg van den Hoff (ze.sh)](https://github.com/jghub/ze)** — Engineered the true exponential decay algorithm, the event-clock architecture, and the highly optimized `awk` core used in this fork.
* **[elseawhy (lazy)]()** — Extended the logic to file tracking, built the smart editor auto-escalation wrappers, and integrated seamless background auto-pruning.
