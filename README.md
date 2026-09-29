# World Layoffs – Adattisztítás és Adatelemzés MySQL Segítségével

Ebben a projektben egy globális, tech szektorbeli leépítéseket tartalmazó adathalmazon (`layoffs`) végeztem el teljes körű **adattisztítást (Data Cleaning)** és **feltáró adatelemzést (Exploratory Data Analysis - EDA)** **MySQL** segítségével. 

A projekt célja az volt, hogy a nyers, formázatlan, hiányos és duplikált adatokat átalakítsam egy konzisztens, megbízható táblává, majd haladó SQL technikákkal (pl. CTE-k, ablakfüggvények, gördülő aggregációk) elemezzem a leépítési trendeket vállalatok, iparágak és évek szerint.

---

## 🏗️ 1. Rész: Adattisztítás (Data Cleaning in MySQL)

A nyers adatokat sosem közvetlenül módosítottam; létrehoztam egy köztes munkafelszínt (`layoffs_staging`, majd `layoffs_staging2`), és ezen végeztem el a négy fő tisztítási fázist:

### 1. Duplikációk azonosítása és eltávolítása (Remove Duplicates)
* Mivel a táblában nem volt egyedi kulcs (Primary Key), a `ROW_NUMBER()` ablakfüggvényt használtam `PARTITION BY` záradékkal a rekordok összes releváns oszlopa mentén:
  ```sql
  ROW_NUMBER() OVER(
    PARTITION BY company, location, industry, total_laid_off, 
                 percentage_laid_off, `date`, stage, country, funds_raised_millions
  ) AS row_num
  ```
* Az azonosított duplikált sorokat (`row_num > 1`) töröltem a véglegesített `layoffs_staging2` táblából.

### 2. Adatok egységesítése és standardizálása (Standardize Data)
* **Felesleges szóközök levágása:** A `company` mezők elején és végén lévő felesleges szóközöket eltávolítottam a `TRIM()` függvénnyel.
* **Kategóriák konszolidálása:** A különböző elnevezésű kriptoipari kategóriákat (pl. *Crypto Currency*, *CryptoCurrency*) egységesen `'Crypto'` megnevezésre frissítettem:
  ```sql
  UPDATE layoffs_staging2
  SET industry = 'Crypto'
  WHERE industry LIKE 'Crypto%';
  ```
* **Karakterhibák javítása:** A `country` oszlopban előforduló hibás záró írásjeleket (pl. `'United States.'`) levágtam:
  ```sql
  UPDATE layoffs_staging2
  SET country = TRIM(TRAILING '.' FROM country)
  WHERE country LIKE 'United States%';
  ```
* **Dátumkonverzió:** A szöveges (`text`) típusú dátummezőt a `STR_TO_DATE()` függvénnyel dátummá alakítottam át (`%m/%d/%Y`), majd az oszlop típusát módosítottam `DATE`-re (`ALTER TABLE ... MODIFY COLUMN`).
  ```sql
  update layoffs_staging2
  set date = str_to_date(`date`, '%m/%d/%Y');
  ```

### 3. Hiányzó és üres értékek kezelése (Handling Nulls & Blanks)
* Az üres szöveges értékeket (`''`) formálisan átkonvertáltam standard `NULL` értékekre az `industry` mezőben.
* **Adatpótlás önösszekapcsolással (Self-Join):** Ahol egy vállalatnál egy sorban hiányzott az iparág, de egy másik rekordban ugyanahhoz a céghez és lokációhoz szerepelt az érték, egy önösszekapcsolás segítségével feltöltöttem a hiányzó adatot:
  ```sql
  UPDATE layoffs_staging2 t1
  JOIN layoffs_staging2 t2
    ON t1.company = t2.company
  SET t1.industry = t2.industry
  WHERE t1.industry IS NULL
    AND t2.industry IS NOT NULL;
  ```

### 4. Felesleges oszlopok és nem elemezhető adatok eltávolítása
* A duplikátum-kezeléshez létrehozott segédoszlopot töröltem:
  ```sql
  ALTER TABLE layoffs_staging2 DROP COLUMN row_num;
  ```

