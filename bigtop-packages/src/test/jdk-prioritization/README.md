#JDK Prioritization Test

Run this script in a Linux VM (preferably our supported distributionss so we catch any nuances in the versions of bash or other utilities). The script will create a chroot jail, remount virtual devices inside it, then delete the jail. If something goes wrong, that has the potential to really damage the OS.

Check out cdh-package.git with a version of bigtop-detect-javahome that has your modifications, make sure the sequence of JDK paths in bigtop-detect-javahome-test.sh reflects our current recommendations (keeping in mind that changes in the order outside of major releases may catch customers off-guard), and run the script from its own directory:

    git clone git://github.sf.cloudera.com/CDH/cdh-package.git
    cd cdh-package/bigtop-packages/src/test/jdk-prioritization
    ./bigtop-detect-javahome-test.sh

The test script will return the exit code of bigtop-detect-javahome: 0 for success, non-zero on error. If the script fails to find each JDK in the correct order, it will tell you what it expected and what it found.
