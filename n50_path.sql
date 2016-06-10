--
--DROP FUNCTION path(double precision,
--                   double precision,
--                   double precision,
--                   double precision,
--                   double precision);

-- http://workshop.pgrouting.org/chapters/wrapper.html
-- http://lists.osgeo.org/pipermail/pgrouting-users/2012-January/000927.html
-- https://github.com/pgRouting/pgrouting/issues/355
-- http://gis.stackexchange.com/questions/142231
-- http://gis.stackexchange.com/questions/16157
-- http://gis.stackexchange.com/questions/87370
-- http://www.dpriver.com/pp/sqlformat.htm

CREATE OR REPLACE FUNCTION path(
  IN x1 double precision,
  IN y1 double precision,
  IN x2 double precision,
  IN y2 double precision,
  IN path_buffer double precision DEFAULT 2000,
  IN point_buffer double precision DEFAULT 10,
  IN targets integer DEFAULT 1,
  OUT path_id integer,
  OUT cost double precision,
  OUT geom geometry
) RETURNS SETOF record AS

$BODY$
DECLARE
  sql       text;
  point1    text;
  point2    text;
  rec       record;
  rec1      record;
  rec2      record;
  prec1     double precision;
  prec2     double precision;
  srid_in   smallint;
  srid_db   smallint;

