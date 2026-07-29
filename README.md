# lazy

`lazy` is a fork of [rupa/z](https://github.com/rupa/z) — a shell script that
tracks your most-used directories by *frecency* (frequency + recency) so you
can jump to them by typing a fragment of the name instead of the full path.

This fork extends the same idea to **files**, not just directories, and folds
in a couple of quality-of-life changes on top:

- Tracks files and directories in **separate datafiles** (`~/.lazydir`,
  `~/.lazyfile`), so directory and file matching never collide.
- Ships `cd()` and `e()` wrapper functions out of the box — `cd` falls back
  to fuzzy directory matching, `e` falls back to fuzzy file matching and
  opens the result in your editor.
- Tab completion is type-aware: completing after `cd` only offers
  directories, completing after `e` only offers files.
- A configurable `$_LAZY_EDITOR` controls what opens matched files — change
  editors without touching any function or alias.
- Built-in `lazy help` (or `-h` / `--help`) prints every flag and tunable.

All credit for the original algorithm, the frecency scoring, and the aging
logic goes to [rupa deadwyler](https://github.com/rupa) — this is a fork,
not a rewrite from scratch.

## Install

Put this in your `.bashrc` or `.zshrc`:

```bash
. /path/to/lazy
```

Then just use your shell normally — `cd` around, `e` a few files — for a
day or two to build up the database. Optionally set any of the tunables
below **before** the `source` line.

```bash
export _LAZY_MAX_SCORE=999999999999
export _LAZY_EDITOR=nvim
```

Run `lazy help` any time for the full reference.

## Use

```
lazy foo             go to the best match (dir -> cd, file -> open in $_LAZY_EDITOR)
lazy dir foo         restrict matches to directories, cd to the best one
lazy file foo        restrict matches to files, open the best one
lazy foo bar         match against multiple terms
cd foo                fuzzy-cd fallback when foo isn't a real directory
e foo                 fuzzy-open fallback when foo isn't a real file
```

> The `dir`/`file` subcommand must come immediately after `lazy`, before any
> flags — `lazy file -e foo`, not `lazy -e file foo`.

### Flags

| Flag | Meaning |
| --- | --- |
| `-c` | restrict matches to subdirectories of `$PWD` |
| `-e` | echo the best match instead of acting on it |
| `-h` | show help (same as `lazy help`) |
| `-l` | list all matches instead of acting on one |
| `-r` | go by highest rank instead of frecency |
| `-t` | go by most recently accessed instead of frecency |
| `-x` | remove the current directory from the directory datafile |
| `--` | treat all remaining args as literal search terms |

### Tunables

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
| `_LAZY_NO_E_WRAP` | — | don't define the built-in `e()` wrapper |

## How it works

Each line in a datafile is `path|rank|last_accessed_epoch`. Every time you
visit a directory (via the shell prompt hook) or open a file (via `e`), its
rank is bumped and its timestamp updated. Frecency is computed at query time
by weighting rank against how recently the entry was touched, so something
used a lot a while ago and something used once five minutes ago can both
surface near the top, depending on the exact numbers. When the sum of all
ranks in a datafile crosses `$_LAZY_MAX_SCORE`, every rank is aged down by a
factor of 0.99 to keep old, stale entries from dominating forever.

Files are only added to `~/.lazyfile` when opened through `e` or
`lazy file` — there's no way to hook every possible editor invocation
automatically, so a file opened by some other means (straight `nvim path`,
an IDE, etc.) won't be tracked unless it goes through `lazy`.

## Do's and Don'ts

- **Don't** source `lazy` in root's `.bashrc`/`.zshrc`, or run it as root via
  `sudo -s` without care. `cd()`/`e()` are shell functions, not real
  binaries — they only exist inside the shell that sourced them, so running
  it as root just means root now has fuzzy-cd too, tracking root's own
  `~/.lazydir`/`~/.lazyfile`, with root's usual footguns (wrong ownership on
  datafiles, `_LAZY_OWNER` easy to get wrong, etc.). There's no real upside
  to it living in root's shell.
- **Don't** run `sudo e foo`. `sudo` execs a literal binary named `e` from
  `$PATH` — it has no idea `e` is a function in your normal shell, so it
  will just fail with `sudo: e: command not found`.
- **Do** use `sudoedit /path/to/file` (or `sudo -e /path/to/file`, same
  thing) when you need to edit a file you don't own. It edits a temp copy
  under your own user and only writes back with elevated privileges,
  which is both safer and simpler than trying to get `lazy`/`e` to work
  under `sudo`.
- **Do** keep `lazy` scoped to your normal user shell. If you genuinely need
  frecency-based matching while root (rare), it's cleaner to `sudo -E -s`
  (preserve your environment) and point `_LAZY_DIR_DATA`/`_LAZY_FILE_DATA`
  at your own datafiles explicitly, rather than sourcing it from root's own
  dotfiles.

## License

WTFPL, same as upstream. See [LICENSE](LICENSE).
