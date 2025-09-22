
*------------------------------------------------------------------------------*
** 	  National Statistical Office (NSO) & World Bank Poverty and Equity GP 	  **
*------------------------------------------------------------------------------*
** PROJECT			2019-20 Poverty measurement
** COUNTRY			Malawi
** COUNTRYCODE  	MWI
** YEAR				2019-2020
** SURVEY NAME		IHS5
** SECTION 			Generate consumption aggregate 
** LAST UPDATE      June 2021
*------------------------------------------------------------------------------*


*------------------------------------------------------------------------------*
*Directory shortcuts (Uncomment only if running script individually)
*------------------------------------------------------------------------------*

	gl folder "C:\Users\edson\Downloads\Katherin EAFIT\WoldBank\2019 Poverty Measurement"
	gl ddo "$folder\Do files"
	gl din "$folder\Input files"
	gl dout "$folder\Output files"


*------------------------------------------------------------------------------*

*------------------------------------------------------------------------------*
*1) Merging all components
*------------------------------------------------------------------------------*

	*--------------------------------------------------------------------------*
	*1.1) Collapse food item expenditure by categries 
	*--------------------------------------------------------------------------*
	
	use "$dout\food_ihs5", clear
	*Beverages
	gen exp_cat012_i = value*52 if inrange(item,901,907) | inlist(item,912) | inlist(item,909,910,916)		
	*Alcohol
	gen exp_cat021 = value*52 if inrange(item,913,915) | inlist(item,908) | inlist(item,911)
	*Vendor
	gen exp_cat111 = value*52 if inrange(item,820,830)
	*Food
	gen exp_cat011 = value*52 if inrange(item,101,818) | inrange(item,831,838) | inrange(item,5021,5123)
	collapse  (sum) exp_cat*, by(HHID) 
	label var exp_cat012_i "Beverage consumption, Sec G"
	label var exp_cat021   "Alcohol consumption, Sec G"
	label var exp_cat111   "Vendor consumption, Sec G"
	label var exp_cat011   "Food, non-vendor consumption, Sec G"

	*--------------------------------------------------------------------------*
	*1.2) Merge Non-Food Expenditure
	*--------------------------------------------------------------------------*
	
		foreach f in educa health house ijk durables {
		merge 1:1 HHID using "$dout\nonfood_`f'.dta"
		drop _merge
		}
		merge 1:1 HHID using "$dout\rent.dta", nogen

	*--------------------------------------------------------------------------*
	*1.3) Group items f same categories from diferent data sources
	*--------------------------------------------------------------------------*	

		foreach coicop in 12 45 51 53 55 56 91 95{
		egen exp_cat0`coicop' = rsum( exp_cat0`coicop'_*)
		}

	*--------------------------------------------------------------------------*
	*1.4) Label categories
	*--------------------------------------------------------------------------*

		label var exp_cat011 "Food, nominal annual consumption"
		label var exp_cat012 "Beverage, nominal annual consumption"
		label var exp_cat021 "Alcohol, nominal annual consumption"
		label var exp_cat022 "Tobacco, nominal annual consumption"
		label var exp_cat031 "Clothing, nominal annual consumption"
		label var exp_cat032 "Footwear, nominal annual consumption"
		label var exp_cat041 "Actual rents for housing, nominal annual consumption"
		label var exp_cat042 "Estimated rents for housing, nominal annual consumption"
		label var exp_cat045 "Electricity, gas, other fuels, nominal annual consumption"
		label var exp_cat051 "Decorations, carpets, nominal annual consumption"
		label var exp_cat052 "Household textiles, nominal annual consumption"
		label var exp_cat053 "Appliances, nominal annual consumption"
		label var exp_cat054 "Dishes, nominal annual consumption"
		label var exp_cat055 "Tools/equipment for home, nominal annual consumption"
		label var exp_cat056 "Routine Home maintenance, nominal annual consumption"
		label var exp_cat061 "Health drugs, nominal annual consumption"
		label var exp_cat062 "Health out-patient, nominal annual consumption"
		label var exp_cat063 "Health hospitalization, nominal annual consumption"
		label var exp_cat071 "Vehicles, nominal annual consumption"
		label var exp_cat072 "Operation of vehicles, nominal annual consumption"
		label var exp_cat073 "Transport, nominal annual consumption"
		label var exp_cat081 "Postal services, nominal annual consumption"
		label var exp_cat083 "Phone and fax services, nominal annual consumption"
		label var exp_cat091 "Audio-visual, nominal annual consumption"
		label var exp_cat092 "Major durables for rec, nominal annual consumption"
		label var exp_cat093 "Other recreational items, pets, nominal annual consumption"
		label var exp_cat094 "Recreational services, nominal annual consumption"
		label var exp_cat095 "Newspapers, books, stationery, nominal annual consumption"
		label var exp_cat101 "Education, nominal annual consumption"
		label var exp_cat111 "Vendors/Cafes/Restaurants, nominal annual consumption"
		label var exp_cat112 "Accommodation services, nominal annual consumption"
		label var exp_cat121 "Personal care, nominal annual consumption"
		label var exp_cat123 "Personal effects, nominal annual consumption"
		recode exp_cat* (.=0)

	*--------------------------------------------------------------------------*
	*1.5) Merge basic variables
	*--------------------------------------------------------------------------*
	
	merge 1:1 HHID using "$dout\basicvars_ihs5.dta", nogen

	*--------------------------------------------------------------------------*
	*1.6) Merge price index
	*--------------------------------------------------------------------------*
	
	merge m:1 urban_region syear smonth using "$dout\Price_index_ihs5.dta", nogen
	rename cpi temporal

