#! /usr/bin/env bash

set +H
# This prevents ! from being interpreated as a history command, so we can use it in conditionals

# Must be run by root, or an account with sudo privileges (let's check for /dev/null while we're at it)
if ! sudo echo > /dev/null; then
    echo 'Error: this test requires sudo / root privileges and /dev/null: one of these is missing'
fi

# Requires no parameters - if we receive any there's been a mistake
if [ -n "${1}" ]; then
    echo 'Error: this script does not take any parameters: see the README'
    exit 1
fi

# Check that all required utilities are available on the path
MISSING_REQUIRED_UTILITY=false
for required_utility in \
    env mktemp mkdir cp dirname which tail sed ldd grep bash ls chmod touch cat echo chmod mount chroot umount rm
do
    if ! which ${required_utility} 2>&1 >/dev/null; then
        echo "Required utility not found: ${required_utility}"
        MISSING_REQUIRED_UTILITY=true
    fi
done
if [ "${MISSING_REQUIRED_UTILITY}" == 'true' ]; then
    exit 1
fi

# Create temporary directory for jail
jail=`mktemp -d`

# Installs a file from the host to the same path in the jail
function install_file() {
    file=${1}
    mkdir -p `dirname ${jail}${file}`
    cp -f ${file} ${jail}${file}
}

# Installs an executable and all shared libraries against which it links to the same paths in the jail
function install_utility() {
    executable=${1}
    which=`which ${executable} | tail -1 | sed -e 's/\s\+//g'` # which sometimes returns alias information at the top, so we take the tail and strip whitespace
    install_file ${which}
    for library in `ldd ${which} | sed -e 's/\s\+/\n/g' | grep ^/`; do
        install_file ${library}
    done
}

# Install all the utilities used by bigtop-detect-javahome or our test driver script in the jail
for utility in \
    bash chmod env ls mkdir rm touch
do
    install_utility ${utility}
done

# Install bigtop-detect-javahome and our test driver script
bin_dir=${jail}/bin
mkdir -p ${bin_dir}
test_target=`find ../.. -name bigtop-detect-javahome`
test_driver='bigtop-detect-javahome-test-in-jail.sh'
cp ${test_target} ${bin_dir}/`basename ${test_target}`
cp ${test_driver} ${bin_dir}/${test_driver}
chmod +x ${bin_dir}/${test_driver}

# Mount /dev/null inside the jail (bigtop-detect-javahome uses it)
mkdir ${jail}/dev; touch ${jail}/dev/null
sudo mount --rbind /dev/null ${jail}/dev/null

# Run our test inside the jail
sudo chroot ${jail} /bin/${test_driver}

# Save exit code information
exit_code=${?}
echo "Exit code: ${exit_code}"

# Unmount /dev/null and delete the rest of the jail
sudo umount ${jail}/dev/null
sudo rm -rf ${jail}

exit ${exit_code}

