# DAX measures

All measures live in the `hotel_bookings` table of `powerbi/Hotel_Analysis.pbix`. The expressions below are copied from the saved model. Each result was checked against the matching SQL query in `sql/02_analysis_queries.sql`.

| Measure | DAX | Result (all data) | SQL check |
|---|---|---|---|
| Total Bookings | `COUNTROWS(hotel_bookings)` | 300 | query 2 |
| Average ADR | `AVERAGE(hotel_bookings[adr])` | 123.73 | query 2 |
| Cancelled Bookings | `CALCULATE(COUNTROWS(hotel_bookings), hotel_bookings[is_canceled] = TRUE())` | 55 | query 4b |
| Cancellation Rate% | `DIVIDE([Cancelled Bookings], [Total Bookings])` | 18.3% | query 2 |
| Total Revenue | `SUMX(hotel_bookings, hotel_bookings[adr] * (hotel_bookings[stays_weekend_nights] + hotel_bookings[stays_week_nights]))` | 118,487.50 | query 2 |
| % of Total Bookings | `DIVIDE([Total Bookings], CALCULATE([Total Bookings], ALL(hotel_bookings[market_segment])))` | per segment, sums to 100% | query 5 |

## Design notes

**`= TRUE()` instead of `= 1`.** `is_canceled` is a `BIT` in SQL Server. Power BI imports it as a True/False column, so a filter written as `= 1` fails. This was found by validating the first version of the card against SQL.

**`SUMX` for revenue.** Revenue is ADR multiplied by nights stayed. That multiplication must happen row by row before adding up, which is what `SUMX` does. `SUM(adr) * SUM(nights)` would give a wrong answer.

**`DIVIDE` instead of `/`.** `DIVIDE` returns blank rather than an error when the denominator is zero, for example when a slicer selection leaves no bookings.

**`ALL(...)` in % of Total Bookings.** `ALL(hotel_bookings[market_segment])` removes the segment filter from the denominator, so each row is divided by the overall total instead of by itself. The SQL equivalent is `SUM(COUNT(*)) OVER ()`.

## Known limitation: Total Revenue includes cancellations

`Total Revenue` adds up every booking, cancelled ones included, so it is **booked revenue**. Revenue on the 55 cancelled bookings is 22,656.29, which is 19.1% of the total. Revenue after removing them is 95,831.21.

A measure that would show the net figure, not yet in the model:

```dax
Net Revenue =
CALCULATE ( [Total Revenue], hotel_bookings[is_canceled] = FALSE () )
```

The revenue card on the Executive Overview is therefore labelled "Booked Revenue". Adding the measure above and showing it on a second card would make the net figure visible too.

## Other limitations

- No date table and no relationships. The model is one flat table, and Power BI's automatic date hierarchy is used for the monthly chart. A dedicated calendar table would be needed for time-intelligence measures such as year-on-year.
- The monthly chart pools 2024 and 2025 into calendar months, so it is not a year-over-year trend.
- 17 bookings have zero nights, so they add to booking counts and ADR but contribute no revenue.
