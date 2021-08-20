#!/bin/bash
cd /src/
# run codeql 
echo "Install the dependencies for compiling the repository"
apt-get update -yqq
apt-get install -yqq python3 libncurses5 rsync libpulse0 libgl1-mesa-dev
update-alternatives --install /usr/bin/python python /usr/bin/python3 10
apt-get install install gcc-multilib g++-multilib libc6-dev-i386
export PATH=$PATH:/src/bin/
repo --help
cd /src/source/
source build/envsetup.sh
export ALLOW_NINJA_ENV=true
# lunch aosp_arm-eng
# lunch aosp_arm64-eng
# lunch aosp_x86_64-eng
lunch sdk_phone_x86_64
echo "Building the whole android project"
m
echo "Finished building the whole android project"
tail -f /dev/null
echo "done"
exit 1

cd /src/source/system/bt/
rm -rf /src/source/out/soong/.glob/system/bt
rm -rf /src/source/out/soong/.intermediates/system/bt
rm -rf bt-cpp-db
echo "Create the codeql database for bluetooth" 
codeql database create bt-cpp-db --language=cpp --command="/src/source/build/soong/soong_ui.bash --make-mode -j28"
echo "Run the queries to find results"
codeql database analyze -j0 bt-cpp-db /root/codeql-repo/cpp/ql/src/Likely\ Bugs/ \
	/root/codeql-repo/cpp/ql/src/Best\ Practices/ \
	/root/codeql-repo/cpp/ql/src/Critical/ \
	/root/codeql-repo/cpp/ql/src/experimental/ \
	--format=csv --output /src/bt-cpp-results.csv

CWE=$(ls -d /root/codeql-repo/cpp/ql/src/Security/CWE/* | grep -v CWE-020)
codeql database analyze -j0 bt-cpp-db $CWE --format=csv --output /src/bt-cpp-security-results.csv

cd /src/source/system/nfc/
rm -rf /src/source/out/soong/.glob/system/nfc
rm -rf /src/source/out/soong/.intermediates/system/nfc
rm -rf nfc-cpp-db
echo "Create the codeql database for nfc" 
codeql database create nfc-cpp-db --language=cpp --command="/src/source/build/soong/soong_ui.bash --make-mode -j28"
echo "Run the queries to find results"
codeql database analyze -j0 nfc-cpp-db /root/codeql-repo/cpp/ql/src/Likely\ Bugs/ \
	/root/codeql-repo/cpp/ql/src/Best\ Practices/ \
	/root/codeql-repo/cpp/ql/src/Critical/ \
	/root/codeql-repo/cpp/ql/src/experimental/ \
	--format=csv --output /src/nfc-cpp-results.csv

CWE=$(ls -d /root/codeql-repo/cpp/ql/src/Security/CWE/* | grep -v CWE-020)
codeql database analyze -j0 nfc-cpp-db $CWE --format=csv --output /src/nfc-cpp-security-results.csv

cd /src/source/system/core/
rm -rf /src/source/out/soong/.glob/system/core
rm -rf /src/source/out/soong/.intermediates/system/core
rm -rf core-cpp-db
echo "Create the codeql database for core"
codeql database create core-cpp-db --language=cpp --command="/src/source/build/soong/soong_ui.bash --make-mode -j28"
echo "Run the queries to find results"
codeql database analyze -j0 core-cpp-db /root/codeql-repo/cpp/ql/src/Likely\ Bugs/ \
	/root/codeql-repo/cpp/ql/src/Best\ Practices/ \
	/root/codeql-repo/cpp/ql/src/Critical/ \
	/root/codeql-repo/cpp/ql/src/experimental/ \
	--format=csv --output /src/core-cpp-results.csv

CWE=$(ls -d /root/codeql-repo/cpp/ql/src/Security/CWE/* | grep -v CWE-020)
codeql database analyze -j0 core-cpp-db $CWE --format=csv --output /src/core-cpp-security-results.csv

