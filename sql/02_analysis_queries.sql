/* =====================================================================
   Horizon Hotel Group | Revenue & Booking Performance
   File:    02_analysis_queries.sql
   Purpose: Exploratory and validation queries on hotel_bookings.
            Each result is mirrored by a Power BI visual or measure.
   Engine:  SQL Server (T-SQL). Run ONE query at a time in SSMS:
            highlight it, then press F5.
   Data:    300 synthetic bookings. See README for the data note.
   Run first: 01_setup_hotel_bookings.sql
   ===================================================================== */

USE HotelAnalytics;
GO


/* ---------------------------------------------------------------------
   1. DATA CHECK
   Look at the table before analysing it.
   --------------------------------------------------------------------- */

-- 1a. First 10 rows
SELECT TOP 10 *
FROM hotel_bookings;

-- 1b. Row count and date range (expect 300 rows, 2024-01-03 to 2025-12-26)
SELECT
    COUNT(*)          AS total_rows,
    MIN(arrival_date) AS first_arrival,
    MAX(arrival_date) AS last_arrival
FROM hotel_bookings;


/* ---------------------------------------------------------------------
   2. HEADLINE KPIs
   Mirrors the four cards on the Executive Overview page.
   Power BI measures: Total Bookings, Average ADR, Cancellation Rate%,
   Total Revenue.
   Total revenue = ADR x number of nights, summed over all bookings.
   --------------------------------------------------------------------- */
SELECT
    COUNT(*)                                                           AS total_bookings,
    CAST(AVG(adr) AS DECIMAL(10,2))                                    AS average_adr,
    CAST(AVG(CASE WHEN is_canceled = 1 THEN 1.0 ELSE 0.0 END) * 100
         AS DECIMAL(5,1))                                              AS cancellation_rate_pct,
    CAST(SUM(adr * (stays_weekend_nights + stays_week_nights))
         AS DECIMAL(12,2))                                             AS total_revenue
FROM hotel_bookings;
-- Expected: 300 | 123.73 | 18.3 | 118487.50

-- 2b. Booked revenue vs revenue that is actually kept
--     The Total Revenue measure above counts EVERY booking, including the
--     cancelled ones, so it is booked revenue. Net revenue removes cancellations.
SELECT
    CAST(SUM(adr * (stays_weekend_nights + stays_week_nights))
         AS DECIMAL(12,2))                                             AS booked_revenue,
    CAST(SUM(CASE WHEN is_canceled = 0
                  THEN adr * (stays_weekend_nights + stays_week_nights)
                  ELSE 0 END) AS DECIMAL(12,2))                        AS net_revenue,
    CAST(SUM(CASE WHEN is_canceled = 1
                  THEN adr * (stays_weekend_nights + stays_week_nights)
                  ELSE 0 END) AS DECIMAL(12,2))                        AS revenue_on_cancelled
FROM hotel_bookings;
-- Expected: 118487.50 | 95831.21 | 22656.29  (19.1% of booked revenue was cancelled)


/* ---------------------------------------------------------------------
   3. RATE AND VOLUME
   --------------------------------------------------------------------- */

-- 3a. Average ADR and bookings by hotel
SELECT
    hotel,
    CAST(AVG(adr) AS DECIMAL(10,2)) AS avg_adr,
    COUNT(*)                        AS total_bookings
FROM hotel_bookings
GROUP BY hotel;
-- Expected: City Hotel 109.81 (183) | Resort Hotel 145.49 (117)

-- 3b. Average ADR and bookings by market segment, highest rate first
--     Mirrors the "Average ADR by Market Segment" bar chart.
SELECT
    market_segment,
    CAST(AVG(adr) AS DECIMAL(10,2)) AS avg_adr,
    COUNT(*)                        AS total_bookings
FROM hotel_bookings
GROUP BY market_segment
ORDER BY avg_adr DESC;
-- Expected: Direct 150.01 (52) | Online TA 126.56 (133) | Offline TA/TO 123.15 (45)
--           Corporate 112.74 (39) | Groups 98.93 (23) | Complementary 33.91 (8)


/* ---------------------------------------------------------------------
   4. CANCELLATION RISK
   is_canceled is a BIT column. SQL Server cannot AVG() a BIT directly,
   so it is converted first. (Power BI has the same type issue: BIT
   arrives as True/False, which is why the DAX filter uses = TRUE().)
   --------------------------------------------------------------------- */