---

## 🔍 2. Rész: Feltáró Adatelemzés (Exploratory Data Analysis - EDA)

A megtisztított adathalmazra összetett lekérdezéseket futtattam, hogy megválaszoljam a legfontosabb üzleti kérdéseket:

### 1. Extrém értékek és teljes leépítések (100%-os elbocsátások)
* Megkerestem azokat a cégeket, amelyek a teljes munkaerő-állományukat elbocsátották (`percentage_laid_off = 1`), csökkenő sorrendbe állítva őket a bevont tőke (`funds_raised_millions`) alapján, hogy lássam, mely jelentős tőkével rendelkező cégek zártak be.

### 2. Időbeli trendek és kumulatív gördülő összeg (Rolling Total)
* Kiszámoltam a havonta elbocsátott dolgozók számát, és egy **Közös Táblakifejezést (CTE)**, valamint a `SUM() OVER(ORDER BY ...)` ablakfüggvényt alkalmaztam a kumulatív (gördülő) leépítési számok követésére:
  ```sql
  WITH Rolling_Total AS (
    SELECT SUBSTRING(`date`, 1, 7) AS `MONTH`, SUM(total_laid_off) AS total_off
    FROM layoffs_staging2
    WHERE SUBSTRING(`date`, 1, 7) IS NOT NULL
    GROUP BY `MONTH`
    ORDER BY 1 ASC
  )
  SELECT `MONTH`, total_off,
         SUM(total_off) OVER(ORDER BY `MONTH`) AS rolling_total
  FROM Rolling_Total;
  ```

### 3. Vállalati rangsorok évek szerint (Dense Rank Top 5)
* Többszörös CTE segítségével azonosítottam azokat az 5 legtöbb embert elbocsátó céget minden évre külön-külön a `DENSE_RANK()` ablakfüggvénnyel:
  ```sql
  WITH Company_Year(company, Years, Total_laid_off) AS (
    SELECT company, YEAR(`date`), SUM(total_laid_off)
    FROM layoffs_staging2
    GROUP BY company, YEAR(`date`)
  ), Company_Year_Rank AS (
    SELECT *, 
           DENSE_RANK() OVER(PARTITION BY Years ORDER BY Total_laid_off DESC) AS Ranking
    FROM Company_Year
    WHERE Years IS NOT NULL
  )
  SELECT *
  FROM Company_Year_Rank
  WHERE Ranking <= 5;
  ```

### 4. Ipari és finanszírozási fázis szerinti bontás
* Csoportosításokkal felmértem, hogy mely fejlődési szakaszban lévő cégek (pl. Post-IPO, Series B, C) és mely iparágak bocsátották el a legtöbb munkavállalót a vizsgált időszakban.

---

## 🛠️ Alkalmazott SQL Készségek & Technikák

* **DDL & DML:** `CREATE TABLE LIKE`, `INSERT INTO`, `UPDATE`, `ALTER TABLE`, `DROP COLUMN`
* **Adattisztítási funkciók:** `TRIM()`, `TRAILING`, `STR_TO_DATE()`, `SUBSTRING()`
* **Hiányzó adatok kitöltése:** `JOIN` önmagával (`Self-Join`)
* **Haladó analitika és logikai szerkezetek:**
  * CTE-k (`WITH ... AS`)
  * Ablakfüggvények (`ROW_NUMBER()`, `DENSE_RANK()`, `SUM() OVER()`)
  * Particionálás és rendezés (`PARTITION BY`, `ORDER BY`)
  * Aggregációk (`SUM()`, `AVG()`, `MAX()`, `GROUP BY`)

---

## 📁 Repository Tartalma

* `layoffs.csv` – A kiindulási nyers adathalmaz.
* `Data_cleaning.sql` – A teljes tisztítási folyamat szkriptje (duplikációk kiszűrése, standardizálás, típuskonverziók, adathiányok kezelése).
* `Exploratory_Data_Analysis.sql` – A feltáró analitikai lekérdezések, ablakfüggvények és rangsorok szkriptje.
