#!/bin/bash

function log() {
  MESSAGE="${1:-""}"
  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S:%N %z")
  echo "${TIMESTAMP} - ${MESSAGE}"
}

function log_error_and_exit() {
  ERROR_MESSAGE="${1:-"An unspecified error occurred"}"
  TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S:%N %z")
  echo "$timestamp - $error_message" >&2 
  exit 1
}

PROFILENAME="$1"
PROFILENAMEDISPLAY="$2"

GCPROFILEPATH=~/apps/google_chrome/profiles/${PROFILENAME}
GCOPTS="--disable-session-crashed-bubble --enable-leak-detection"

mkdir -p "${GCPROFILEPATH}"
if [ -f "${GCPROFILEPATH}/Local State" ] ; then
  rm "${GCPROFILEPATH}/Local State"
fi
if [ -f "${GCPROFILEPATH}/Default/Preferences" ] ; then
  sed -i 's/"exited_cleanly":false/"exited_cleanly":true/; s/"exit_type":"[^"]\+"/"exit_type":"Normal"/' "${GCPROFILEPATH}/Default/Preferences"
fi
CMD="google-chrome ${GCOPTS} --user-data-dir=${GCPROFILEPATH}"
log "Executing: ${CMD}"
${CMD} >/dev/null 2>/dev/null &

CHROMEPID_LOOPACTIVE="yes"
CHROMEPID_LOOPCOUNT=0
while [ "${CHROMEPID_LOOPACTIVE}" == "yes" ] ; do
 CHROMEPID=$(pgrep --newest -f "chrome.* --user-data-dir=.*/google_chrome/profiles/${PROFILENAME}$")
 if [ $? -eq 0 ] ; then
  if (( ${CHROMEPID} )) ; then
   log "Chrome PID: ${CHROMEPID}"
   CHROMEPID_LOOPACTIVE="no"
  fi
 else
  log "CHROMEPID checked exit with a non-zero"
 fi
 ((CHROMEPID_LOOPCOUNT+=1))
 if [ ${CHROMEPID_LOOPCOUNT} -ge 60 ] ; then
  log_error_and_exit "ERROR: Failed to find CHROMEPID within 60 attempts"
 fi
 sleep 1
done

TRUEWID=""
WIDLIST=$(xdotool search --pid ${CHROMEPID})
for THISWID in ${WIDLIST} ; do
 THISPID=$(xdotool getwindowpid ${THISWID})
 if [ "${THISPID}" == "${CHROMEPID}" ] ; then
  TRUEWID="${THISWID}"
 fi
done

if [ "${TRUEWID}" == "" ] ; then
 WINDOWNAMING_LOOPACTIVE="no"
else
 WINDOWNAMING_LOOPACTIVE="yes"
fi

log "Matched WID: ${TRUEWID}"

while [ "${WINDOWNAMING_LOOPACTIVE}" == "yes" ] ; do
 THISWINDOWNAME=$(xdotool getwindowname ${TRUEWID})
 if [ "${THISWINDOWNAME}" != "${PROFILENAMEDISPLAY}" ] ; then
  log "Setting WID: ${TRUEWID} to ${PROFILENAMEDISPLAY}"
  xdotool set_window --name "${PROFILENAMEDISPLAY}" ${TRUEWID}
  if [ $? -ne 0 ] ; then
   WINDOWNAMING_LOOPACTIVE="no"
  fi
 fi
 sleep 1
done
