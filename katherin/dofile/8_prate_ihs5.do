
*------------------------------------------------------------------------------*
** 	  National Statistical Office (NSO) & World Bank Poverty and Equity GP 	  **
*------------------------------------------------------------------------------*
** PROJECT			2019-20 Poverty measurement
** COUNTRY			Malawi
** COUNTRYCODE  	MWI
** YEAR				2019-2020
** SURVEY NAME		IHS5
** SECTION 			Poverty head count ratio
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
	
	use "$dout\tconsumption_ihs5.dta",clear
	gen pcrexp = rexpagg/hhsize
	replace pcrexp =  pcrexp/365
	gen m = 1	
	merge m:1 m using "$dout\pline_ihs5", nogen
	merge m:1 m using "$dout\upline_ihs5", nogen
	drop m
	gen poor = (pcrexp<m_pline)
	gen upoor = (pcrexp<d_upline)	
	keep HHID poor upoor
	save "$dout\poor", replace 
	
	*tab poor [aweight= hh_wgt*hhsize]
	
	*** revisar con el peso que el tab poor [aweight= hh_wgt*hhsize] que quede como 50.74 
	
	//tomando la base de datos original 
	*use "C:\Users\edson\Downloads\Katherin EAFIT\WoldBank\Datos originales\Output files originals\poor.dta", clear
	
	
	
