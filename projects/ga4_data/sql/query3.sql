-- detailed user table (user-day level)
-- output: event_date, user_pseudo_id, user_segment

WITH
-- 1) date spine for the analysis window
date_spine AS (
  SELECT d AS event_date
  FROM UNNEST(GENERATE_DATE_ARRAY(DATE '2020-11-01', DATE '2021-01-31')) AS d
),

-- 2) read specific events (unbounded by date to allow lookback history for recency)
events_of_interest AS (
  SELECT
    PARSE_DATE('%Y%m%d', e.event_date) AS event_date,
    e.event_name,
    e.user_pseudo_id,
    e.ecommerce.transaction_id AS transaction_id,
    IFNULL(e.ecommerce.purchase_revenue_in_usd, 0) AS transaction_volume,
    IFNULL(e.ecommerce.total_item_quantity, 0) AS total_qty
  FROM `sandbox-2-472920.ga4_obfuscated_sample_ecommerce2.events_*` e
  WHERE e.event_name IN (
    'first_visit', 'purchase', 'page_view',
    'view_item', 'view_promotion',
    'add_to_cart', 'begin_checkout',
    'select_promotion', 'select_item'
  )
),

-- 3) users that appear at least once within the analysis window
users_in_period AS (
  SELECT DISTINCT user_pseudo_id
  FROM events_of_interest
  WHERE event_date BETWEEN DATE '2020-11-01' AND DATE '2021-01-31'
),

-- 4) every user x every date in the window (full grid to ensure daily classification)
user_days AS (
  SELECT u.user_pseudo_id, d.event_date
  FROM users_in_period u
  CROSS JOIN date_spine d
),

-- 5) first visit date per user (overall)
first_visit_per_user AS (
  SELECT user_pseudo_id, MIN(event_date) AS first_visit_date
  FROM events_of_interest
  WHERE event_name = 'first_visit'
  GROUP BY user_pseudo_id
),

-- 6) purchases (overall)
purchases AS (
  SELECT DISTINCT user_pseudo_id, event_date AS purchase_date
  FROM events_of_interest
  WHERE event_name = 'purchase'
),

-- 7) shopping-intent events (overall; used for Engaged Shopper)
shopping_events AS (
  SELECT DISTINCT user_pseudo_id, event_date
  FROM events_of_interest
  WHERE event_name IN (
    'view_item', 'view_promotion',
    'add_to_cart', 'begin_checkout',
    'select_promotion', 'select_item'
  )
),

-- 8) last purchase on/before each user-day
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

-- 9) per-day flags
daily_new AS (
  SELECT fvu.user_pseudo_id, fvu.first_visit_date AS event_date, TRUE AS is_new
  FROM first_visit_per_user fvu
),
daily_shoppers AS (
  SELECT se.user_pseudo_id, se.event_date, TRUE AS shopped_today
  FROM shopping_events se
),
purchases_today AS (
  SELECT user_pseudo_id, purchase_date AS event_date, TRUE AS purchased_today
  FROM purchases
)

-- 10) final classification (precedence: New > Active > Dormant > Lost > Engaged Shopper > Prospect)
SELECT
  ud.event_date,
  ud.user_pseudo_id,
  CASE
    WHEN IFNULL(n.is_new, FALSE) THEN 'New'
    WHEN lppd.last_purchase_date IS NOT NULL
         AND DATE_DIFF(ud.event_date, lppd.last_purchase_date, DAY) <= 30
      THEN 'Active'
    WHEN lppd.last_purchase_date IS NOT NULL
         AND DATE_DIFF(ud.event_date, lppd.last_purchase_date, DAY) BETWEEN 31 AND 60
      THEN 'Dormant'
    WHEN lppd.last_purchase_date IS NOT NULL
         AND DATE_DIFF(ud.event_date, lppd.last_purchase_date, DAY) > 60
      THEN 'Lost'
    WHEN IFNULL(s.shopped_today, FALSE) AND NOT IFNULL(pt.purchased_today, FALSE)
      THEN 'Engaged Shopper'
    ELSE 'Prospect'
  END AS user_segment
FROM user_days ud
LEFT JOIN daily_new n
  ON n.user_pseudo_id = ud.user_pseudo_id AND n.event_date = ud.event_date
LEFT JOIN last_purchase_per_day lppd
  ON lppd.user_pseudo_id = ud.user_pseudo_id AND lppd.event_date = ud.event_date
LEFT JOIN daily_shoppers s
  ON s.user_pseudo_id = ud.user_pseudo_id AND s.event_date = ud.event_date
LEFT JOIN purchases_today pt
  ON pt.user_pseudo_id = ud.user_pseudo_id AND pt.event_date = ud.event_date
ORDER BY 1, 2;
