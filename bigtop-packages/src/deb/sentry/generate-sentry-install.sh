#!/bin/bash

# We need to exlude the /plugin folder from under /usr/lib/sentry/lib.
# 1. Creating a temporary file, and append to it all the files from uder /usr/lib/sentry/lib
# 2. Compare the aggregated contents of the temp file and sentry.install.include_temp with that of sentry-hdfs-plugin.install and remove overlapping strings
# 3. The resulting file sentry.install now has all files barring files under /plugin

set -x

rm -f debian/sentry.install.include_temp

for files in debian/tmp/usr/lib/sentry/lib/*
do
  echo ${files} | cut -d '/' -f3- | sed 's/^/\//' >> debian/sentry.install.include_temp
done

rm -f debian/sentry.install
cat debian/sentry.install.include_temp debian/sentry.install.include | grep -v -x -f debian/sentry-hdfs-plugin.install > debian/sentry.install