*------------------------------------------------------------------------------*
*2) Generate real consumption
*------------------------------------------------------------------------------*

	foreach v of varlist exp_cat??? {		
	gen r`v' = (`v'/price_indexL)*100
	}	
	foreach v of varlist exp_cat??? {
	local Name : variable label `v'
	local Real : subinstr local Name ", nominal" ", real(April 2019 price)"
	label var r`v' "`Real'"
	}

*------------------------------------------------------------------------------*
*3) Aggregating NOMINAL consumption into broad groups (Coicop 2 digits)
*------------------------------------------------------------------------------*
	
	foreach n of numlist 1/9 {
	egen exp_cat0`n' = rsum(exp_cat0`n'?)
	}
	foreach n of numlist 10/12 {
	egen exp_cat`n' = rsum(exp_cat`n'?)
	}
	label var exp_cat01 "Food/Bev, nominal annual consumption"
	label var exp_cat02 "Alc/Tobacco, nominal annual consumption"
	label var exp_cat03 "Clothing/Footwear, nominal annual consumption"
	label var exp_cat04 "Housing/Utilities, nominal annual consumption"
	label var exp_cat05 "Furnishings, nominal annual consumption"
	label var exp_cat06 "Health, nominal annual consumption"
	label var exp_cat07 "Transport, nominal annual consumption"
	label var exp_cat08 "Communication, nominal annual consumption"
	label var exp_cat09 "Recreation, nominal annual consumption"
	label var exp_cat10 "Education, nominal annual consumption"
	label var exp_cat11 "Hotels and restaurants, nominal annual consumption"
	label var exp_cat12 "Misc Goods & Services, nominal annual consumption"

*------------------------------------------------------------------------------*	
*4) aggregating REAL (Spatially & within survey Temporally adjusted) consumption
*------------------------------------------------------------------------------*

	foreach n of numlist 1/9 {
	egen rexp_cat0`n' = rsum(rexp_cat0`n'?)
	}
	foreach n of numlist 10/12 {
	egen rexp_cat`n' = rsum(rexp_cat`n'?)
	}
	foreach v of varlist exp_cat?? {
	local Name : variable label `v'
	local Real : subinstr local Name ", nominal" ", real(April 2019 price)"
	label var r`v' "`Real'"
	}

*------------------------------------------------------------------------------*	
*5) Generate total consumption of the household
*------------------------------------------------------------------------------*
	
	egen rexpagg = rsum(rexp_cat??)
	egen expagg = rsum(exp_cat??)
	label var expagg  "Total nominal annual consumption per household"
	label var rexpagg "Total real annual consumption per household"
	gen rexpaggpc=rexpagg/hhsize
	gen expaggpc=expagg/hhsize	
	label var expaggpc  "Total nominal annual per capita consumption"
	label var rexpaggpc "Total real annual per capita consumption"

*------------------------------------------------------------------------------*
*6) Keep & save desired variables
*------------------------------------------------------------------------------*
	
	local v HHID ea_id district TA region urban_region urban sdate smonth syear hhsize adulteq hh_wgt exp_cat* rexp_cat* price_indexL expagg rexpagg expaggpc rexpaggpc
	keep `v'
	order `v'
	save "$dout\tconsumption_ihs5.dta", replace
		
