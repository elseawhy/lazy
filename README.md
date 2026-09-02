# lazy

`lazy` is a heavily stripped-down, zero-bloat fork of [rupa/z](https://github.com/rupa/z). It tracks your most-used directories by *frecency* (frequency + recency) so you can jump to them by typing a fragment of the name instead of the full path. Built to match my workflow, it natively supports Bash and Zsh out of the box.

Highly recommended to be used with [HalFrgrd/flyline](https://github.com/HalFrgrd/flyline) (Bash only).

This fork extends the exact same concept to **files**, but removes all the clunky manual CLI commands. It is designed to be a completely silent, drop-in background utility that makes your `cd` and your `$EDITOR` context-aware and highly efficient.

- Tracks files and directories in **separate datafiles** (`~/.lazydir`, `~/.lazyfile`), so directory and file matching never collide.
- **Ships smart wrappers out of the box** — `cd` falls back to fuzzy directory matching, and your preferred editor falls back to fuzzy file matching.
- **Auto-Privilege Escalation** — The editor wrapper intelligently checks if you have write access to the target file. If you don't, it instantly recognizes the boundary and automatically executes `sudo -e` instead.
- **Continuous Background Pruning** — Dead paths, manually corrupted entries, and old history are automatically purged from the database via a background process every time an entry is added, keeping the database perfectly clean with virtually zero latency to your prompt.
- **Dynamically adapts to your workflow** — By default, the script creates smart aliases for `cd` and your preferred `$EDITOR`. You can fully customize these alias names, or disable them entirely to use the underlying functions directly.
- **Intelligent Flag Bypass** — Passing any standard editor flags (`-v`, `+42`, etc.) instantly safely downgrades the wrapper into a raw passthrough.
- **Instant Tab Completion** — Fuses your frecency history with normal local directory/file completions in a single list. Prioritizes history matches at the top and falls straight through to standard completion if a real path (contains `/`) is typed.
- **Configurable Blacklists** — Exclude specific paths from ever polluting your history using standard shell arrays. By default, safely ignores anything outside your `$HOME` directory (as well as `$HOME` itself).

  > All credit for the original algorithm, the frecency scoring, and the aging logic goes to [rupa/z](https://github.com/rupa/z), along with [jghub/ze](https://github.com/jghub/ze) for the event clock and exponential decay algorithms.

## Who this script is for :)

This tool is built for users who...

- **Want `zoxide` for files** — You love the frictionless, frecency-based jumping of tools like `z` or `zoxide` for directories, and you want that exact same magic for opening your most-used files.
- **Crave workflow QoL** — You want your environment to be smart enough to find the file you need without forcing you to memorize or type out tedious absolute and relative paths.
- **Are tired of `sudo $EDITOR`** — You hate opening a system configuration file, getting a "Permission denied" error on save, and having to back out just to type `sudo !!`. 
- **Prioritize strict security** — You want a robust, secure way to edit system root files. This script automatically invokes `sudo -e` (sudoedit) for anything you lack write access to, safely dropping root privileges before launching your editor so you never have to manually type `sudo`.
  
  > **Important Note on `sudo`:** Make sure you are using the original C-based [sudo](https://github.com/sudo-project/sudo) package. The Rust rewrite (`sudo-rs`) currently has a weird quirk with `sudo -e` where if you open a new file and leave it completely blank, it blindly copies that empty file back to the root location anyway. This script relies on the original `sudo`, which intelligently aborts the operation if no changes are made!

## Install

Put this in your `.bashrc` or `.zshrc`:

```bash
# 1. Export your editor: nvim, emacs, micro, nano, etc.
export EDITOR=nvim

# 2. Source the script
. /path/to/lazy
```

*(Quick note — If you completely forget to set your editor variables, the script will gracefully default to `nano`.)*

Then just use your terminal normally — `cd` around, open a few files — for a day or two to build up the database. 

## Use

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
| `nvim /etc/new/foo.txt`| No | **No** | Detects lack of parent permissions, and securely opens using `sudo -e`. |
| `nvim fstab ~/.bashrc` | Mixed | Mixed | Sequentially processes each file. Evaluates permissions individually to safely elevate (`sudo -e /etc/fstab`) without breaking local files (`nvim ~/.bashrc`). |
| `nvim -c theme foo` | N/A | N/A | Detects editor flags. Bypasses fuzzy tracking and securely passes raw arguments straight to the editor. |
| `nvim /etc/` | Yes (Dir) | **No** | Detects a directory. Skips `.lazyfile` tracking, but smartly elevates (`sudo -e`) to safely open the protected folder browser. |

## Tunables

You can override these by exporting them before the `source` line

| Variable | Default | Purpose |
| --- | --- | --- |
| `_LAZY_DIR_DB` | `~/.lazydir` | directory datafile path |
| `_LAZY_FILE_DB` | `~/.lazyfile` | file datafile path |
| `_LAZY_HALF_LIFE` | `85` | number of commands before a score halves |
| `_LAZY_MAX_ENTRIES` | `1000` | maximum number of entries to track per file |
| `_LAZY_MAX_COMPLETIONS` | `10` | maximum number of matches to show in completion |
| `_LAZY_CD_COMMAND` | `cd` | command to alias for smart cd (set to empty to disable) |
| `_LAZY_EDITOR_COMMAND` | basename of `EDITOR` | command to alias for smart editor (set to empty to disable) |
| `_LAZY_DIR_BLACKLIST` | `(empty)` | array of path prefixes to ignore for cd |
| `_LAZY_FILE_BLACKLIST`| `(empty)` | array of path prefixes to ignore for editor |
| `EDITOR` | `$VISUAL`, else `nano` | program used to open matched files |

`EDITOR` supports arguments and absolute paths. Providing an absolute path prevents binary spoofing. Malicious inputs are safely neutralized because the script expands the variable into an array and executes it via the command builtin. For example if an attacker sets `EDITOR="nano; curl example.com"`, behind the scenes it executes exactly like this

```bash
exec_cmd=("nano;" "curl" "example.com")
command "${exec_cmd[@]}"
```

This forces the shell to search for an executable literally named `nano;` rather than running the malicious curl command, safely resulting in a command not found error.

## How it works

Each line in a datafile is exactly two tab-separated columns: `path` and `score`. `lazy` uses an implicit event clock (time advances per command, not by wall-clock) to apply exponential half-life decay (`score / (2 ^ (1 / HALF_LIFE))`) across the database. The newly visited path receives a +1 score bonus. The database is continuously pre-sorted by score to allow instant read lookups without spawning sub-shells. When the database exceeds `_LAZY_MAX_ENTRIES` (default `1000`), the lowest-scoring entries are automatically pruned. *(The underlying exponential decay algorithms were heavily inspired by **[jghub/ze](https://github.com/jghub/ze)**).*

Files are only added to `~/.lazyfile` when opened through your smart editor wrapper. Files opened by other means won't be tracked.

## Don'ts

- **Don't** source `lazy` in root's `.bashrc`. Running as root means tracking root's own datafiles and dealing with ownership headaches. 
- **Don't** manually run `sudo nvim foo`. Your shell will completely bypass this script's intelligence, skip the frecency database, and break the automation. Just let the wrapper handle the elevation for you natively!

## Have yet to implement
- Safe automatic directory creation

## License

Distributed under the **MIT License**. 

Original `z.sh` was distributed under the WTFPL v2. This fork integrates algorithms from `ze.sh` (MIT License). See [LICENSE](LICENSE) for more information.

## Acknowledgements
* **[rupa deadwyler (z.sh)](https://github.com/rupa/z)** — Creator of the original `z.sh` and the core frecency jumping concept.
* **[Joerg van den Hoff (ze.sh)](https://github.com/jghub/ze)** — True exponential decay algorithm and the event-clock architecture.
