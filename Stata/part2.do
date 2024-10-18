				****** I wrote write-up part 2 at write-up pdf file*********
		******************************************************************************

/**Part 2
Exploratory analysis
Using Wave 1 data, conduct exploratory analysis to understand the relationship between
depression and household and demographic characteristics among individuals in Ghana.
**/

/** Specifically, do the following:
Q1: Explore the relationship between depression and:
● (1) Household wealth, proxied by total asset value.
● (2) A household or demographic characteristic that seems interesting to you.
Present the results from your exploration through tables, plots, a write-up, or anything else you
**/

* Q1: Explore the relationship between depression and:
* ● (1) Household wealth, proxied by total asset value.

// import the dataset
cd "\\Client\H$\Desktop\GPRL_StataAssessment_2024\data"
use merged.dta, clear

* Keep only Wave 1 data for the analysis
keep if wave == 1

*Looked at each of factor for each column
label list

* Summary statistics for total_asset_value and depression score
summarize total_asset_value kessler_score

* Scatter plot of depression score by total_asset_value
scatter kessler_score total_asset_value, title("Depression score vs Total Asset Value") xlabel(, format(%10.0gc)) ylabel(, format(%10.0gc))

* Correlation between k-10 scale scores and total_asset_value
correlate kessler_score total_asset_value

* Q1: Explore the relationship between depression and:
* ● (2) A household or demographic characteristic that seems interesting to you.

// age, gender, treated_household

// age
* Summary statistics for age and kessler_score
summarize age kessler_score


// gender
*gender(1 - Male, 5 - Female)
tabulate gender

*summary statistics of depression scores gender
by gender, sort: summarize kessler_score

*  Box Plot of Depression Scores by Gender
graph box kessler_score, over(gender)  title("Depression Score by Gender")

* Histogram of Depression Scores by Gender
histogram kessler_score, by(gender) title("Depression Scores by Gender")

* Difference in depression scores between genders.
ttest kessler_score, by(gender)


// treat_hh(household = 1(when treated) 0 if not)
tabulate treat_hh

*summary statistics of depression scores by treatment indicator
by treat_hh, sort: summarize kessler_score

*  Box Plot of Depression Scores by Treatment Status
graph box kessler_score, over(treat_hh)  title("Depression Score by Treatment Status")

* Histogram of Depression Scores by Treatment status
histogram kessler_score, by(treat_hh) title("Depression Scores(by hhid))")

* Conduct a t-test to see if the mean depression score differs between treatment groups
ttest kessler_score, by(treat_hh)

* Regression 
* using robust standard error

* Regress depression scores on total_asset_value

reg kessler_score total_asset_value, robust
eststo model1

* Regress depression scores on age
reg kessler_score age, robust
eststo model2

* Regress depression scores on gender
reg kessler_score gender, robust
eststo model3

* Regress depression scores on treat_hh
reg kessler_score treat_hh, robust
eststo model4
esttab, r2 ar2 se scalar(rmse)

* output the regression results
outreg2 [model1 model2 model3 model4] using "RegressionResults.doc", replace word title("Regression Analysis")

* outreg2 [model1 model2 model3 model4] using "RegressionResults.tex", replace word title("Regression Analysis") tex

/**
Evaluating the RCT
Using Wave 2 data to measure outcomes, answer the following questions, explaining any
decisions and assumptions you make, and interpret your results. There is no need for you to address the validity of the random assignment of the intervention.
**/

* Q2: Were the GT sessions effective at reducing depression?

// Following assumption for my RCT evaluation

* To check whether Group Therapy sessions in wave 2 are effective for decreasing depression, I will do a statistical analysis compare depression scores(kessler_score) between treatment(treated household) and control(controlled household) at wave2 

use merged.dta, clear

* Keep only Wave 2 data
keep if wave == 2

* summary statistics of kessle and /treat_hh
summarize kessler_score treat_hh

*summary statistics of depression scores by treatment indicator
by treat_hh, sort: summarize kessler_score

* To check randomization
tabulate treat_hh

* Average treatment effect for treated wave 2(after intervention)
regress kessler_score treat_hh, robust
eststo fit1
esttab, r2 ar2 se scalar(rmse)

* Save regression results
outreg2 fit1 using "GT_effectiveness.doc", replace 
* outreg2 fit1 using "GT_effectiveness.tex", replace 

/**
Q3: Did the effect of the GT sessions on depression vary for men and women? To answer this
question perform a linear regression of the Kessler Score against a “Woman” binary variable, a “Treated Household” binary variable, and an interaction term “Treated Household * Woman”, using only wave 2 observations.

Note: In your write-up for this question, please make sure to explain and interpret all coefficients in your specification, keeping in mind units and reference groups.
**/

* To check randomization between gender
tabulate gender

*Summary Statistics of kessler_score by gender
sort gender
by gender: summarize kessler_score

*Linear Regression of Differential treatment effect: to measure the average treatment effect of GT between two gender
regress kessler_score treat_hh gender treat_hh#gender, robust
eststo fit2
esttab, r2 ar2 se scalar(rmse)

* Save regression results
outreg2 fit2 using "GT_gender.doc", replace
* outreg2 fit2 using "GT_gender.tex", replace