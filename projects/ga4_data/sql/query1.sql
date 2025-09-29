-- this is a query for segmentation analysis
-- output columns: event_date, user_segment, users
-- this query is only intended for trend analysis (aggregated user count over time)
-- for user-level data designed for reverse ETL, please check <query3.sql>

WITH
-- read only specific events that we need
events_of_interest AS (
  SELECT
    PARSE_DATE('%Y%m%d', e.event_date) AS event_date,
    e.event_name,
    e.user_pseudo_id,
    e.ecommerce.transaction_id AS transaction_id,
    IFNULL(
      e.ecommerce.purchase_revenue_in_usd,
      0
    ) AS transaction_volume
  FROM `sandbox-2-472920.ga4_obfuscated_sample_ecommerce2.events_*` e
  WHERE e.event_name IN ('first_visit', 'purchase', 'page_view')
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

-- users + days to classify
user_days AS (
  SELECT user_pseudo_id, event_date FROM first_visits
  UNION DISTINCT
  SELECT user_pseudo_id, purchase_date AS event_date FROM purchases
  UNION DISTINCT
  SELECT user_pseudo_id, event_date FROM page_view_days
),

-- last purchase on each day
last_purchase_per_day AS (
  SELECT
    ud.user_pseudo_id,
    ud.event_date,
    MAX(p.purchase_date) AS last_purchase_date
  FROM user_days ud
  LEFT JOIN purchases p ON p.user_pseudo_id = ud.user_pseudo_id AND p.purchase_date <= ud.event_date
  GROUP BY ud.user_pseudo_id, ud.event_date
),

-- mark "New" customers
daily_new AS (
  SELECT fv.user_pseudo_id, fv.event_date, TRUE AS is_new
  FROM first_visits fv
),

-- final classification
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
    ELSE 'Prospect' -- never purchased & not new (let's label as 'Prospect')
  END AS user_segment
FROM user_days ud
LEFT JOIN daily_new n
  ON n.user_pseudo_id = ud.user_pseudo_id AND n.event_date = ud.event_date
LEFT JOIN last_purchase_per_day lppd
  ON lppd.user_pseudo_id = ud.user_pseudo_id AND lppd.event_date = ud.event_date
)

SELECT event_date, user_segment, COUNT(DISTINCT user_pseudo_id) AS users
FROM final
GROUP BY 1,2