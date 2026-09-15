/* ==============================================================================
   EXPLORATORY DATA ANALYSIS (EDA): WORLD LAYOFFS DATASET
   
   Objectives:
   1. Assess baseline summary metrics and extreme values (outliers/shutdowns)
   2. Aggregate layoffs across dimensions: Company, Industry, Country, Stage, and Year
   3. Calculate cumulative metrics using Time-Series Window Functions (Rolling Totals)
   4. Construct multi-CTE ranking models to determine the Top 5 companies per year
   ============================================================================== */


-- ==============================================================================
-- 1. BASELINE DISTRIBUTIONS & OUTLIERS
-- ==============================================================================

-- 1.1 Initial inspection of cleaned staging table
SELECT *
FROM layoffs_staging2;

-- 1.2 Identify maximum layoff volume and percentage
SELECT MAX(total_laid_off) AS max_laid_off, 
       MAX(percentage_laid_off) AS max_percentage_laid_off
FROM layoffs_staging2;

-- 1.3 Total shutdowns: 100% workforce reduction (percentage_laid_off = 1)
-- Ordered by capital raised to reveal the largest funded failures
SELECT *
FROM layoffs_staging2
WHERE percentage_laid_off = 1
ORDER BY funds_raised_millions DESC;


-- ==============================================================================
-- 2. DIMENSIONAL AGGREGATIONS
-- ==============================================================================

-- 2.1 Layoff volume by Company (Top impacted organizations overall)
SELECT company, 
       SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
GROUP BY company
ORDER BY total_laid_off DESC;

-- 2.2 Layoff volume by Industry
SELECT industry, 
       SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
GROUP BY industry
ORDER BY total_laid_off DESC;

-- 2.3 Layoff volume by Country
SELECT country, 
       SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
GROUP BY country
ORDER BY total_laid_off DESC;

-- 2.4 Annual layoff volume trend
SELECT YEAR(`date`) AS layoff_year, 
       SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
WHERE `date` IS NOT NULL
GROUP BY YEAR(`date`)
ORDER BY layoff_year DESC;

-- 2.5 Layoff volume by Company Funding Stage (e.g., Seed, Series B, Post-IPO)
SELECT stage, 
       SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
GROUP BY stage
ORDER BY total_laid_off DESC;


-- ==============================================================================
-- 3. TIME-SERIES ANALYSIS: MONTHLY & ROLLING TOTALS
-- ==============================================================================

-- 3.1 Monthly layoff volume (YYYY-MM string slicing)
SELECT SUBSTRING(`date`, 1, 7) AS layoff_month, 
       SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
WHERE SUBSTRING(`date`, 1, 7) IS NOT NULL
GROUP BY layoff_month
ORDER BY layoff_month ASC;

-- 3.2 Running / Cumulative Total across months using a CTE and Window Function
WITH monthly_layoffs AS (
    SELECT SUBSTRING(`date`, 1, 7) AS layoff_month, 
           SUM(total_laid_off) AS total_off
    FROM layoffs_staging2
    WHERE SUBSTRING(`date`, 1, 7) IS NOT NULL
    GROUP BY layoff_month
)
SELECT layoff_month, 
       total_off,
       SUM(total_off) OVER (ORDER BY layoff_month ASC) AS rolling_total
FROM monthly_layoffs
ORDER BY layoff_month ASC;


-- ==============================================================================
-- 4. MULTI-LEVEL RANKING: TOP 5 COMPANIES PER YEAR
-- ==============================================================================

-- 4.1 Company layoffs broken down by Year
SELECT company, 
       YEAR(`date`) AS layoff_year, 
       SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
WHERE `date` IS NOT NULL
GROUP BY company, YEAR(`date`)
ORDER BY total_laid_off DESC;

-- 4.2 Chained CTE: Rank top 5 companies with most layoffs per calendar year
-- CTE 1: Aggregate total layoffs per company per year
WITH company_year (company, years, total_laid_off) AS (
    SELECT company, 
           YEAR(`date`), 
           SUM(total_laid_off)
    FROM layoffs_staging2
    WHERE `date` IS NOT NULL
    GROUP BY company, YEAR(`date`)
), 
-- CTE 2: Apply DENSE_RANK partitioned by year and ordered by total layoffs
company_year_rank AS (
    SELECT company, 
           years, 
           total_laid_off,
           DENSE_RANK() OVER (PARTITION BY years ORDER BY total_laid_off DESC) AS ranking
    FROM company_year
)
-- Filter out only the top 5 per partition
SELECT company, 
       years AS layoff_year, 
       total_laid_off, 
       ranking
FROM company_year_rank
WHERE ranking <= 5
ORDER BY layoff_year ASC, ranking ASC;