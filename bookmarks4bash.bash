#!/usr/bin/env bash
[[ -z ${BASH_VERSION} ]] && echo 'You are not running a bash version' && exit 1
BBMARKSFILE="~/.b4brc"

__bb_printUsage () {
    prog=${0#*/}
    local msg
    readarray msg <<EOF
    .Usage: $prog [-l] [-a [/dir/path]] [-d [/dir/path]] [-f bmark_file] [bookmark]
    .
    .Without any option the command goto the directory pointed by the bookmark.
    .
    .Options:
    .
    .  -h              show this usage message, then exit
    .  -l              list defined bookmarks
    .  -f bmark_file   use alternative bookmark file (default: ${BBMARKSFILE})
    .  -a [/dir/path]  add a bookmark to the list of bookmarks
    .  -d [/dir/path]  delete a bookmark
EOF
    shopt -s extglob
    printf '%s' "${msg[@]#+( ).}"
    shopt -u extglob
    code=1
    [[ $opt == "h" ]] && code=0
    return $code
}

declare -A _Bstore


__bb_load_bookmarks(){
    local line
    local key
    local value
    exec 6<$1
    set -f ## disable pathname expansion
    while IFS=' ' read -r -u 6 key value || [[ -n "${key}" ]] ; do
	[[ ${key} =~ ^[[:blank:]]*$ ]] && continue        # skip blank lines
	[[ ${key} =~ ^[[:blank:]]*#.* ]] && continue  # skip comment lines
	[[ "${value}" =~ ^[[:blank:]]*#.* ]] && continue
	[[ -z ${value} ]] && continue # skip empty bookmarks
	_Bstore[$key]=${value}
    done
    set +f
    exec 6>&-
    unset IFS
}

__bb_search_key(){
    local key=$1
    local k
    for k in ${!_Bstore[@]} ; do
	[[ ${k} == ${key} ]] && return 0
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
    rm ${BBMARKSFILE}
    for k in ${!_Bstore[@]} ; do
	echo ${k} ${_Bstore[$k]} >> ${BBMARKSFILE}
    done
}

[[ -r ${BBMARKSFILE} ]] && __bb_load_bookmarks ${BBMARKSFILE}

__bb_add(){
    local bookmark=$1
    local path=$2
    local found=''
    __bb_search_key ${bookmark} &&
	! __bb_ask4overwrite || { ${_Bstore[$bookmark]}=${path} && _writefile }
}

__bb_del(){
    local bookmark=$1
    __bb_search_key ${bookmark} && { unset ${_Bstore[$bookmark]} && __bb_writefile } ||
	    echo "Bookmark does not exist"
} 

__bb_goto(){
    local bm  bmark=$1
    for bm in ${!_Bstore[@]} ; do
	[[ ${bmark} == ${bm} ]] && cd ${_Bstore[$bm]} && return 0
    done
    return 1
}

__bb_list(){
    local bm strmax=0
    for bm in ${!_Bstore[@]} ; do
	(( strmax < ${#bm} )) && strmax=${#bm}
    done
    (( strmax+=2 ))
    for bm in ${!_Bstore[@]} ; do
	printf " %-${strmax}s%s\n" $bm ${_Bstore[$bm]};
    fi
}



bb(){
    local list dirpath bookmark badd
    list=0
    badd=0
    bdel=0
    while getopts ':a:d:f:hl' opt ; do
	case $opt in
	    h) __bb_printUsage ; return $? ;;
	    l) list=1 ;;
	    f) BBMARKSFILE=${OPTARG} ;;
	    a) badd=1 ; dirpath=${OPTARG} ;;
	    d) bdel=1 ; dirpath=${OPTARG} ;;
	esac
    done
    shift $(($OPTIND - 1))
    bookmark=$1
    (( badd )) && (( bdel ))
}
