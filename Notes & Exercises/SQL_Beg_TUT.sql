select * 
FROM Parks_and_Recreation.employee_demographics;

select first_name
FROM Parks_and_Recreation.employee_demographics;

select first_name, last_name, birth_date
FROM Parks_and_Recreation.employee_demographics;

select first_name, last_name, birth_date, (age+10)*10
FROM Parks_and_Recreation.employee_demographics;


SELECT distinct gender #prints uniques values here
from Parks_and_Recreation.employee_demographics;


# WHERE CLAUSE
select * 
from employee_salary
where first_name ='leslie'
;


# WHERE CLAUSE its like the if in python return the condition
select * 
from employee_salary
where salary >= 50000
;
# logical operator and or not 
select *
from employee_demographics
where birth_date > '1985-01-01'
and gender = 'male'
;

select *
from employee_demographics
where birth_date > '1985-01-01'
or gender = 'male'
;

# like statment using % and _
select *
from employee_demographics
where first_name like 'Jer%' # THIS MEANS ANYTHING AFTER JER WILL BE PRINTED OR %er% any word that has er it will print what is before and after it. 
;

select * 
from employee_demographics
where first_name like 'a%'
;

select * 
from employee_demographics
where first_name like 'a__' # __ a and 2 char after it 
;

select * 
from employee_demographics
where birth_date like '1989%'
;

# aggregate fun AVG, MIN, MAX
#GROUP BY ... ORDER BY ... in the group by the select has to match the group by statment 
select gender
from Parks_and_Recreation.employee_demographics
group by gender
;

# what is this really doing is grouping by gender and getting agg fun avg age on them 
select gender, avg(age), max(age), min(age), count(age)
from Parks_and_Recreation.employee_demographics
group by gender 
;

# order by asc or dec
# VIP note while using order by be carefull about unique values
select *
from Parks_and_Recreation.employee_demographics
order by gender, age 
;

# having clause always comes after the group by the same blocl written by where will give error.
select gender, avg(age)
from employee_demographics
group by gender 
having avg(age)>40
;



select occupation, avg(salary)
from employee_salary
where occupation like '%manager%'
group by occupation
having avg(salary) > 75000
;


select * 
from employee_demographics
order by age desc # desc is big to small
limit 3 # print only 3 rows limit 2,1 means will print the row after row 2
;

-- aliasing 
select gender, avg(age) as avg_age 
from employee_demographics
group by gender
having avg_age > 40
;


# joins: inner joins, outer joins, self joins

select * 
from employee_demographics as dem 
inner join employee_salary as sal
	on dem.employee_id = sal.employee_id
;

select * 
from employee_demographics as dem 
right outer join employee_salary as sal
	on dem.employee_id = sal.employee_id
;# here it will take the right table as main and match it with left table if thers is nothing missing it will be null.


-- self join here is you join the same table on its self means that you want to make operation on the same table.
select emp1.employee_id as emp_santa, 
emp1.first_name as first_name_santa,
emp1.last_name as last_name_santa,

emp2.employee_id as emp_santa, 
emp2.first_name as first_name_santa,
emp2.last_name as last_name_santa

from employee_salary as emp1
join employee_salary as emp2 
	on emp1.employee_id +1 = emp2.employee_id

;

-- joinning multiple tables

select * 
from employee_demographics as dem
inner join employee_salary as sal
	on dem.employee_id = sal.employee_id
inner join parks_departments as pd 
on sal.dept_id = pd.department_id
;


-- union is to merge rows together you have union all that merge the table even with duplicates and union distinct that merge only unique rows
select first_name, last_name 
from employee_demographics
union all
select first_name, last_name 
from employee_salary
;

#example for union
select first_name, last_name , 'old man' as label
from employee_demographics
where age > 40 and gender = 'male'
union 
select first_name, last_name, 'old lady' as label
from employee_demographics
where age > 40 and gender = 'female'
union 
select first_name, last_name, 'highly paid employee' as label 
from employee_salary
where salary > 70000
order by first_name, last_name
;

select first_name, length(first_name)
from employee_demographics
order by 2;

select first_name, upper(first_name) 
from employee_demographics
;

select first_name, lower(first_name) 
from employee_demographics
; 
# TRIM TRIMS THE SPACES LTRIM AND RTRIM ALSO LOOK SUBSTRING/LEFT/RIGHT/ REPLACE / LOCATE

select first_name, last_name,
concat(first_name,' ',last_name) as full_name
from employee_demographics
; 

select first_name, last_name, age,
case 
	when age <= 30 then 'young'
    when age between 31 and 50 then 'old' 
