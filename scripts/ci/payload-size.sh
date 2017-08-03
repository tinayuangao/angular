#!/bin/bash

readonly PROJECT_NAME="angular-payload-size"

calculateSize() {
  size=$(stat -c%s "$filename")
  label=$(echo "$filename" | sed "s/.*\///" | sed "s/\..*//")
  payloadData="$payloadData\"uncompressed/$label\": $size, "

  gzip -7 $filename -c >> "${filename}7.gz"
  size7=$(stat -c%s "${filename}7.gz")
  payloadData="$payloadData\"gzip7/$label\": $size7, "

  gzip -9 $filename -c >> "${filename}9.gz"
  size9=$(stat -c%s "${filename}9.gz")
  payloadData="$payloadData\"gzip9/$label\": $size9, "
}

checkSize() {
  if [[ $size -gt ${limitUncompressed[$label]} ]]; then
    failed=true
    echo "Uncompressed $label size is $size which is greater than ${limitUncompressed[$label]}"
  elif [[ $size7 -gt ${limitGzip7[$label]} ]]; then
    failed=true
    echo "Gzip7 $label size is $size7 which is greater than ${limitGzip7[$label]}"
  elif [[ $size9 -gt ${limitGzip9[$label]} ]]; then
    failed=true
    echo "Gzip9 $label size is $size9 which is greater than ${limitGzip9[$label]}"
  fi
}

addTimestamp() {
  # Add Timestamp
  timestamp=$(date +%s)
  payloadData="$payloadData\"timestamp\": $timestamp, "
}

addMessage() {
  message=$(echo $TRAVIS_COMMIT_MESSAGE | sed 's/"/\\"/g' | sed 's/\\/\\\\/g')
  payloadData="$payloadData\"message\": \"$message\""
}

addChange() {
  # Add change source: application, dependencies, or 'application+dependencies'
  yarnChanged=false
  allChangedFiles=$(git diff --name-only $TRAVIS_COMMIT_RANGE $parentDir | wc -l)
  allChangedFileNames=$(git diff --name-only $TRAVIS_COMMIT_RANGE $parentDir)

  if [[ $allChangedFileNames == *"yarn.lock"* ]]; then
    yarnChanged=true
  fi

  if [[ $allChangedFiles -eq 1 ]] && [[ "$yarnChanged" = true ]]; then
    # only yarn.lock changed
    change='dependencies'
  elif [[ $allChangedFiles -gt 1 ]] && [[ "$yarnChanged" = true ]]; then
    change='application+dependencies'
  elif [[ $allChangedFiles -gt 0 ]]; then
    change='application'
  else
    # Nothing changed in aio/
    exit 0
  fi
  payloadData="$payloadData\"change\": \"$change\", "
}

uploadData() {
  name="$1"
  payloadData="{${payloadData}}"

  echo $payloadData

  if [[ "$TRAVIS_PULL_REQUEST" == "false" ]]; then
    readonly safeBranchName=$(echo $TRAVIS_BRANCH | sed -e 's/\./_/g')
    readonly dbPath=/payload/$name/$safeBranchName/$TRAVIS_COMMIT

    # WARNING: FIREBASE_TOKEN should NOT be printed.
    set +x
    firebase database:update --data "$payloadData" --project $PROJECT_NAME --confirm --token "$ANGULAR_PAYLOAD_FIREBASE_TOKEN" $dbPath
  fi
}

# Track payload size, $1 is the name in database, $2 is the file path
# $3 is the filename of limites, $4 is the
trackPayloadSize() {
  name="$1"
  path="$2"
  limitPath="$3"
  trackChange=$4
  [ "$limitPath" = "" ] && checkSize=false || checkSize=true
  if [[ $checkSize = true ]]; then
    source $limitPath
  fi

  payloadData=""
  failed=false
  for filename in $path; do
    calculateSize
    if [[ $checkSize = true ]]; then
      echo checksize
      checkSize
    fi
  done
  addTimestamp
  if [[ $trackChange = true ]]; then
    addChange
  fi
  addMessage
  uploadData $name
  if [[ $failed = true ]]; then
    echo exit 1
    exit 1
  fi
}
