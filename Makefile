#!/bin/bash

DIST_DIR="dist"
APP_DIR=${DIST_DIR}/vimflowy

vimflowy:
	mkdir -p ${APP_DIR}
	rm -rf ${APP_DIR}
	# builds everything into public/
	npm run gulp clean
	npm run gulp assets
	# copy entire public folder
	cp -r public ${APP_DIR}
	# stuff for chrome packaged app
	cp package/* ${APP_DIR}/
	echo "Success!  Result at ${APP_DIR}"
vimflowy.zip: vimflowy
	zip -r ${DIST_DIR}/vimflowy.zip ${APP_DIR}
	echo "Zipfile at ${DIST_DIR}/vimflowy.zip"
deploy:
	bitballoon && bitballoon deploy ${APP_DIR}
	echo "Successfully deployed to bitballoon!"
