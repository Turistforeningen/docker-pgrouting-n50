FROM starefossen/pgrouting:9-2-2
MAINTAINER Den Norske Turistforening (DNT) <opensource@turistforeningen.no>

ARG N50_URL
ENV N50_URL ${N50_URL:-"https://s3-eu-west-1.amazonaws.com/turistforeningen/postgis"}

ARG N50_DATE
ENV N50_DATE ${N50_DATE:-"16-06-14"}

# Download pgRouting compatible and pre-processed version of N50 data from S3
ADD "${N50_URL}/n50_vegsti-${N50_DATE}.backup" /n50_vegsti.backup

# Add the database init script which will be run when running the Docker Image
# for the first time. This will not be run if an existing database exists.
# https://github.com/docker-library/docs/tree/master/postgres#how-to-extend-this-image
COPY ./n50_init.sh /docker-entrypoint-initdb.d/routingx50.sh

# Add the psql router function `path` this is the function that does the
# shortest path routing on the N50 vegsti data.
COPY ./n50_path.sql /docker-entrypoint-initdb.d/routingx50path.sql
