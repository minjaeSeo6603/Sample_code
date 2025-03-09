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
