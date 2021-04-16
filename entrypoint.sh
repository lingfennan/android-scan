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
source build/envsetup.sh
export ALLOW_NINJA_ENV=true
lunch aosp_arm-eng
echo "Building the whole android project"
m
echo "Finished building the whole android project"

cd /src/source/system/bt/
rm -rf /src/source/out/soong/.glob/system/bt
rm -rf /src/source/out/soong/.intermediates/system/bt
rm -rf bt-cpp-db
echo "Create the codeql database for bluetooth" 
codeql database create bt-cpp-db --language=cpp --command="/src/source/build/soong/soong_ui.bash --make-mode -j28"
echo "Run the queries to find results"
# codeql database analyze -j0 bt-cpp-db /root/codeql-repo/cpp/ql/src/Likely\ Bugs/ \
# 	/root/codeql-repo/cpp/ql/src/Best\ Practices/ \
# 	/root/codeql-repo/cpp/ql/src/Critical/ \
# 	/root/codeql-repo/cpp/ql/src/experimental/ \
# 	--format=csv --output /src/bt-cpp-results.csv

CWE=$(ls -d /root/codeql-repo/cpp/ql/src/Security/CWE/* | grep -v CWE-020)
codeql database analyze -j0 bt-cpp-db $CWE --format=csv --output /src/bt-cpp-security-results.csv

cd /src/source/system/nfc/
rm -rf /src/source/out/soong/.glob/system/nfc
rm -rf /src/source/out/soong/.intermediates/system/nfc
rm -rf nfc-cpp-db
echo "Create the codeql database for nfc" 
codeql database create nfc-cpp-db --language=cpp --command="/src/source/build/soong/soong_ui.bash --make-mode -j28"
echo "Run the queries to find results"
# codeql database analyze -j0 nfc-cpp-db /root/codeql-repo/cpp/ql/src/Likely\ Bugs/ \
# 	/root/codeql-repo/cpp/ql/src/Best\ Practices/ \
# 	/root/codeql-repo/cpp/ql/src/Critical/ \
# 	/root/codeql-repo/cpp/ql/src/experimental/ \
# 	--format=csv --output /src/nfc-cpp-results.csv

CWE=$(ls -d /root/codeql-repo/cpp/ql/src/Security/CWE/* | grep -v CWE-020)
codeql database analyze -j0 nfc-cpp-db $CWE --format=csv --output /src/nfc-cpp-security-results.csv

