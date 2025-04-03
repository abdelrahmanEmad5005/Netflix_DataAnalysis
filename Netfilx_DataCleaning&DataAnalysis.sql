----------------------------------------------------------------DATA CLEANING----------------------------------------------------------------
--change the size of the MAX to a sutable size to save storage 
ALTER TABLE netflix_titles ALTER COLUMN show_id VARCHAR(10);
ALTER TABLE netflix_titles ALTER COLUMN type VARCHAR(10);
ALTER TABLE netflix_titles ALTER COLUMN title NVARCHAR(200);  -- Convert from VARCHAR to NVARCHAR for foreign characters
ALTER TABLE netflix_titles ALTER COLUMN director VARCHAR(250);
ALTER TABLE netflix_titles ALTER COLUMN cast VARCHAR(1000);
ALTER TABLE netflix_titles ALTER COLUMN country VARCHAR(150);  
ALTER TABLE netflix_titles ALTER COLUMN date_added VARCHAR(20);
ALTER TABLE netflix_titles ALTER COLUMN release_year INT;
ALTER TABLE netflix_titles ALTER COLUMN rating VARCHAR(10);
ALTER TABLE netflix_titles ALTER COLUMN duration VARCHAR(10);
ALTER TABLE netflix_titles ALTER COLUMN listed_in VARCHAR(1000);
ALTER TABLE netflix_titles ALTER COLUMN description VARCHAR(500);

--make sure
select * 
from netflix_titles
where show_id = 's5023'-- title col. write a foregin characters correctly

---------------------------------------------------------------------------------

-- set a primary key for the table
select show_id, count(*) 
from netflix_titles
group by show_id
having count(*)>1
-- no results apper so i will make it as a primary key
-- first modify show_id to NOT NULL
ALTER TABLE netflix_titles 
ALTER COLUMN show_id VARCHAR(10) NOT NULL
-- then add the Primary Key constraint
ALTER TABLE netflix_titles 
ADD CONSTRAINT pk_show_id PRIMARY KEY (show_id)

---------------------------------------------------------------------------------

--remove duplicates rows
--find if there is a duplicates or not 
select *
from netflix_titles
where concat(upper(title),type) in
	(
		select concat(upper(title),type)
		from netflix_titles
		group by upper(title), type
		having count(*) > 1
	)
order by title
--display data witout duplicates
WITH CTE AS (
    SELECT *, 
           ROW_NUMBER() OVER (PARTITION BY title, type ORDER BY show_id) AS rn
    FROM netflix_titles
)
select * 
from cte 
where rn = 1

---------------------------------------------------------------------------------

--new tables for listed_in, director, cast, country
select show_id , trim(value) as director
into netflix_directors
from netflix_titles
cross apply string_split(director,',')

select show_id , trim(value) as Genre
into netflix_Genre
from netflix_titles
cross apply string_split(listed_in,',')

select show_id , trim(value) as cast
into netflix_cast
from netflix_titles
cross apply string_split(cast,',')

select show_id , trim(value) as country
into netflix_country
from netflix_titles
cross apply string_split(country,',')

---------------------------------------------------------------------------------

--treate with null values
insert into netflix_country
select show_id, m.country
from netflix_titles nt
inner join
	(
	select country , director
	from netflix_country nc 
	inner join 
	netflix_directors nd
	on nd.show_id = nc.show_id
	group by director , country
	) m
on nt.director = m.director
where nt.country is null

---------------------------------------------------------------------------------

select * from netflix_titles where duration is null
--clean table 
WITH CTE AS (
    SELECT *, 
           ROW_NUMBER() OVER (PARTITION BY title, type ORDER BY show_id) AS rn
    FROM netflix_titles
)select show_id, type, title, cast(date_added as date) as date_added, release_year, 
		rating, case when duration is null then rating else duration end as duration, description
into netflix
from cte

----------------------------------------------------------------DATA ANALYSIS----------------------------------------------------------------

-- for each director count the number of movies and tv shows created by them for each director who have created both
select nd.director , 
       (count(distinct case when n.type = 'movie' then n.show_id end)) as no_of_movies ,
	   (count(distinct case when n.type = 'TV show' then n.show_id end)) as no_of_tvshows
from netflix n
inner join 
netflix_directors nd
on n.show_id = nd.show_id
group by nd.director
having count(distinct n.type) > 1

-- which top 5 countries have highest number of comedy movies
select top 5 nc.country, count(distinct ng.show_id) as num_of_movies
from netflix n
inner join netflix_country nc
on n.show_id = nc.show_id
inner join netflix_Genre ng
on n.show_id = ng.show_id
where n.type = 'movie' and ng.Genre = 'Comedies'
group by nc.country
order by num_of_movies desc

-- for each year which director has maximum nmber of movies released
with cte as (select nd.director , year(n.date_added) as date_year , count(distinct n.show_id) as num_of_movies 
     		 from netflix n 
			 inner join netflix_directors nd
			 on n.show_id = nd.show_id
			 where n.type = 'movie'
			 group by nd.director , year(n.date_added)
			 ) ,
cte2 as (select *,
			  dense_rank() over(partition by date_year order by num_of_movies desc) as drn
		      from cte) 
select * 
from cte2 
where drn = 1
 
 --what is the average duration of movies in each genre
 select ng.Genre , avg(cast(left(n.duration, PATINDEX('%[^0-9]%', n.duration) - 1) AS INT)) as average_duration
 from netflix n
 inner join netflix_Genre ng
 on n.show_id = ng.show_id
 where n.type = 'movie'
 group by ng.Genre
order by average_duration desc

--find the list of directors who have created horror and comedy movies both and the number of movies
select nd.director , 
	   count(distinct case when ng.Genre = 'Comedies' then ng.show_id end) num_of_Comedies,
	   count(distinct case when ng.Genre = 'Horror Movies' then ng.show_id end) num_of_Horror
from netflix n
inner join netflix_directors nd
on n.show_id = nd.show_id
inner join netflix_Genre ng
on n.show_id = ng.show_id
where n.type = 'movie' and ng.Genre in ('Comedies' , 'Horror Movies')
group by nd.director
having count(distinct ng.Genre) = 2
