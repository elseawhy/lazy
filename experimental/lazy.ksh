# Copyright (c) 2009 rupa deadwyler - core frecency concept
# Copyright (c) 2026 Joerg van den Hoff (jghub) - exponential decay
# Copyright (c) 2026 elseawhy - file tracking, smart wrappers & auto-escalation
#
# Original z.sh was distributed under the WTFPL v2.
# lazy is distributed under the MIT License, forked/extended to track files.

_LAZY_REAL_HOME="$(realpath "$HOME" 2>/dev/null || echo "$HOME")"
_LAZY_DIR_DB="$(realpath "${_LAZY_DIR_DB:-$_LAZY_REAL_HOME/.lazydir}" 2>/dev/null || echo "${_LAZY_DIR_DB:-$_LAZY_REAL_HOME/.lazydir}")"
_LAZY_FILE_DB="$(realpath "${_LAZY_FILE_DB:-$_LAZY_REAL_HOME/.lazyfile}" 2>/dev/null || echo "${_LAZY_FILE_DB:-$_LAZY_REAL_HOME/.lazyfile}")"

[[ -d "$_LAZY_DIR_DB" || -d "$_LAZY_FILE_DB" ]] && { echo "lazy: $_LAZY_DIR_DB or $_LAZY_FILE_DB is a directory" >&2; return 1; }

_LAZY_MAX_ENTRIES=$(
	awk -v H="${_LAZY_HALF_LIFE:-85}" -v M="${_LAZY_MAX_ENTRIES:-1000}" '
		BEGIN { 
			safe = int(1 / (1 - (0.5 ^ (1 / H)))) + 1; 
			if (M < safe) { 
				printf "lazy: _LAZY_MAX_ENTRIES is too low. Automatically set to the minimum safe number (%d) to guarantee entry tracking.\n", safe > "/dev/stderr";
				print safe
			} else print M 
		}
	'
)

export EDITOR="${EDITOR:-${VISUAL:-nano}}"
export VISUAL="$EDITOR"

_lazy_editor_alias="${EDITOR%% *}"
alias cd='_lazy_cd'
alias "${_lazy_editor_alias##*/}"='_lazy_editor'

function _lazy_write {
	[[ ! ( ( "$1" == "$_LAZY_DIR_DB" && "$2" == "-d" ) || ( "$1" == "$_LAZY_FILE_DB" && "$2" == "-f" ) ) || -z "$3" ]] && return 1
    [[ ( "$2" == "-d" && "$3" != "$HOME/"* ) || ( "$2" == "-f" && "$3" != "$_LAZY_REAL_HOME/"* ) ]] && return 0

    typeset db="$1" flag="$2" target="$3" blacklist
    shift 3
    for blacklist in "$@"; do
        [[ -n "$blacklist" && "$target" == "$blacklist"* ]] && return 0
    done

    [[ -f "$db" ]] || touch "$db" 2>/dev/null || return 1
    typeset tempfile="$(mktemp "${db}.XXXXXX")"
    
    if while IFS=$'\t' read -r path rest; do
        [ $flag "$path" ] && printf "%s\t%s\n" "$path" "$rest"
    done < "$db" 2>/dev/null | awk -F'\t' -v target="$target" -v H="${_LAZY_HALF_LIFE:-85}" '
        BEGIN { OFS="\t"; OFMT="%.17g"; CONVFMT="%.17g"; decay = 2 ^ (1 / H) }
        NF == 2 {
            if ($1 == target) {
                found = 1
                print $1, ($2 / decay) + 1
            } else print $1, $2 / decay
        }
        END { if (!found) print target, 1 }
    ' | LC_ALL=C sort -t$'\t' -k2,2gr -k1,1 | head -n "$_LAZY_MAX_ENTRIES" > "$tempfile" && [[ -s "$tempfile" ]]; then
    	\env mv -f "$tempfile" "$db"
	else
    	\env rm -f "$tempfile"
	fi
}

