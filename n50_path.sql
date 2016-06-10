-- Shortest path routing function for N50 vegsti data

CREATE OR REPLACE FUNCTION path(
  IN x1 double precision,
  IN y1 double precision,
  IN x2 double precision,
  IN y2 double precision,
  IN path_buffer double precision DEFAULT 2000,
  IN point_buffer double precision DEFAULT 10,
  IN targets integer DEFAULT 1,
  IN srid_in integer DEFAULT 4326,
  IN srid_db integer DEFAULT 25833,
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
  source    record;
  target    record;
  prec1     double precision;
  prec2     double precision;

BEGIN
  -- Find the closest edge (source) near the start (x1, y1)
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
  INTO source;

  -- Find the closest edge (target) near the end (x2, y2)
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
  INTO target;

  RAISE NOTICE '[ROUTER] source.id=% source.prec=%', source.id, source.prec;
  RAISE NOTICE '[ROUTER] target.id=% target.prec=%', target.id, target.prec;

  -- Return if we could not find source or target edges
  IF source.id IS null OR target.id IS null THEN
    RAISE NOTICE '[ROUTER] source or target is NULL; returning';
    RETURN;
  END IF;

  -- Since we do not route form exactly the beginning of each edge we need to
  -- cut the source and target edges where the closest start and end points
  -- (respectively) are located.

  sql := 'UNION SELECT
    ogc_fid AS id,
    source::int,
    -888::int AS target,
    cost::float * ' || source.prec || ' AS cost
  FROM n50.n50_vegsti
  WHERE ogc_fid = ' || source.id || '

  UNION SELECT
    ogc_fid AS id,
    -888::int AS source,
    target::int,
    cost::float * (1 - ' || source.prec || ') AS cost
  FROM n50.n50_vegsti
  WHERE ogc_fid = ' || source.id || '

  UNION SELECT
    ogc_fid AS id,
    source::int,
    -999::int AS target,
    cost::float * ' || target.prec || ' AS cost
  FROM n50.n50_vegsti
  WHERE ogc_fid = ' || target.id || '

  UNION SELECT
    ogc_fid AS id,
    -999::int AS source,
    target::int,
    cost::float * (1 - ' || target.prec || ') AS cost
  FROM n50.n50_vegsti
  WHERE ogc_fid = ' || target.id;

  -- If the edge is long or the route is short we could end up with a shortest
  -- route consisting of a single edge or a subset of it. We handle that by
  -- inserting dummy edges into the pool of edges.

  IF (source.id = target.id) THEN
    RAISE NOTICE '[ROUTER] source.id = target.id';

    sql := sql || 'UNION SELECT
      ogc_fid AS id,
      -888::int AS source,
      -999::int AS target,
      cost::float * ' || source.prec || ' * ' || target.prec || ' AS cost
    FROM n50.n50_vegsti
    WHERE ogc_fid = ' || source.id || '

    UNION SELECT
      ogc_fid AS id,
      -999::int AS source,
      -888::int AS target,
      cost::float * ' || target.prec || ' * ' || source.prec || ' AS cost
    FROM n50.n50_vegsti
    WHERE ogc_fid = ' || target.id;
  END IF;

  -- Since there are 1.5 million edges in the database we need to limit the
  -- shortes path search to only the subset of edges that can reasonably match.

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

  -- This is the actual SQL query that takes the edges and applies the
  -- K-Shortest Path routing algorithm implemeted by `pgr_ksp`.

  sql := 'SELECT
    path.path_id,
    ST_LineMerge(ST_Collect(vegsti.geometri)) AS geom,
    SUM(path.cost) AS cost
  FROM
    pgr_ksp(
      ''' || sql || ''',
      -888,
      -999,
      ' || targets || ',
      directed:=false
    ) AS path,
    n50.n50_vegsti AS vegsti
  WHERE path.edge = vegsti.ogc_fid
  GROUP BY path.path_id
  ORDER BY SUM(path.cost)';

  -- Now, get the shortest paths and process them before returning

  FOR rec IN EXECUTE sql
  LOOP
    -- Return if no route was found
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

    -- Ok, so `rec.geom` is the combined geometry of the all edges in the
    -- shortes path. However, since we rarly route from the exact beginning of
    -- an edge we need to trim the route in both ends to the points where we
    -- want the route to source and target.

    -- Locate the point on the route closest to the source point
    prec1 := ST_LineLocatePoint(
      rec.geom, ST_Transform(
        ST_GeometryFromText('POINT(' || x1 || ' ' || y1 || ')', srid_in), srid_db
      )
    );

    -- Locate the point on the route closest to the target point
    prec2 := ST_LineLocatePoint(
      rec.geom, ST_Transform(
        ST_GeometryFromText('POINT(' || x2 || ' ' || y2 || ')', srid_in), srid_db
      )
    );

    RAISE NOTICE '[ROUTING] path_id=%, start=%, end=%', rec.path_id, prec1, prec2;

    -- Now that we have the closest points in both ends we just need to trim the
    -- route in order to fit our source and target requirements. Since the route can
    -- be returned source to target or target to source we check reverse the route when
    -- necessary before trimming.

    IF (prec2 < prec1) THEN
      rec.geom := ST_Reverse(ST_LineSubstring(rec.geom, prec2, prec1));
    ELSE
      rec.geom := ST_LineSubstring(rec.geom, prec1, prec2);
    END IF;

    RAISE NOTICE '[ROUTING] path_id=%, cost=%', rec.path_id, rec.cost;

    -- Return the resulting record as defined in our function definition
    path_id := rec.path_id;
    cost := rec.cost;
    geom := rec.geom;

    -- Continue processing the next shortest route
    RETURN NEXT;

  END LOOP;
  RETURN;

END;

$BODY$
LANGUAGE 'plpgsql' VOLATILE STRICT;
