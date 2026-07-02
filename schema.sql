-- =====================================================================
-- SET B — Section 3: Normalized Schema
-- Denormalized source: hotel_bookings.csv (12,000 rows, 28 columns)
-- =====================================================================

CREATE TABLE customers (
    customer_id            INTEGER PRIMARY KEY,
    customer_name           VARCHAR(100) NOT NULL,
    customer_segment         VARCHAR(20)  NOT NULL,
    customer_signup_date      DATE        NOT NULL,
    customer_home_city         VARCHAR(50) NOT NULL,
    customer_loyalty_tier       VARCHAR(20) NOT NULL
        CHECK (customer_loyalty_tier IN ('None','Silver','Gold','Platinum'))
        -- Footnote 7: 'None' is a real tier VALUE here, not SQL NULL.
);

CREATE TABLE properties (
    property_id           INTEGER PRIMARY KEY,
    property_name          VARCHAR(100) NOT NULL,
    property_city            VARCHAR(50) NOT NULL,
    property_star_rating      INTEGER     NOT NULL CHECK (property_star_rating BETWEEN 1 AND 5),
    property_type               VARCHAR(20) NOT NULL,
    property_total_rooms          INTEGER     NOT NULL CHECK (property_total_rooms > 0)
    -- Footnote 4: property_name is intentionally NOT unique/indexed as an identifier.
    -- A handful of names repeat across different cities with different property_ids.
    -- Always join/group on property_id, never on property_name.
);

CREATE TABLE bookings (
    booking_id            INTEGER PRIMARY KEY,
    customer_id             INTEGER NOT NULL REFERENCES customers(customer_id),
    property_id               INTEGER NOT NULL REFERENCES properties(property_id),
    booking_date                DATE    NOT NULL,
    checkin_date                  DATE    NOT NULL,
    checkout_date                  DATE    NOT NULL,
    room_type                        VARCHAR(20) NOT NULL,
    num_rooms                          INTEGER NOT NULL CHECK (num_rooms >= 0),
    nights                                INTEGER NOT NULL CHECK (nights > 0),
    booking_channel                        VARCHAR(30) NOT NULL,
    adr                                      DECIMAL(10,2) NOT NULL,
    discount_amount                            DECIMAL(10,2) NOT NULL DEFAULT 0,
    coupon_code                                  VARCHAR(20) NOT NULL DEFAULT '',
    total_amount                                   DECIMAL(12,2) NOT NULL,
    payment_method                                   VARCHAR(20) NOT NULL,
    booking_status                                     VARCHAR(20) NOT NULL
        CHECK (booking_status IN ('Completed','Cancelled','No-Show')),
    -- Footnote 1: invalid stays (checkout <= checkin) are rejected at write time.
    CHECK (checkout_date > checkin_date)
);

CREATE TABLE reviews (
    review_id             INTEGER PRIMARY KEY AUTOINCREMENT,
    booking_id              INTEGER NOT NULL UNIQUE REFERENCES bookings(booking_id),
    review_rating             DECIMAL(3,1) NOT NULL,
    review_date                 DATE NOT NULL
    -- Footnote 5: reviews table only ever holds one row per booking, and a
    -- foreign key to bookings means a review can only exist if a booking row
    -- exists; application/ETL layer additionally rejects inserts where the
    -- referenced booking's booking_status = 'Cancelled' (SQLite CHECK cannot
    -- reference another table directly, so this is enforced via a trigger,
    -- see below).
    -- Footnote 6: raw scale is 1-5 for Individual/Group, 1-10 for Corporate.
    -- Normalize at query time by joining to customers.customer_segment.
);

-- Enforces Footnote 5 (no reviews on Cancelled bookings) across tables.
CREATE TRIGGER trg_no_review_on_cancelled
BEFORE INSERT ON reviews
FOR EACH ROW
WHEN (SELECT booking_status FROM bookings WHERE booking_id = NEW.booking_id) = 'Cancelled'
BEGIN
    SELECT RAISE(ABORT, 'Cannot attach a review to a Cancelled booking (Footnote 5)');
END;

-- ---------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------
-- bookings.checkin_date: every monthly/date-range rollup (B-Q2's monthly
-- revenue trend, and any "bookings in period X" query) filters or groups on
-- this column; without an index it forces a full table scan each time.
CREATE INDEX idx_bookings_checkin_date ON bookings(checkin_date);

-- bookings.property_id: the join key for every property-level rollup
-- (B-Q1 groups room types within property_type via a join to properties),
-- and the FK is not auto-indexed by SQLite.
CREATE INDEX idx_bookings_property_id ON bookings(property_id);
