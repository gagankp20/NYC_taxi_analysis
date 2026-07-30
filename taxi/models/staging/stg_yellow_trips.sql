with source as (
    select * from {{ source('raw', 'yellow_trips') }}
),

cleaned as (
    select
        vendorid,
        ratecodeid,
        payment_type,
        pulocationid,
        dolocationid,
        store_and_fwd_flag,
        tpep_pickup_datetime          as pickup_at,
        tpep_dropoff_datetime         as dropoff_at,
        date(tpep_pickup_datetime)    as pickup_date,
        hour(tpep_pickup_datetime)    as pickup_hour,
        dayname(tpep_pickup_datetime) as pickup_dow,
        nullif(passenger_count, 0)    as passenger_count,
        trip_distance,
        datediff('second', tpep_pickup_datetime, tpep_dropoff_datetime) / 60.0 as trip_duration_min,
        fare_amount,
        tip_amount,
        tolls_amount,
        total_amount,
        round(tip_amount / nullif(fare_amount, 0) * 100, 2) as tip_pct
    from source
    where trip_distance > 0
      and fare_amount  >= 0
      and total_amount >= 0
      and tpep_dropoff_datetime > tpep_pickup_datetime
      and tpep_pickup_datetime >= '2024-01-01'
      and tpep_pickup_datetime <  '2025-01-01'
)

select * from cleaned