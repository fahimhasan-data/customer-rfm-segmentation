# Customer Segmentation & RFM Analysis
### E-Commerce SQL Project | PostgreSQL

---

## Project Summary

This project segments **1,189 e-commerce customers** into 5 actionable tiers using RFM (Recency, Frequency, Monetary) analysis — identifying a **$235K revenue recovery opportunity** from the existing customer base with zero new acquisition cost.

| | |
|---|---|
| **Tool** | PostgreSQL |
| **Dataset** | 1,200 orders · 1,189 customers · Jan 2023 – Jun 2025 |
| **Approach** | RFM scoring · Customer segmentation · Retention strategy |
| **Business Impact** | $235,900 recovery potential identified |

---

## Key Findings

| Segment | Customers | Avg LTV | Days Inactive | Action |
|---------|-----------|---------|---------------|--------|
| Champions | 8 | $2,160 | 265 | VIP program |
| Loyal | 218 | $1,819 | 188 | Loyalty tier |
| Potential Loyal | 524 | $1,198 | 422 | Reactivation |
| At Risk | 370 | $565 | 622 | Win-back campaign |
| Lost | 69 | $203 | 804 | Accept churn |

**Critical insight:** Only **0.92% repeat purchase rate** (industry benchmark: 20–30%). The business is almost entirely dependent on new customer acquisition — an expensive and unsustainable model.

---

## Files in This Repository

| File | Description |
|------|-------------|
| 📄 [`project1_customer_segmentation_rfm.sql`](./project1_customer_segmentation_rfm.sql) | Full SQL analysis · 818 lines · 10 sections |
| 📊 [`project1_rfm_query_results.pdf`](./project1_rfm_query_results.pdf) | SQL queries with output screenshots |
| 📁 [`ecommerce_orders.csv`](./ecommerce_orders.csv) | Raw dataset used in this analysis |

---

## SQL File — Navigate by Section

Click any section to jump directly to that part of the code:

| Section | Description | Link |
|---------|-------------|------|
| 0 | Database Setup | [Go →](./project1_customer_segmentation_rfm.sql#L81) |
| 1 | Data Quality & Customer Overview | [Go →](./project1_customer_segmentation_rfm.sql#L101) |
| 2 | RFM Metric Calculation | [Go →](./project1_customer_segmentation_rfm.sql#L182) |
| 3 | RFM Scoring (1–4 per dimension) | [Go →](./project1_customer_segmentation_rfm.sql#L226) |
| 4 | Customer Segmentation | [Go →](./project1_customer_segmentation_rfm.sql#L280) |
| 5 | Segment Revenue & Business Value | [Go →](./project1_customer_segmentation_rfm.sql#L337) |
| 6 | Coupon Effectiveness by Segment | [Go →](./project1_customer_segmentation_rfm.sql#L396) |
| 7 | Acquisition Channel by Segment | [Go →](./project1_customer_segmentation_rfm.sql#L468) |
| 8 | Repeat Purchase & Retention | [Go →](./project1_customer_segmentation_rfm.sql#L529) |
| 9 | At-Risk Customer Action List | [Go →](./project1_customer_segmentation_rfm.sql#L615) |
| 10 | Business Decisions & Strategy | [Go →](./project1_customer_segmentation_rfm.sql#L686) |

> **Tip:** Press `Ctrl + F` inside the SQL file to search by section name.

---

## Business Decisions Delivered

1. **VIP Program** for 8 Champions → protect $17,280 in at-risk revenue
2. **Loyalty Tier** for 218 Loyal customers → $92,920 upgrade potential
3. **Reactivation Campaign** for 524 Potential Loyal → $94,607 opportunity
4. **3-Email Win-Back** for 370 At Risk customers → $31,083 recovery
5. **Coupon Strategy** → restrict FREESHIP to Loyal segment only

**Total projected recovery: $235,910 from existing customers**

---

## Dataset

📁 **Source file:** [`ecommerce_orders.csv`](./ecommerce_orders.csv)
- 1,200 orders · 14 columns
- Columns: OrderID, Date, CustomerID, Product, Quantity, UnitPrice, PaymentMethod, OrderStatus, TrackingNumber, ItemsInCart, CouponCode, ReferralSource, TotalPrice

---

## Related Projects

| | Repository | Focus | Impact |
|--|------------|-------|--------|
| ➡️ | [revenue-leakage-analysis](https://github.com/YOUR-USERNAME/revenue-leakage-analysis) | Where is revenue lost? | $70–104K recovery |
| ➡️ | [executive-dashboard](https://github.com/YOUR-USERNAME/executive-dashboard) | Power BI KPI dashboard | Real-time insights |

---

**Author:** [MD FAHIM HASAN JALANEY] · [hasanfahim087@gmail.com] · [LinkedIn](https://www.linkedin.com/in/md-fahim-hasan-jalaney/)
