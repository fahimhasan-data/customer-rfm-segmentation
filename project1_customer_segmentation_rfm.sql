/*
================================================================================
  PROJECT 1 — CUSTOMER SEGMENTATION & RFM ANALYSIS
  Retention Strategy for E-Commerce Revenue Growth
================================================================================

  Author        : MD FAHIM HASAN JALANEY
  Tool          : PostgreSQL 18 (pgAdmin 4) or DBeaver(used it)
  Dataset       : E-Commerce Orders (1,200 records | Jan 2023 – Jun 2025)
  GitHub        : https://github.com/fahimhasan-data
  LinkedIn      : https://www.linkedin.com/in/md-fahim-hasan-jalaney/

--------------------------------------------------------------------------------
  BUSINESS PROBLEM
--------------------------------------------------------------------------------
  The business is treating all 1,189 customers the same — sending identical
  promotions, applying blanket discounts, and running one-size-fits-all
  campaigns. The result:

    → Marketing budget wasted on Lost customers who will never return
    → Champions and Loyal customers not being rewarded or retained
    → At-Risk customers silently drifting away with no intervention
    → No data-driven basis for deciding who to target and how

  Without customer segmentation, every marketing dollar has the same ROI
  regardless of who it's spent on. That is revenue left on the table.

--------------------------------------------------------------------------------
  OBJECTIVE
--------------------------------------------------------------------------------
  Build a full RFM (Recency, Frequency, Monetary) scoring model in PostgreSQL.
  Classify every customer into an actionable segment — Champion, Loyal,
  Potential Loyal, At Risk, or Lost — and deliver a retention strategy
  for each segment backed by real revenue data.

--------------------------------------------------------------------------------
  WHAT IS RFM?
--------------------------------------------------------------------------------
  R — RECENCY   : How recently did the customer place an order?
                  (Fewer days since last order = higher score)
  F — FREQUENCY : How many orders has the customer placed?
                  (More orders = higher score)
  M — MONETARY  : How much total revenue has the customer generated?
                  (Higher spend = higher score)

  Each dimension is scored 1–4. Combined RFM score (3–12) determines segment.

--------------------------------------------------------------------------------
  DATASET COLUMNS USED
--------------------------------------------------------------------------------
  OrderID        — Unique order identifier
  Date           — Order date
  CustomerID     — Unique customer identifier
  Product        — Product purchased
  TotalPrice     — Order value
  OrderStatus    — Delivered, Cancelled, Returned, etc.
  CouponCode     — Discount code used
  ReferralSource — Acquisition channel
  PaymentMethod  — Payment type

--------------------------------------------------------------------------------
  ANALYSIS ROADMAP
--------------------------------------------------------------------------------
  SECTION 0  — Database Setup (reuses table from Project 2)
  SECTION 1  — Data Quality & Customer Overview
  SECTION 2  — RFM Metric Calculation
  SECTION 3  — RFM Scoring (1–4 per dimension)
  SECTION 4  — Customer Segmentation
  SECTION 5  — Segment Revenue & Business Value Analysis
  SECTION 6  — Coupon Effectiveness by Segment
  SECTION 7  — Acquisition Channel by Segment
  SECTION 8  — Repeat Purchase & Retention Analysis
  SECTION 9  — At-Risk Customer Identification (Action List)
  SECTION 10 — Business Decisions & Retention Strategy

================================================================================
*/


/* =============================================================================
   SECTION 0 — DATABASE SETUP
   ============================================================================= */

/*
  ► This project reuses the orders table created in Project 2.
    If running independently, execute the CREATE TABLE and COPY commands
    from project2_revenue_leakage_analysis.sql first, then run this file.

  SET search_path TO ecommerce;
*/

SET search_path TO ecommerce;

-- Reference date for Recency calculation (latest date in dataset)
-- Set as a variable to make the model easy to update
-- In production: replace with CURRENT_DATE
-- \set analysis_date '2025-06-30'


/* =============================================================================
   SECTION 1 — DATA QUALITY & CUSTOMER OVERVIEW
   Business Question: Who are our customers and how active are they?
   ============================================================================= */

