with spine as (
    select dateadd(day, seq4(), date '2024-01-01') as full_date
    from table(generator(rowcount => 366))
)

select
    full_date,
    year(full_date)                       as year,
    month(full_date)                      as month,
    monthname(full_date)                  as month_name,
    day(full_date)                        as day_of_month,
    dayname(full_date)                    as day_name,
    (dayname(full_date) in ('Sat','Sun')) as is_weekend,
    weekofyear(full_date)                 as week_of_year,
    quarter(full_date)                    as quarter
from spine
where full_date < date '2025-01-01'