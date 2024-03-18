#!/bin/bash

if [[ -n $$ ]] ; then
 THISPID=$$
fi

if [[ -n $1 ]] ; then
 PROFILENAME=$1
fi

if [[ -n $2 ]] ; then
 PROFILENAMEDISPLAY=$2
fi

if [[ -n $3 ]] ; then
 PROFILEMODE=$3
fi

GCPROFILEBASEPATH=~/apps/google_chrome/profiles
GCPROFILEPATH="${GCPROFILEBASEPATH}/${PROFILENAME}"
LOCAL_METADATA_PATH="${GCPROFILEPATH}/_local_metadata"
LOCKFILE_PATH="${LOCAL_METADATA_PATH}/launcher.lock"
GCOPTS="--disable-session-crashed-bubble --enable-leak-detection"

BASELOGFILEPATH=~/logs/google_chrome-launcher

function get_uptime() {
  UPTIME_SECONDS=$(cat /proc/uptime | cut -f 1 -d ' ')
  echo ${UPTIME_SECONDS}
}

function get_gui_login_time() {
  GUI_LOGIN_TIMESTAMP="$(last | grep 'still logged in' | grep 'tty1' | sed "s/\ *\ /\ /g" | cut -f 4-7 -d ' ')"
  GUI_LOGIN_SECONDS=$(date -d "${GUI_LOGIN_TIMESTAMP}" "+%s")
  echo ${GUI_LOGIN_SECONDS}
}

function get_init_delay() {
  TARGET_DELAY=5
  GUI_LOGIN_SECONDS=$(get_gui_login_time)
  TARGET_EPOCH=$((${GUI_LOGIN_SECONDS} + ${TARGET_DELAY}))
  NOW_EPOCH=$(date "+%s")
  INIT_DELAY=$((${TARGET_EPOCH} - ${NOW_EPOCH}))
  if [[ ${INIT_DELAY} -lt 0 ]] ; then
    INIT_DELAY=0
  fi
  echo ${INIT_DELAY}
}

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
  THISPID=$$
  if [[ -z ${THISPID} ]] ; then
    log_error_and_exit "THISPID is not set"
  fi
  MESSAGE="${1:-""}"
  TIMESTAMP=$(get_timestamp)
  THISPROFILENAME="${PROFILENAME:-"NA"}"
  echo "${TIMESTAMP} - ${THISPROFILENAME} (${THISPID}) - ${MESSAGE}" >> $(get_log_path)
}

function log_error_and_exit() {
  ERROR_MESSAGE="ERROR: ${1:-"An unspecified error occurred"}"
  log "${ERROR_MESSAGE}" >> $(get_log_path)
  echo "${ERROR_MESSAGE}" >&2
  exit 1
}

function update_lock_file_contents() {
  THIS_TIMESTAMP=$(date +"%s")
  if ! (( ${THIS_TIMESTAMP} )) ; then
    log_error_and_exit "THIS_TIMESTAMP is not an integer"
  fi
  mkdir -p "${LOCAL_METADATA_PATH}"
  echo -n "${THISPID}:${THIS_TIMESTAMP}" > "${LOCKFILE_PATH}"
}

function expire_lock() {
  if [[ -f "${LOCKFILE_PATH}" ]] ; then
    LOCKFILE_PID=$(head -n 1 "${LOCKFILE_PATH}" | cut -f 1 -d ':')
    LOCKFILE_TIMESTAMP=$(head -n 1 "${LOCKFILE_PATH}" | cut -f 2 -d ':')
    if ! (( ${LOCKFILE_TIMESTAMP} )) ; then
      log_error_and_exit "LOCKFILE_TIMESTAMP is not an integer"
    fi
    EXPIRY_TIMESTAMP=$(date -d "-60 seconds" +"%s")
    if ! (( ${EXPIRY_TIMESTAMP} )) ; then
      log_error_and_exit "EXPIRY_TIMESTAMP is not an integer"
    fi
    THIS_TIMESTAMP=$(date +"%s")
    if ! (( ${THIS_TIMESTAMP} )) ; then
      log_error_and_exit "THIS_TIMESTAMP is not an integer"
    fi
    if [[ ${THISPID} -ne ${LOCKFILE_PID} ]] ; then
      if [[ ${LOCKFILE_TIMESTAMP} -le ${EXPIRY_TIMESTAMP} ]] ; then
        log "Expiring stale lock for PID:${LOCKFILE_PID}"
        rm "${LOCKFILE_PATH}"
      fi
    fi
  fi
}