-- 1.1  Total customer and order count
SELECT
    COUNT(DISTINCT customerid)    AS uniquecustomers,
    COUNT(orderid)                AS totalorders,
    ROUND(
        COUNT(orderid) * 1.0 /
        COUNT(DISTINCT customerid), 2
    )                             AS avgorderspercustomer,
    MIN(date)                     AS firstorderdate,
    MAX(date)                     AS latestorderdate
FROM ecommerce;

-- 1.2  Repeat vs one-time buyer split
WITH customerorders AS (
    SELECT
        customerid,
        COUNT(orderid) AS totalorders
    FROM ecommerce
    GROUP BY customerid
)
SELECT
    CASE WHEN totalorders = 1 THEN 'One-Time Buyer'
         ELSE 'Repeat Buyer'
    END                                             AS customertype,
    COUNT(*)                                        AS customercount,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pctofcustomers
FROM customerorders
GROUP BY customertype
ORDER BY customercount DESC;

-- 1.3  Customer revenue distribution
WITH customerrevenue AS (
    SELECT
        customerid,
        ROUND(SUM(totalprice), 2) AS lifetimevalue
    FROM ecommerce
    GROUP BY customerid
)
SELECT
    CASE
        WHEN lifetimevalue >= 3000 THEN 'High Value   (>= $3,000)'
        WHEN lifetimevalue >= 1500 THEN 'Mid Value    ($1,500–$2,999)'
        WHEN lifetimevalue >= 500  THEN 'Low Value    ($500–$1,499)'
        ELSE                            'Minimal Value (< $500)'
    END                                             AS valuetier,
    COUNT(*)                                        AS customers,
    ROUND(SUM(lifetimevalue), 2)                    AS totalrevenue,
    ROUND(SUM(lifetimevalue) * 100.0 /
        SUM(SUM(lifetimevalue)) OVER (), 1)         AS pctofrevenue
FROM customerrevenue
GROUP BY valuetier
ORDER BY totalrevenue DESC;


/* =============================================================================
   SECTION 2 — RFM METRIC CALCULATION
   ============================================================================= */

-- 2.1  Calculate raw RFM metrics per customer
CREATE OR REPLACE VIEW rfmbase AS
SELECT
    customerid,
    MAX(date)                                  AS lastorderdate,
    COUNT(orderid)                             AS frequency,
    ROUND(SUM(totalprice), 2)                  AS monetary,
    DATE '2025-06-30' - MAX(date)              AS recencydays
FROM ecommerce
GROUP BY customerid;

-- View the base RFM metrics
SELECT *
FROM rfmbase
ORDER BY monetary DESC
LIMIT 20;

-- 2.2  RFM distribution summary
SELECT
    ROUND(MIN(recencydays), 0)    AS minrecency,
    ROUND(AVG(recencydays), 0)    AS avgrecency,
    ROUND(MAX(recencydays), 0)    AS maxrecency,
    ROUND(MIN(frequency), 0)      AS minfrequency,
    ROUND(AVG(frequency), 2)      AS avgfrequency,
    ROUND(MAX(frequency), 0)      AS maxfrequency,
    ROUND(MIN(monetary), 2)       AS minmonetary,
    ROUND(AVG(monetary), 2)       AS avgmonetary,
    ROUND(MAX(monetary), 2)       AS maxmonetary
FROM rfmbase;


/* =============================================================================
   SECTION 3 — RFM SCORING
   ============================================================================= */

-- 3.1  Score each customer on R, F, M dimensions
CREATE OR REPLACE VIEW rfmscores AS
SELECT
    customerid,
    lastorderdate,
    recencydays,
    frequency,
    monetary,
    5 - NTILE(4) OVER (ORDER BY recencydays ASC) AS rscore,
    NTILE(4) OVER (ORDER BY frequency ASC)        AS fscore,
    NTILE(4) OVER (ORDER BY monetary ASC)         AS mscore
FROM rfmbase;

