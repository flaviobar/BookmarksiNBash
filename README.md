# BookmarksiNBash

Bash4 extension (written only in and for bash4) to implement a
bookmark system

# Installation

Take bookmarks4bash.bash and put in a directory that you like. (DIR_THAT_YOU_LIKE)

Append in your ~/.bashrc:

    case $- in
        *i*) [ ${BASH_VERSION%%.*} -ge 4 ] &&
            . ${DIR_THAT_YOU_LIKE}/bookmarks4bash.bash ;;
    esac

~/.bashrc should be called in .profile file.
