#!/bin/bash
set -x

if [ $# != 1 ]; then
    echo "Usage: filter-requires.sh <pattern_to_pass_to_grep>. The pattern passed will be removed from the list of requirements for installing this package." >&2
    echo "Terminating." >&2
    exit 1
fi

if [ -x /usr/lib/rpm/redhat/find-requires ] ; then
    FINDREQ=/usr/lib/rpm/redhat/find-requires
else
    FINDREQ=/usr/lib/rpm/find-requires
fi

output=`$FINDREQ` 

if [ ! -z "${output}" ]; then
    echo "${output}" | grep -v -e "^#" | grep -v -e "$1"
fi
