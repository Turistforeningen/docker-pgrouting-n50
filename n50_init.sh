#!/bin/bash

function usage {
  echo "Usage: ${0} [TABLE] [FILE]";
}

function main {
  declare -r S=n50
  declare -r T=${1}
  declare -r FILE=${2}

  if [ -z ${T} ]; then
    usage ${@}
    echo "ERROR: TABLE can not be undefined";
    exit 1
  fi

  if [ -z ${FILE} ]; then
    usage ${@}
    echo "ERROR: FILE can not be undefined";
    exit 1
  fi

  # Wait for postgres to become responsive...
  sleep 5

  echo "pg_restore: creating schema ${S}..."
  "${psql[@]}" -c "CREATE SCHEMA IF NOT EXISTS ${S}"

  echo "pg_restore: restoring ${T} from ${FILE}...";
  pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
    --verbose --clean --if-exists --no-owner --no-privileges \
    --schema "${S}" \
    --table "${T}" \
    --table "${T}_vertices_pgr" \
    "${FILE}"

  echo "pg_restore: restoring indexes..."
  "${psql[@]}" <<-EOSQL
    CREATE INDEX n50_vegsti_geometri_gix ON ${S}.${T} USING GIST ("geometri");
    CREATE UNIQUE INDEX n50_vegsti_ogc_fid_idx ON ${S}.${T} ("ogc_fid");
    CREATE INDEX n50_vegsti_source_idx ON ${S}.${T} ("source");
    CREATE INDEX n50_vegsti_target_idx ON ${S}.${T} ("target");
    CREATE INDEX n50_vegsti_cost_idx ON ${S}.${T} ("cost");
EOSQL
  echo
}

main "n50_vegsti" "/n50_vegsti.backup"
