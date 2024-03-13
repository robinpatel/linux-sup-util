#!/bin/bash

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
echo "${CMD}"
${CMD} >/dev/null 2>/dev/null &

sleep 1

CHROMEPID_LOOPACTIVE="yes"
while [ "${CHROMEPID_LOOPACTIVE}" == "yes" ] ; do
 CHROMEPID=$(pgrep --newest -f "chrome.* --user-data-dir=.*/google_chrome/profiles/${PROFILENAME}$")
 if [ $? -eq 0 ] ; then
  if [ (( ${CHROMEPID} )) ] ; then
    CHROMEPID_LOOPACTIVE="no"
  fi
 fi
 sleep 1
done

TRUEWID=""
WIDLIST=$(xdotool search --name "Google Chrome")
for THISWID in ${WIDLIST} ; do
 THISPID=$(xdotool getwindowpid ${THISWID})
 if [ "${THISPID}"  == "${CHROMEPID}" ] ; then
  echo "Matched WID: ${THISWID}"
  TRUEWID="${THISWID}"
 fi
done

if [ "${TRUEWID}" == "" ] ; then
 LOOPACTIVE="no"
else
 LOOPACTIVE="yes"
fi

while [ "${LOOPACTIVE}" == "yes" ] ; do
 THISWINDOWNAME=$(xdotool getwindowname ${TRUEWID})
 if [ "${THISWINDOWNAME}" != "${PROFILENAMEDISPLAY}" ] ; then
  echo "Setting WID: ${THISWID} to ${PROFILENAMEDISPLAY}"
  xdotool set_window --name "${PROFILENAMEDISPLAY}" ${TRUEWID}
  if [ $? -ne 0 ] ; then
   LOOPACTIVE="no"
  fi
 fi
 sleep 1
done

