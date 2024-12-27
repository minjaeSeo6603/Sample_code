/****************************
* Interview
****************************/

* Import data 
import excel "/accounts/gen/guest/ppori34/interview/raw/Sampledata_RA.xlsx", sheet("Sheet1") firstrow clear

* Rename the column names
rename wsdateofincorporation date_of_incorporation
rename wsprimarysiccode primary_sic_code
rename wsprivateindicator private_indicator
rename wssdccusip sdc_cusip
rename wssedol sedol
rename wsticker ticker
rename wscid company_id
rename wscash cash
rename wscashandstinvestments cash_and_short_term_investments
rename wscommonsharesoutstanding common_shares_outstanding
rename wscommonstock common_stock
rename wscostofgoodssold cost_of_goods_sold
rename wsearningsbeforeinttaxesanddepr ebitd
rename wsexports exports
rename wsnetincome net_income
rename wsreturnonassets return_on_assets
rename wssales sales
rename wstotalassets total_assets
rename wscurrentassets current_assets
rename wscurrentliabilities current_liabilities
rename wstotalltdebt total_liabilities_and_debt
rename wsppe property_plant_equipment
rename wscashflow cash_flow
rename wscurrentmarketcap current_market_cap
rename wsforeignloans foreign_loans
rename wsinternationalassets international_assets
rename wsinternationaloperatingincome international_operating_income
rename wsinternationalsales international_sales
rename wssalesgaap sales_gaap
rename wssalesusd sales_usd

* Check missing values with 550 observations
summarize property_plant_equipment current_assets current_liabilities cash ebitd sales sales_usd employees


* Handle missing values
* Replace missing values in key variables with group-level median to maintain panel structure
foreach var of varlist property_plant_equipment current_assets current_liabilities cash ebitd sales sales_usd employees {
    bysort country year: egen median_`var' = median(`var')
    replace `var' = median_`var' if missing(`var')
    drop median_`var'
}


/****************************
- Earning before taxes and interest includes depreciation
- Operating Income = Earnings before interest and taxes = ebitd(Earnings before interest,taxes, and depreciaton
****************************/

* 1> Create the following new variables:

* ROIC (Return on Invested Capital) = Operating Income / Invested Capital at time t-1
* groupping by country year 
gen invested_capital = property_plant_equipment + current_assets - current_liabilities - cash
bysort country iso (year): gen roic = ebitd / invested_capital[_n-1] if invested_capital[_n-1] != .

* b. Annual Growth in Sales
bysort country iso (year): gen growth_sales = (sales - sales[_n-1]) / sales[_n-1] if sales[_n-1] != .

* Age variables still missing due to the unknown date of incorporation for missing ones
* Age of the firm
gen year_of_incorporation = year(date_of_incorporation)
gen age = year - year_of_incorporation

* Labor Productivity
gen labor_productivity = sales_usd / employees


sum invested_capital growth_sales age labor_productivity


*>2 Provide the following summary statistics on each of the variables created above as well as the input variables

* Summary statistics(1)
foreach var of varlist invested_capital roic property_plant_equipment current_assets current_liabilities cash{
      summarize `var', detail
}

* Summary statistics(2)
foreach var of varlist sales growth_sales labor_productivity sales_usd employees{
        summarize `var', detail
}

* Summary statistics(3)
foreach var of varlist age year year_of_incorporation {
    summarize `var', detail
}

* Check for missing variables
misstable summarize

* 3> Winsorize the top and bottom 1% of the values for ROIC and Labor Productivity
bysort country year: egen roic_p1 = pctile(roic), p(1)
bysort country year: egen roic_p99 = pctile(roic), p(99)

replace roic = max(roic, roic_p1) if roic < roic_p1
replace roic = min(roic, roic_p99) if roic > roic_p99

gen roic_w = roic

bysort country year: egen labor_productivity_p1 = pctile(labor_productivity), p(1)
bysort country year: egen labor_productivity_p99 = pctile(labor_productivity), p(99)

replace labor_productivity = max(labor_productivity, labor_productivity_p1) if labor_productivity < labor_productivity_p1
replace labor_productivity = min(labor_productivity, labor_productivity_p99) if labor_productivity > labor_productivity_p99

gen labor_productivity_w = labor_productivity


* Summary statistics for this winsorization 
summarize roic_w labor_productivity_w, detail


* 4> Compute median ROIC for each country each year
bysort country year: egen median_roic = median(roic_w)

* Save this sample data files
save "/accounts/gen/guest/ppori34/interview/raw/Updated_Sampledata_RA.dta",replace

* 5> Merge the dataset with the country-year-level variables in the data “WEO_Data”. 

* Load WEO DATA and change from wide to long table
import excel "/accounts/gen/guest/ppori34/interview/raw/WEO_Data.xlsx", firstrow clear
keep iso Country SubjectDescriptor Units Q-AA

