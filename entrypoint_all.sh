#!/bin/bash
cd /src/
# run codeql 
echo "Install the dependencies for compiling the repository"
apt-get update -yqq
apt-get install -yqq python3 libncurses5 rsync
update-alternatives --install /usr/bin/python python /usr/bin/python3 10
export PATH=$PATH:/src/bin/
repo --help
cd /src/source/
rm -rf /src/source/out
rm -rf all-cpp-db
source build/envsetup.sh
export ALLOW_NINJA_ENV=true
lunch aosp_arm-eng
echo "Create the codeql database for the whole android project" 
codeql database create all-cpp-db --language=cpp --command="/src/source/build/soong/soong_ui.bash --make-mode -j28"
echo "Finished creating the codeql database the whole android project"
echo "Run the queries to find results"
# codeql database analyze -j0 all-cpp-db /root/codeql-repo/cpp/ql/src/Likely\ Bugs/ \
# 	/root/codeql-repo/cpp/ql/src/Best\ Practices/ \
# 	/root/codeql-repo/cpp/ql/src/Critical/ \
# 	/root/codeql-repo/cpp/ql/src/experimental/ \
# 	--format=csv --output /src/all-cpp-results.csv

CWE=$(ls -d /root/codeql-repo/cpp/ql/src/Security/CWE/* | grep -v CWE-020)
codeql database analyze -j0 all-cpp-db $CWE --format=csv --output /src/all-cpp-security-results.csv