-- 3.2  View RFM scores with combined total
SELECT
    customerid,
    recencydays,
    frequency,
    ROUND(monetary, 2)            AS monetary,
    rscore,
    fscore,
    mscore,
    (rscore + fscore + mscore)    AS rfmtotalscore
FROM rfmscores
ORDER BY rfmtotalscore DESC
LIMIT 20;

-- 3.3  Score distribution
SELECT
    (rscore + fscore + mscore)    AS rfmtotalscore,
    COUNT(*)                      AS customercount
FROM rfmscores
GROUP BY rfmtotalscore
ORDER BY rfmtotalscore DESC;


/* =============================================================================
   SECTION 4 — CUSTOMER SEGMENTATION
   ============================================================================= */

-- 4.1  Assign segments based on combined RFM score
CREATE OR REPLACE VIEW rfmsegments AS
SELECT
    customerid,
    lastorderdate,
    recencydays,
    frequency,
    monetary,
    rscore,
    fscore,
    mscore,
    (rscore + fscore + mscore) AS rfmtotalscore,
    CASE
        WHEN (rscore + fscore + mscore) >= 10 THEN 'Champion'
        WHEN (rscore + fscore + mscore) >= 8  THEN 'Loyal'
        WHEN (rscore + fscore + mscore) >= 6  THEN 'Potential Loyal'
        WHEN (rscore + fscore + mscore) >= 4  THEN 'At Risk'
        ELSE                                        'Lost'
    END AS segment,
    CASE
        WHEN (rscore + fscore + mscore) >= 10 THEN 'Reward heavily. They are your best customers.'
        WHEN (rscore + fscore + mscore) >= 8  THEN 'Nurture with loyalty program and early access.'
        WHEN (rscore + fscore + mscore) >= 6  THEN 'Engage with personalised offers to convert.'
        WHEN (rscore + fscore + mscore) >= 4  THEN 'Win-back campaign before they go cold.'
        ELSE                                        'Last-chance offer. Accept churn if no response.'
    END AS recommendedaction
FROM rfmscores;

-- 4.2  Full segment overview
SELECT
    segment,
    COUNT(customerid) AS customercount,
    ROUND(COUNT(customerid) * 100.0 /
        SUM(COUNT(customerid)) OVER (), 1) AS pctofcustomers,
    ROUND(AVG(recencydays), 0)             AS avgrecencydays,
    ROUND(AVG(frequency), 2)               AS avgorders,
    ROUND(AVG(monetary), 2)                AS avglifetimevalue,
    ROUND(SUM(monetary), 2)                AS totalsegmentrevenue
FROM rfmsegments
GROUP BY segment
ORDER BY avglifetimevalue DESC;

/* =============================================================================
   SECTION 5 — SEGMENT REVENUE & BUSINESS VALUE ANALYSIS
   ============================================================================= */

-- 5.1  Revenue concentration by segment
SELECT
    segment,
    COUNT(customerid)                                         AS customers,
    ROUND(SUM(monetary), 2)                                   AS totalrevenue,
    ROUND(SUM(monetary) * 100.0 / SUM(SUM(monetary)) OVER (), 1) AS pctoftotalrevenue,
    ROUND(AVG(monetary), 2)                                   AS avgcustomervalue,
    ROUND(MIN(monetary), 2)                                   AS minvalue,
    ROUND(MAX(monetary), 2)                                   AS maxvalue
FROM rfmsegments
GROUP BY segment
ORDER BY totalrevenue DESC;

-- 5.2  Segment value-to-size efficiency ratio
SELECT
    segment,
    COUNT(customerid)                                   AS customers,
    ROUND(SUM(monetary), 2)                             AS totalrevenue,
    ROUND(SUM(monetary) / COUNT(customerid), 2)         AS revenuepercustomer,
    ROUND(
        (SUM(monetary) / COUNT(customerid)) /
        AVG(SUM(monetary) / COUNT(customerid)) OVER (),
        2
    )                                                    AS efficiencyvsavg
FROM rfmsegments
GROUP BY segment
ORDER BY revenuepercustomer DESC;

