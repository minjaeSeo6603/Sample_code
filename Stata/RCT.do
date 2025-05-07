/*********************************************************************
** Part1 
**    - Import & clean demographics (household size, gender)
**    - Clean & process assets (median imputation, total asset values)
**    - Construct Kessler-10 score and depression categories
**    - Merge datasets into individual-wave level panel
*********************************************************************/

clear all
set more off

/****************************
* Set globals
****************************/

* Set file paths 
* Change to your working directory and file path

if "`c(username)'" == "seominjae"{
	global root "/Users/seominjae/Desktop/GPRL_StataAssessment_2025"
	global figures "${root}/figures"
	global data_raw "${root}/data/raw"
	global data_clean "${root}/data/clean"
	global data_merge "${root}/data/merge"
}

*Part 1*

*** Demographics: Import and Cleaning ***
use "${data_raw}/demographics.dta", clear

* Inspect the first few rows and variable names
list in 1/10  
describe  

* Ensure unique identifiers: Household ID, Household member ID, villageid, and wave are uniquely identifies observations
isid hhid hhmid villageid wave

* Convert gender and treat_hh to Dummy variables
decode gender, gen(gender_str)  // Convert labeled values to string
gen gender_num = .
replace gender_num = 1 if gender_str == "Female"
replace gender_num = 0 if gender_str == "Male"

* Drop the original gender variable
drop gender gender_str

* Rename the new numeric gender variable back to gender
rename gender_num gender

* Label the numeric gender variable for clarity
label variable gender "Gender"
label define gender_label 1 "Female" 0 "Male"
label values gender

* Verify that the conversion worked
desc gender

* Replace treat_hh to label values
label values treat_hh

* save data in the clean folders
save "${data_clean}/demographics_clean.dta", replace


*Q2*

* Compute household size based on the number of members surveyed per household in Wave 1
egen hh_size_wave = count(hhmid) if wave == 1, by(hhid)

* Fill in the household size for Wave 2 using the same values from Wave 1
bysort hhid (wave): replace hh_size_wave = hh_size_wave[_n-1] if missing(hh_size_wave)

* Label the variable
label variable hh_size_wave "Household size (from Wave 1, assumed constant for Wave 2)"

* Verify results: browse the first 20 rows
list wave hhid hhmid hh_size_wave in 1/20

sort wave hhid hhmid

*Q3: Calculate the monetary value of all assets*

* import assets data
use "${data_raw}/assets.dta", clear

* Remove leading zeros from `hhid`
* Convert `hhid` to numeric (ensuring no scientific notation)
destring hhid, replace force

* Ensure Stata displays the full number (fix scientific notation)
format hhid %12.0f  // Displays hhid as a full number

* Verify the changes
brow hhid

* Impute missing current values using median by asset type
by Asset_Type, sort: egen med_val = median(currentvalue)
replace currentvalue = med_val if missing(currentvalue)
drop med_val

*Q4: Create a variable that contains the total monetary value for each observation, by multiplying quantity and the imputed current value.* 
* Calculate total value for each asset record (quantity * currentvalue)
gen totalvalue = quantity * currentvalue
browse hhid wave quantity currentvalue totalvalue in 1/20

*Q5: Produce a dataset at the household-wave level (for each household, there should be at most two observations, one for each wave) which contains the following variables:*

* Create category-wise total values based on asset_type
gen total_animals  = totalvalue if Asset_Type == 1
replace total_animals = 0 if missing(total_animals)

gen total_tools = totalvalue if Asset_Type == 2
replace total_tools = 0 if missing(total_tools)

gen total_durables = totalvalue if Asset_Type == 3
replace total_durables = 0 if missing(total_durables)

collapse (sum) total_animals total_tools total_durables, by(hhid wave)

* Compute total asset value for each household-wave
gen total_assets = total_animals + total_tools + total_durables

* Label variables
label variable total_animals "Total value of animals (household, wave)"
label variable total_tools "Total value of tools (household, wave)"
label variable total_durables "Total value of durable goods (household, wave)"
label variable total_assets "Total asset value (household, wave)"

* save data
sort wave hhid
save "${data_clean}/assets_clean.dta", replace

*Q6: construct the kessler score (name it kessler score) and a categorical variable named kessler categories with 4 categories: no significant depression, mild depression, moderate depression, and severe depression*

*import depression data*
use "${data_raw}/depression.dta", clear

* Check variable names for the 10 questions (assuming they are q1 to q10 for example)
describe

