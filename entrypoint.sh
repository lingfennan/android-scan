#!/bin/bash
cd /src/
# run codeql 
if [ -s cpp-db ];then
	rm -r cpp-db
fi
echo "Install the dependencies for compiling the repository"
apt-get update -yqq
apt-get install -yqq python3
update-alternatives --install /usr/bin/python python /usr/bin/python3 10
export PATH=$PATH:/src/bin/
repo --help
cd /src/source/
source build/envsetup.sh
export ALLOW_NINJA_ENV=true
lunch aosp_arm-eng

echo "Create the codeql database for android"
codeql database create cpp-db --language=cpp --command="/src/source/build/soong/soong_ui.bash --make-mode"
CWE=$(ls -d /root/codeql-repo/cpp/ql/src/Security/CWE/* | grep -v CWE-020)
codeql database analyze -j0 cpp-db $CWE --format=csv --output /src/cpp-security-results.csv

exit 0

cd /src/source/system/bt/
echo "Create the codeql database for bluetooth" 
codeql database create cpp-db --language=cpp --command="/src/source/build/soong/soong_ui.bash --make-mode"
echo "Run the queries to find results"
codeql database analyze -j0 cpp-db /root/codeql-repo/cpp/ql/src/Likely\ Bugs/ \
	/root/codeql-repo/cpp/ql/src/Best\ Practices/ \
	/root/codeql-repo/cpp/ql/src/Critical/ \
	/root/codeql-repo/cpp/ql/src/experimental/ \
	--format=csv --output /src/bt-cpp-results.csv

CWE=$(ls -d /root/codeql-repo/cpp/ql/src/Security/CWE/* | grep -v CWE-020)
codeql database analyze -j0 cpp-db $CWE --format=csv --output /src/bt-cpp-security-results.csv

cd /src/source/system/nfc/
echo "Create the codeql database for nfc" 
codeql database create cpp-db --language=cpp --command="/src/source/build/soong/soong_ui.bash --make-mode"
echo "Run the queries to find results"
codeql database analyze -j0 cpp-db /root/codeql-repo/cpp/ql/src/Likely\ Bugs/ \
	/root/codeql-repo/cpp/ql/src/Best\ Practices/ \
	/root/codeql-repo/cpp/ql/src/Critical/ \
	/root/codeql-repo/cpp/ql/src/experimental/ \
	--format=csv --output /src/nfc-cpp-results.csv

CWE=$(ls -d /root/codeql-repo/cpp/ql/src/Security/CWE/* | grep -v CWE-020)
codeql database analyze -j0 cpp-db $CWE --format=csv --output /src/nfc-cpp-security-results.csv

