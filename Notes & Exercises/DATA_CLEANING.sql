
-- data cleaning project
select *
from layoffs;

-- 1. remove duplicates
-- 2. standardize data
-- 3. null values or blank vlaues
-- 4. remove any col 

create table layoffs_stagging
like layoffs;

select *
from layoffs_stagging;

insert layoffs_stagging
select * 
from layoffs;

-- identify duplicates

-- ROW_NUMBER() : Simply counts rows one by one (e.g., 1, 2, 3...) in the order they appear.
-- OVER(PARTITION BY ...) : This tells the function how to group the rows before numbering them. 
-- It splits the data into "partitions" (groups) based on matching values in these columns: company, industry, total_laid_off, 
-- percentage_laid_off, and 'date' (which is likely meant to be a column named "date"—the single 
-- quotes might be a way to handle it if "date" is a reserved word in your database, or it could be a typo; 
-- if it's truly a string 'date', it wouldn't affect grouping since it's constant). 
-- For each unique combination of those values, it restarts the numbering at 1. 
-- This is often used to spot duplicates (e.g., if row_num > 1 in a group, those are extra copies of the same data).
# if row_num has 2 means there is duplicates


with duplicates_cte as 
(
select *,
row_number() over(partition by company, location, industry, 
total_laid_off, percentage_laid_off, 'date', stage, country, funds_raised_millions) as row_num
from layoffs_stagging
)

select * 
from duplicates_cte
where row_num > 1 ;

select * 
from layoffs_stagging
where company = 'casper' ;


-- in data standarization its crucial to have uniques values and dont have two with the same meaning 


select *
from layoffs_stagging;

-- date formatting in mysql 
select `date`,
STR_To_DATE(`date`, '%m/%d/%Y')
from layoffs_stagging;

update layoffs_stagging
set `date` = STR_To_DATE(`date`, '%m/%d/%Y');


alter table layoffs_stagging
modify column `date` date;


-- hadling nulls

select * 
from layoffs_stagging
where industry is null
or industry = '';

select * 
from layoffs_stagging where company = 'airbnb' ; 

select t1.industry , t2.industry
from layoffs_stagging t1 
join layoffs_stagging t2 
	on t1.company = t2.company
where (t1.industry is null or t1.industry = '')
and t2.industry is not null 
;

update layoffs_stagging
set industry = null
where industry = ''
;

update layoffs_stagging t1
join layoffs_stagging t2 
	on t1.company = t2.company
set t1.industry = t2.industry
where (t1.industry is null or t1.industry = '')
and t2.industry is not null ; 

-- sometimes its empty and null in the table map to another before doing filling empty cells

select * 
from layoffs_stagging
where total_laid_off is null
and percentage_laid_off is null ;

delete 
from layoffs_stagging
where total_laid_off is null
and percentage_laid_off is null ;

select company, trim(company)
from layoffs_stagging;

update layoffs_stagging
set company = trim(company);


