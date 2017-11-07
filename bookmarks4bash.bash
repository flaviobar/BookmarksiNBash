#!/usr/bin/env bash
[[ -z ${BASH_VERSION} ]] && echo 'You are not running a bash version' && exit 1
BBMARKSFILE="~/.b4brc"

__bb_printUsage () {
    prog=${0#*/}
    local msg
    readarray msg <<EOF
    .Usage: $prog [-l] [-a [/dir/path]] [-d [/dir/path]] [bookmark]
    .
    .Without any option the command goto the directory pointed by the bookmark.
    .
    .Options:
    .
    .  -h              show this usage message, then exit
    .  -l              list defined bookmarks
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
    local fst=1
    [[ -z ${!_Bstore[*]} ]] && {
	: > ${BBMARKSFILE}
	return 0
    }
    for k in ${!_Bstore[@]} ; do
	(( fst )) && {
	    echo ${k} ${_Bstore[$k]} > ${BBMARKSFILE}
	    fst=0 ;\
	} ||
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
    __bb_search_key ${bmark} || return 1
    [[ -d ${bmark} ]] || return 2
    [[ -x ${bmark} ]] || return 3
    for bm in ${!_Bstore[@]} ; do
	[[ ${bmark} == ${bm} ]] && cd ${_Bstore[$bm]} && break
    done
    return 0
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

valid_optarg(){
    ## invalid OPTARG if it begins with a dash
    # (( ${#OPTARG} > 1 )) && [[ ${OPTARG:0:1} == '-' ]] && {
    [[ ${OPTARG:0:1} == '-' ]] && {
	echo "Argument of -${opt} option cannot begin with -" 
	OPTARG=$opt
	((OPTIND-=1))
	opt=":"
	return 1
    }
    return 0
}

bb(){
    OPTIND=1
    local llist=0 ladd=0 ldel=0 i nexpos toadd todel 
    while getopts ':adhl-' opt ; do
    # while getopts ':a:bcd:-' opt ; do
	i=1
	while (( i )) ; do
	    i=0
	    case $opt in
		# interpreting double dash as the end of the options
		# a) valid_optarg && {
		# 	 echo argomento valido  $opt ${OPTIND} ${OPTARG} ; } || {
		# 	 echo argomento non valido $opt $OPTIND $OPTARG ; i=1 ; continue ; }
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
		       toadd=${nexpos}
		       (( OPTIND+=1 ))
		   }
		   ;;
		d) ldel=1
		   nexpos=${@:$OPTIND:1}
		   [[ ${nexpos:0:1} != '-' ]] && {
		       todel=${nexpos}
		       (( OPTIND+=1 ))
		   }
		   ;;
		# f) valid_optarg && {
		# 	 laltfile=1
		# 	 newBfile=${OPTARG}
		#      } || { i=1 ; continue ; }
		#    ;;
		-) break 2
		   ;;
		\:) echo "Option -${OPTARG} needs a mandatory (valid) argument"
		    return 1
		    ;;
		\?) echo "Opzion -${OPTARG} doesn't exist" && return 1 ;
	    esac
	done
    done
    if (( llist+ladd+ldel > 1 )) ; then
	echo "Options -a, -d and -l are mutually exclusive. Only one of these can be used at once"
	return 2
    fi
    shift $(($OPTIND - 1))
    
    (( llist )) && __bb_list && return 0

    (( ${#@} > 1 )) &&
	echo "Only one positional argument allowed, using the first one"
    
    nexpos=$1

    toadd=${toadd:-'-'}
    todel=${todel:-'-'}
    
    if (( ladd )) ; then
	# __bb_add $bookmark $path
	if [[ ${toadd} == '-' ]] ; then
	    # here if -a without parameter
	    if [[ -z ${nexpos} ]] ; then
		# without $1
		__bb_add ${PWD##/} ${PWD}
	    else
		__bb_add  ${PWD}
		return 0
	    fi
	elif [[ ${toadd} != '-' ]] ; then
	    # here if -a with parameter
	    if [[ -z ${nexpos} ]] ; then
		# without $1
		__bb_add ${toadd} ${PWD}
	    else
		__bb_add  ${PWD}
		return 0
	    fi
	fi
    elif (( ldel )) ; then
	if [[ ${toadd} == '-' ]] ; then
	    [[ -z ${nexpos} ]] && {
		
		return
	    }
	elif [[ ${toadd} != '-' ]] ; then
	    :
	fi
    else
	__bb_goto ${nexpos} ||
	    echo -e ' '"${nexpos}  ${_Bstore[nextpos]}\n Bookmark or destination doesn't exist"
    fi
}

# appunti di ffunzionamento
### bb -a               aggiunge pwd ai bookmark e lo chiama ${PWD##/}
### bb -a pippo         aggiunge pwd ai bookmark e lo chiama pippo
### bb -a -- path       aggiunge path ai bookmark e lo chiama ${path##/}
### bb -a pippo path aggiunge path ai bookmark e lo chiama ${pippo##/}

### bb -d               elimina PWD dai bookmark se c'è
### bb -d pippo         elimina pippo dai bookmark se c'è
### bb -d -- path       elimina path se presente e notifica il nome trovato
### bb -d pippo path    cerca nome pippo o path ed elimina quello che prova, previa notifica

### bb pippo            va al nome pippo (più avanti cerca pippo nei path registrati, chiede e va)