function update_lock() {
  if [[ -f "${LOCKFILE_PATH}" ]] ; then
    LOCKFILE_PID=$(head -n 1 "${LOCKFILE_PATH}" | cut -f 1 -d ':')
    if [[ ${THISPID} -eq ${LOCKFILE_PID} ]] ; then
      update_lock_file_contents
      echo -n 'LOCK_UPDATED'
    else
      log_error_and_exit "Cannot update lock - THISPID:${THISPID} does not match LOCKFILE_PID:${LOCKFILE_PID}"
    fi
  else
    log_error_and_exit "LOCKFILE_PATH is not a valid file, or does not exist"
  fi
}

function obtain_lock() {
  expire_lock
  if [[ -f "${LOCKFILE_PATH}" ]] ; then
    echo -n 'LOCK_DENIED'
  else
    update_lock_file_contents
    echo -n 'LOCK_GRANTED'
  fi
}

function release_lock() {
  THISPID=$$
  if [[ -z ${THISPID} ]] ; then
    log_error_and_exit "THISPID is not set"
  fi
  if [[ -f "${LOCKFILE_PATH}" ]] ; then
    LOCKFILE_PID=$(head -n 1 "${LOCKFILE_PATH}" | cut -f 1 -d ':')
    LOCKFILE_TIMESTAMP=$(head -n 1 "${LOCKFILE_PATH}" | cut -f 2 -d ':')
    if (( ${LOCKFILE_TIMESTAMP} )) ; then
      if [[ ${THISPID} -eq ${LOCKFILE_PID} ]] ; then
        log "Releasing lock"
        rm "${LOCKFILE_PATH}"
      else
        log_error_and_exit "LOCKFILE_PID:${LOCKFILE_PID} is not equal to THISPID:${THISPID}"
      fi
    else
      log_error_and_exit "Lock file is corrupted: LOCKFILE_TIMESTAMP is not an integer"
    fi
  else
    log_error_and_exit "Lock file is missing when attempting to release it"
  fi
}

function update_window_name_if_needed() {
  WID="$1"
  WINDOW_NAME="$2"
  THIS_WINDOW_NAME=$(xdotool getwindowname ${WID})
  if [[ "${WINDOW_NAME}" != "${THIS_WINDOW_NAME}" ]] ; then
    log "WID:${WID} - Setting window name to ${WINDOW_NAME}"
    xdotool set_window --name "${WINDOW_NAME}" ${WID} 2>/dev/null
    if [[ $? -ne 0 ]] ; then
      return 1
    fi
  fi
  return 0
}

if [[ -z "${THISPID}" ]] ; then
  log_error_and_exit "THISPID is not set"
fi

if [[ -z "${PROFILENAME}" ]] ; then
 log_error_and_exit "Variable PROFILENAME is not provided"
fi

if [[ -z "${PROFILENAMEDISPLAY}" ]] ; then
 log_error_and_exit "Variable PROFILENAMEDISPLAY is not provided"
fi

if [[ "${GCPROFILEPATH%/}" == "${GCPROFILEBASEPATH}" ]] ; then
 log_error_and_exit "Variable GCPROFILEPATH:${GCPROFILEPATH%/} matches variable GCPROFILEBASEPATH:${GCPROFILEBASEPATH}"
fi