* Count missing responses in Kessler-10 questions
egen missing_kessler = rowmiss(tired nervous sonervous hopeless restless sorestless depressed everythingeffort nothingcheerup worthless)
label variable missing_kessler "Number of Missing Kessler Questions"
summarize missing_kessler

* Mean imputation for respondents with ≤2 missing Kessler responses
egen mean_kessler = rowmean(tired nervous sonervous hopeless restless sorestless depressed everythingeffort nothingcheerup worthless)

* Generate total Kessler-10 score:
gen kessler_score = tired + nervous + sonervous + hopeless + restless + sorestless + depressed + everythingeffort + nothingcheerup + worthless

* Replace missing scores with imputed values for respondents missing ≤2 responses
replace kessler_score = mean_kessler if missing_kessler > 0 & missing_kessler < 3

* Drop respondents with 3+ missing responses
replace kessler_score = . if missing_kessler >= 3

* Remove temporary imputation variable
drop mean_kessler

* Label the Kessler-10 score
label variable kessler_score "Kessler-10 Total Score (10-50, higher = more distress)"

* Create categorical variable for distress levels
gen kessler_categories = .
replace kessler_categories = 0 if kessler_score >= 10 & kessler_score <= 15
replace kessler_categories = 1 if kessler_score >= 16 & kessler_score <= 21
replace kessler_categories = 2 if kessler_score >= 22 & kessler_score <= 29
replace kessler_categories = 3 if kessler_score >= 30 & kessler_score <= 50
replace kessler_categories = 4 if missing(kessler_score)  // Mark missing values

* Label the categories for interpretation
label define kessler_labels 0 "no significant depression" 1 "mild depression" 2 "moderate depression" 3 "severe depression" 4 "Missing"
label values kessler_categories kessler_labels
label variable kessler_categories "Kessler Categories"

* Justify Missingness
tabulate wave if missing_kessler > 0
* 313 missing Kessler-10 responses are entirely from Wave 1 (100%)
* We should not use strict listwise deletion, as it may distort comparisons.
* Use mean Imputations, which assumes that missing values are similar to observed values, but if 3+ responses are missing, this assumption is weaker
* Therefore, threshold for missing questions <2 for mean imputations

* Verify final results
tabulate kessler_categories, missing
summarize kessler_score

sort wave hhid hhmid

* save data
save "${data_clean}/depression_clean.dta", replace


*Q7:Constructing a single dataset*

* Load the demographics dataset (base dataset)
use "${data_clean}/demographics_clean.dta", clear

* Merge with the depression data
merge 1:1 wave hhid hhmid using "${data_clean}/depression_clean.dta"
sort wave hhid hhmid

* Drop unmatched records (if necessary)
drop if _merge == 1   // Individuals in depression but not in demographics
drop _merge  // Remove merge indicator

* Merge with assets data
merge m:1 wave hhid using "${data_clean}/assets_clean.dta"
sort wave hhid 

* Drop unmatched household records from assets if they are not useful
drop if _merge == 2  // Remove extra households from assets that don't exist in demographics + depression

* Drop the merge indicator variable
drop _merge

* Save the final dataset
save "${data_merge}/merged.dta", replace

/*********************************************************************
** PART 2: EXPLORATORY ANALYSIS
** - Depression vs Household Wealth (Total Assets)
** - Depression vs Gender(Binary Indicator), age(Continuous),age_group (Demographic Characteristic)
*********************************************************************/

clear all
set more off
set scheme s2color  // Improved visualization theme

/****************************
* 1. Set Global Paths
****************************/

* Change file paths based on your system
if "`c(username)'" == "seominjae"{
    global root "/Users/seominjae/Desktop/GPRL_StataAssessment_2025"
    global figures "${root}/figures/plot"
    global tables "${root}/figures/table"
    global data_merge "${root}/data/merge"
    global data_clean "${root}/data/clean"
}

* Load merged dataset
use "${data_merge}/merged.dta", clear

* Keep only Wave 1 (Baseline Data)
keep if wave == 1

/****************************
* 2. Depression vs Household Wealth (Total Assets)
****************************/

*** Summary Statistics ***
summarize kessler_score total_assets

*** Scatter Plot: Depression vs Total Assets ***
graph twoway (scatter kessler_score total_assets, msize(vsmall) mcolor(blue)) ///
             (lfit kessler_score total_assets, lcolor(red)), ///
             title("Depression vs Household Wealth", size(large)) ///
             xtitle("Total Asset Value", size(medium)) ytitle("Kessler Score (Depression)", size(medium)) ///
             legend(label(1 "Individuals") label(2 "Linear Fit") size(small)) ///
             graphregion(color(white)) bgcolor(white)