* Rename columns to reflect actual years with a prefix
rename Country country
rename Q year_2000
rename R year_2001
rename S year_2002
rename T year_2003
rename U year_2004
rename V year_2005
rename W year_2006
rename X year_2007
rename Y year_2008
rename Z year_2009
rename AA year_2010

* Describe the labels
describe

* Reshape the WEO data to long format
reshape long year_, i(iso country SubjectDescriptor Units) j(year)

* Rename the reshaped value column for clarity
rename year_ value

* Save the imported data as a Stata (.dta) file
save "/accounts/gen/guest/ppori34/interview/raw/Updated_WEO_DATA.dta", replace


* Before merging remove the duplicates of country and year
use "/accounts/gen/guest/ppori34/interview/raw/Updated_WEO_DATA.dta", clear
duplicates report country year

collapse (mean) value, by(country year)

save "/accounts/gen/guest/ppori34/interview/raw/Updated_WEO_DATA_collapsed.dta", replace

* Now merged
use "/accounts/gen/guest/ppori34/interview/raw/Updated_Sampledata_RA.dta", clear
merge m:1 country year using "/accounts/gen/guest/ppori34/interview/raw/Updated_WEO_DATA_collapsed.dta"

save "/accounts/gen/guest/ppori34/interview/raw/merged.dta", replace


* 6> For each country, generate a graph where one line shows the median Return on InvestedCapital (units on left y-axis) and a second line showing real GDP growth (units on right y-axis), both over time.

* For first graph 
use "/accounts/gen/guest/ppori34/interview/raw/Updated_Sampledata_RA.dta", clear
keep country year median_roic
duplicates drop
save "/accounts/gen/guest/ppori34/interview/raw/median_roic_data.dta", replace

* For second graph
use "/accounts/gen/guest/ppori34/interview/raw/Updated_WEO_DATA.dta", clear

* Keep only the real GDP growth for merging
keep if SubjectDescriptor == "Gross domestic product, constant prices"
rename value gdp_growth
keep country year gdp_growth

* Save for merging
save "/accounts/gen/guest/ppori34/interview/raw/gdp_growth_data.dta", replace

* Load the median ROIC data and merge with GDP growth data
use "/accounts/gen/guest/ppori34/interview/raw/median_roic_data.dta", clear
merge m:1 country year using "/accounts/gen/guest/ppori34/interview/raw/gdp_growth_data.dta"

* Drop unmatched observations
keep if _merge == 3
drop _merge


* 6> For each country, generate a graph where one line shows the median Return on InvestedCapital (units on left y-axis) and a second line showing real GDP growth (units on right y-axis), both over time.

* Mergin with the subset of datasets
use "/accounts/gen/guest/ppori34/interview/raw/Updated_Sampledata_RA.dta", clear
keep country year median_roic
duplicates drop
save "/accounts/gen/guest/ppori34/interview/raw/median_roic_data.dta", replace

* Load the real GDP growth data from the WEO dataset
use "/accounts/gen/guest/ppori34/interview/raw/Updated_WEO_DATA.dta", clear

* Keep only the real GDP growth for merging
keep if SubjectDescriptor == "Gross domestic product, constant prices"
rename value gdp_growth
keep country year gdp_growth

* Save for merging
save "/accounts/gen/guest/ppori34/interview/raw/gdp_growth_data.dta", replace

* Load the median ROIC data and merge with GDP growth data
use "/accounts/gen/guest/ppori34/interview/raw/median_roic_data.dta", clear
merge m:1 country year using "/accounts/gen/guest/ppori34/interview/raw/gdp_growth_data.dta"

* Drop unmatched observations
keep if _merge == 3
drop _merge

* Generate graph for each country
levelsof country, local(countries)

foreach c of local countries {
    * Restrict data to current country
    keep if country == "`c'"

    * Create a graph with dual y-axes
    twoway ///
        (line median_roic year, yaxis(1) lcolor(blue) lpattern(solid) lwidth(medium)) ///
        (line gdp_growth year, yaxis(2) lcolor(red) lpattern(dash) lwidth(medium)), ///
        title("ROIC and GDP Growth for `c' Over Time") ///
        ytitle("Median ROIC (%)") ///
        ytitle("GDP Growth (%)", axis(2)) ///
        legend(order(1 "Median ROIC" 2 "GDP Growth")) ///
        xlabel(2000(1)2010)

    * Export the graph
    graph export "graph_`c'.png", replace

    * Load the full dataset again
    use "/accounts/gen/guest/ppori34/interview/raw/median_roic_data.dta", clear
    merge m:1 country year using "/accounts/gen/guest/ppori34/interview/raw/gdp_growth_data.dta"
    keep if _merge == 3
    drop _merge
}
