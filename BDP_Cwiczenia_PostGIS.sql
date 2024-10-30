-- Zadanie 2

CREATE DATABASE cw3;

-- Zadanie 3

CREATE EXTENSION postgis;

-- Zadanie 4

CREATE TABLE buildings (
	id INT,
	geometry GEOMETRY,
	name VARCHAR(255)
);

CREATE TABLE roads (
	id INT,
	geometry GEOMETRY,
	name VARCHAR(255)
);

CREATE TABLE poi (
	id INT,
	geometry GEOMETRY,
	name VARCHAR(255)
);

-- Zadanie 5

INSERT INTO roads (id, name, geometry) VALUES 
(1, 'Road_X', 'LINESTRING(0 4.5, 12 4.5)'),
(2, 'Road_Y', 'LINESTRING(7.5 10.5, 7.5 0)');

INSERT INTO buildings (id, name, geometry) VALUES 
(3, 'Building_A', 'POLYGON((8 4, 10.5 4, 10.5 2.5, 8 1.5, 8 4))'),
(4, 'Building_B', 'POLYGON((4 7, 6 7, 6 5, 4 5, 4 7))'),
(5, 'Building_C', 'POLYGON((3 8, 5 8, 5 6, 3 6, 3 8))'),
(6, 'Building_D', 'POLYGON((9 9, 10 9, 10 8, 9 8, 9 9))'),
(7, 'Building_F', 'POLYGON((1 2, 2 2, 2 1, 1 1, 1 2))');

INSERT INTO poi (id, name, geometry) VALUES
(8, 'Point_G', 'POINT(1 3.5)'),
(8, 'Point_H', 'POINT(5.5 1.5)'),
(8, 'Point_I', 'POINT(6.5 6)'),
(8, 'Point_J', 'POINT(9.5 6)'),
(8, 'Point_K', 'POINT(6 9.5)');

-- Zadanie 6

-- Wyznacz całkowitą długość dróg w analizowanym mieście.

SELECT SUM(ST_Length(geometry)) FROM roads;

-- Wypisz geometrię (WKT), pole powierzchni oraz obwód poligonu reprezentującego budynek o nazwie Building_A.

SELECT 
	geometry, 
	ST_Area(geometry) AS pole, 
	ST_perimeter(geometry) AS obwod 
FROM buildings
WHERE name = 'Building_A';

-- Wypisz nazwy i pola powierzchni wszystkich poligonów w warstwie budynki.
-- Wyniki posortuj alfabetycznie.

SELECT name, ST_Area(geometry) FROM buildings ORDER BY name ASC;

-- Wypisz nazwy i obwody 2 budynków o największej powierzchni.

SELECT 
	name, 
	ST_Perimeter(geometry) AS obwod 
FROM buildings ORDER BY ST_Area(geometry) DESC LIMIT 2;

-- Wyznacz najkrótszą odległość między budynkiem Building_C a punktem K.

SELECT ST_Distance(
	(SELECT geometry FROM buildings WHERE name = 'Building_C'),
	(SELECT geometry FROM poi WHERE name = 'Point_K')
) FROM (
	(SELECT * FROM buildings WHERE name = 'Building_C') UNION ALL (SELECT * FROM poi WHERE name = 'Point_K')
) LIMIT 1;

-- Wypisz pole powierzchni tej części budynku Building_C, która znajduje się w odległości większej niż 0.5 od budynku Building_B.

SELECT ST_Area(geometry) FROM buildings 
WHERE name = 'Building_C' AND ST_Distance(
	(SELECT geometry FROM buildings WHERE name = 'Building_C'),
	(SELECT geometry FROM buildings WHERE name = 'Building_B')
) < 0.5;

-- Wybierz te budynki, których centroid (ST_Centroid) znajduje się powyżej drogi o nazwie Road_X.

SELECT * FROM (
	(SELECT * FROM buildings) UNION ALL (SELECT * FROM roads)
) WHERE name LIKE 'Building%' AND ST_Centroid(geometry) > (
	SELECT geometry FROM roads WHERE name = 'Road_X'
);

-- Oblicz pole powierzchni tych części budynku BuildingC i poligonu o współrzędnych
-- (4 7, 6 7, 6 8, 4 8, 4 7), które nie są wspólne dla tych dwóch obiektów?

INSERT INTO buildings (id, name, geometry) VALUES 
(13, 'Building_Alpha', 'POLYGON((4 7, 6 7, 6 8, 4 8, 4 7))');

SELECT SUM(ST_Area(geometry)) FROM buildings WHERE (
	(SELECT geometry FROM buildings WHERE name = 'Building_C') NOT IN (SELECT geometry FROM buildings WHERE name = 'Building_Alpha')
) AND (
	(SELECT geometry FROM buildings WHERE name = 'Building_Alpha') NOT IN (SELECT geometry FROM buildings WHERE name = 'Building_C')
) AND (name = 'Building_A' OR name = 'Building_Alpha');
