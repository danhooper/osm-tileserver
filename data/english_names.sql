update planet_osm_line SET name = "name:en" || ' (' || name || ')' where "name:en" is not null and name not like '%' || "name:en" || '%';

update planet_osm_point SET name = "name:en" || ' (' || name || ')' where "name:en" is not null and name not like '%' || "name:en" || '%';
update planet_osm_polygon SET name = "name:en" || ' (' || name || ')' where "name:en" is not null and name not like '%' || "name:en" || '%';
update planet_osm_roads SET name = "name:en" || ' (' || name || ')' where "name:en" is not null and name not like '%' || "name:en" || '%';
