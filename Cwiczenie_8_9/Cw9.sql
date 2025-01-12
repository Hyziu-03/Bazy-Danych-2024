create table raster (geom geometry);
insert into raster select st_union(geom) from "Exports";
select * from raster;
