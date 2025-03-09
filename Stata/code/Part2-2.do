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
