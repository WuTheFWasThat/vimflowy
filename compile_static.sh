#!/bin/bash

if [ $# -lt 1 ]; then
  echo "Usage: $0 <out_folder, e.g. /Users/jeffwu/Documents>"
  return 1 2>/dev/null || exit 1 # Work when sourced
fi

PORT=8081
rm -rf public/assets
SERVER_OUT=$(mktemp /tmp/tmp.out.XXXXXXXXXX)
rm $SERVER_OUT
mkfifo $SERVER_OUT
NODE_ENV=production coffee server.coffee $PORT 2>&1 >$SERVER_OUT &
NODE_PID=$!

OUTPUT_FOLDER=$1
TMP_FOLDER=$(mktemp -d /tmp/tmp.XXXXXXXXXX)

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
    if read -t 1 line <"$1"; then # bashism
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
    curl -s localhost:$PORT > $TMP_FOLDER/index.html
    cp -r public/* $TMP_FOLDER/
else
    echo "Server could not start"
    return 2 2>/dev/null || exit 2 # Work when sourced
fi

# unnecessary manifest.json from connect-assets.  chrome app upload complains about it
rm -rf $TMP_FOLDER/assets/manifest.json
# stuff for chrome packaged app
cp package/* $TMP_FOLDER/

(
    cd $TMP_FOLDER
    zip -q -r vimflowy.zip .
)
rm -rf $OUTPUT_FOLDER/vimflowy $OUTPUT_FOLDER/vimflowy.zip
mv $TMP_FOLDER/vimflowy.zip $OUTPUT_FOLDER/vimflowy.zip
mv $TMP_FOLDER $OUTPUT_FOLDER/vimflowy

kill $NODE_PID
rm $SERVER_OUT

echo "Success!  Results at $OUTPUT_FOLDER/vimflowy.zip $OUTPUT_FOLDER/vimflowy"
