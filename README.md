# turistforeningen/pgrouting-n50

[![Docker Stars](https://img.shields.io/docker/stars/turistforeningen/pgrouting-n50.svg?maxAge=2592000)](https://hub.docker.com/r/turistforeningen/pgrouting-n50/)
[![Docker Pulls](https://img.shields.io/docker/pulls/turistforeningen/pgrouting-n50.svg?maxAge=2592000)](https://hub.docker.com/r/turistforeningen/pgrouting-n50/)
[![ImageLayers Size](https://img.shields.io/imagelayers/image-size/turistforeningen/pgrouting-n50/latest.svg?maxAge=2592000)](https://hub.docker.com/r/turistforeningen/pgrouting-n50/)
[![ImageLayers Layers](https://img.shields.io/imagelayers/layers/turistforeningen/pgrouting-n50/latest.svg?maxAge=2592000)](https://hub.docker.com/r/turistforeningen/pgrouting-n50/)

The `turistforeningen/pgrouting-n50` image provides a Docker container running
Postgres 9.4 with PostGIS 2.1 and pgRouting 2.1 installed. This image is based
on the official `postgres` image.

For more information see the documentation of the following parent images:

* [`postgres`](https://github.com/docker-library/docs/tree/master/postgres#readme)
* [`appropriate/postgis`](https://github.com/appropriate/docker-postgis#readme)
* [`starefossen/pgrouting`](https://github.com/Starefossen/docker-pgrouting#readme)

## Usage

```
$ docker pull turistforeningen/pgrouting-n50
$ docker run --name n50 turistforeningen/pgrouting-n50
```

## Update Data

* Download [N50 data](http://data.kartverket.no/download/content/n50-kartdata-utm33-hele-landet-postgis) from Kartverket.
* Extract and copy `n50_custom.backup` to the `./data` directory in this repository.
* Import and process `n50_custom.backup`:

```sh
$ docker-compose create postgres
$ docker-compose start postgres

$ docker-compose run --rm --entrypoint /bin/bash psql \
    ./util/pg_import.sh n50_vegsti ./data/n50_custom.backup
```

* Export processed N50 datafile:

```sh
$ docker-compose run --rm --entrypoint /bin/bash psql ./util/pg_export.sh n50_vegsti
```

* Upload the processed N50 datafile AWS S3 bucket.
* Update `N50_DATE` in `Dockerfile` and tag the release.
* Push master and let Docker Hub do it's magic.

## Custom Build

```
$ docker build -t turistforeningen/pgrouting-n50 \
  --build-arg N50_URL=. \
  --build-arg N50_DATE=yy-mm-dd \
  .
```

## Testing

```
$ docker-compose create postgres
$ docker-compose start postgres
$ docker-compose run --rm psql -f util/drop.sql
$ docker-compose run --rm psql -f n50_path.sql
$ docker-compose run --rm psql -f test.sql
```

## Licenses

* [PostgreSQL Docker Image](https://github.com/docker-library/postgres) - MIT
* [PostGIS Docker Image](https://github.com/appropriate/docker-postgis/blob/master/LICENSE) - MIT
* [pgRouting Docker Image](https://github.com/Starefossen/docker-pgrouting/blob/master/LICENSE) - MIT
* [N50 Data from Kartverket](http://www.kartverket.no/en/Kart/Gratis-kartdata/Terms-of-use/) - CC BY 4.0