function _lazy_read {
    [[ -z "$2" || ! -f "$1" ]] && return 1
    typeset db="$1"
    shift
    awk -F'\t' -v query="$*" '
        BEGIN {
            gsub(/ /, ".*", query)
            case_sensitive = (query != tolower(query))
        }
        NF == 2 {
            base = parts[split($1, parts, "/")]
            if ((case_sensitive ? base : tolower(base)) ~ query) {
                print $1
                found = 1
                exit
            }
        }
        END { exit !found }
    ' "$db"
}

function _lazy_cd {
    typeset old_pwd="$PWD"
    [[ $# -gt 0 && "$1" != "-" && ! -d "$*" ]] && set -- "$(_lazy_read "$_LAZY_DIR_DB" "$@" || echo "$*")"
    command cd ${1+"$*"} || return
    [[ "$old_pwd" != "$PWD" ]] && (_lazy_write "$_LAZY_DIR_DB" -d "$PWD" ${_LAZY_DIR_BLACKLIST[@]+"${_LAZY_DIR_BLACKLIST[@]}"} 2>/dev/null &)
}

function _lazy_editor {
    typeset target exec_cmd
    [[ $# -eq 0 || " $*" == *" "[-+]* ]] && {
    	set -A exec_cmd -- $EDITOR
    	command "${exec_cmd[@]}" "$@"
    	return
    }
    for target; do
        set -A exec_cmd -- $EDITOR
        
        [[ "$target" != */* && ! -f "$target" ]] && target="$(_lazy_read "$_LAZY_FILE_DB" "$target" 2>/dev/null || echo "$target")"
        if [[ -f "$target" ]]; then
            target="$(realpath "$target" 2>/dev/null || echo "$target")"
            (_lazy_write "$_LAZY_FILE_DB" -f "$target" ${_LAZY_FILE_BLACKLIST[@]+"${_LAZY_FILE_BLACKLIST[@]}"} &)
            [[ ! -w "$target" ]] && set -A exec_cmd -- sudo -e
        else
        	typeset dname="${target%/*}"
        	[[ "$dname" == "$target" ]] && dname="."
        	[[ -z "$dname" ]] && dname="/"
        	[[ ! -d "$dname" ]] && {
        		echo "lazy: directory '$dname' does not exist for target '$target'" >&2
        		continue
        	}
            [[ ! -w "$dname" ]] && set -A exec_cmd -- sudo -e
        fi
        command "${exec_cmd[@]}" "$target"
    done
}

function lazy {
    printf "lazy - frecency-based smart cd and editor launcher\n\n\
USAGE\n\
  %-21s%s\n\
  %-21s%s\n\
  %-21s%s\n\n\
TUNABLES (initialize these in .bashrc before sourcing lazy)\n\
  _LAZY_DIR_DB            directory datafile path (default: ~/.lazydir)\n\
  _LAZY_FILE_DB           file datafile path (default: ~/.lazyfile)\n\
  _LAZY_DIR_BLACKLIST     array of path prefixes to ignore for cd (default: empty)\n\
  _LAZY_FILE_BLACKLIST    array of path prefixes to ignore for editor (default: empty)\n\
  _LAZY_HALF_LIFE         commands until score halves (default: 85)\n\
  _LAZY_MAX_ENTRIES       maximum number of entries to track per file (default: 1000)\n\
  _LAZY_MAX_COMPLETIONS   maximum number of matches to show in completion (default: 10)\n\
  EDITOR                  program used to open matched files (default: nano)\n\n\
CURRENT STATS\n\
  %-24s%s\n\
  %-24s%s\n\
  %-24s%s\n" \
        "lazy" "show this help" \
        "cd foo" "falls back to smart directory jump" \
        "${_lazy_editor_alias##*/} foo" "falls back to smart file open (auto-escalates if no write permission)" \
        "Half-Life" "${_LAZY_HALF_LIFE:-85} commands" \
        "Maximum Entries" "$_LAZY_MAX_ENTRIES" \
        "Maximum possible score" "$(awk -v H="${_LAZY_HALF_LIFE:-85}" 'BEGIN { printf "%.1f", 1 / (1 - (0.5 ^ (1 / H))) }')"
}