if [[ -n "${PROFILEMODE}" ]] ; then
 if [[ "${PROFILEMODE}" == "incognito" ]] ; then
  GCOPTS="${GCOPTS} --incognito"
 fi
fi

if [[ $(obtain_lock) == 'LOCK_GRANTED' ]] ; then
  log "Lock granted"
else
  log_error_and_exit "Cannot obtain lock on start of process"
fi

mkdir -p $(dirname ${BASELOGFILEPATH})
TIMESTAMP=$(get_timestamp)
echo "Start time: ${TIMESTAMP}"
echo "Initially logging to file: $(get_log_path)"

if [[ $(get_init_delay) -gt 0 ]] ; then
  echo "Init Delay: $(get_init_delay) Second(s)"
  log "Init Delay: $(get_init_delay) Second(s)"
  sleep $(get_init_delay)
fi

EARLIEST_TIME_TO_UPDATE_LOCK=0

mkdir -p "${GCPROFILEPATH}"
mkdir -p "${LOCAL_METADATA_PATH}"
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
  CHROMEPID=$(pgrep --newest -f "chrome.* ${GCOPTS} --user-data-dir=.*/google_chrome/profiles/${PROFILENAME}$")
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

WID=""
WIDLIST=$(xdotool search --pid ${CHROMEPID})
for THISWID in ${WIDLIST} ; do
  if (( ${THISWID} )) ; then
    THISWIDWINDOWNAME=$(xdotool getwindowname ${THISWID})
    log "Checking WID: ${THISWID} (${THISWIDWINDOWNAME})"
    if [[ "${THISWIDWINDOWNAME}" != "google-chrome" ]] ; then
      log "Matched WID: ${THISWID}"
      WID=${THISWID}
    fi
  else
    log_error_and_exit "WID from WIDLIST is not an integer (THISWID:${THISWID})"
  fi
done

if (( ${WID} )) ; then
  log "Setting Window Naming Monitor to ACTIVE"
  WINDOWNAMING_LOOPACTIVE="yes"
else
  log_error_and_exit "WID is not an integer (WID:${WID})"
fi

THISWINDOWNAME=$(xdotool getwindowname ${WID})
while [[ "${WINDOWNAMING_LOOPACTIVE}" == "yes" ]] ; do
  NOWEPOCHTIME=$(date +"%s")
  if [[ ${NOWEPOCHTIME} -ge ${EARLIEST_TIME_TO_UPDATE_LOCK} ]] ; then
    expire_lock
    if [[ "$(update_lock)" != 'LOCK_UPDATED' ]] ; then
      log_error_and_exit "Cannot update lock"
    else
      EARLIEST_TIME_TO_UPDATE_LOCK=$(date -d "+15 seconds" +"%s")
    fi
  fi
  THISWINDOWNAMEPREVIOUS="${THISWINDOWNAME}"
  THISWINDOWNAME=$(xdotool getwindowname ${WID} 2>/dev/null)
  if [[ $? -ne 0 ]] ; then
    WINDOWNAMING_LOOPACTIVE="no"
    READYTOSET="no"
  fi
  if [[ "${WINDOWNAMING_LOOPACTIVE}" == "yes" && "${THISWINDOWNAME}" != "${THISWINDOWNAMEPREVIOUS}" && "${THISWINDOWNAME}" != "" ]] ; then
    log "WID:${WID} - Window Name: ${THISWINDOWNAME}"
  fi
  if [[ "${THISWINDOWNAME}" != "${PROFILENAMEDISPLAY}" && "${THISWINDOWNAME}" == "${THISWINDOWNAMEPREVIOUS}" ]] ; then
    if [[ "${READYTOSET}" == "yes" ]] ; then
      update_window_name_if_needed ${WID} "${PROFILENAMEDISPLAY}" || WINDOWNAMING_LOOPACTIVE="no"
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

release_lock

log "Exiting with a zero status"
exit 0