-- 5.3  Estimated revenue at risk
SELECT
    'At Risk + Lost Customers'      AS scenario,
    COUNT(customerid)               AS customersatrisk,
    ROUND(SUM(monetary), 2)         AS revenueatrisk,
    ROUND(SUM(monetary) * 0.20, 2)  AS recovery20pcttarget,
    ROUND(SUM(monetary) * 0.35, 2)  AS recovery35pcttarget
FROM rfmsegments
WHERE segment IN ('At Risk', 'Lost');


/* =============================================================================
   SECTION 6 — COUPON EFFECTIVENESS BY SEGMENT
   ============================================================================= */

-- 6.1  Coupon usage distribution across segments
SELECT
    s.segment,
    COALESCE(o.couponcode, 'NO COUPON') AS couponcode,
    COUNT(o.orderid)                    AS orderswithcoupon,
    ROUND(SUM(o.totalprice), 2)         AS revenuewithcoupon,
    ROUND(AVG(o.totalprice), 2)         AS avgordervalue
FROM rfmsegments s
JOIN ecommerce o ON s.customerid = o.customerid
GROUP BY s.segment, couponcode
ORDER BY s.segment, orderswithcoupon DESC;

-- 6.2  Which segments use coupons most
SELECT
    s.segment,
    COUNT(o.orderid) AS totalorders,
    SUM(CASE WHEN o.couponcode IS NOT NULL THEN 1 ELSE 0 END) AS couponorders,
    ROUND(
        SUM(CASE WHEN o.couponcode IS NOT NULL THEN 1 ELSE 0 END)
        * 100.0 / COUNT(o.orderid), 1
    ) AS couponusagepct,
    ROUND(AVG(CASE WHEN o.couponcode IS NOT NULL
              THEN o.totalprice END), 2) AS avgcouponordervalue,
    ROUND(AVG(CASE WHEN o.couponcode IS NULL
              THEN o.totalprice END), 2) AS avgnoncouponordervalue
FROM rfmsegments s
JOIN ecommerce o ON s.customerid = o.customerid
GROUP BY s.segment
ORDER BY couponusagepct DESC;

-- 6.3  FREESHIP coupon analysis
SELECT
    s.segment,
    COUNT(CASE WHEN o.couponcode = 'FREESHIP' THEN 1 END) AS freeshiporders,
    COUNT(CASE WHEN o.couponcode = 'FREESHIP'
              AND o.orderstatus = 'Delivered' THEN 1 END) AS freeshipdelivered,
    COUNT(CASE WHEN o.couponcode = 'FREESHIP'
              AND o.orderstatus = 'Returned' THEN 1 END) AS freeshipreturned,
    ROUND(
        COUNT(CASE WHEN o.couponcode = 'FREESHIP'
                  AND o.orderstatus = 'Returned' THEN 1 END)
        * 100.0 / NULLIF(
            COUNT(CASE WHEN o.couponcode = 'FREESHIP' THEN 1 END), 0
        ), 1
    ) AS freeshipreturnratepct
FROM rfmsegments s
JOIN ecommerce o ON s.customerid = o.customerid
GROUP BY s.segment
ORDER BY freeshipreturnratepct DESC NULLS LAST;


/* =============================================================================
   SECTION 7 — ACQUISITION CHANNEL BY SEGMENT
   ============================================================================= */

-- 7.1  Segment distribution by referral source
SELECT
    o.referralsource,
    s.segment,
    COUNT(DISTINCT s.customerid) AS customers
FROM rfmsegments s
JOIN ecommerce o ON s.customerid = o.customerid
GROUP BY o.referralsource, s.segment
ORDER BY o.referralsource, customers DESC;

