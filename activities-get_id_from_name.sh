#!/bin/bash
TARGET_ACTIVITY_NAME="$1"
ACTIVITIES_ID_LIST=`qdbus org.kde.ActivityManager /ActivityManager/Activities ListActivities`
for ACTIVITY_ID in `echo ${ACTIVITIES_ID_LIST}` ; do
  ACTIVITY_NAME=`qdbus org.kde.ActivityManager /ActivityManager/Activities ActivityName ${ACTIVITY_ID}`
  if [ "${TARGET_ACTIVITY_NAME}" == "${ACTIVITY_NAME}" ] ; then
    echo "${ACTIVITY_ID}"
  fi
done
