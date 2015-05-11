#!/bin/bash
set -x


if [ $# != 1 ]; then
    echo "Usage: filter-provides.sh <pattern_to_pass_to_grep>. All occurances of this pattern will be removed from what this package provides" >&2
    echo "Terminating build." >&2
    exit 1
fi

if [ -x /usr/lib/rpm/redhat/find-provides ] ; then
     FINDPROV=/usr/lib/rpm/redhat/find-provides
else
    FINDPROV=/usr/lib/rpm/find-provides
fi

output=`$FINDPROV`

if [ ! -z "${output}" ]; then
    echo "${output}" | grep -v -e "$1"
fi
