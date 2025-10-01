-- segmentation trend query (daily aggregates)
-- output: event_date, user_segment, users

WITH
-- 1) date spine for the analysis window
date_spine AS (
  SELECT d AS event_date
  FROM UNNEST(GENERATE_DATE_ARRAY(DATE '2020-11-01', DATE '2021-01-31')) AS d
),

-- 2) read only specific events that we need (do NOT restrict by date here,
--    so last purchase "history" can precede the window if present)
events_of_interest AS (
  SELECT
    PARSE_DATE('%Y%m%d', e.event_date) AS event_date,
    e.event_name,
    e.user_pseudo_id,
    e.ecommerce.transaction_id AS transaction_id,
    IFNULL(e.ecommerce.purchase_revenue_in_usd, 0) AS transaction_volume
  FROM `sandbox-2-472920.ga4_obfuscated_sample_ecommerce2.events_*` e
  WHERE e.event_name IN ('first_visit', 'purchase', 'page_view')
),

-- 3) users that appear at least once within the analysis window
users_in_period AS (
  SELECT DISTINCT user_pseudo_id
  FROM events_of_interest
  WHERE event_date BETWEEN DATE '2020-11-01' AND DATE '2021-01-31'
),

-- 4) every user x every date in the window
user_days AS (
  SELECT u.user_pseudo_id, d.event_date
  FROM users_in_period u
  CROSS JOIN date_spine d
),

-- 5) first visit date per user (first occurrence overall)
first_visit_per_user AS (
  SELECT user_pseudo_id, MIN(event_date) AS first_visit_date
  FROM events_of_interest
  WHERE event_name = 'first_visit'
  GROUP BY user_pseudo_id
),

-- 6) all purchase dates per user (overall)
purchases AS (
  SELECT DISTINCT user_pseudo_id, event_date AS purchase_date
  FROM events_of_interest
  WHERE event_name = 'purchase'
),

-- 7) last purchase on/before each user-day
last_purchase_per_day AS (
  SELECT
    ud.user_pseudo_id,
    ud.event_date,
    MAX(p.purchase_date) AS last_purchase_date
  FROM user_days ud
  LEFT JOIN purchases p
    ON p.user_pseudo_id = ud.user_pseudo_id
   AND p.purchase_date <= ud.event_date
  GROUP BY ud.user_pseudo_id, ud.event_date
),

-- 8) classify each user-day
final AS (
  SELECT
    ud.event_date,
    ud.user_pseudo_id,
    CASE
      WHEN fvu.first_visit_date = ud.event_date THEN 'New'
      WHEN lppd.last_purchase_date IS NOT NULL
           AND DATE_DIFF(ud.event_date, lppd.last_purchase_date, DAY) <= 30
        THEN 'Active'
      WHEN lppd.last_purchase_date IS NOT NULL
           AND DATE_DIFF(ud.event_date, lppd.last_purchase_date, DAY) BETWEEN 31 AND 60
        THEN 'Dormant'
      WHEN lppd.last_purchase_date IS NOT NULL
           AND DATE_DIFF(ud.event_date, lppd.last_purchase_date, DAY) > 60
        THEN 'Lost'
      ELSE 'Prospect'  -- never purchased & not new
    END AS user_segment
  FROM user_days ud
  LEFT JOIN first_visit_per_user fvu
    ON fvu.user_pseudo_id = ud.user_pseudo_id
  LEFT JOIN last_purchase_per_day lppd
    ON lppd.user_pseudo_id = ud.user_pseudo_id
   AND lppd.event_date = ud.event_date
)

-- 9) aggregate for trend analysis
SELECT
  event_date,
  user_segment,
  COUNT(DISTINCT user_pseudo_id) AS users
FROM final
GROUP BY 1, 2
ORDER BY 1, 2;
