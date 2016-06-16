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
  psql -U postgres -h postgres -d postgres -c "CREATE SCHEMA IF NOT EXISTS ${S}"

  echo "pg_restore: dropping \"${S}.${T}_vertices_pgr\"...";
  psql -U postgres -h postgres -d postgres <<-EOSQL
    DROP TABLE IF EXISTS ${S}.${T}_vertices_pgr;
EOSQL
  echo

  echo "pg_restore: restoring ${T} from ${FILE}...";
  pg_restore -U postgres -h postgres -d postgres \
    --verbose --clean --if-exists --no-owner --no-privileges \
    --schema "${S}" \
    --table "${T}" \
    --table "${T}_vertices_pgr" \
    "${FILE}"

  echo "pg_restore: restoring indexes..."
  psql -U postgres -h postgres -d postgres <<-EOSQL
    DELETE FROM ${S}.${T} WHERE geometri IS NULL;
    DELETE FROM ${S}.${T} WHERE ogc_fid IS NULL;

    CREATE INDEX n50_vegsti_geometri_gix ON ${S}.${T} USING GIST ("geometri");
    CREATE UNIQUE INDEX n50_vegsti_ogc_fid_idx ON ${S}.${T} ("ogc_fid");

    ALTER TABLE ${S}.${T} ADD COLUMN "source" integer;
    ALTER TABLE ${S}.${T} ADD COLUMN "target" integer;
    SELECT pgr_createTopology('${S}.${T}', 0.00001, 'geometri', 'ogc_fid');
    CREATE INDEX n50_vegsti_source_idx ON ${S}.${T} ("source");
    CREATE INDEX n50_vegsti_target_idx ON ${S}.${T} ("target");

    ALTER TABLE ${S}.${T} ADD COLUMN cost double precision;
    UPDATE ${S}.${T} SET cost = ST_Length(geometri);
    CREATE INDEX n50_vegsti_cost_idx ON ${S}.${T} ("cost");
EOSQL
  echo
}

main ${@}
