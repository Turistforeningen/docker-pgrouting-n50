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

## Licenses

* [PostgreSQL Docker Image](https://github.com/docker-library/postgres) - MIT
* [PostGIS Docker Image](https://github.com/appropriate/docker-postgis/blob/master/LICENSE) - MIT
* [pgRouting Docker Image](https://github.com/Starefossen/docker-pgrouting/blob/master/LICENSE) - MIT
* [N50 Data from Kartverket](http://www.kartverket.no/en/Kart/Gratis-kartdata/Terms-of-use/) - CC BY 4.0
