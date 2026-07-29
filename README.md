# lazy

`lazy` is a heavily stripped-down fork of [rupa/z](https://github.com/rupa/z). It tracks your most-used directories by *frecency* (frequency + recency) so you can jump to them by typing a fragment of the name instead of the full path.

This fork extends the exact same concept to **files**, but removes all the bloated manual CLI commands. It is designed to be a completely silent, drop-in background utility that simply makes your `cd` and your `$EDITOR` smart. That's it. 

- Tracks files and directories in **separate datafiles** (`~/.lazydir`, `~/.lazyfile`), so directory and file matching never collide.
- Ships smart wrappers out of the box — `cd` falls back to fuzzy directory matching, and your preferred editor falls back to fuzzy file matching. 
- **Dynamically adapts to your editor:** Whether you use `nvim`, `emacs`, `micro`, or `nano`, the script automatically creates a smart wrapper function matching your editor's name.
- Tab completion is type-aware: completing after `cd` only offers directories, completing after your editor only offers files.
- Tab completion is context-aware: an empty word suggests your history, a fuzzy fragment (no `/`) searches the frecency database, and a real path (contains `/`) falls straight through to normal filesystem completion.
- Built-in `lazy help` (or `-h` / `--help`) prints the available tunables.

All credit for the original algorithm, the frecency scoring, and the aging logic goes to [rupa deadwyler](https://github.com/rupa). 

## Install

**Crucial Step:** You MUST set your editor variable *before* you source the script, or the smart file wrapper won't configure itself properly.

Put this in your `.bashrc` or `.zshrc`:

    # 1. Define your editor! (The script uses this to dynamically name the wrapper function)
    # This works with nvim, emacs, micro, nano, etc.
    export _LAZY_EDITOR="nvim"
    
    # 2. Source the script
    . /path/to/lazy

Then just use your terminal normally — `cd` around, open a few files — for a day or two to build up the database. 

## Use

There are no clunky `lazy file foo` or `lazy dir foo` commands to memorize. Just use your normal commands, and the script handles the rest quietly in the background.

Assuming you set `_LAZY_EDITOR="micro"`, your workflow looks like this:

    cd foo          # fuzzy-cd fallback when foo isn't a real directory
    micro foo       # fuzzy-open fallback when foo isn't a real file in the DB
    micro ./foo     # bypasses the database to explicitly create/open a file in $PWD

*(If your editor is `emacs`, just swap `micro` with `emacs` in the above examples.)*

### Tunables

You can override these by exporting them before the `source` line:

| Variable | Default | Purpose |
| --- | --- | --- |
| `_LAZY_CMD` | `lazy` | command name the script is aliased to |
| `_LAZY_DIR_DATA` | `~/.lazydir` | directory datafile path |
| `_LAZY_FILE_DATA` | `~/.lazyfile` | file datafile path |
| `_LAZY_MAX_SCORE` | `9000` | aging threshold before scores decay |
| `_LAZY_EDITOR` | `$EDITOR`, else `vi` | program used to open matched files |
| `_LAZY_OWNER` | — | username to chown datafiles to (for `sudo -s` use) |
| `_LAZY_EXCLUDE_DIRS` | — | array of path prefixes to never track |
| `_LAZY_NO_RESOLVE_SYMLINKS` | — | don't resolve symlinks when tracking `$PWD` |
| `_LAZY_NO_PROMPT_COMMAND` | — | don't auto-hook `PROMPT_COMMAND`/`precmd` |
| `_LAZY_NO_CD_WRAP` | — | don't define the built-in `cd()` wrapper |
| `_LAZY_NO_E_WRAP` | — | don't define the built-in editor wrapper |

### Tab completion

Completion is context-aware based on what you've typed (using `nvim` as an example here, but it adapts to your `_LAZY_EDITOR`):

| You type | What happens |
| --- | --- |
| `cd <TAB>` | lists your directory history from `.lazydir` |
| `nvim <TAB>` | lists your file history from `.lazyfile` |
| `cd te<TAB>` | fuzzy-matches `te` against directory history |
| `nvim te<TAB>` | fuzzy-matches `te` against file history |
| `cd /real/path<TAB>` | falls straight through to normal filesystem completion |
| `nvim /real/path<TAB>` | falls straight through to normal filesystem completion |

> **Note:** this fallback relies on bash's `-o default`/`-o bashdefault` completion options. Under zsh's `compctl`, there's no equivalent automatic fallback, so typing an explicit path currently only searches the frecency database even under zsh.

## How it works

Each line in a datafile is `path|rank|last_accessed_epoch`. Every time you visit a directory or open a file via your editor wrapper, its rank is bumped and its timestamp updated. Frecency is computed at query time by weighting rank against how recently the entry was touched. When the sum of all ranks in a datafile crosses `$_LAZY_MAX_SCORE`, every rank is aged down by a factor of 0.99 to keep old entries from dominating forever.

Files are only added to `~/.lazyfile` when opened through your smart editor wrapper. Files opened by other means won't be tracked.

## Do's and Don'ts

- **Don't** source `lazy` in root's `.bashrc`/`.zshrc`, or run it as root via `sudo -s` without care. `cd()` and your editor wrapper are shell functions, not real binaries. Running as root means tracking root's own datafiles and dealing with ownership headaches. 
- **Don't** run `sudo $EDITOR foo` expecting the fuzzy-search to work. `sudo` execs a literal binary from `$PATH` — it has no idea your editor is a function in your normal shell, so it will bypass the script entirely.
- **Do** use `sudoedit /path/to/file` (or `sudo -e /path/to/file`) when you need to edit a file you don't own. It edits a temp copy under your own user, which is cleaner than trying to force the jump-list to work under `sudo`.
- **Do** keep `lazy` scoped to your normal user shell. 

## License

WTFPL, same as upstream. See [LICENSE](LICENSE).
