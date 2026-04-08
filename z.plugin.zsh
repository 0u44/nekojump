Z_DATABASE="${Z_DATABASE:-$HOME/.z_database}"
__Z_MAX_SCORE=10000
__Z_DATABASE_VERSION=1

_z_init_db() {
    [[ -f "$1" ]] || print "VERSION: $__Z_DATABASE_VERSION" > "$1"
}

_z_fail() {
    print -P "%F{red}$1%f" >&2
}

_z_warn() {
    print -P "%F{yellow}$1%f" >&2
}


_z_check_db_compat() {
    local db="$1"
    [[ -f "$db" ]] || return 0
    local db_version
    db_version="$(head -n 1 "$db" 2>/dev/null)"
    [[ "$db_version" == "VERSION: $__Z_DATABASE_VERSION" ]] && return 0
    _z_fail "Incompatible database version in $db (found: $db_version, expected: VERSION: $__Z_DATABASE_VERSION)"
    return 1
}

_z_track() {
    local db="$Z_DATABASE"
    local db_lock="${db}.lock"
    local temp_db="${db}.$$"
    local now="$(date +%s)"
    local target="$PWD"

    # [[ -f "$db_lock" ]] 
    
    _z_init_db "$db"
    _z_check_db_compat "$db" || return 1

    # [[ -f "$db.lock" ]] || \touch "$db.lock"

    _z_init_db "$temp_db"
    \awk -F '|' -v now="$now" -v target="$target" -v max="$__Z_MAX_SCORE" '
    BEGIN { found = 0 }
    NR>1 {
        score = $1; path = $2; ts = $3
        days = (now - ts) / 86400
        if (days > 0) score = score * (0.9 ^ days)
        
        if (path == target) {
            score += 1
            ts = now
            found = 1
        }
        
        if (score > max) score = max
        if (score >= 0.01) printf "%.3f|%s|%s\n", score, path, ts
    }
    END {
        if (!found) printf "1.000|%s|%s\n", target, now
    }' "$db" >> "$temp_db" && \mv -f "$temp_db" "$db"
}

zcd() {
    local query="$*"
    
    if [[ -d "$query" ]]; then
        cd "$query"
        return 0
    elif [[ -f "$query" ]]; then
        cd "${query:h}"
        return 0
    fi

    local parent="$PWD"
    local lower_query="${(L)query}"
    while [[ "$parent" != "/" && "$parent" != "." ]]; do
        parent="${parent:h}"
        if [[ "${(L)parent:t}" == *"$lower_query"* ]]; then
            cd "$parent"
            return 0
        fi
        [[ "$parent" == "/" ]] && break
    done

    local db="$Z_DATABASE"
    [[ -f "$db" ]] || {
        _z_fail "the Z database dosen't exist"
        _z_warn "failing back to the old cd command"
        cd "$query"
        return $?
    }

    _z_check_db_compat "$db" || {
        _z_warn "failing back to the old cd command"
        cd "$query"
        return $?
    }
    
    local match
    match=$(awk -F'|' -v q="$query" '
        BEGIN { IGNORECASE=1 } 
        NR>1 && $2 ~ q { print $1, $2 }
    ' "$db" 2>/dev/null | sort -k1,1nr | head -n 1 | cut -d' ' -f2-)

    if [[ -z "$match" ]]; then
        _z_fail "No match found for '$1'"
        return 1
    fi

    # Handle case where matched path is a file (unlikely but safe)
    if [[ -f "$match" ]]; then
        _z_warn 'the match is a file, using the parent'
        match="${match:h}"
    fi

    if [[ -d "$match" ]]; then
        cd "$match"
    else
        _z_fail "z: Match exists in DB but directory is missing: $match"
        # TODO(anas): Clean up here automatically?
        return 1
    fi
}

zi() {
    command -v fzf >/dev/null || return 69
    local db="$Z_DATABASE"
    [[ -f "$db" ]] || return 1
    _z_check_db_compat "$db" || return 1
    local dest="$(tail --lines=+2 "$db" | sort -t '|' -k1 -nr | cut -d '|' -f 2 | fzf)"
    [[ -n "$dest" ]] && cd "$dest"
}

zd() {
    local db="$Z_DATABASE"
    local temp_db="${db}.$$"
    local target="${1:-$PWD}"
    _z_init_db "$temp_db"
    _z_check_db_compat "$db" || return 1
    \awk -F '|' -v target="$target" 'NR>1 && $2 != target' "$db" >> "$temp_db" && \mv -f "$temp_db" "$db"
}

zclean() {
    local db="$Z_DATABASE"
    local temp_db="${db}.$$"
    _z_init_db "$temp_db"
    _z_check_db_compat "$db" || return 1
    \awk -F '|' '{
        if (system("test -d \"" $2 "\"") == 0) print $0
    }' "$db" >> "$temp_db" && \mv  -f "$temp_db" "$db"
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd _z_track
[[ ! -f "$Z_DATABASE" ]] && _z_init_db "$Z_DATABASE"
alias z="zcd"
