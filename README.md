# Hotel-Bookings-Revenue-Discount-Analysis
End-to-end data project: cleaned and normalized a 12,000-row denormalized booking export, rebuilt it as a proper relational schema, and used SQL + Python to find and size a real margin leak in the OTA booking channel — with a concrete, low-risk recommendation to fix it.

Business Problem

The company had one flat hotel_bookings.csv (28 columns, no referential integrity) as its only source of truth for bookings, customers, and properties. Nobody could confidently answer:


Is our reported revenue and booking data trustworthy?
Which booking channel is costing us the most in discounts, and why?
Are the coupons we issue actually earning their keep?


What I Did

1. Data quality audit & cleaning (analysis.ipynb, Section 1)
Screened all 12,000 records and found 397 problem rows across five categories:

IssueRowsInvalid stays (checkout ≤ check-in)120Bookings dated before customer signup163Zero-room bookings60Property names duplicated across cities4Cancelled bookings carrying a review50

Also caught a silent encoding bug: "no coupon" was stored two different ways ('' and 'NONE'), which would have understated real coupon usage by ~50% in any naive GROUP BY.

2. Normalized database design (schema.sql)
Split the flat file into customers, properties, bookings, and reviews with foreign keys, check constraints, and a trigger that blocks reviews from ever attaching to a cancelled booking — enforcing data integrity at write time instead of relying on downstream cleanup. Added targeted indexes on bookings.checkin_date and bookings.property_id, the two columns every rollup query filters or joins on.

3. Analytical SQL (queries.sql)


Ranked top-performing room type per property type using DENSE_RANK() (chosen deliberately over ROW_NUMBER()/RANK() so ties aren't silently hidden or gaps introduced if the query is later extended to "top N").
Built a monthly revenue trend with a running cumulative total for 2024, confirming ₹292,196,106.23 in full-year realized revenue.


4. Case study: discount leakage (analysis.ipynb, Section 2)


Measured discount intensity per channel and found OTA at 7.30%, nearly 2 points above the 5.32% platform average.
Checked whether that gap was just customer mix (OTA does skew toward individual travelers) — mix explains part of it, but not all.
Tested whether OTA coupons actually work: coupon and non-coupon bookings cancel at statistically indistinguishable rates (21.8% vs 22.1%), but coupon bookings bring in 13.1% less revenue per room. The coupons weren't changing behavior — they were a discount on sales that would have happened anyway.


5. Recommendation with guardrails
Proposed a 10% cut to OTA coupon discounts, restricted to first-time customers, with a defined leading indicator (completed bookings over the first 60 days) and an explicit rollback trigger (>5% drop vs. baseline) so the change can be reversed before it does damage.

Business Impact


Data integrity fixed at the schema level, not just patched in one analysis — the trigger and constraints prevent the 397-row class of errors from recurring, so every future report built on this schema starts clean.
Quantified a specific margin leak: OTA coupon spend of ₹9,639,385.67 identified as largely non-performing.
Sized a concrete recovery: 10% reduction in OTA discounting recovers an estimated ₹963,938.57 in margin, with a rollback threshold that caps downside risk if bookings volume reacts negatively.
Gave the team a repeatable query layer (indexed schema + parameterized SQL) instead of one-off spreadsheet analysis, so this kind of channel/discount audit can be rerun in minutes going forward.


Repo Contents

FileDescriptionschema.sqlNormalized table definitions, constraints, trigger, indexesqueries.sqlRanking and cumulative-revenue analytical queriesanalysis.ipynbFull data cleaning + case study notebook (pandas/matplotlib)answers.docxFormatted write-up of all findings, tables, and charts

Stack

Python (pandas, matplotlib) for cleaning and exploration · SQLite-dialect SQL (window functions, CTEs, triggers) for the analytical layer.
