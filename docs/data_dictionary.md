# Data dictionary: `hotel_bookings`

300 synthetic booking records, one row per booking. Arrival dates run from 2024-01-03 to 2025-12-26. The data was generated for this portfolio project and follows the column structure of public hotel-booking datasets. It contains no real guests or hotels.

| Column | SQL type | Meaning | Values |
|---|---|---|---|
| booking_id | INT (primary key) | Unique booking number | 1 to 300 |
| hotel | VARCHAR(20) | Property | City Hotel, Resort Hotel |
| arrival_date | DATE | Date the guest arrives | 2024-01-03 to 2025-12-26 |
| lead_time | INT | Days between booking and arrival | |
| stays_weekend_nights | INT | Weekend nights booked | |
| stays_week_nights | INT | Weekday nights booked | |
| adults | INT | Adults in the booking | |
| children | INT | Children in the booking | |
| country | VARCHAR(10) | Guest country, 3-letter code | 10 countries |
| market_segment | VARCHAR(20) | Where the booking came from | Direct, Online TA, Offline TA/TO, Corporate, Groups, Complementary |
| distribution_channel | VARCHAR(20) | Distribution channel | Direct, Corporate, GDS, TA/TO |
| customer_type | VARCHAR(20) | Booking type | Transient, Transient-Party, Contract, Group |
| deposit_type | VARCHAR(20) | Deposit terms | No Deposit, Non Refund, Refundable |
| adr | DECIMAL(10,2) | Average daily rate (price per night) | |
| is_canceled | BIT | 1 if the booking was cancelled, 0 if the guest stayed | |
| total_of_special_requests | INT | Number of special requests | |

TA/TO = travel agent / tour operator. ADR = average daily rate.
