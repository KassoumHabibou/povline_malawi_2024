
*------------------------------------------------------------------------------*
** 	  National Statistical Office (NSO) & World Bank Poverty and Equity GP 	  **
*------------------------------------------------------------------------------*
** PROJECT			2019-20 Poverty measurement
** COUNTRY			Malawi
** COUNTRYCODE  	MWI
** YEAR				2019-2020
** SURVEY NAME		IHS5
** SECTION 			Household variables
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
 
	use "$din/HH_MOD_B", clear												 
	gen age = hh_b05a
	gen 	factorAE = .														
	replace factorAE = 0.33 if age<1
	replace factorAE = 0.47 if inrange(age,1,2)
	replace factorAE = 0.55 if inrange(age,2.01,3)
	replace factorAE = 0.63 if inrange(age,3.01,5)
	replace factorAE = 0.73 if inrange(age,5.01,7)
	replace factorAE = 0.79 if inrange(age,7.01,10)
	replace factorAE = 0.84 if inrange(age,10.01,12)
	replace factorAE = 0.91 if inrange(age,12.01,14)
	replace factorAE = 0.97 if inrange(age,14.01,16)
	quietly sum age
	replace factorAE = 1.00 if inrange(age,16.01,r(max))
	label var factorAE "Adult Equivalent factor"
	//Create AE variable 
	gen hhsize = 1	
	//Create HH size variable
	collapse (sum) hhsize factorAE, by(HHID) 									
	rename factorAE adulteq
	label var adulteq "Adult equivalence" 
	label var hhsize "Household size" 
	
	merge 1:1 HHID using "$din/HH_MOD_A_FILT"
	rename reside urban															
	//Urban/rural Identifier
	label var urban "Urban/rural"
	label define region_1 1 North 2 Central 3 South
	label val region region_1
	gen urban_region = .														
	//Rura/Urban by Region
	replace urban_region = 1 if urban==1
	replace urban_region = 2 if urban==2 & region==1
	replace urban_region = 3 if urban==2 & region==2
	replace urban_region = 4 if urban==2 & region==3
	label var urban_region "Rural/Urban division by region"
	label define urban_region_l 1 "Urban" 2 "Rural North" 3 "Rural Centre" 4 "Rural South"
	label val urban_region urban_region_l
	cap d hh_a01																
	//District
	cap gen district = hh_a01
	label var district "District"
	label val district hh_a21d
	gen TA = hh_a02a															
	//TA
	label var TA "Traditional Authority"
	split interviewDate,p(-) 													
	//Spliting Survey time variable
	rename interviewDate1 syear
	rename interviewDate2 smonth
	rename interviewDate3 sdate
	label var sdate "Day of month for interview"
	label var smonth "Month of interview"
	label var syear "Year of interview"
	destring sdate smonth syear,replace
	foreach v in date month year{												
	//Apply EA time for missing HHs
	egen c_s`v'=max(s`v'), by(ea_id)
	replace s`v'=c_s`v' if s`v'==.
	} 
	label define month_l 1 January 2 February 3 March 4 April 5 May 6 June 7 July 8 August  9 September 10 October 11 November 12 December
	label val smonth month_l
	local variables HHID ea_id district TA region urban_region urban sdate smonth syear hhsize adulteq hh_wgt 
	keep  `variables'
	order `variables'
	quietly compress
	sort HHID
	save "$dout\basicvars_ihs5", replace


