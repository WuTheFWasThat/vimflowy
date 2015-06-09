#!/bin/bash

if [ $# -lt 1 ]; then
  echo "Usage: $0 <out_folder, e.g. /Users/jeffwu/Documents>"
  return 1 2>/dev/null || exit 1 # Work when sourced
fi

rm -rf public/assets
SERVER_OUT=$(mktemp --tmpdir=/tmp tmp.XXXXXXXXXX)
rm $SERVER_OUT
mkfifo $SERVER_OUT
NODE_ENV=production coffee server.coffee 2>&1 >$SERVER_OUT &
NODE_PID=$!

OUTPUT_FOLDER=$1
TMP_FOLDER=$(mktemp --tmpdir=/tmp tmp.XXXXXXXXXX)
rm -rf $TMP_FOLDER
mkdir -p $TMP_FOLDER

wait_for_start(){
    echo "Waiting for server start..." >/dev/stderr
    while read line; do
        case ${line} in
        *"Started server"*)
            break;;
        *   )
            ;;
        esac
    done <"$1"
    line=""
    if read -t 0.3 line <"$1"; then # bashism
        case ${line} in
            *EADDRINUSE*)
                echo "Server port in use" >/dev/stderr
                return 1;;
        esac 
    fi
    echo "Server started successfully" >/dev/stderr
    return 0;
}

if wait_for_start $SERVER_OUT; then
    curl -s localhost:8080 > $TMP_FOLDER/index.html
    cp -r public/* $TMP_FOLDER/
else
    echo "Server could not start"
    return 2 2>/dev/null || exit 2 # Work when sourced
fi

(
    cd $TMP_FOLDER
    zip -q -r vimflowy.zip .
)
mv $TMP_FOLDER/vimflowy.zip $OUTPUT_FOLDER/vimflowy.zip
rm -rf $TMP_FOLDER

kill $NODE_PID
rm $SERVER_OUT
