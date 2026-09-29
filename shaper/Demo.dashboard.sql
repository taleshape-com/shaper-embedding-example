-- shaperid:demo-dashboard

SELECT 'Healthcare Admissions & Distribution Analytics'::SECTION, 'Population health overview, clinical breakdowns, and cost distributions'::SUBTITLE;

CREATE TEMP TABLE raw_admissions AS (
  FROM 'http://taleshape.com/sample-data/healthcare_demo_data.parquet'
);

CREATE TEMP TABLE dataset AS (
  SELECT
    *,
    ("Discharge Date" - "Date of Admission") AS stay_days
  FROM raw_admissions
  WHERE insurance_id = getvariable('insurance_id')
);

SELECT ('healthcare-admissions-' || today())::DOWNLOAD_CSV AS "CSV";
SELECT * FROM dataset;

SELECT count(*) AS "Total Admissions" FROM dataset;

SELECT concat('$', printf('%,d', coalesce(round(sum("Billing Amount"))::BIGINT, 0))) AS "Total Billed" FROM dataset;

SELECT concat(coalesce(round(avg(stay_days), 1), 0), ' days') AS "Avg Length of Stay" FROM dataset;

SELECT concat('$', printf('%,d', coalesce(round(avg("Billing Amount"))::BIGINT, 0))) AS "Avg Billing / Patient" FROM dataset;

SELECT 'Demographic & Clinical Distributions'::SECTION, 'Patient age, condition, and test outcome distributions'::SUBTITLE;

SELECT 'Age Distribution by Gender'::LABEL, 'Patient volume across 10-year age brackets'::SUBTITLE;
SELECT
  concat((floor(Age / 10) * 10)::INT, '-', (floor(Age / 10) * 10 + 9)::INT)::XAXIS AS "Age Group",
  Gender::CATEGORY,
  count(*)::BARCHART_STACKED,
FROM dataset
GROUP BY "Age Group", Gender
ORDER BY "Age Group", Gender;

SELECT 'Test Results Distribution by Condition'::LABEL, 'Proportion of normal, abnormal, and inconclusive outcomes'::SUBTITLE;
SELECT
  "Medical Condition"::XAXIS,
  (count(*)::DOUBLE / sum(count(*)) OVER (PARTITION BY "Medical Condition"))::BARCHART_STACKED_PERCENT,
  "Test Results"::CATEGORY,
FROM dataset
GROUP BY "Medical Condition", "Test Results"
ORDER BY "Medical Condition", "Test Results";

SELECT 'Blood Type Distribution'::LABEL, 'Patient blood type breakdown'::SUBTITLE;
SELECT
  "Blood Type"::CATEGORY,
  count(*)::DONUTCHART,
FROM dataset
GROUP BY "Blood Type"
ORDER BY count(*) DESC;

SELECT 'Cost & Stay Duration Distributions'::SECTION, 'Statistical spread of billing amounts and hospitalization length'::SUBTITLE;

SELECT 'Billing Distribution by Medical Condition'::LABEL, 'Box plot showing median, quartiles, and outliers'::SUBTITLE;
SELECT
  "Medical Condition"::XAXIS,
  BOXPLOT("Billing Amount"),
FROM dataset
GROUP BY "Medical Condition"
ORDER BY "Medical Condition";

SELECT 'Length of Stay Distribution by Urgency'::LABEL, 'Hospitalization days across elective, emergency, and urgent admissions'::SUBTITLE;
SELECT
  "Admission Type"::XAXIS,
  BOXPLOT(stay_days),
FROM dataset
GROUP BY "Admission Type"
ORDER BY "Admission Type";

SELECT 'Admission Trends & Medication Breakdown'::SECTION, 'Historical monthly volume and top prescribed treatments'::SUBTITLE;

SELECT 'Monthly Admission Volume'::LABEL, 'Admissions over time by urgency level'::SUBTITLE;
SELECT
  date_trunc('month', "Date of Admission")::DATE::XAXIS,
  "Admission Type"::CATEGORY,
  count(*)::BARCHART_STACKED,
FROM dataset
GROUP BY 1, 2
ORDER BY 1, 2;

SELECT 'Top Prescribed Medications'::LABEL, 'Frequency of prescribed medications'::SUBTITLE;
SELECT
  Medication::YAXIS,
  count(*)::BARCHART,
FROM dataset
GROUP BY Medication
ORDER BY count(*) DESC;

SELECT 'https://taleshape.com/shaper/docs/dashboard-embedding/'::FOOTER_LINK AS "More: Shaper Embedding Docs";