graph export "${figures}/depression_wealth.png", replace

*** Box Plot: Depression by Wealth Quartiles ***

* Divide total assets into 4 quartiles
xtile asset_quartile = total_assets, nq(4) 
* Define meaningful labels for quartiles
label define asset_labels 1 "Lowest Wealth" 2 "Low-Middle Wealth" 3 "Upper-Middle Wealth" 4 "Highest Wealth"
label values asset_quartile asset_labels

* Box Plot: Depression by Wealth Quartiles
graph box kessler_score, over(asset_quartile, label(labsize(small))) ///
    title("Depression by Household Wealth Quartiles", size(large)) ///
    ylabel(, angle(0) grid) ytitle("Kessler Score", size(medium)) ///
    graphregion(color(white)) bgcolor(white)

* Export the Box Plot as PNG
graph export "${figures}/depression_quartiles.png", replace

*** Correlation Analysis ***
correlate kessler_score total_assets

*** Regression: Does Wealth Predict Depression? ***
regress kessler_score total_assets


/****************************
* 3. Depression vs Gender
****************************/

*** Summary Statistics by Gender ***
tabstat kessler_score, by(gender) statistics(mean sd min max)

* Define Gender Labels (0 = Female, 1 = Male)
label define gender_labels 1 "Female" 0 "Male"
label values gender gender_labels

*** Box Plot: Depression by Gender ***
graph box kessler_score, over(gender, label(labsize(medium))) ///
    title("Depression by Gender", size(large)) ///
    ylabel(, angle(0) grid) ytitle("Kessler Score", size(medium)) ///
    graphregion(color(white)) bgcolor(white)

graph export "${figures}/depression_gender.png", replace

*** Regression: Does Gender Predict Depression? ***
regress kessler_score i.gender

/****************************
* 4. Depression vs age
****************************/

*** Summary Statistics ***
summarize age total_assets

* Visualize Depression by Age
gen age_group = .
replace age_group = 1 if age >= 4 & age < 18
replace age_group = 2 if age >= 18 & age < 30
replace age_group = 3 if age >= 30 & age < 50
replace age_group = 4 if age >= 50
replace age_group = 5 if age == -999  // Keep missing age separate
label define age_lbl 1 "Age(4-17)," 2 "Age(18-29)" 3 "Age(30-49)" 4 "Age(50+)" 5 "Missing Age"
label values age_group age_lbl

graph box kessler_score, over(age_group) ///
    title("Depression by Age Category (Wave 1)") ///
    ylabel(, grid) ytitle("Kessler Score")

graph export "${figures}/depression_age_group.png", replace

	

** Likewise deletion**
gen age_scatter = age
drop if age_scatter == -999

** Correlation Analysis
corr kessler_score age_scatter

*** Scatter Plot: Depression vs Age ***

** summary statistics with likewise deletion
summarize age_scatter kessler_score

graph twoway (scatter age_scatter kessler_score, msize(vsmall) mcolor(blue)) ///
             (lfit kessler_score age_scatter, lcolor(red)), ///
             title("Depression vs Age(with likewise deletion)", size(large)) ///
             xtitle("Age", size(medium)) ytitle("Kessler Score (Depression)", size(medium)) ///
             legend(label(1 "Individuals") label(2 "Linear Fit") size(small)) ///
             graphregion(color(white)) bgcolor(white)
			 
graph export "${figures}/depression_age.png", replace

*** Regression: Does age Predict Depression? ***
regress kessler_score age_scatter


/****************************
* 5. Additional: Wealth Grouping (Above/Below Median)
****************************/

* Create a wealth grouping (above/below median total assets)
quietly summarize total_assets
scalar median_w1_wealth = r(p50)
gen byte wealth_group = .
replace wealth_group = 0 if total_assets < median_w1_wealth
replace wealth_group = 1 if total_assets >= median_w1_wealth
label define wealth_lbl 0 "Below Median Wealth" 1 "Above Median Wealth"
label values wealth_group wealth_lbl
label var wealth_group "Wealth group (baseline median split)"

* Compare mean depression (K10) by wealth group
tabulate wealth_group, summarize(kessler_score)
ttest kessler_score, by(wealth_group)

* save data for part2-1
save "${data_merge}/merged_wave1.dta", replace


* Save it as log ouputs
log using "${tables}/table_part2_1.log", replace
summarize kessler_score total_assets
correlate kessler_score total_assets
regress kessler_score total_assets
tabstat kessler_score, by(gender) statistics(mean sd min max)
regress kessler_score i.gender
summarize age_scatter kessler_score
corr kessler_score age_scatter
regress kessler_score age_scatter
ttest kessler_score, by(wealth_group)
log close

