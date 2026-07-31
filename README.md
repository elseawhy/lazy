# lazy

`lazy` is a heavily stripped-down, zero-bloat fork of [rupa/z](https://github.com/rupa/z). It tracks your most-used directories by *frecency* (frequency + recency) so you can jump to them by typing a fragment of the name instead of the full path. Built to match my workflow, currently only supports Bash.

Highly recommended to be used with [HalFrgrd/flyline](https://github.com/HalFrgrd/flyline).

This fork extends the exact same concept to **files**, but removes all the clunky manual CLI commands. It is designed to be a completely silent, drop-in background utility that makes your `cd` and your `$EDITOR` incredibly smart.

- Tracks files and directories in **separate datafiles** (`~/.lazydir`, `~/.lazyfile`), so directory and file matching never collide.
- **Ships smart wrappers out of the box** — `cd` falls back to fuzzy directory matching, and your preferred editor falls back to fuzzy file matching.
- **Auto-Privilege Escalation** — If you attempt to open or jump to a file outside of your `$HOME` directory, the editor wrapper instantly recognizes the boundary and automatically executes `sudo -e` instead. Zero friction.
- **Smart Environment Sync** — Automatically propagates your preferred editor to `$EDITOR`/`$VISUAL` if they aren't already set, so `sudo -e` (which only ever reads `$SUDO_EDITOR`, `$VISUAL`, or `$EDITOR`) picks up your editor too instead of falling back to its own default. Note: if `$SUDO_EDITOR` is set separately, it takes precedence over this sync, since `sudo -e` checks it first.
- **Self-Cleaning** — Dead paths are automatically purged from the database during the read cycle if the file or directory no longer exists on your drive.
- **Dynamically adapts to your editor** — Whether you use `nvim`, `emacs`, `micro`, or `nano`, the script automatically creates a smart wrapper function matching your editor's name.
- **Tab completion is context-aware** — an empty word suggests your history, a fuzzy fragment (no `/`) searches the frecency database, and a real path (contains `/`) falls straight through to normal filesystem completion.

All credit for the original algorithm, the frecency scoring, and the aging logic goes to [rupa deadwyler](https://github.com/rupa). 

## Who this script is for :)

This tool is built for users who...

- **Want `zoxide` for files** — You love the frictionless, frecency-based jumping of tools like `z` or `zoxide` for directories, and you want that exact same magic for opening your most-used files.
- **Crave workflow QoL** — You want your environment to be smart enough to find the file you need without forcing you to memorize or type out tedious absolute and relative paths.
- **Are tired of `sudo $EDITOR`** — You hate opening a system configuration file, getting a "Permission denied" error on save, and having to back out just to type `sudo !!`. 
- **Prioritize strict security** — You want a robust, secure way to edit system root files. This script automatically invoke `sudo -e` (sudoedit) for anything outside your home directory, you never have to type `sudo`.

## Install

Put this in your `.bashrc`

    # 1. Define your editor! (The script uses this to dynamically name the wrapper function)
    # This works with nvim, emacs, micro, nano, etc.
    export _LAZY_EDITOR="nvim"
    
    # 2. Source the script
    . /path/to/lazy

*(Quick note — If you completely forget to set your editor variables, the script will gracefully default to `nano`.)*

Then just use your terminal normally — `cd` around, open a few files — for a day or two to build up the database. 

## Use

There are no clunky `lazy file foo` or `lazy dir foo` commands to memorize. Just use your normal commands, and the script handles the rest quietly in the background.

Assuming you set `_LAZY_EDITOR="nvim"`, your workflow looks like this

    cd foo          # fuzzy-cd fallback when foo isn't a real directory
    nvim foo        # fuzzy-open fallback when foo isn't a real file in the DB
    nvim ./foo      # bypasses the database to explicitly create/open a file in $PWD
    nvim file1 file2 # bypasses the database entirely to open multiple files normally
    nvim fstab      # fuzzy-resolves in user-space, detects it's outside $HOME, and runs sudo -e /etc/fstab
    nvim /etc/hosts # bypasses the database, detects it's outside $HOME, and runs sudo -e /etc/hosts

*(If your editor is `emacs` or `micro`, just swap `nvim` in the above examples.)*

### Tunables

You can override these by exporting them before the `source` line

| Variable | Default | Purpose |
| --- | --- | --- |
| `_LAZY_DIR_DATA` | `~/.lazydir` | directory datafile path |
| `_LAZY_FILE_DATA` | `~/.lazyfile` | file datafile path |
| `_LAZY_MAX_SCORE` | `9000` | aging threshold before scores decay |
| `_LAZY_EDITOR` | `$EDITOR`/`$VISUAL`, else `nano` | program used to open matched files |

### Tab completion

Completion is context-aware based on what you've typed (using `nvim` as an example here, but it adapts to your `_LAZY_EDITOR`)

| You type | What happens |
| --- | --- |
| `cd <TAB>` | lists your directory history from `.lazydir` |
| `nvim <TAB>` | lists your file history from `.lazyfile` |
| `cd te<TAB>` | fuzzy-matches `te` against directory history |
| `nvim te<TAB>` | fuzzy-matches `te` against file history |
| `cd /real/path<TAB>` | falls straight through to normal filesystem completion |
| `nvim /real/path<TAB>` | falls straight through to normal filesystem completion |

## How it works

Each line in a datafile is `path|rank|last_accessed_epoch`. Every time you visit a directory or open a file via your editor wrapper, its rank is bumped and its timestamp updated. Frecency is computed at query time by weighting rank against how recently the entry was touched. When the sum of all ranks in a datafile crosses `$_LAZY_MAX_SCORE`, every rank is aged down by a factor of 0.99 to keep old entries from dominating forever.

Files are only added to `~/.lazyfile` when opened through your smart editor wrapper. Files opened by other means won't be tracked.

## Don'ts

- **Don't** source `lazy` in root's `.bashrc`. Running as root means tracking root's own datafiles and dealing with ownership headaches. 
- **Don't** manually run `sudo nvim foo`. Your shell will completely bypass this script's intelligence, skip the frecency database, and break the automation. Just let the wrapper handle the elevation for you natively!

## Have yet to implement:
- Multifile editing support
- Editor arguments support

## License

WTFPL, same as upstream. See [LICENSE](LICENSE).
