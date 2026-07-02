# Holiday-Proximity Demand Tagger 

What it does: Pulls the 2024 India public-holiday calendar from the Nager
Date API, tags every booking whose check-in date falls within ±2 days of a
holiday, and compares booking value, length of stay, and cancellation rate
for holiday-adjacent vs. ordinary bookings.

How to run: `pip install pandas requests`, place `hotel_bookings.csv`
in the same folder as `holiday_demand_tagger.py`, then run
`python holiday_demand_tagger.py`.

Design decision: A successful-but-empty API response is treated as a
failure and triggers the fallback path, not just network/HTTP errors —
Nager Date can return `200 OK` with `[]` for countries it doesn't fully
cover, and India is one of them at the time of writing (its own coverage
page lists Europe/Antarctica as "fully supported" and everything else as
"varying"). Silently treating that as "zero holidays" would have quietly
produced a wrong answer instead of a loud one.

Limitation: The ±2-day window treats every holiday equally, but a
Monday holiday (creating a long weekend for working professionals) and a
mid-week holiday (which doesn't) likely drive very different traveller
behavior — this script doesn't distinguish between them.
