#!/usr/bin/env bash

set -e -o pipefail

cd `dirname $0`

# Track payload size functions
source ../scripts/ci/payload-size.sh

# Workaround https://github.com/yarnpkg/yarn/issues/2165
# Yarn will cache file://dist URIs and not update Angular code
readonly cache=.yarn_local_cache
function rm_cache {
  rm -rf $cache
}
rm_cache
mkdir $cache
trap rm_cache EXIT

# Create and build a new Angular project by angular-cli
testDir="hello_world__cli"
npm install -g @angular/cli
ng new hello-world-cli --directory $testDir
sed -i 's/ng test/ng build \&\& ng test --single-run/g' $testDir/package.json

for testDir in $(ls | grep -v node_modules) ; do
  [[ -d "$testDir" ]] || continue
  echo "#################################"
  echo "Running integration test $testDir"
  echo "#################################"
  (
    cd $testDir
    # Workaround for https://github.com/yarnpkg/yarn/issues/2256
    rm -f yarn.lock
    yarn install --cache-folder ../$cache
    yarn test || exit 1
    trackPayloadSize "$testDir" "dist/*.js" "" false
  )
done