-- 4a. By hotel, Method A: CAST the BIT to a number, then SUM and AVG
SELECT
    hotel,
    COUNT(*)                                        AS total_bookings,
    SUM(CAST(is_canceled AS INT))                   AS cancelled_count,
    AVG(CAST(is_canceled AS FLOAT)) * 100           AS cancellation_rate_pct
FROM hotel_bookings
GROUP BY hotel;

-- 4b. By hotel, Method B: CASE WHEN (same answer, more explicit, rounded)
--     Preferred style for the rest of this file.
SELECT
    hotel,
    COUNT(*)                                                        AS total_bookings,
    SUM(CASE WHEN is_canceled = 1 THEN 1 ELSE 0 END)                AS cancelled_count,
    CAST(AVG(CASE WHEN is_canceled = 1 THEN 1.0 ELSE 0.0 END) * 100
         AS DECIMAL(5,1))                                           AS cancellation_rate_pct
FROM hotel_bookings
GROUP BY hotel;
-- Expected: Resort Hotel 26 of 117 = 22.2 | City Hotel 29 of 183 = 15.8

-- 4c. By market segment, highest risk first
SELECT
    market_segment,
    COUNT(*)                                                        AS total_bookings,
    SUM(CASE WHEN is_canceled = 1 THEN 1 ELSE 0 END)                AS cancelled_count,
    CAST(AVG(CASE WHEN is_canceled = 1 THEN 1.0 ELSE 0.0 END) * 100
         AS DECIMAL(5,1))                                           AS cancellation_rate_pct
FROM hotel_bookings
GROUP BY market_segment
ORDER BY cancellation_rate_pct DESC;
-- Expected: Groups 34.8 (23) | Complementary 25.0 (8) | Online TA 21.1 (133)
--           Corporate 15.4 (39) | Direct 13.5 (52) | Offline TA/TO 8.9 (45)
-- Caution:  Groups and Complementary are small samples (23 and 8 bookings).

-- 4d. By deposit type, highest risk first
--     Mirrors the "Cancellation Rate by Deposit Type" bar chart.
SELECT
    deposit_type,
    COUNT(*)                                                        AS total_bookings,
    SUM(CASE WHEN is_canceled = 1 THEN 1 ELSE 0 END)                AS cancelled_count,
    CAST(AVG(CASE WHEN is_canceled = 1 THEN 1.0 ELSE 0.0 END) * 100
         AS DECIMAL(5,1))                                           AS cancellation_rate_pct
FROM hotel_bookings
GROUP BY deposit_type
ORDER BY cancellation_rate_pct DESC;
-- Expected: Refundable 28.6 (14) | No Deposit 21.3 (230) | Non Refund 3.6 (56)
-- Caution:  Refundable rests on 14 bookings. This pattern was built into the
--           synthetic data, so it is not a finding about real hotels.


/* ---------------------------------------------------------------------
   5. SEGMENT SCORECARD
   One query that mirrors the segment tables in Power BI:
   volume, share of all bookings, ADR and cancellation rate.
   pct_of_bookings uses a window function. Power BI equivalent:
   % of Total Bookings = DIVIDE([Total Bookings],
                          CALCULATE([Total Bookings], ALL(hotel_bookings[market_segment])))
   --------------------------------------------------------------------- */
SELECT
    market_segment,
    COUNT(*)                                                        AS total_bookings,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2))  AS pct_of_bookings,
    CAST(AVG(adr) AS DECIMAL(10,2))                                 AS avg_adr,
    CAST(AVG(CASE WHEN is_canceled = 1 THEN 1.0 ELSE 0.0 END) * 100
         AS DECIMAL(5,1))                                           AS cancellation_rate_pct
FROM hotel_bookings
GROUP BY market_segment
ORDER BY total_bookings DESC;
-- Expected share: Online TA 44.33 | Direct 17.33 | Offline TA/TO 15.00
--                 Corporate 13.00 | Groups 7.67 | Complementary 2.67


/* ---------------------------------------------------------------------
   6. BOOKINGS BY MONTH
   Mirrors the monthly line chart. Months are pooled across 2024 and 2025,
   so this shows volume by calendar month, not a year-on-year trend.
   --------------------------------------------------------------------- */
SELECT
    MONTH(arrival_date) AS month_number,
    COUNT(*)            AS bookings
FROM hotel_bookings
GROUP BY MONTH(arrival_date)
ORDER BY month_number;
-- Expected Jan to Dec: 26, 27, 32, 20, 31, 20, 33, 20, 21, 26, 28, 16
-- Caution:  The month-to-month swings are random noise in synthetic data,
--           not seasonality.
