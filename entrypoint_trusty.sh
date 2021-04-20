#!/bin/bash
cd /src/
# run codeql 
echo "Install the dependencies for compiling the repository"
apt-get update -yqq
apt-get install -yqq libncurses5 rsync python2 libcurl4-gnutls-dev curl gcc-multilib openssl libssl-dev
update-alternatives --install /usr/bin/python python /usr/bin/python2 10
export PATH=$PATH:/src/bin/
cd /src/trusty/
rm -rf /src/trusty/build-root
rm -rf trusty-cpp-db
echo "Create the codeql database for the android trusty" 
codeql database create trusty-cpp-db --language=cpp --command="./trusty/vendor/google/aosp/scripts/build.py generic-arm64"
echo "Finished creating the codeql database for the android trusty"
echo "Run the queries to find results"
# codeql database analyze -j0 trusty-cpp-db /root/codeql-repo/cpp/ql/src/Likely\ Bugs/ \
# 	/root/codeql-repo/cpp/ql/src/Best\ Practices/ \
# 	/root/codeql-repo/cpp/ql/src/Critical/ \
# 	/root/codeql-repo/cpp/ql/src/experimental/ \
# 	--format=csv --output /src/trusty-cpp-results.csv

CWE=$(ls -d /root/codeql-repo/cpp/ql/src/Security/CWE/* | grep -v CWE-020 | grep -v CWE-807 | grep -v CWE-835 | grep -v CWE-764 | grep -v CWE-134)
codeql database analyze -j0 trusty-cpp-db $CWE --format=csv --output /src/trusty-cpp-security-results.csv

