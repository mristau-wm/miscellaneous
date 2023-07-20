create table staged_regions as
select r.name, ST_Union(z.geom) as geometry -- union staged_zip_codes
from regions r
join places_regions pr on (pr.region_id = r.id)
join places p on (p.id = pr.place_id)
join staged_zip_codes z on (z.zip = p.name)
where p.category = 'zipcode' and p.country_iso_code = 'US' and r.parent_id = 5
group by r.name;