BEGIN
  -- http://boundlessgeo.com/2011/09/indexed-nearest-neighbour-search-in-postgis/
  -- http://gis.stackexchange.com/questions/34997

  -- SRID for point inputs (WGS 84)
  srid_in := 4326;

  -- SRID in N50 data (ETRS89 / UTM zone 33N)
  srid_db := 25833;

  -- Start Point
  point1 := 'ST_Transform(ST_GeometryFromText(
    ''POINT(' || x1 || ' ' || y1 || ')'', ' || srid_in || '
  ), ' || srid_db || ')';

  EXECUTE 'SELECT
      ogc_fid AS id,
      ST_LineLocatePoint(geometri, ' || point1 || ') AS prec
    FROM n50.n50_vegsti
    WHERE geometri && ST_Buffer(' || point1 || ', ' || point_buffer || ')
    ORDER BY ST_Distance(geometri, ' || point1 || ')
    LIMIT 1'
  INTO rec1;

  -- Stop Point
  point2 := 'ST_Transform(ST_GeometryFromText(
    ''POINT(' || x2 || ' ' || y2 || ')'', ' || srid_in || '
  ), ' || srid_db || ')';

  EXECUTE 'SELECT
      ogc_fid AS id,
      ST_LineLocatePoint(geometri, ' || point2 || ') AS prec
    FROM n50.n50_vegsti
    WHERE geometri && ST_Buffer(' || point2 || ', ' || point_buffer || ')
    ORDER BY ST_Distance(geometri, ' || point2 || ')
    LIMIT 1'
  INTO rec2;

  RAISE NOTICE '[ROUTER] source.id=% source.prec=%', rec1.id, rec1.prec;
  RAISE NOTICE '[ROUTER] target.id=% target.prec=%', rec2.id, rec2.prec;

  IF rec1.id IS null OR rec2.id IS null THEN
    RAISE NOTICE '[ROUTER] source or target is NULL; returning';
    RETURN;
  END IF;

  sql := 'UNION SELECT
    ogc_fid AS id,
    source::int,
    -888::int AS target,
    cost::float * ' || rec1.prec || ' AS cost
  FROM n50.n50_vegsti
  WHERE ogc_fid = ' || rec1.id || '

  UNION SELECT
    ogc_fid AS id,
    -888::int AS source,
    target::int,
    cost::float * (1 - ' || rec1.prec || ') AS cost
  FROM n50.n50_vegsti
  WHERE ogc_fid = ' || rec1.id || '

  UNION SELECT
    ogc_fid AS id,
    source::int,
    -999::int AS target,
    cost::float * ' || rec2.prec || ' AS cost
  FROM n50.n50_vegsti
  WHERE ogc_fid = ' || rec2.id || '

  UNION SELECT
    ogc_fid AS id,
    -999::int AS source,
    target::int,
    cost::float * (1 - ' || rec2.prec || ') AS cost
  FROM n50.n50_vegsti
  WHERE ogc_fid = ' || rec2.id;

  IF (rec1.id = rec2.id) THEN
    RAISE NOTICE '[ROUTER] source.id = target.id';

    sql := sql || 'UNION SELECT
      ogc_fid AS id,
      -888::int AS source,
      -999::int AS target,
      cost::float * ' || rec1.prec || ' * ' || rec2.prec || ' AS cost
    FROM n50.n50_vegsti
    WHERE ogc_fid = ' || rec1.id || '

    UNION SELECT
      ogc_fid AS id,
      -999::int AS source,
      -888::int AS target,
      cost::float * ' || rec2.prec || ' * ' || rec1.prec || ' AS cost
    FROM n50.n50_vegsti
    WHERE ogc_fid = ' || rec2.id;
  END IF;

  sql := 'SELECT
    ogc_fid as id,
    source::int,
    target::int,
    cost::float
  FROM n50.n50_vegsti
  WHERE geometri && ST_Buffer(
    ST_LineFromMultiPoint(
      ST_Transform(
        ST_GeometryFromText($$MULTIPOINT(
          ' || x1 || ' ' || y1 || ',
          ' || x2 || ' ' || y2 || '
        )$$, ' || srid_in || '),
        ' || srid_db || '
      )),
    ' || path_buffer || '
  )

  ' || sql;

  sql := 'SELECT
    path.path_id,
    ST_LineMerge(ST_Collect(vegsti.geometri)) AS geom,
    SUM(path.cost) AS cost
  FROM
    pgr_ksp(''' || sql || ''', -888, -999, ' || targets || ', directed:=false) AS path,
    n50.n50_vegsti AS vegsti
  WHERE path.edge = vegsti.ogc_fid
  GROUP BY path.path_id
  ORDER BY SUM(path.cost)';

  FOR rec IN EXECUTE sql
  LOOP
    IF rec.geom IS NULL THEN
      RAISE NOTICE '[ROUTER] route geometry is NULL; returning';
      RETURN;
    END IF;

    -- If the geometry is not a `LINESTRING` it means `ST_LineMerge` was not
    -- able to merge path geometry to a contiguous line.
    IF GeometryType(rec.geom) != 'LINESTRING' THEN
      RAISE NOTICE '[ROUTER] route geometry is MULTILINE; returning';
      RETURN;
    END IF;

    prec1 := ST_LineLocatePoint(
      rec.geom, ST_Transform(
        ST_GeometryFromText('POINT(' || x1 || ' ' || y1 || ')', srid_in), srid_db
      )
    );

    prec2 := ST_LineLocatePoint(
      rec.geom, ST_Transform(
        ST_GeometryFromText('POINT(' || x2 || ' ' || y2 || ')', srid_in), srid_db
      )
    );

    RAISE NOTICE '[ROUTING] path_id=%, start=%, end=%', rec.path_id, prec1, prec2;

    -- ST_LineSubstring:  2nd arg must be smaller then 3rd arg
    -- ST_Reverse: reverse if we detect that second is smaller than first

    IF (prec2 < prec1) THEN
      rec.geom := ST_Reverse(ST_LineSubstring(rec.geom, prec2, prec1));
    ELSE
      rec.geom := ST_LineSubstring(rec.geom, prec1, prec2);
    END IF;

    RAISE NOTICE '[ROUTING] path_id=%, cost=%', rec.path_id, rec.cost;

    -- Return record
    path_id := rec.path_id;
    cost := rec.cost;
    geom := rec.geom;

    RETURN NEXT;

  END LOOP;
  RETURN;

END;

$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;
