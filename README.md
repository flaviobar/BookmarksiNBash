# BookmarksiNBash

Bash4 extension (written only in and for bash4) to implement a
bookmark system

# Installation

Put in your ~/.bashrc:

    case $- in
        *i*) [ ${BASH_VERSION%%.*} -ge 4 ] &&
            . ${HOME}/src/BookmarksiNBash/bookmarks4bash.bash ;;
    esac

~/.bashrc should be called in .profile file.