end as age_bracket
from employee_demographics;

-- pay increase and bonus 
-- < 50000 = 5%
-- > 50000 = 7%
-- Finance = 10% bonus 

select first_name, last_name, salary,
case 
	when salary < 50000 then salary + (salary*0.05)
	when salary > 50000 then salary * 1.07

end as new_salary,
case
	when dept_id = 6 then salary *.10
end as bonus
from employee_salary;


-- subqueries 
select * 
from employee_demographics
where employee_id in # the in operand should select only one col
				 (select employee_id 
					from employee_salary
						where dept_id = 1
                 );

select first_name, salary,
(select avg(salary) from employee_salary)
from employee_salary; # you also do subquesries in the from command 


-- window fucntions vip 

# exmple of group by this is not window example....
select gender, avg(salary) as avg_salary
from employee_demographics dem
join employee_salary sal 
	on dem.employee_id = sal.employee_id
group by gender; 

# here is the window
select gender, avg(salary) over()
from employee_demographics dem
join employee_salary sal 
	on dem.employee_id = sal.employee_id
;

# here we have on its individual rows
select dem.first_name, dem.last_name, gender, avg(salary) over(partition by gender)
from employee_demographics dem
join employee_salary sal 
	on dem.employee_id = sal.employee_id
;




select dem.first_name, dem.last_name, gender, salary,
sum(salary) over(partition by gender order by dem.employee_id) as rolling_total
from employee_demographics dem
join employee_salary sal 
	on dem.employee_id = sal.employee_id
;

-- row number, rank, dense rank 
select dem.first_name, dem.last_name, gender, salary,
row_number() over(partition by gender order by salary desc) as row_num,
rank() over(partition by gender order by salary desc) as rank_num,
dense_rank() over(partition by gender order by salary desc) as dense_ranke
from employee_demographics dem
join employee_salary sal 
	on dem.employee_id = sal.employee_id
;



-- ADVANCED MYSQL TUT
-- CTE

-- with CTE_Example (avg_sal) as # you can do this here instead of doing aliasing 
-- (
-- SELECT gender , avg(salary) as avg_sal , max(salary) , min(salary) , count(salary)
-- from employee_demographics dem
-- join employee_salary sal
-- 	on dem.employee_id = sal.employee_id
-- group by gender
-- )
-- select avg(avg_sal)
-- from CTE_Example
-- ;


with CTE_Example as 
(
select employee_id, gender, birth_date
from employee_demographics
where birth_date > '1985-01-01'
),
CTE_Example2 as
(
select employee_id, salary
from employee_salary
where salary > 50000
)
select * 
from CTE_Example
join CTE_Example2
	ON CTE_Example.employee_id = CTE_Example2.employee_id
;

-- Temporary Tables

CREATE TEMPORARY TABLE temp_table
(
    first_name    VARCHAR(50),
    last_name     VARCHAR(50),
    favorite_name VARCHAR(100)
);


insert into temp_table 
values('marco', 'freberg', 'omar and salma');

select *
from temp_table;

create temporary table salary_over_50k
select * 
from employee_salary
where salary >= 50000;

select *
from salary_over_50k;

-- -----------------------------------------------------------

create procedure large_salaries()
select *
from employee_salary
where salary >= 50000;
call large_salaries();

drop procedure if exists 'large_salaries2'
DELIMITER $$
create procedure large_salaries2()
BEGIN
	select *
	from employee_salary
	where salary >= 50000;
	SELECT *
    FROM employee_salary
    where salary >= 10000;
END $$
DELIMITER ;


call large_salaries2 ; 






drop procedure if exists 'large_salaries3'
DELIMITER $$
create procedure large_salaries3(par int)
BEGIN
	select salary
	from employee_salary
    where employee_id = par;
END $$
DELIMITER ;

call large_salaries3(1) ;


-- triggers and events
-- write a trigger when data is updated in salary is to update the demographic

delimiter $$
create trigger employee_insert 
	after insert on employee_salary 
    for each row 
begin
	insert into employee_demographics (employee_id, first_name, last_name)
    values (new.employee_id, new.first_name, new.last_name);
end $$
delimiter ;

insert into employee_salary (employee_id, first_name, last_name, occupation, salary, dept_id)
values(13, 'marco', 'hanna', 'student', 5000000, null);

-- events takes place when its scheduled
delimiter $$
create event delete_retires
on schedule every 30 second
do
begin
	delete 
    from employee_demographic
    where age >= 60;
end $$
delimiter ; 










