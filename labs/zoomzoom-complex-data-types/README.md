# ZoomZoom SQL Lab 7

This ALY6420 lab uses PostgreSQL to analyze nested ZoomZoom sales records and customer email data. It covers JSONB extraction, array membership, expansion with `unnest()`, and aggregation with `jsonb_each()`.

## Run the lab

Open [the SQL script](Timer_Senarith_ALY6420_Lab7.sql) in DBeaver or DataGrip, connect to a PostgreSQL database with the [ZoomZoom dataset](https://github.com/PacktPublishing/SQL-for-Data-Analytics-Fourth-Edition/tree/main/Datasets) loaded in the `public` schema, and run the labeled sections in order. The four-product reference examples can also be run independently.

The final sections include a measured Neon execution plan and a query correction. The corrected example gives average maximum speeds of 42.5 kph for EV Scooter and 31 kph for Cargo.
