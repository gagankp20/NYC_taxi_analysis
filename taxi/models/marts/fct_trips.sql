with trips as (
    select * from {{ ref('stg_yellow_trips') }}
)

select
    row_number() over (order by pickup_at) as trip_id,
    pickup_date   as date_key,
    pulocationid  as pickup_zone_id,
    dolocationid  as dropoff_zone_id,
    ratecodeid    as rate_code_id,
    payment_type  as payment_type_id,
    vendorid      as vendor_id,
    pickup_at,
    dropoff_at,
    pickup_hour,
    store_and_fwd_flag,
    passenger_count,
    trip_distance,
    trip_duration_min,
    fare_amount,
    tip_amount,
    tolls_amount,
    total_amount,
    tip_pct
from trips