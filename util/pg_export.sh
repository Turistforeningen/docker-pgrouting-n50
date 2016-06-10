#!/bin/bash

function usage {
  echo "Usage: ${0} [TABLE]";
}

function main {
  declare -r TABLE=${1}

  if [ -z ${TABLE} ]; then
    usage ${@}
    echo "ERROR: TABLE can not be undefined";
    exit 1
  fi

  if [ -z ${FILE} ]; then
    declare -r FILE="./data/${TABLE}-$(date '+%y-%m-%d').backup"
  else
    declare -r FILE=${2}
  fi

  echo "pg_dump: n50.${TABLE} => ${FILE}...";
  sleep 5

  pg_dump -U postgres -h postgres -d postgres \
    --verbose --clean --no-owner --no-privileges \
    --format custom \
    --schema "n50" \
    --table "n50.${TABLE}" \
    --table "n50.${TABLE}_vertices_pgr" \
    --file "${FILE}"
}

main ${@}
