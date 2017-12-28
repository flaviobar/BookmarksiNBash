# [ -z "${BASH_VERSION}" ] && echo 'You are not running a bash version' && return 1

BBMARKSFILE="${HOME}/.bash_bookmarks"

__to_stderr(){
    echo -e "$*" >&2
}

__bb_printUsage () {
    local msg code
    readarray msg <<EOF
    .Usage: $prog [-l] [-a [bookmark]] [-d [bookmark]] [/dir/path]
    .       $prog bookmark
    .
    .Without any option the command goto the directory pointed by the bookmark.
    . -- states for the end of the options.
    .
    .Options:
    .
    .  -h              show this usage message, then exit
    .  -l              list defined bookmarks
    .  -a [bookmark]   add a bookmark to the list of bookmarks
    .  -d [bookmark]   delete a bookmark
    .  -r              reset all bookmarks
    .
    .Synopsis
    .
    . $prog -a               add \$PWD to the bookmark list, naming it as \${PWD##/}
    . $prog -a bmark         add \$PWD to the bookmark list, naming it as bmark
    . $prog -a -- path       add path to the bookmark list, naming it as \${path##/}
    . $prog -a bmark path    add path to the bookmark list, naming it as bmark
    .
    . $prog -d               delete \$PWD from the bookmark list
    . $prog -d bmark         delete bmark from the bookmark list
    . $prog -d -- path       delete path from the bookmark list, giving notification
    .                           of the found name
    . $prog -d bmark path    delete bmark from the bookmark list but only 
    .                           if it points to path
    .
    . $prog -l [bmark1] ...  list bookmark[s], showing paths. Without parameters it 
    .                           shows all defined bookmarks
    .
    . $prog bmark            go to bmark
    .
EOF
    shopt -s extglob
    printf '%s' "${msg[@]#+( ).}"
    shopt -u extglob
    code=1
    [[ $opt == "h" ]] && code=0
    return $code
}

declare -A _Bstore
declare __bb_reply

__bb_load_bookmarks(){
    local line
    local key
    local value
    exec 4<$1
    set -f ## disable pathname expansion

    while IFS=$'\t' read -u 4 -r key value || [[ -n "${key}" ]] ; do
        [[ "${key}" =~ ^[[:blank:]]*$ ]] && continue        # skip blank lines
        [[ "${key}" =~ ^[[:blank:]]*#.* ]] && continue  # skip comment lines
        [[ "${value}" =~ ^[[:blank:]]*#.* ]] && continue
        [[ -z "${value}" ]] && continue # skip empty bookmarks
        _Bstore[$key]="${value}"
    done
    set +f
    exec 4>&-
    unset IFS
}

__bb_reload_bmarks(){
    unset _Bstore
    declare -g -A _Bstore
    __bb_load_bookmarks ${BBMARKSFILE}
}

[[ -r ${BBMARKSFILE} ]] || : > ${BBMARKSFILE}
__bb_load_bookmarks ${BBMARKSFILE}

__bb_search_key(){
    local key="$1"
    local k
    for k in "${!_Bstore[@]}" ; do
        [[ "${k}" == "${key}" ]] && return 0
    done
    return 1
}

__bb_search_val(){
    local val="$1"
    local k
    for k in "${!_Bstore[@]}" ; do
        [[ "${_Bstore[$k]}" == "${val}" ]] && __bb_reply="$k" && return 0
    done
    return 1
}

__bb_ask4overwrite(){
    local overwrite
    read -e -N 1 -p 'Bookmark already exists, overwrite?([yY]/[nN]) ' overwrite
    [[ ${overwrite} =~ ^[yY]$ ]] && return 0
    return 1
}

__bb_writefile(){
    local fle="$1"
    : > ${fle:=${BBMARKSFILE}}
    for k in "${!_Bstore[@]}" ; do
        echo -e "${k}\t${_Bstore[$k]}" >> "${fle}"
    done
}

__bb_list(){
    local bm ll strmax=0
    [[ "$1" ]] && ll=( "$@" ) || ll=( "${!_Bstore[@]}" )
    for bm in "${ll[@]}" ; do
        (( strmax < ${#bm} )) && strmax=${#bm}
    done
    (( strmax+=2 ))
    for bm in "${ll[@]}" ; do
        printf " %-${strmax}s%s\n" "${bm}" "${_Bstore[$bm]}"
    done
}

__bb_add(){
    local bookmark="$1"
    local path="$2"
    [[ -d "${path}" ]] && [[ -x "${path}" ]] ||
        { __to_stderr "Path of destination doesn't exist or is not reachable, bookmark not created" ; return 1 ; }
    pushd "${path}" > /dev/null
    path="${PWD}"
    popd > /dev/null
    __bb_search_key "${bookmark}" && 
        ! __bb_ask4overwrite || { _Bstore[$bookmark]="${path}" && __bb_writefile ; }
}

__bb_del(){
    local bookmark="$1"
    __bb_search_key "${bookmark}" && { unset "_Bstore[${bookmark}]" && __bb_writefile ; } ||
        { __to_stderr "Bookmark does not exist" ; return 1 ; }
}

__bb_reset(){
    __bb_writefile ${BBMARKSFILE}.bak
    unset _Bstore
    declare -g -A _Bstore
    : > ${BBMARKSFILE}
}

__bb_del_path(){
    local path="$1" tmp
    pushd "${path}" > /dev/null
    path="${PWD}"
    popd > /dev/null
    __bb_search_val "${path}"
    tmp=$?
    if (( tmp )) ; then
        __to_stderr "${path} not found in bookmarks"
        return $tmp
    else
        echo "Deleting bookmark"
        __bb_list "${__bb_reply}"
        __bb_del "${__bb_reply}"
        __bb_reply=
    fi
}

__bb_goto(){
    local bm  bmark="$1"
    __bb_search_key "${bmark}" || return 1
    [[ -d "${_Bstore[$bmark]}" ]] || return 2
    [[ -x "${_Bstore[$bmark]}" ]] || return 3
    for bm in "${!_Bstore[@]}" ; do
        [[ "${bmark}" == "${bm}" ]] && { [[ "${PWD}" != "${_Bstore[$bm]}" ]] && cd "${_Bstore[$bm]}" || : ;} && return 0
    done
    return 1
}

valid_optarg(){
    ## invalid OPTARG if it begins with a dash
    # (( ${#OPTARG} > 1 )) && [[ ${OPTARG:0:1} == '-' ]] && {
    [[ ${OPTARG:0:1} == '-' ]] && {
        __to_stderr "Argument of -${opt} option cannot begin with -" 
        OPTARG=$opt
        ((OPTIND-=1))
        opt=":"
        return 1
    }
    return 0
}

bb(){
    prog=${FUNCNAME[0]}
    OPTIND=1
    local llist=0 ladd=0 ldel=0 lreset=0
    local i nexpos toadd todel tmp sum opt
    while getopts ':adhlr-' opt ; do
    # while getopts ':a:bcd:-' opt ; do
        i=1
        while (( i )) ; do
            i=0
            case $opt in
                # interpreting double dash as the end of the options
                # a) valid_optarg && {
                #        echo argomento valido  $opt ${OPTIND} ${OPTARG} ; } || {
                #        echo argomento non valido $opt $OPTIND $OPTARG ; i=1 ; continue ; }
                #  ;;
                # b is an option with an optional argument
                # b) zz=${@:$OPTIND:1} ;
                #    [[ ${zz:0:1} != '-' ]] && {
                #        OPTARG=$zz
                #        ((OPTIND+=1))
                #    }
                #    echo $opt $OPTIND $OPTARG
                #    ;;
                # c) echo $opt $OPTIND $OPTARG
                #    ;;
                # d) echo $opt $OPTIND $OPTARG
                #    ;;
                # -) break 2
                #    ;;
                # \:) echo opzione -${OPTARG} necessita di argomento obligatorio
                #     return 1
                #     ;;
                # \?) echo opzione -${OPTARG} inesistente && return 1 ;
                
                h) __bb_printUsage
                   return $?
                   ;;
                l) llist=1
                   ;;
                a) ladd=1
                   nexpos=${@:$OPTIND:1}
                   [[ ${nexpos:0:1} != '-' ]] && {
                       toadd="${nexpos}"
                       (( OPTIND+=1 ))
                   }
                   ;;
                d) ldel=1
                   nexpos=${@:$OPTIND:1}
                   [[ ${nexpos:0:1} != '-' ]] && {
                       todel="${nexpos}"
                       (( OPTIND+=1 ))
                   }
                   ;;
                r) lreset=1
                   ;;
                # f) valid_optarg && {
                #        laltfile=1
                #        newBfile=${OPTARG}
                #      } || { i=1 ; continue ; }
                #    ;;
                -) break 2
                   ;;
                \:) __to_stderr "Option -${OPTARG} needs a mandatory (valid) argument"
                    return 1
                    ;;
                \?) __to_stderr "Option -${OPTARG} doesn't exist" && return 1
                    ;;
            esac
        done
    done
    sum=$(( llist+ladd+ldel+lreset ))

    (( sum+${#@} )) || { __bb_printUsage || return 1 ; }
    
    if (( sum > 1 )) ; then
        __to_stderr "Options -a, -d, -l and -r are mutually exclusive. Only one of these can be used at once"
        return 2
    fi
    
    shift $(($OPTIND - 1))
    
    __bb_reload_bmarks
    
    (( llist )) && __bb_list $@ && return 0

    (( lreset )) && __bb_reset && return 0

    (( ${#@} > 1 )) &&
        __to_stderr "Only one positional argument allowed, using the first one"
    
    nexpos="$1"

    toadd="${toadd:--}"
    todel="${todel:--}"
    
    if (( ladd )) ; then
        # __bb_add $bookmark $path
        if [[ "${toadd}" == '-' ]] ; then
            # here if -a without parameter
            nexpos="${nexpos:-${PWD}}"
            [[ "${nexpos}" =~ (.*)/$ ]] && nexpos="${BASH_REMATCH[1]}"
            __bb_add "${nexpos##*/}" "${nexpos}" || return $?
            # if [[ -z ${nexpos} ]] ; then
            #   # without $1
            #   __bb_add ${PWD##*/} ${PWD} || return $?
            # else
            #   __bb_add ${nexpos##*/} ${nexpos} || return $?
            # fi
        else
            # here if -a with parameter
            nexpos="${nexpos:-${PWD}}"
            __bb_add "${toadd}" "${nexpos}" || return $?
            # if [[ -z ${nexpos} ]] ; then
            #   # without $1
            #   __bb_add ${toadd} ${PWD} || return $?
            # else
            #   __bb_add ${toadd} ${nexpos} || return $?
            # fi
        fi
    elif (( ldel )) ; then
        if [[ "${todel}" == '-' ]] ; then
            # here if -d without parameter
            nexpos="${nexpos:-${PWD}}"
            __bb_del_path "${nexpos}" || return $?
        else
            # here if -d with parameter
            if [[ -z "${nexpos}" ]] ; then
                __bb_del "${todel}" || return $?
            else
                [[ "${nexpos}" =~ (.*)/$ ]] && nexpos="${BASH_REMATCH[1]}"
                [[ "${_Bstore[$todel]}" == "${nexpos}" ]] && __bb_del "${todel}" || {
                        __to_stderr "There is no bookmark ${todel} pointing to ${nexpos}"
                        return 1
                    }
            fi
        fi
    else
	__bb_goto "${nexpos}" || {
	    __to_stderr ' '"${nexpos}  ${_Bstore[nextpos]}\n Bookmark or destination doesn't exist" 
	    return 1
	}
    fi
}


# TODO

