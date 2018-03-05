#!/bin/bash
# some commonly used bash functions

# print messages with timestamp prefix
msg() {
    echo >&2 -e `date "+%F %T"` $@
}

# This waits for a url to be available by querying once a second for
# specified number of seconds.
#
# @param ${1}: url to test
# @param ${2}: Number of seconds. Optional argument, defaults to 30
#
# If the url doesn't respond, we fail.
waitForUrl() {
    url=${1}
    secondsToTry=${2}
    handleServerId=

    if [ -z "${secondsToTry}" ]; then
        secondsToTry=30
    fi

    if [[ ${url} == https* ]]; then
        handleServerId=" -k"
    fi

    msg "Waiting for ${url} for up to ${secondsToTry} seconds..."

    attempt=0
    while [ ${attempt} -lt ${secondsToTry} ]; do
        statuscode=$(curl${handleServerId} --silent --output /dev/null --write-out "%{http_code}" ${url})
        if test ${statuscode} -eq 200; then
            msg "GET ${statuscode}"
            return 0
        fi
        msg "GET ${statuscode}"
        sleep 1
        attempt=`expr ${attempt} + 1`
    done
    msg "ERROR: ${url} is not responding with a 200"
    return 1
}

waitForUrlOrExit() {
    url=$1
    secondsToTry=$2

    waitForUrl ${url} ${secondsToTry}
    rc=$?
    if [ ${rc} -ne 0 ]; then
        msg "Wait for k8s control plane failed!"
        exit 1
    fi
}