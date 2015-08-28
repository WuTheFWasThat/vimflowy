#!/bin/bash

if [ $# -lt 1 ]; then
  echo "Usage: $0 <out_folder, e.g. /Users/jeffwu/Documents>"
  return 1 2>/dev/null || exit 1 # Work when sourced
fi

PORT=8081
rm -rf public/assets

OUTPUT_FOLDER=$1

# builds everything into public/
gulp clean
gulp assets

# stuff for chrome packaged app
cp package/* public/

(
    cd public/
    zip -q -r vimflowy.zip .
)
rm -rf $OUTPUT_FOLDER/vimflowy $OUTPUT_FOLDER/vimflowy.zip
mv public/vimflowy.zip $OUTPUT_FOLDER/vimflowy.zip
mv public $OUTPUT_FOLDER/vimflowy

echo "Success!  Results at $OUTPUT_FOLDER/vimflowy.zip $OUTPUT_FOLDER/vimflowy"