/*********************************************************************
** PART 3: EVALUATING THE RCT (Wave 2)
**  
** - Q2: Were GT sessions effective at reducing depression?
** - Q3: Did the effect of GT sessions differ by gender?
**
** Notes:
** - Uses Wave 2 data
** - Analyzes the impact of GT sessions on depression (Kessler Score)
** - Performs regression analysis with interaction terms
** - Exports well-formatted tables and visualizations
**
*********************************************************************/

clear all
set more off
set scheme s2color  // Improved visualization theme

/****************************
* 1. Set Global Paths
****************************/

* Change file paths based on your system
if "`c(username)'" == "seominjae"{
    global root "/Users/seominjae/Desktop/GPRL_StataAssessment_2025"
    global figures "${root}/figures/plot"
    global tables "${root}/figures/table"
    global data_merge "${root}/data/merge"
    global data_clean "${root}/data/clean"
}

* Load merged dataset
use "${data_merge}/merged.dta", clear

* Keep only Wave 2 observations for post-treatment analysis
keep if wave == 2

* Remove age=-999
list age if age == -999
drop if age  == -999 // remove one entry 
summarize age kessler_score

* create age categories
gen age_group = .
replace age_group = 1 if age >= 2 & age < 18
replace age_group = 2 if age >= 18 & age < 30
replace age_group = 3 if age >= 30 & age < 50
replace age_group = 4 if age >= 50
label define age_lbl 1 "Age(2-17)," 2 "Age(18-29)" 3 "Age(30-49)" 4 "Age(50+)"
label values age_group age_lbl


/****************************
* 2. GT Sessions & Depression: Were They Effective? (Q2)
****************************/

*** Summary Statistics ***
summarize kessler_score treat_hh


*** Box Plot: Depression by Treatment Group ***
label define treatment_labels 0 "Control" 1 "Treated"
label values treat_hh treatment_labels

graph box kessler_score, over(treat_hh, label(labsize(medium))) ///
    title("Depression by GT Treatment Group (Wave 2)", size(large)) ///
    ylabel(, angle(0) grid) ytitle("Kessler Score (Depression)", size(medium)) ///
    graphregion(color(white)) bgcolor(white)

graph export "${figures}/depression_treatment.png", replace

*** Regression: Did GT Sessions Reduce Depression? ***
regress kessler_score treat_hh


/****************************
* 3. GT Sessions & Gender Interaction Effect (Q3)
****************************/

*** Define Woman (Binary Variable) ***

*** Interaction Term: Treatment x Woman ***
gen woman = gender // woman(binary indicator) is same as gender variable
gen treat_woman = treat_hh * woman  // Interaction term: Treated Household * gender(1 = woman, 0 = man)

*** Regression: Does Gender Modify the Treatment Effect? ***
regress kessler_score treat_hh woman treat_woman


/****************************
* Additional: GT Sessions & Gender Interaction Effect adding controls (Q3)
****************************/

*** Regression: Differential treatment effect of gender on kessler scores with including demographic control ***
regress kessler_score age treat_hh woman treat_woman 


/****************************
* 4. Presentation: Box Plots & Interpretation
****************************/

*** Box Plot: Depression by Treatment & Gender ***
graph box kessler_score, over(treat_hh, label(labsize(medium))) by(gender, title("Depression by Treatment & Gender (Wave 2)", size(large))) ///
    ylabel(, angle(0) grid) ytitle("Kessler Score (Depression)", size(medium)) ///
    graphregion(color(white)) bgcolor(white)

graph export "${figures}/depression_treatment_gender.png", replace

*** Box Plot: Depression by Treatment & Age Group ***
graph box kessler_score, over(treat_hh, label(labsize(medium))) by(age_group, title("Depression by Treatment & Age group (Wave 2)", size(large))) ///
    ylabel(, angle(0) grid) ytitle("Kessler Score (Depression)", size(medium)) ///
    graphregion(color(white)) bgcolor(white)

graph export "${figures}/depression_treatment_age.png", replace

* save data for part2-2
save "${data_merge}/merged_wave2.dta", replace


* Save it as log ouputs
log using "${tables}/table_part2_2.log", replace
summarize kessler_score treat_hh 
regress kessler_score treat_hh
regress kessler_score treat_hh woman treat_woman 
regress kessler_score age treat_hh woman treat_woman 
log close
