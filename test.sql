SELECT 'test 1' as test, path_id as id, ST_Length(geom) as length
FROM path(
  6.26297, 60.91346,
  6.22052, 60.96570
);

SELECT 'test 2 (bbox)' as test, path_id as id, ST_Length(geom) as length
FROM path(
  6.26297, 60.91346,
  6.22052, 60.96570,
  bbox:='{5.41213,60.87099,6.59591,61.07090}'
);

SELECT 'test 3' as test, path_id as id, ST_Length(geom) as length
FROM path(
  6.26297, 60.91346,
  6.22052, 60.96570,
  path_buffer:=0
);

SELECT 'test 4' as test, path_id as id, ST_Length(geom) as length
FROM path(
  6.26297, 60.91346,
  6.22052, 60.96570,
  point_buffer:=0
);

SELECT 'test 5 (targets)' as test, path_id as id, ST_Length(geom) as length
FROM path(
  6.26297, 60.91346, 6.22052, 60.96570,
  targets:=2
);
