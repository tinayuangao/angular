#!/usr/bin/env bash

set -e -o pipefail

cd `dirname $0`

# Track payload size functions
source ../scripts/ci/payload-size.sh
source ./_payload-limits.sh

# Workaround https://github.com/yarnpkg/yarn/issues/2165
# Yarn will cache file://dist URIs and not update Angular code
readonly cache=.yarn_local_cache
function rm_cache {
  rm -rf $cache
}
rm_cache
mkdir $cache
trap rm_cache EXIT

# We need to install `ng` but don't want to do it globally so we plate it into `.ng-cli` folder.
# This check prevents constant re-installing.
if [ ! -d ".ng-cli" ]; then
  (
    mkdir -p .ng-cli
    cd .ng-cli
    yarn add https://github.com/angular/cli-builds --cache-folder ../$cache
  )
fi
./ng-cli-create.sh cli-hello-world

for testDir in $(ls | grep -v node_modules) ; do
  [[ -d "$testDir" ]] || continue
  echo "#################################"
  echo "Running integration test $testDir"
  echo "#################################"
  (
    cd $testDir
    # Workaround for https://github.com/yarnpkg/yarn/issues/2256
    rm -f yarn.lock
    rm -rf dist
    yarn install --cache-folder ../$cache
    yarn build
    yarn test || exit 1
    # Track payload size for cli-hello-world and hello_world__closure
    if [[ $testDir == cli-hello-world ]] || [[ $testDir == hello_world__closure ]]; then
      trackPayloadSize "$testDir" "dist/*.js" true false
    fi
  )
done

trackPayloadSize "umd" "../dist/packages-dist/*/bundles/*.umd.min.js" false false
