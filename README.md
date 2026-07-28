# NYC Taxi Analytics Platform on Snowflake

An end-to-end data platform built on Snowflake using ~40M NYC yellow-taxi trips (2024), from raw ingestion through a governed, performance-tuned star schema, finished with an interactive Power BI dashboard on a live Snowflake connection. Cost controls were built in from day one — the **entire build cost ~3.59 credits (<1% of the free trial)**.

> **Data source:** [NYC TLC Trip Record Data](https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page) (public, free) — yellow-taxi Parquet files + the taxi-zone lookup CSV.

---

## Dashboard

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/b49085f2-6a7c-4b7c-86f2-cc23c0f83dbd" />


*Interactive Power BI report: KPI cards, monthly trend, daily trips with a 30-day forecast, tip rate by payment type, revenue by borough (drill-down to zone), and trips by hour — with Borough / Month / Payment slicers.*

---

## Architecture

```
NYC TLC files (Parquet + CSV)
        |  COPY INTO  (stages, file formats)
        v
   RAW    ── yellow_trips  (as-loaded, ~40M rows)
        |  clean + derive  (justified filters, trip duration, tip %)
        v
 STAGING  ── trips_clean
        |  dimensional modeling (star schema)
        v
  MARTS   ── fct_trips  +  dim_date / dim_zone / dim_rate_code / dim_payment_type / dim_vendor
        |  pre-aggregate for BI
        v
  Reporting tables  ── bi_trip_summary / bi_daily_trips / bi_zone_revenue
        |
        v
   Power BI (live connection)   ·   (next: Airflow orchestration)
```

Layered "medallion" design: **raw** (untouched source) → **staging** (cleaned) → **marts** (star schema) → **reporting** (pre-aggregated for BI).

---

## Repo contents

| Path | Phase | What it does |
|------|-------|--------------|
| `sql/00_setup.sql` | 0 | Warehouses, resource monitor (spend cap), databases/schemas, RBAC roles |
| `sql/01_load_data.sql` | 1 | File format + stage + `COPY INTO` (with timestamp transform) |
| `sql/02_staging.sql` | 2 | Profile raw data, then clean into `staging.trips_clean` |
| `sql/03_models.sql` | 2 | Star schema: 5 dimensions + `fct_trips` |
| `sql/04_governance.sql` | 3 | Dynamic data masking, row-access policy, Time Travel, zero-copy cloning |
| `sql/05_performance.sql` | 4 | Scale to ~40M rows, clustering, Search Optimization, cost analysis |
| `sql/06_reporting.sql` | 5 | Pre-aggregated BI tables (`bi_trip_summary`, `bi_daily_trips`, `bi_zone_revenue`) |
| `powerbi/` | 5 | Power BI report + dashboard screenshot |
| `LEARNINGS.md` | — | Plain-English notes on every concept (the "why" behind each step) |

---

## Highlights

- **Star schema** over ~40M trips: `fct_trips` (measures + keys) surrounded by 5 dimension tables.
- **Governance:** RBAC, column-level masking, row-access policies (role → borough mapping), Time Travel, zero-copy cloning.
- **Performance:** clustering cut a benchmark query from **32/32 → 2/44 partitions and 155 MB → 15 MB scanned (~90% less)**, validated in the Query Profile; Search Optimization for point lookups (44 → 1 partition).
- **Cost governance:** resource monitor + XS auto-suspending warehouses + `ACCOUNT_USAGE` analysis. **Whole build ~3.59 credits.**
- **BI:** interactive Power BI dashboard on a live Snowflake connection — forecast, DAX measures, slicers, and borough→zone drill-down, powered by pre-aggregated reporting tables.

---

## Key engineering decisions

- **Pre-aggregate for BI:** rather than importing 38M rows into Power BI, small summary tables (~7k / ~366 / ~260 rows) are built in Snowflake and imported — fast loads, snappy interactions.
- **Explicit timestamp handling:** Parquet stored times as microseconds; a `TO_TIMESTAMP_NTZ(..., 6)` transform on load prevents mis-scaled dates.
- **`IF NOT EXISTS` for stages/formats:** so re-running setup never wipes uploaded files.

---

## How to run

1. A Snowflake account (Enterprise edition recommended for masking / search optimization).
2. Run the SQL files in order: `00 → 01 → 02 → 03 → 04 → 05 → 06`.
3. For loading steps, download the NYC TLC files (links in `01` / `05`), upload to the internal stages, and run the `COPY INTO` commands.
4. Open the Power BI report and point the Snowflake connection at your account.

## Tech

Snowflake · SQL · Parquet · dimensional modeling · RBAC & data governance · query tuning · cost management · Power BI · DAX. Airflow orchestration.


