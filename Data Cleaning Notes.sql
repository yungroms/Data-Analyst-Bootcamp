/* ==============================================================================
   DATA CLEANING PIPELINE: WORLD LAYOFFS DATASET
   
   Core Objectives:
   1. Create isolated staging environments to preserve raw production data
   2. Detect and remove duplicate records using Window Functions (`ROW_NUMBER()`)
   3. Standardize and normalize values (whitespace trimming, category grouping, trailing characters)
   4. Convert string date formats to relational `DATE` data types
   5. Impute missing/blank data using self-joins based on shared entity keys
   6. Remove unusable entries (unimputable double-nulls) and helper columns
   ============================================================================== */


-- ==============================================================================
-- PHASE 1: STAGING ENVIRONMENT CREATION
-- ==============================================================================

-- 1.1 Inspect original raw records
SELECT *
FROM world_layoffs.layoffs;

-- 1.2 Create first staging table with identical schema structure (no data copied yet)
CREATE TABLE layoffs_staging
LIKE layoffs;

-- 1.3 Populate the staging table with all raw data
INSERT INTO layoffs_staging
SELECT *
FROM layoffs;

SELECT *
FROM layoffs_staging;


-- ==============================================================================
-- PHASE 2: DUPLICATE DETECTION & REMOVAL
-- ==============================================================================

-- 2.1 Initial duplicate check across primary business keys
SELECT *,
       ROW_NUMBER() OVER(
           PARTITION BY company, industry, total_laid_off, percentage_laid_off, `date`
       ) AS row_num
FROM layoffs_staging;

-- 2.2 Precise duplicate identification partitioned across ALL table attributes
WITH duplicate_cte AS (
    SELECT *,
           ROW_NUMBER() OVER(
               PARTITION BY company, location, industry, total_laid_off, 
                            percentage_laid_off, `date`, stage, country, 
                            funds_raised_millions
           ) AS row_num
    FROM layoffs_staging
)
SELECT *
FROM duplicate_cte
WHERE row_num > 1;

-- 2.3 Create second staging table (`layoffs_staging2`) containing an explicit `row_num` column
-- Note: MySQL does not permit direct deletion from an updatable CTE referencing window functions
CREATE TABLE `layoffs_staging2` (
    `company` text,
    `location` text,
    `industry` text,
    `total_laid_off` int DEFAULT NULL,
    `percentage_laid_off` text,
    `date` text,
    `stage` text,
    `country` text,
    `funds_raised_millions` int DEFAULT NULL,
    `row_num` int
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 2.4 Populate `layoffs_staging2` with computed row numbers
INSERT INTO layoffs_staging2
SELECT *,
       ROW_NUMBER() OVER(
           PARTITION BY company, location, industry, total_laid_off, 
                        percentage_laid_off, `date`, stage, country, 
                        funds_raised_millions
       ) AS row_num
FROM layoffs_staging;

-- 2.5 Verify identified duplicates before physical deletion
SELECT *
FROM layoffs_staging2
WHERE row_num > 1;

-- 2.6 Delete duplicate rows (Temporarily disabling safe updates mode for non-indexed key deletion)
SET SQL_SAFE_UPDATES = 0;

DELETE FROM layoffs_staging2
WHERE row_num > 1;

SET SQL_SAFE_UPDATES = 1;

-- Verify all duplicate rows (row_num > 1) have been purged
SELECT *
FROM layoffs_staging2
WHERE row_num > 1;


-- ==============================================================================
-- PHASE 3: STANDARDIZING & NORMALIZING DATA
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 3.1 Trimming Whitespace from Company Names
-- ------------------------------------------------------------------------------
SELECT company, TRIM(company)
FROM layoffs_staging2;

UPDATE layoffs_staging2
SET company = TRIM(company);

-- ------------------------------------------------------------------------------
-- 3.2 Standardizing Industry Labels (Grouping 'Crypto', 'Crypto Currency', etc.)
-- ------------------------------------------------------------------------------
SELECT DISTINCT industry
FROM layoffs_staging2
ORDER BY 1;

-- Inspect all variations of Crypto-related industries
SELECT *
FROM layoffs_staging2
WHERE industry LIKE 'Crypto%';

-- Unify all variants under the single category 'Crypto'
UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

-- ------------------------------------------------------------------------------
-- 3.3 Cleaning Country Names (Removing Trailing Periods)
-- ------------------------------------------------------------------------------
SELECT DISTINCT country
FROM layoffs_staging2
ORDER BY 1;

-- Isolate instances with trailing punctuation (e.g., 'United States.')
SELECT DISTINCT country, TRIM(TRAILING '.' FROM country)
FROM layoffs_staging2
WHERE country LIKE 'United States%';

-- Remove trailing periods
UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';

-- ------------------------------------------------------------------------------
-- 3.4 Parsing String Dates to Proper SQL DATE Format
-- ------------------------------------------------------------------------------
-- Test string-to-date conversion pattern (%m/%d/%Y)
SELECT `date`,
       STR_TO_DATE(`date`, '%m/%d/%Y')
FROM layoffs_staging2;

-- Standardize string values into SQL ISO date format (YYYY-MM-DD)
UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

-- Alter the physical schema: change column data type from TEXT to DATE
ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;


-- ==============================================================================
-- PHASE 4: HANDLING NULL & BLANK VALUES (IMPUTATION)
-- ==============================================================================

-- 4.1 Convert empty string representations ('') in `industry` to true SQL NULLs
-- This ensures all missing data is uniformly identified by `IS NULL`
UPDATE layoffs_staging2
SET industry = NULL
WHERE industry = '';

-- Inspect rows still containing NULL values in `industry`
SELECT *
FROM layoffs_staging2
WHERE industry IS NULL;

-- 4.2 Validate cross-row consistency for companies with known and missing industries (e.g., Airbnb)
SELECT *
FROM layoffs_staging2
WHERE company = 'Airbnb';

-- 4.3 Self-Join: Match blank rows (t1) with populated rows (t2) belonging to the same company
SELECT t1.company, t1.industry AS missing_ind, t2.industry AS source_ind
FROM layoffs_staging2 t1
JOIN layoffs_staging2 t2
    ON t1.company = t2.company
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;

-- 4.4 Impute missing industries using the matched populated records
UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2
    ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;

-- Inspect companies where industry could not be imputed (e.g., Bally's only has 1 record)
SELECT *
FROM layoffs_staging2
WHERE industry IS NULL;


-- ==============================================================================
-- PHASE 5: REMOVING UNUSABLE RECORDS & INTERMEDIATE COLUMNS
-- ==============================================================================

-- 5.1 Identify rows with missing critical metrics across both layoff measures
-- If both total_laid_off and percentage_laid_off are NULL, the record has no analytical utility
SELECT *
FROM layoffs_staging2
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;

-- Purge these unimputable records
DELETE FROM layoffs_staging2
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;

-- 5.2 Drop the temporary helper column used for deduplication
ALTER TABLE layoffs_staging2
DROP COLUMN row_num;

-- Final inspection of the cleaned dataset
SELECT *
FROM layoffs_staging2;