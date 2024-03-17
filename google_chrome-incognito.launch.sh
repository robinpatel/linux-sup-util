#!/bin/bash

if [[ -n $1 ]] ; then
 PROFILENAME=$1
fi

if [[ -n $2 ]] ; then
 PROFILENAMEDISPLAY=$2
fi

GCPROFILEPATH=~/apps/google_chrome/profiles/${PROFILENAME}
GCOPTS="--disable-session-crashed-bubble --enable-leak-detection --incognito"

BASELOGFILEPATH=~/logs/google_chrome-launcher

function get_nano_epoch_time() {
 EPOCH_TIME_NANO=$(date +"%s:%N")
 echo ${EPOCH_TIME_NANO}
}

function get_timestamp() {
  EPOCH_TIME_NANO="${1:-$(get_nano_epoch_time)}"
  EPOCH_TIME=$(echo ${EPOCH_TIME_NANO} | cut -f 1 -d ':')
  TIMESTAMP=$(date -d "@${EPOCH_TIME}" +"${EPOCH_TIME_NANO} - %Y-%m-%d %H:%M:%S %z")
  echo ${TIMESTAMP}
}

function get_log_path() {
  LOGDATESTAMP=$(date +"%Y%m%d")
  LOGFILEPATH="${BASELOGFILEPATH}-${LOGDATESTAMP}.log"
  echo "${LOGFILEPATH}"
}

function log() {
  MESSAGE="${1:-""}"
  TIMESTAMP=$(get_timestamp)
  THISPROFILENAME="${PROFILENAME:-"NA"}"
  echo "${TIMESTAMP} - ${THISPROFILENAME} - ${MESSAGE}" >> $(get_log_path)
}

function log_error_and_exit() {
  ERROR_MESSAGE="ERROR: ${1:-"An unspecified error occurred"}"
  log "${ERROR_MESSAGE}" >> $(get_log_path)
  echo "${ERROR_MESSAGE}" >&2
  exit 1
}

if [[ ! -n "${PROFILENAME}" ]] ; then
 log_error_and_exit "Variable PROFILENAME is not provided"
fi

if [[ ! -n "${PROFILENAMEDISPLAY}" ]] ; then
 log_error_and_exit "Variable PROFILENAMEDISPLAY is not provided"
fi

mkdir -p $(dirname ${BASELOGFILEPATH})
TIMESTAMP=$(get_timestamp)
echo "Start time: ${TIMESTAMP}"
echo "Initially logging to file: $(get_log_path)"

mkdir -p "${GCPROFILEPATH}"
if [[ -f "${GCPROFILEPATH}/Local State" ]] ; then
  rm "${GCPROFILEPATH}/Local State"
fi
if [[ -f "${GCPROFILEPATH}/Default/Preferences" ]] ; then
  sed -i 's/"exited_cleanly":false/"exited_cleanly":true/; s/"exit_type":"[^"]\+"/"exit_type":"Normal"/' "${GCPROFILEPATH}/Default/Preferences"
fi
CMD="google-chrome ${GCOPTS} --user-data-dir=${GCPROFILEPATH}"
log "Executing: ${CMD}"
${CMD} >/dev/null 2>/dev/null &

CHROMEPID_LOOPACTIVE="yes"
CHROMEPID_LOOPCOUNT=0
while [[ "${CHROMEPID_LOOPACTIVE}" == "yes" ]] ; do
 CHROMEPID=$(pgrep --newest -f "chrome.* --user-data-dir=.*/google_chrome/profiles/${PROFILENAME}$")
 if [[ $? -eq 0 ]] ; then
  if (( ${CHROMEPID} )) ; then
   log "Chrome PID: ${CHROMEPID}"
   CHROMEPID_LOOPACTIVE="no"
  fi
 else
  log "CHROMEPID check exited with a non-zero"
 fi
 ((CHROMEPID_LOOPCOUNT+=1))
 if [[ ${CHROMEPID_LOOPCOUNT} -ge 60 ]] ; then
  log_error_and_exit "Failed to find CHROMEPID within 60 attempts"
 fi
 sleep 1
done

sleep 1
TRUEWID=""
WIDLIST=$(xdotool search --pid ${CHROMEPID})
for THISWID in ${WIDLIST} ; do
 if (( ${THISWID} )) ; then
  THISWIDWINDOWNAME=$(xdotool getwindowname ${THISWID})
  log "Checking WID: ${THISWID} (${THISWIDWINDOWNAME})"
  if [[ "${THISWIDWINDOWNAME}" != "google-chrome" ]] ; then
   log "Matched WID: ${THISWID}"
   TRUEWID=${THISWID}
  fi
 else
  log_error_and_exit "WID from WIDLIST is not an integer (THISWID:${THISWID})"
 fi
done

if (( ${TRUEWID} )) ; then
 log "Setting Window Naming Monitor to ACTIVE"
 WINDOWNAMING_LOOPACTIVE="yes"
else
 log_error_and_exit "WID is not an integer (TRUEWID:${TRUEWID})"
fi

THISWINDOWNAME=$(xdotool getwindowname ${TRUEWID})
while [[ "${WINDOWNAMING_LOOPACTIVE}" == "yes" ]] ; do
 THISWINDOWNAMEPREVIOUS="${THISWINDOWNAME}"
 THISWINDOWNAME=$(xdotool getwindowname ${TRUEWID} 2>/dev/null)
 if [[ $? -ne 0 ]] ; then
  WINDOWNAMING_LOOPACTIVE="no"
  READYTOSET="no"
 fi
 if [[ "${WINDOWNAMING_LOOPACTIVE}" == "yes" && "${THISWINDOWNAME}" != "${THISWINDOWNAMEPREVIOUS}" && "${THISWINDOWNAME}" != "" ]] ; then
  log "Window Name: ${THISWINDOWNAME}"
 fi
 if [[ "${THISWINDOWNAME}" != "${PROFILENAMEDISPLAY}" && "${THISWINDOWNAME}" == "${THISWINDOWNAMEPREVIOUS}" ]] ; then
  if [[ "${READYTOSET}" == "yes" ]] ; then
   log "Setting WID: ${TRUEWID} to ${PROFILENAMEDISPLAY}"
   xdotool set_window --name "${PROFILENAMEDISPLAY}" ${TRUEWID} 2>/dev/null || WINDOWNAMING_LOOPACTIVE="no"
  fi
  NOWEPOCHTIME=$(date +"%s")
  if [[ ${NOWEPOCHTIME} -ge ${EARLIESTTIMETOSET} ]] ; then
   READYTOSET="yes"
  fi
 else
  EARLIESTTIMETOSET=$(date -d "+10 seconds" +"%s")
  READYTOSET="no"
 fi
 sleep 0.25
done

log "Exiting with a zero status"
exit 0