-- 7.2  Channel quality score
SELECT
    o.referralsource,
    COUNT(DISTINCT s.customerid) AS totalcustomers,
    COUNT(DISTINCT CASE WHEN s.segment IN ('Champion','Loyal')
                        THEN s.customerid END) AS highvaluecustomers,
    ROUND(
        COUNT(DISTINCT CASE WHEN s.segment IN ('Champion','Loyal')
                            THEN s.customerid END)
        * 100.0 / COUNT(DISTINCT s.customerid), 1
    ) AS highvaluepct,
    COUNT(DISTINCT CASE WHEN s.segment IN ('At Risk','Lost')
                        THEN s.customerid END) AS lowqualitycustomers,
    ROUND(
        COUNT(DISTINCT CASE WHEN s.segment IN ('At Risk','Lost')
                            THEN s.customerid END)
        * 100.0 / COUNT(DISTINCT s.customerid), 1
    ) AS lowqualitypct,
    ROUND(AVG(s.monetary), 2) AS avgcustomerltv
FROM rfmsegments s
JOIN ecommerce o ON s.customerid = o.customerid
GROUP BY o.referralsource
ORDER BY highvaluepct DESC;

-- 7.3  Best channel + segment combination
SELECT
    o.referralsource,
    s.segment,
    COUNT(DISTINCT s.customerid) AS customers,
    ROUND(AVG(s.monetary), 2)    AS avglifetimevalue,
    ROUND(SUM(s.monetary), 2)    AS totalrevenue
FROM rfmsegments s
JOIN ecommerce o ON s.customerid = o.customerid
GROUP BY o.referralsource, s.segment
ORDER BY avglifetimevalue DESC
LIMIT 15;


/* =============================================================================
   SECTION 8 — REPEAT PURCHASE & RETENTION ANALYSIS
   ============================================================================= */

