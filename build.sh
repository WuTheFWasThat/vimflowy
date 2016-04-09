#!/bin/bash

set -e

OUTPUT_FOLDER="dist"
HELP=false
DEPLOY=false
ZIP=false

while getopts "dho:z" opt; do
  case $opt in
    d)
      echo "Deploying!"
      DEPLOY=true
      ;;
    h)
      HELP=true
      ;;
    o)
      OUTPUT_FOLDER=$OPTARG;
      echo "Output folder: $OPTARG"
      ;;
    z)
      ZIP=true
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

shift $((OPTIND-1))

if [ "$HELP" = true ] ; then
  echo
  echo "Usage: $0 [-h] [-o <output_folder>] [-d]"
  echo "Flags: "
  echo "-h                 : help"
  echo "-o <output_folder> : folder to compile static site to"
  echo "-d                 : deploy"
  echo "-z                 : zip"
  echo
  exit 2
fi

mkdir -p $OUTPUT_FOLDER
rm -rf $OUTPUT_FOLDER/vimflowy

# builds everything into public/
npm run gulp clean
npm run gulp assets
# copy entire public folder
cp -r public $OUTPUT_FOLDER/vimflowy

# stuff for chrome packaged app
cp package/* $OUTPUT_FOLDER/vimflowy/

echo "Success!  Result at $OUTPUT_FOLDER/vimflowy"

if [ "$ZIP" = true ] ; then
    zip -r $OUTPUT_FOLDER/vimflowy.zip $OUTPUT_FOLDER/vimflowy
    echo "Zipfile at $OUTPUT_FOLDER/vimflowy.zip"
fi

if [ "$DEPLOY" = true ] ; then
    bitballoon && bitballoon deploy $OUTPUT_FOLDER/vimflowy
    echo "Successfully deployed to bitballoon!"
fi
