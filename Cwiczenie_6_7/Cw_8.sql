-- Przykłady

ALTER SCHEMA schema_name RENAME TO hyziak;

CREATE EXTENSION postgis_raster SCHEMA hyziak;

CREATE TABLE hyziak.intersects AS
SELECT a.rast, b.municipality
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality ilike 'porto';

ALTER TABLE hyziak.intersects
ADD COLUMN rid SERIAL PRIMARY KEY;

CREATE INDEX idx_intersects_rast_gist 
ON hyziak.intersects
USING gist(ST_ConvexHull(rast));

SELECT AddRasterConstraints('hyziak'::name, 'intersects'::name, 'rast'::name);

CREATE TABLE hyziak.clip AS
SELECT ST_Clip(a.rast, b.geom, true), b.municipality
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality like 'PORTO';

CREATE TABLE hyziak.union AS
SELECT ST_Union(ST_Clip(a.rast, b.geom, true))
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast);

CREATE TABLE hyziak.porto_parishes AS
WITH r AS (
	SELECT rast FROM rasters.dem LIMIT 1
) SELECT ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767) 
AS rast FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';

DROP TABLE hyziak.porto_parishes;

CREATE TABLE hyziak.porto_parishes AS
WITH r AS (
	SELECT rast FROM rasters.dem
	LIMIT 1
) SELECT st_union(ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767)) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';

DROP TABLE hyziak.porto_parishes; 

CREATE TABLE hyziak.porto_parishes AS
WITH r AS (
SELECT rast FROM rasters.dem
LIMIT 1 )
SELECT st_tile(st_union(ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767)),128,128,true,-32767) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';

CREATE TABLE hyziak.intersection as
SELECT a.rid,(ST_Intersection(b.geom,a.rast)).geom,(ST_Intersection(b.geom,a.rast)).val
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.parish ILIKE 'paranhos' and ST_Intersects(b.geom,a.rast);

CREATE TABLE hyziak.landsat_nir AS
SELECT rid, ST_Band(rast,4) AS rast
FROM rasters.landsat8;

CREATE TABLE hyziak.paranhos_dem AS
SELECT a.rid,ST_Clip(a.rast, b.geom,true) as rast
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);

CREATE TABLE hyziak.paranhos_slope AS
SELECT a.rid,ST_Slope(a.rast,1,'32BF','PERCENTAGE') as rast
FROM hyziak.paranhos_dem AS a;

CREATE TABLE hyziak.paranhos_slope_reclass AS
SELECT a.rid,ST_Reclass(a.rast,1,']0-15]:1, (15-30]:2, (30-9999:3', '32BF',0)
FROM hyziak.paranhos_slope AS a;

SELECT st_summarystats(a.rast) AS stats
FROM hyziak.paranhos_dem AS a;

SELECT st_summarystats(ST_Union(a.rast))
FROM hyziak.paranhos_dem AS a;

WITH t AS (
	SELECT st_summarystats(ST_Union(a.rast)) AS stats
FROM hyziak.paranhos_dem AS a
) SELECT (stats).min,(stats).max,(stats).mean FROM t;

WITH t AS (
	SELECT b.parish AS parish, st_summarystats(ST_Union(ST_Clip(a.rast, b.geom,true))) AS stats
	FROM rasters.dem AS a, vectors.porto_parishes AS b
	WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
	group by b.parish
) SELECT parish,(stats).min,(stats).max,(stats).mean FROM t;

SELECT b.name,st_value(a.rast,(ST_Dump(b.geom)).geom)
FROM rasters.dem a, vectors.places AS b
WHERE ST_Intersects(a.rast,b.geom) ORDER BY b.name;

CREATE TABLE hyziak.tpi30 AS
SELECT ST_TPI(a.rast,1) AS rast
FROM rasters.dem a;

CREATE INDEX idx_tpi30_rast_gist ON hyziak.tpi30
USING gist (ST_ConvexHull(rast));

SELECT AddRasterConstraints('hyziak'::name, 'tpi30'::name,'rast'::name);

-- Problem do samodzielnego rozwiązania
-- Przetwarzanie poprzedniego zapytania może potrwać dłużej niż minutę, a niektóre zapytania mogą potrwać zbyt długo. W celu skrócenia 
-- czasu przetwarzania czasami można ograniczyć obszar zainteresowania i obliczyć mniejszy region. Dostosuj zapytanie z przykładu 10, 
-- aby przetwarzać tylko gminę Porto. Musisz użyć ST_Intersects, sprawdź Przykład 1 - ST_Intersects w celach informacyjnych. Porównaj 
-- różne czasy przetwarzania. Na koniec sprawdź wynik w QGIS.

create table hyziak.tpi30_porto as
SELECT ST_TPI(a.rast,1) as rast
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality ilike 'porto'

CREATE INDEX idx_tpi30_porto_rast_gist ON hyziak.tpi30_porto
USING gist (ST_ConvexHull(rast));

SELECT AddRasterConstraints('hyziak'::name, 'tpi30_porto'::name,'rast'::name);

CREATE TABLE hyziak.porto_ndvi AS
WITH r AS (
	SELECT a.rid,ST_Clip(a.rast, b.geom,true) AS rast
	FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
	WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
) SELECT
	r.rid,ST_MapAlgebra(
	r.rast, 1,
	r.rast, 4,
	'([rast2.val] - [rast1.val]) / ([rast2.val] + [rast1.val])::float','32BF'
) AS rast FROM r;

CREATE INDEX idx_porto_ndvi_rast_gist 
ON hyziak.porto_ndvi
USING gist (ST_ConvexHull(rast));

SELECT AddRasterConstraints('hyziak'::name, 'porto_ndvi'::name,'rast'::name);

create or replace function hyziak.ndvi(
	value double precision [] [] [],
	pos integer [][],
	VARIADIC userargs text []
) RETURNS double precision AS
$$
BEGIN
	RETURN (value [2][1][1] - value [1][1][1])/(value [2][1][1]+value [1][1][1]); 
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE COST 1000;

CREATE TABLE hyziak.porto_ndvi2 AS
WITH r AS (
	SELECT a.rid,ST_Clip(a.rast, b.geom,true) AS rast
	FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
	WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
) SELECT
r.rid,ST_MapAlgebra(
	r.rast, ARRAY[1,4],
	'hyziak.ndvi(double precision[], integer[],text[])'::regprocedure, 
	'32BF'::text
) AS rast FROM r;

CREATE INDEX idx_porto_ndvi2_rast_gist ON hyziak.porto_ndvi2
USING gist (ST_ConvexHull(rast));

SELECT AddRasterConstraints('hyziak'::name, 'porto_ndvi2'::name,'rast'::name);

SELECT ST_AsTiff(ST_Union(rast))
FROM hyziak.porto_ndvi;

SELECT ST_AsGDALRaster(ST_Union(rast), 'GTiff', ARRAY['COMPRESS=DEFLATE', 'PREDICTOR=2', 'PZLEVEL=9'])
FROM hyziak.porto_ndvi;

CREATE TABLE tmp_out AS
SELECT lo_from_bytea(0,
	ST_AsGDALRaster(ST_Union(rast), 'GTiff', ARRAY['COMPRESS=DEFLATE', 'PREDICTOR=2', 'PZLEVEL=9'])
) AS loid FROM hyziak.porto_ndvi;

SELECT lo_export(loid, 'C:\Home\myraster.tiff') FROM tmp_out;

SELECT lo_unlink(loid) FROM tmp_out; 
