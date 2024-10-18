cd "\\Client\H$\Desktop\GPRL_StataAssessment_2024\data"

// Q1: At what level is each dataset uniquely identified (i.e. what does each row represent and which variables are unique identifiers?)

/**************************************************************
* Dataset: Demographics
* Description: Each row represents a combination of a household at different wave( incator of before and after Group Therapies) and demographic information for each member within that household.
* Unique Identifiers: hhid (household ID), (wave = 1(before) or 2(after), hhmid (household member ID)
**************************************************************/
use demographics.dta, clear
browse in 1/5

/**************************************************************
* Dataset: Asset
* Description: Each row represents a combination of a household at a specific wave and information about the quantity and monetary value of assets owned by the household.
* Unique Identifiers: hhid (household ID),  (wave = 1(before) or 2(after)
**************************************************************/
use assets.dta, clear
browse in 1/5

/**************************************************************
* Dataset: Depression
* Description: Each row represents a combination of a household at different wave with information for the Kessler Psychological Distress Scale collected for household heads and their spouses.
* Unique Identifiers: hhid (household ID), wave = 1(before) or 2(after), ,hhmid (household member ID)
**************************************************************/
use depression.dta, clear
browse in 1/5



/**Q2: Import the demographics dataset, and calculate a variable proxying for household size, based on how many members were surveyed in each household in Wave 1.You can assume the
household size for Wave 2 to be the same as Wave 1.**/
use demographics.dta, clear

* Keep only the observations for Wave 1
keep if wave == 1

* Generate household size proxy variable how many members were surveyed in each household in Wave 1
bysort hhid: egen household_size_proxy_wave1 = count(hhmid)

* Assume the same household size for Wave 2 as Wave 1
gen household_size_proxy_wave2 = household_size_proxy_wave1

* Describe the variable
sum household_size_proxy_wave1 

browse hhid hhmid household_size_proxy_wave1 in 1/10

/**Q3. To calculate the monetary value of all assets, you should use the ‘currentvalue’ variable, which reports the monetary value of a single unit of the asset. However, you will notice that this variable is often missing. Please use the median of “currentvalue” for each type of asset (bytype we mean, for example, “chickens”, “Cutlass”, “Room Furniture”, “Radio”, “Cell (mobile) Phone handset”, etc.) to impute the missing values**/

use assets.dta, clear

* Calculate the median current value for each type of asset
egen median_currentvalue =  median(currentvalue), by(Asset_Type)

* Impute missing values of currentvalue with the median for each type of asset
replace currentvalue = median_currentvalue if missing(currentvalue)
drop median_currentvalue

* View hhid = 010100001002
browse hhid wave currentvalue in 1/22

/**Q4: Create a variable that contains the total monetary value for each observation, by
multiplying quantity and the imputed current value.**/
gen total_monetary_value = quantity * currentvalue 

* Display the first 22 observations of hhid, wave, and total monetary value
browse hhid wave quantity currentvalue total_monetary_value in 1/22

/**Q5: Produce a dataset at the household-wave level (for each household, there should be atmost two observations, one for each wave) which contains the following variables: householdID, wave ID, total value of animals, total value of tools, and total value of durable goods. Then,also create a total asset value variable.**/

* convert hhid string value to numeric value
destring hhid, replace

* Calculate total value of animals, tools, and durable goods by household and wave
egen total_value_animals = total(quantity * currentvalue) if Asset_Type == 1, by(hhid wave)
egen total_value_tools = total(quantity * currentvalue) if Asset_Type == 2, by(hhid wave)
egen total_value_durable_goods = total(quantity * currentvalue) if Asset_Type == 3, by(hhid wave)

* Calculate total asset value by household and wave
egen total_asset_value = total(currentvalue), by(hhid wave)

* Keep only one observation per household-wave pair
collapse (first) total_value_animals total_value_tools total_value_durable_goods (first) total_asset_value, by(hhid wave)

* Display the resulting dataset
browse hhid wave total_value_animals total_value_tools total_value_durable_goods total_asset_value in 1/10

save updated_assets.dta, replace


/**Mental health/depression data:
Q6: A Kessler-10 scale is a measure of mental health that uses 10 questions that identify how
often people experience symptoms associated with depression.**/
use depression.dta, clear

* Calculate Kessler score
egen kessler_score = rowtotal(tired nervous sonervous hopeless restless sorestless depressed everythingeffort nothingcheerup worthless)

* Categorize into depression categories
gen kessler_categories = ""
replace kessler_categories = "no significant depression" if kessler_score >= 10 & kessler_score <= 19
replace kessler_categories = "mild depression" if kessler_score >= 20 & kessler_score <= 24
replace kessler_categories = "moderate depression" if kessler_score >= 25 & kessler_score <= 29
replace kessler_categories = "severe depression" if kessler_score >= 30 & kessler_score <= 50
replace kessler_categories = "." if kessler_score == 0
list wave hhid hhmid kessler_score kessler_categories in 1/20

* Describe the new variables
sum kessler_score
tab kessler_categories

save depression.dta, replace

/**Q7: At this point you have created three datasets: demographics, assets, and mental health.
Please combine all three of these datasets to create a single dataset that you will use for data
exploration and analysis. The unit of observation in this dataset should be an individual in a
given survey round. (There should be at most two observations per individual, one for Wave 1
and another for Wave 2).**/

// merging depression with demographics
* Load the depression dataset
use depression.dta, clear

* Long to double
recast double hhid

* Merge with the demographics data
merge 1:m hhid wave hhmid using demographics.dta

* Check merge results
tab _merge

* Keep only records from depression that have a match in demographics
drop if _merge == 2
drop _merge

* Save the combined dataset
save combined_data.dta, replace

// Merging combined with assets
use updated_assets.dta, clear

* Since hhid is not double, then recast
recast double hhid

* Check for duplicates in the assets data
duplicates report hhid wave

// Merging two

* Load the combined dataset of depression and demographics
use combined_data.dta, clear  

* Merge with the aggregated assets data
merge m:1 hhid wave using updated_assets.dta

* Check merge results
tab _merge

* Keep only records from the combined dataset that have a match in assets
drop if _merge == 2
drop _merge

* Save the final merged dataset
save merged.dta, replace