#!/bin/bash

usage() {
  echo "
usage: $0 <options>
  Required :
     --install-file-name=FILE     Name of the install file that is to be generated
     --path-to-scan=DIR           Directory where the list of files to be installed is picked up from.
     --include-file=FILE          The file that needs to be included
     --exclude-files=FILES        Quoted list of space seperated exclude files
     --prefix=PREFIX              Prefix path to all files. This has to be the same prefix passed to install_<component>.sh scripts.
  "
}

OPTS=$(getopt \
  -n $0 \
  -o '' \
  -l 'install-file-name:' \
  -l 'path-to-scan:' \
  -l 'include-file:' \
  -l 'exclude-files:' \
  -l 'prefix:' \
  -l 'help' -- "$@")

if [ $? != 0 ] ; then
    usage
    exit 1
fi

eval set -- "$OPTS"
while true ; do
    case "$1" in
        --install-file-name)
        INSTALL_FILE_NAME=$2 ; shift 2
        ;;
        --path-to-scan)
        SCAN_DIR=$2 ; shift 2
        ;;
        --include-file)
        INCLUDE_FILE=$2 ; shift 2
        ;;
        --exclude-files)
        EXCLUDE_FILES=( $2 ) ; shift 2
        ;;
        --prefix)
        PREFIX=$2 ; shift 2
        ;;
        --help)
        usage
		exit 0
        ;;
        --)
        shift ; break
        ;;
        *)
        echo "Unknown option: $1" >&2
        usage
        exit 1
        ;;
    esac
done

for var in INSTALL_FILE_NAME SCAN_DIR EXCLUDE_FILES INSTALL_FILE_NAME PREFIX; do
  if [ -z "$(eval "echo \$$var")" ]; then
    echo Missing param: $var
    usage
    exit 1
  fi
done

# Check for correctness of input parameters.
if [ ! -d "$PREFIX" ] || [ ! -d "$SCAN_DIR" ]; then
  echo "Check --prefix or --scan_dir parameter, it does not point to a valid directory" >&2
fi

PREFIX=`echo $PREFIX | sed -E 's,/+$,,'`

if [[ $SCAN_DIR != $PREFIX* ]]; then
  echo " The prefix string needs to be a substring of scan-dir. Check parameters" >&2
fi

# Check if the include and exclude files exist
for excludeFile in ${EXCLUDE_FILES[@]}; do
 if [ ! -f debian/${excludeFile} ]; then
  echo "Exclude file supplied: $excludeFile does not exist." >&2
  exit 1
 fi
done

if [ ! -f debian/${INCLUDE_FILE} ]; then
 echo "Include file supplied: $includeFile does not exist" >&2
 exit 1
fi

temporary_include_file="debian/include_file_temp"

rm -f ${temporary_include_file}
rm -f debian/${INSTALL_FILE_NAME}

# Pick up all file names ignoring directory names and strip out the prefix from each of them.
find ${SCAN_DIR} -not -type d | sed 's,^'$PREFIX',,' > ${temporary_include_file}

cat ${temporary_include_file} debian/${INCLUDE_FILE} > debian/${INSTALL_FILE_NAME}

for excludeFile in ${EXCLUDE_FILES[@]}; do
 while read line
  do
   # Ignore blank lines that are a part of install files.
   if [ ! -z ${line} ]; then
     converted_line=$(echo ${line} | sed 's,'*','.*',')
     if [ -d "${PREFIX}/${line}" ] && [ ! -L "${PREFIX}/${line}" ]; then
       sed -i '\,^'${converted_line}',d' debian/${INSTALL_FILE_NAME}
     else
       sed -i '\,^'${converted_line}'$,d' debian/${INSTALL_FILE_NAME}
     fi
   fi
  done < debian/${excludeFile}
done