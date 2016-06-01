FROM starefossen/pgrouting:9-2-2

ENV N50_BASE "https://s3-eu-west-1.amazonaws.com/turistforeningen/postgis"
ENV N50_DATE "15-08-04"

ADD "${N50_BASE}/n50_vegsti-${N50_DATE}.backup" /n50_vegsti.backup

COPY ./n50_init.sh /docker-entrypoint-initdb.d/routingx50.sh
COPY ./n50_path.sql /docker-entrypoint-initdb.d/routingx50path.sql

#COPY ./n50_vegsti.backup /n50_vegsti.backup
