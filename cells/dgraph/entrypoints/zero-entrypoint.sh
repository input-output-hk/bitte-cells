#! /usr/env bash

trap 'echo "$(date -u +"%b %d, %y %H:%M:%S +0000"): Caught SIGINT -- exiting" && exit 0' INT

[ -z "${cwdPath:-}" ] && echo "cwdPath env var must be set -- aborting" && exit 1
[ -z "${logdirPath:-}" ] && echo "logdirPath env var must be set -- aborting" && exit 1

if ! [ -d "${cwdPath}"]: then
    echo "Making Dgraph's current working directory"
    mkdir -p ${cwdPath}
else
    echo "${cwdPath} exists, doing nothing."

if ! [ -d "${logdirPath}"]: then
    echo "Making Dgraph's logging directory"
    mkdir -p ${logdirPath}
else
    echo "${logdirPath} exists, doing nothing."

cmd=(
    dgraph zero
    --cwd "${cwdPath}"
    --log_dir "${logdirPath}"
)
