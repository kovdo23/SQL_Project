-- Data Cleaning

select *
from layoffs;

-- 1. Remove Duplicates
-- 2. Standardized the Data
-- 3. No values or blank values
-- 4. Remove Any Columns


create table layoffs_staging
like layoffs;


select *
from layoffs_staging;

insert layoffs_staging
select *
from layoffs;


-- 1. Remove duplicates
select *,
row_number() over(partition by
company, industry, total_laid_off, percentage_laid_off, 'date') as row_num
from layoffs_staging;

with duplicate_cte as 
(
select *,
row_number() over(partition by
company, location, 
industry, total_laid_off, percentage_laid_off, 'date',
stage, country, funds_raised_millions) as row_num
from layoffs_staging
)
select *
from duplicate_cte
where row_num > 1;

-- for checking
select *
from layoffs_staging
where company = 'Casper';


with duplicate_cte as 
(
select *,
row_number() over(partition by
company, location, 
industry, total_laid_off, percentage_laid_off, 'date',
stage, country, funds_raised_millions) as row_num
from layoffs_staging
)
delete
from duplicate_cte
where row_num > 1;


CREATE TABLE `layoffs_staging2` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
  `row_num` INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

select *
from layoffs_staging2
where row_num > 1;

insert into layoffs_staging2
select *,
row_number() over(partition by
company, location, 
industry, total_laid_off, percentage_laid_off, 'date',
stage, country, funds_raised_millions) as row_num
from layoffs_staging;



delete
from layoffs_staging2
where row_num > 1;


-- Standardizing data

select company, trim(company)
from layoffs_staging2;

Update layoffs_staging2
SET company = trim(company);


select industry
from layoffs_staging2
order by 1;

select *
from layoffs_staging2
where industry like 'Crypto%';

-- Crypto something needs to be Crypto as well
update layoffs_staging2
set industry = 'Crypto'
where industry like 'Crypto%';

-- trim the dot behind the countries
select distinct country, trim(trailing '.' from country)
from layoffs_staging
order by 1;

update layoffs_staging2
set country = trim(trailing '.' from country)
where country like 'United States%';

select *
from layoffs_staging2;

-- making 'date' format to date from text
select `date`,
str_to_date(`date`, '%m/%d/%Y')
from layoffs_staging2;

update layoffs_staging2
set date = str_to_date(`date`, '%m/%d/%Y');

select `date`
from layoffs_staging2;

-- This needs also, but only on staging table (never or raw table)
alter table layoffs_staging2
modify column `date` date;

select*
from layoffs_staging2;



-- 3. No values or blank values

-- is null != = null
select *
from layoffs_staging2
where total_laid_off is null
and percentage_laid_off is null;

-- This needs because null is more certain than ''
update layoffs_staging2
set industry = null 
where industry = '';

select *
from layoffs_staging2
where industry is null
or industry = ''
;

select *
from layoffs_staging2
where company like 'Bally%';

select t1.industry, t2.industry
from layoffs_staging2 t1
join layoffs_staging2 t2
	on t1.company = t2.company
    and t1.location = t2.location
where (t1.industry is null or t1.industry = '')
and t2.industry is not null;

update layoffs_staging2 t1
join layoffs_staging2 t2
	on t1.company = t2.company
set t1.industry = t2.industry
where (t1.industry is null or t1.industry = '')
and t2.industry is not null
;



-- 4. Remove Any Columns


select *
from layoffs_staging2;

alter table layoffs_staging2
drop column row_num;


