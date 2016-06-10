SELECT path_id as id, ST_Length(geom) as length
FROM path(6.26297,60.91346,6.22052,60.96570);

SELECT path_id as id, ST_Length(geom) as length
FROM path(6.26297,60.91346,6.22052,60.96570, path_buffer:=0);

SELECT path_id as id, ST_Length(geom) as length
FROM path(6.26297,60.91346,6.22052,60.96570, point_buffer:=0);

SELECT path_id as id, ST_Length(geom) as length
FROM path(6.26297,60.91346,6.22052,60.96570, targets:=2);
