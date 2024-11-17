-- Znajdź budynki, które zostały wybudowane lub wyremontowane na przestrzeni roku (zmiana pomiędzy 2018 a 2019).

CREATE VIEW buildings_diff AS 
SELECT ST_Difference(tkb2018.geom, tkb2019.geom) AS diff
FROM t2018_kar_buildings tkb2018 
INNER JOIN t2019_kar_buildings tkb2019 
ON tkb2018.polygon_id = tkb2019.polygon_id
WHERE ST_Difference(tkb2018.geom, tkb2019.geom) != 'POLYGON EMPTY';

-- Znajdź ile nowych POI pojawiło się w promieniu 500 m od wyremontowanych lub wybudowanych budynków, które...
-- ...znalezione zostały w zadaniu 1. Policz je wg ich kategorii.

CREATE VIEW ptd AS
SELECT ST_Difference(tkpt2018.geom, tkpt2019.geom) AS diff, tkpt2019.type AS type
FROM t2018_kar_poi_table tkpt2018
INNER JOIN t2019_kar_poi_table tkpt2019
ON tkpt2018.poi_id  = tkpt2019.poi_id
WHERE NOT ST_IsEmpty(ST_Difference(tkpt2018.geom, tkpt2019.geom));

SELECT DISTINCT ptd.type, COUNT(ptd.type) AS type_count FROM buildings_diff bd
JOIN ptd ON 
  ST_Contains(ST_Buffer(bd.diff, 500), ptd.diff) GROUP BY ptd.type;
 
-- Utwórz nową tabelę o nazwie ‘streets_reprojected’, która zawierać będzie dane z tabeli T2019_KAR_STREETS...
-- ...przetransformowane do układu współrzędnych DHDN.Berlin/Cassini.

CREATE TABLE streets_reprojected (id integer, geom geometry);

INSERT INTO streets_reprojected SELECT gid, geom FROM t2019_kar_streets;

UPDATE streets_reprojected SET geom = ST_SetSRID(geom, 4326);

UPDATE streets_reprojected SET geom = ST_Transform(geom, 3068);

-- Stwórz tabelę o nazwie ‘input_points’ i dodaj do niej dwa rekordy o geometrii punktowej.
-- Użyj następujących współrzędnych:
-- X       Y
-- 8.36093 49.03174
-- 8.39876 49.00644

CREATE TABLE input_points (id integer, geom geometry);

INSERT INTO input_points (id, geom)
VALUES (1, st_setsrid(st_makepoint(8.36093, 49.03174), 4326)),
       (2, st_setsrid(st_makepoint(8.39876, 49.00644), 4326));

-- Zaktualizuj dane w tabeli ‘input_points’ tak, aby punkty te były w układzie współrzędnych DHDN.Berlin/Cassini.

UPDATE input_points SET geom = ST_SetSRID(geom, 3068);

-- Znajdź wszystkie skrzyżowania, które znajdują się w odległości 200 m od linii zbudowanej z punktów w tabeli...
-- ...‘input_points’. Wykorzystaj tabelę T2019_STREET_NODE. Dokonaj reprojekcji geometrii, aby była zgodna z resztą tabel.

UPDATE input_points SET geom = ST_SetSRID(geom, 4326);

UPDATE t2019_kar_street_node SET geom = ST_SetSRID(geom, 4326);

SELECT DISTINCT tksn.geom FROM t2019_kar_street_node tksn 
JOIN input_points ip ON ST_Contains(ST_Buffer(ip.geom, 200), tksn.geom); 

-- Policz jak wiele sklepów sportowych (‘Sporting Goods Store’ - tabela POIs) znajduje się w odległości 300 m od parków (LAND_USE_A).

SELECT DISTINCT COUNT(poi.geom) AS poi_count 
FROM t2018_kar_poi_table poi 
JOIN t2019_kar_land_use_a land 
ON ST_Contains(ST_Buffer(land.geom, 300), poi.geom) 
WHERE poi.type = 'Sporting Goods Store';
 
-- Znajdź punkty przecięcia torów kolejowych (RAILWAYS) z ciekami (WATER_LINES). Zapisz znalezioną geometrię do osobnej tabeli...
-- O nazwie ‘T2019_KAR_BRIDGES’.

CREATE TABLE T2019_KAR_BRIDGES AS SELECT ST_INTERSECTION(a.geom, b.geom)
FROM t2019_kar_water_lines a, t2019_kar_railways b
WHERE a.gid < b.gid
AND ST_INTERSECTS(a.geom, b.geom);
