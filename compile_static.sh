#!/bin/bash

# FIRST:
# `rm -rf public/assets/; NODE_ENV=production nodemon -e coffee,jade,sass server.coffee`

if [ $# -lt 1 ]; then
  echo 'Usage: $0 <out_folder, e.g. /Users/jeffwu/Documents>'
  exit 1
fi

OUTPUT_FOLDER=$1
TMP_FOLDER="/tmp/vimflowy"
rm -rf $TMP_FOLDER
mkdir -p $TMP_FOLDER

curl localhost:8080 > $TMP_FOLDER/index.html
cp -r public/* $TMP_FOLDER/

pushd $TMP_FOLDER
zip -r $OUTPUT_FOLDER/vimflowy.zip .
popd
rm -rf $TMP_FOLDER

