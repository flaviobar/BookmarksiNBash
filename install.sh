#!/bin/bash

user_install_path=

! (( $UID )) && install_path=/usr/local/share || install_path=.local/share



[[ -f .git/HEAD ]] && branchPath=.git/$(cat .git/HEAD | cut -d " " -f 2)

cat $branchPath > version


