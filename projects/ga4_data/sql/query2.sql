WITH
-- read specific events (extended version with engagement events)
events_of_interest AS (
  SELECT
    PARSE_DATE('%Y%m%d', e.event_date) AS event_date,
    e.event_name,
    e.user_pseudo_id,
    e.ecommerce.transaction_id AS transaction_id,
    IFNULL(
      e.ecommerce.purchase_revenue_in_usd,
      0
    ) AS transaction_volume,
    IFNULL(e.ecommerce.total_item_quantity, 0) AS total_qty
  FROM `sandbox-2-472920.ga4_obfuscated_sample_ecommerce2.events_*` e
  WHERE e.event_name IN ('first_visit', 'purchase', 'page_view',
    'view_item', 'view_promotion',
    'add_to_cart', 'begin_checkout',
    'select_promotion', 'select_item')
),

-- first visits
first_visits AS (
  SELECT DISTINCT user_pseudo_id, event_date
  FROM events_of_interest
  WHERE event_name = 'first_visit'
),

-- purchases
purchases AS (
  SELECT DISTINCT user_pseudo_id, event_date AS purchase_date
  FROM events_of_interest
  WHERE event_name = 'purchase'
),

-- page views + days
page_view_days AS (
  SELECT DISTINCT user_pseudo_id, event_date
  FROM events_of_interest
  WHERE event_name = 'page_view'
),

-- shopping-intent events (but not necessarily purchased)
shopping_events AS (
  SELECT DISTINCT user_pseudo_id, event_date
  FROM events_of_interest
  WHERE event_name IN (
    'view_item', 'view_promotion',
    'add_to_cart', 'begin_checkout',
    'select_promotion', 'select_item'
  )
),

-- users + days
user_days AS (
  SELECT user_pseudo_id, event_date FROM first_visits
  UNION DISTINCT
  SELECT user_pseudo_id, purchase_date AS event_date FROM purchases
  UNION DISTINCT
  SELECT user_pseudo_id, event_date FROM page_view_days
  UNION DISTINCT
  SELECT user_pseudo_id, event_date FROM shopping_events
),

-- last purchase on each day
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

-- mark "New" customers
daily_new AS (
  SELECT fv.user_pseudo_id, fv.event_date, TRUE AS is_new
  FROM first_visits fv
),

-- mark shopping-intent customers
daily_shoppers AS (
  SELECT se.user_pseudo_id, se.event_date, TRUE AS shopped_today
  FROM shopping_events se
),

-- mark purchase-today flag (for same-day conversion suppression)
purchases_today AS (
  SELECT user_pseudo_id, purchase_date AS event_date, TRUE AS purchased_today
  FROM purchases
),

-- final classification (precedence: New > Active > Dormant > Lost > Engaged_Shopper > Prospect)
final AS (
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
  ON pt.user_pseudo_id = ud.user_pseudo_id AND pt.event_date = ud.event_date)

SELECT event_date, user_segment, COUNT(DISTINCT user_pseudo_id) AS users
FROM final
GROUP BY 1,2
