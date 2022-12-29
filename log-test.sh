#!/bin/bash

log() {
    local prefix=""
    local stream=1
    local files=()
    # handle options
    while ! ${1+false}
    do case "$1" in
        -e|--error) prefix="ERROR:"; stream=2 ;;
        -f|--file) shift; files+=("${1-}") ;;
        --) shift; break ;; # end of arguments
        -*) log -e "log: invalid option '$1'"; return 1;;
        *) break ;; # start of message
       esac
       shift
    done
    if ${1+false}
    then log -e "log: no message!"; return 1;
    fi
    # if we have a prefix, update our argument list
    if [ "$prefix" ]
    then set -- "$prefix" "$@"
    fi
    # now perform the action
    printf '%b ' "$@" '\n' | tee -a "${files[@]}" >&$stream
}

log "hello" "INFO"