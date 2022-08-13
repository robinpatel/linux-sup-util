#!/bin/bash

PROFILENAME="$1"

GCPROFILEPATH=~/apps/google_chrome/profiles/${PROFILENAME}
GCOPTS="--disable-session-crashed-bubble --enable-leak-detection --incognito"

mkdir -p "${GCPROFILEPATH}"
if [ -f "${GCPROFILEPATH}/Local State" ] ; then
  rm "${GCPROFILEPATH}/Local State"
fi
if [ -f "${GCPROFILEPATH}/Default/Preferences" ] ; then
  sed -i 's/"exited_cleanly":false/"exited_cleanly":true/; s/"exit_type":"[^"]\+"/"exit_type":"Normal"/' "${GCPROFILEPATH}/Default/Preferences"
fi
CMD="google-chrome ${GCOPTS} --user-data-dir=${GCPROFILEPATH}"
echo "${CMD}"
${CMD} >/dev/null 2>/dev/null &