-- 8.1  Repeat purchase rate overall
WITH customerordercount AS (
    SELECT
        customerid,
        COUNT(orderid) AS ordercount
    FROM ecommerce
    GROUP BY customerid
)
SELECT
    SUM(CASE WHEN ordercount >= 2 THEN 1 ELSE 0 END) AS repeatbuyers,
    SUM(CASE WHEN ordercount = 1 THEN 1 ELSE 0 END)  AS onetimebuyers,
    COUNT(*)                                          AS totalcustomers,
    ROUND(
        SUM(CASE WHEN ordercount >= 2 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS repeatratepct
FROM customerordercount;

-- 8.2  Days between first and second order
WITH ordersequence AS (
    SELECT
        customerid,
        date,
        ROW_NUMBER() OVER (PARTITION BY customerid ORDER BY date) AS orderrank
    FROM ecommerce
)
SELECT
    firstorder.customerid,
    firstorder.date AS firstorderdate,
    secondorder.date AS secondorderdate,
    secondorder.date - firstorder.date AS daystorepurchase
FROM ordersequence firstorder
JOIN ordersequence secondorder
    ON firstorder.customerid = secondorder.customerid
    AND firstorder.orderrank = 1
    AND secondorder.orderrank = 2
ORDER BY daystorepurchase ASC;

-- 8.3  Recency buckets
SELECT
    CASE
        WHEN recencydays <= 90  THEN '0–90 days   (Active)'
        WHEN recencydays <= 180 THEN '91–180 days (Warm)'
        WHEN recencydays <= 365 THEN '181–365 days (Cooling)'
        WHEN recencydays <= 730 THEN '366–730 days (Cold)'
        ELSE                          '730+ days   (Dormant)'
    END AS recencybucket,
    COUNT(*) AS customers,
    ROUND(AVG(monetary), 2) AS avglifetimevalue,
    ROUND(SUM(monetary), 2) AS totalrevenue,
    ROUND(COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (), 1) AS pctofcustomers
FROM rfmsegments
GROUP BY recencybucket
ORDER BY MIN(recencydays);


/* =============================================================================
   SECTION 9 — AT-RISK CUSTOMER IDENTIFICATION
   ============================================================================= */

-- 9.1  Priority win-back list
SELECT
    customerid,
    lastorderdate,
    recencydays,
    frequency,
    ROUND(monetary, 2) AS lifetimevalue,
    rscore,
    fscore,
    mscore,
    rfmtotalscore,
    segment,
    recommendedaction
FROM rfmsegments
WHERE segment = 'At Risk'
ORDER BY monetary DESC
LIMIT 25;

-- 9.2  Full prioritised retention action list
SELECT
    segment,
    customerid,
    ROUND(monetary, 2) AS lifetimevalue,
    recencydays,
    rfmtotalscore,
    recommendedaction
FROM rfmsegments
WHERE segment IN ('Champion', 'Loyal', 'At Risk')
ORDER BY
    CASE segment
        WHEN 'Champion' THEN 1
        WHEN 'Loyal' THEN 2
        WHEN 'At Risk' THEN 3
    END,
    monetary DESC;

-- 9.3  Segment-level estimated win-back revenue potential
SELECT
    segment,
    COUNT(customerid) AS customers,
    ROUND(SUM(monetary), 2) AS totalltv,
    ROUND(SUM(monetary) * 0.15, 2) AS potentialif15pctretained,
    ROUND(SUM(monetary) * 0.25, 2) AS potentialif25pctretained,
    ROUND(SUM(monetary) * 0.40, 2) AS potentialif40pctretained
FROM rfmsegments
WHERE segment IN ('At Risk', 'Potential Loyal')
GROUP BY segment
ORDER BY totalltv DESC;

/*
  ► INSIGHT:
    Retaining just 15–25% of At Risk customers would recover tens of thousands
    in revenue. The cost of a win-back email campaign is minimal compared
    to this recovery potential. This makes it the highest-ROI marketing
    activity available to the business right now.
*/


/* =============================================================================
   SECTION 10 — BUSINESS DECISIONS & RETENTION STRATEGY
   ============================================================================= */

/*
  ┌─────────────────────────────────────────────────────────────────────────────┐
  │  EXECUTIVE SUMMARY — KEY FINDINGS                                           │
  ├─────────────────────────────────────────────────────────────────────────────┤
  │                                                                             │
  │  Total Customers       :  1,189                                             │
  │  Repeat Purchase Rate  :  0.92%  (industry avg: 20–30%)                    │
  │  One-Time Buyers       :  1,178 out of 1,189 (99.1%)                       │
  │                                                                             │
  │  SEGMENT BREAKDOWN:                                                         │
  │  ─────────────────────────────────────────────────────────────────────────  │
  │  Champion       :    8 customers | Avg LTV $2,160 | Avg 266 days inactive  │
  │  Loyal          :  218 customers | Avg LTV $1,819 | Avg 188 days inactive  │
  │  Potential Loyal:  524 customers | Avg LTV $1,198 | Avg 422 days inactive  │
  │  At Risk        :  370 customers | Avg LTV $565   | Avg 622 days inactive  │
  │  Lost           :   69 customers | Avg LTV $203   | Avg 804 days inactive  │
  │                                                                             │
  └─────────────────────────────────────────────────────────────────────────────┘

  ────────────────────────────────────────────────────────────────────────────
  DECISION 1 — CHAMPION SEGMENT (8 customers)
  ────────────────────────────────────────────────────────────────────────────
  FINDING : Only 8 Champions exist. They have the highest LTV ($2,160 avg)
            but have not ordered in avg 266 days — they are at risk of
            downgrading to Loyal or At Risk silently.

  ACTION  : Create a VIP programme immediately. Offer exclusive early access
            to new products, a dedicated account manager touchpoint, and
            a personalised thank-you with a 10% loyalty reward on next order.
            Contact them within 7 days. Do not let Champions go cold.

  TARGET  : Keep all 8 Champions active. Prevent any downgrade to Loyal.
            One Champion retained = $2,160 protected.

  ────────────────────────────────────────────────────────────────────────────
  DECISION 2 — LOYAL SEGMENT (218 customers)
  ────────────────────────────────────────────────────────────────────────────
  FINDING : 218 Loyal customers averaging $1,819 LTV but only 188 days
            since last order — still within reachable window.

  ACTION  : Launch a loyalty tier programme (Silver/Gold/Platinum).
            Send personalised product recommendations based on past purchases.
            Offer SAVE10 coupon with a spend threshold to encourage
            their next order. Target within 30 days before they shift At Risk.

  TARGET  : Convert 20% of Loyal customers to Champions = 43 new Champions
            = $92,920 incremental revenue at Champion avg LTV.

  ────────────────────────────────────────────────────────────────────────────
  DECISION 3 — POTENTIAL LOYAL SEGMENT (524 customers)
  ────────────────────────────────────────────────────────────────────────────
  FINDING : Largest segment (44% of customers) with decent LTV ($1,198 avg).
            422 day avg recency means they are fading but not gone.
            This is the biggest untapped revenue opportunity.

  ACTION  : Run a personalised reactivation campaign — surface the product
            category they bought previously and pair with a time-limited offer.
            A/B test SAVE10 vs FREESHIP to see which drives higher re-order
            rate in this segment without triggering returns.

  TARGET  : Convert 10% of Potential Loyal to Loyal = 52 customers
            = $94,607 in incremental revenue at Loyal avg LTV.

  ────────────────────────────────────────────────────────────────────────────
  DECISION 4 — AT RISK SEGMENT (370 customers)
  ────────────────────────────────────────────────────────────────────────────
  FINDING : 370 customers, avg LTV $565, avg 622 days since last order.
            Without intervention, most will shift to Lost within 6 months.
            Combined revenue at stake: ~$209,000.

  ACTION  : Deploy a 3-email win-back sequence:
              Email 1 (Day 1)  — "We miss you" + product recommendation
              Email 2 (Day 7)  — WINTER15 exclusive offer with urgency
              Email 3 (Day 14) — Final offer + ask for feedback if no response
            Customers with no response after Day 14 → move to Lost bucket.

  TARGET  : Recover 15% of At Risk customers = 55 customers
            = $31,083 recovered revenue at avg LTV.

  ────────────────────────────────────────────────────────────────────────────
  DECISION 5 — LOST SEGMENT (69 customers)
  ────────────────────────────────────────────────────────────────────────────
  FINDING : 69 customers, avg LTV $203, avg 804 days inactive.
            These customers likely purchased once during a promotion and
            have no product affinity. Recovery cost exceeds expected value.

  ACTION  : Send one final campaign — deep discount (20%) or free gift
            with minimum spend. If no conversion, suppress from marketing
            lists entirely to reduce unsubscribes and spam complaints.
            Redirect the marketing spend to Potential Loyal segment instead.

  TARGET  : Recover 10% of Lost customers (7 customers) = $1,421 recovered.
            Accept 90% churn from this segment. Do not waste budget here.

  ────────────────────────────────────────────────────────────────────────────
  DECISION 6 — COUPON STRATEGY REALIGNMENT
  ────────────────────────────────────────────────────────────────────────────
  FINDING : Coupons are being distributed across all segments indiscriminately.
            FREESHIP has the highest return/abuse rate.

  ACTION  : Restrict coupon eligibility by segment:
              SAVE10    → Loyal + Potential Loyal only
              FREESHIP  → Champions + Loyal only (high LTV, low abuse risk)
              WINTER15  → Potential Loyal only to incentivize upgrade
            Remove all coupons from Lost segment marketing.

  TARGET  : Reduce coupon-related return rate by 15%. Increase coupon-to-
            delivered-order conversion by 20% by targeting right segments.

  ────────────────────────────────────────────────────────────────────────────
  COMBINED REVENUE IMPACT POTENTIAL
  ────────────────────────────────────────────────────────────────────────────
  If all 6 decisions are executed over 2 quarters:

    Champions retained         :  $17,280   (protect existing 8)
    Loyal → Champion upgrades  :  $92,920   (43 conversions)
    Potential Loyal → Loyal    :  $94,607   (52 conversions)
    At Risk win-back           :  $31,083   (55 recoveries)
    ─────────────────────────────────────────────────────
    TOTAL PROJECTED RECOVERY   : ~$235,890

  All of this comes from the existing customer base.
  Zero new customer acquisition cost required.

*/


/* =============================================================================
   END OF PROJECT
   ============================================================================= */