
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
*1) Prepare food items for merge 
*------------------------------------------------------------------------------*	

	use "$dout\food_ihs5_forpovline.dta", clear
	keep HHID item hhsize qkg pcqkg hh_wgt price
	gen mprice = 1 if missing(price)
	replace mprice = 0 if !missing(price)
	drop if mprice==1
	drop mprice
	merge m:1 item using "$din\calories",nogen keep(match)
	drop if e_kcal==0 | missing(e_kcal)
	replace qkg = qkg/7
	rename (e_kcal) (cal)		
	gen cal_int = (((qkg*cal*10)))
	keep item qkg cal_int HHID cal hh_wgt hhsize
	tempfile basketnoout
	save `basketnoout'	
	
*------------------------------------------------------------------------------*
*2) Choose the reference group and with food items
*------------------------------------------------------------------------------*

	use "$dout\tconsumption_ihs5.dta",clear
	xtile rexpaggpc_q=rexpaggpc[aw=hhsize*hh_wgt],nq(10) 
	keep if rexpaggpc_q==5 | rexpaggpc_q==6                 
	save "$dout\refgroup", replace
	
	
	keep HHID hhsize adulteq hh_wgt price_indexL expagg rexpagg rexpaggpc
	merge 1:m HHID using `basketnoout'
	keep if _merge==3 
	drop _merge
	
*------------------------------------------------------------------------------*
*3) Generate panel 
*------------------------------------------------------------------------------*

	*--------------------------------------------------------------------------*
	*3.1) Generate structure
	*--------------------------------------------------------------------------*
	
		egen hhid = group(HHID)
		egen itid = group(item)
		tsset hhid itid
		tsfill, full
	
	*--------------------------------------------------------------------------*
	*3.2) Replace with 0 if missing consumption
	*--------------------------------------------------------------------------*
	
		replace qkg=0 if qkg==.
		tsset, clear
	
	*--------------------------------------------------------------------------*
	*3.3) Fill missing variables
	*--------------------------------------------------------------------------*
	
		bysort hhid (HHID): replace HHID=HHID[_N]	
		bysort itid: carryforward item, gen (itemf)
		replace item = itemf if missing(item)
		drop itemf
		foreach var in hhsize adulteq hh_wgt price_indexL expagg rexpagg rexpaggpc{
		bysort hhid (`var'): replace `var'=`var'[1]
		}

*------------------------------------------------------------------------------*
*4) Set calories requirement
*------------------------------------------------------------------------------*

	gen cal_req = 2215

*------------------------------------------------------------------------------*
*5) Generate population
*------------------------------------------------------------------------------*

	gsort HHID -qkg
	by HHID: gen first = 1 if _n==1
	egen totalhh =  total(hh_wgt) if first ==1
	bysort hhid (totalhh): replace totalhh=totalhh[1]

*------------------------------------------------------------------------------*
*6) Food popularity
*------------------------------------------------------------------------------*

	bysort item: egen hh_consumer = total(hh_wgt) if qkg>0 & qkg!=. 
	gen popularity = hh_consumer/totalhh
	sort item popularity, stable
	bysort item (popularity): replace popularity = popularity[1]
	replace popularity = 0 if popularity==.	
	
*------------------------------------------------------------------------------*
*7)	Creates caloric intake share of each food in total consumption
*------------------------------------------------------------------------------*
	
	bysort hhid: egen cal_int_hh = total(cal_int) 
	gen tot_intake_temp = cal_int_hh*hh_wgt if first ==1 
	egen tot_intake = total(tot_intake_temp) if first ==1 
	drop tot_intake_temp
	bysort hhid (tot_intake): replace tot_intake=tot_intake[1] 
	gen food_intake_temp = cal_int*hh_wgt
	bysort item: egen food_cal_intake = total(food_intake_temp)
	gen share_intake = food_cal_intake/tot_intake

*------------------------------------------------------------------------------*
*8) Select Items
*------------------------------------------------------------------------------*	

	keep if share_intake>0.05 | popularity>0.3	

*------------------------------------------------------------------------------*
*9) Quantity adjustment to match caloric requirements
*------------------------------------------------------------------------------*
	
	*--------------------------------------------------------------------------*
	*9.1) New population
	*--------------------------------------------------------------------------*

		drop first
		sort HHID, stable
		by HHID: gen first = 1 if _n==1
		egen population = total(hh_wgt) if first == 1
		sort population, stable 
		replace population=population[1] 

	*--------------------------------------------------------------------------*
	*9.2) Total consumption
	*--------------------------------------------------------------------------*

		gen cantidad_h_temp = qkg/hhsize*hh_wgt
		bys item: egen qkg_tot = total(cantidad_h_temp) 
		
	*--------------------------------------------------------------------------*
	*9.3) Generate quantities pc
	*--------------------------------------------------------------------------*
		
		keep item qkg_tot population cal cal_req
		drop if cal ==. 
		duplicates drop 
		gen qkg = qkg_tot/population
		gen cal_intake_pre_adj = qkg*cal*10
	
	*--------------------------------------------------------------------------*
	*9.4) Generate adjustement on quantities
	*--------------------------------------------------------------------------*
		
		egen total_cal_pre_adj = total(cal_intake_pre_adj)
		gen caloric_adj = cal_req/total_cal_pre_adj
		gen q_adj = qkg * caloric_adj 
		gen cal_intake = q_adj*cal*10
		gsort -cal_intake
		drop qkg_tot
		save "$dout/daily_basket.dta", replace

*------------------------------------------------------------------------------*
*10) Impute prices 
*------------------------------------------------------------------------------*

	use "$dout\food_ihs5_forpovline", clear
	merge m:1 urban_region syear smonth using "$dout\Price_index_ihs5.dta", nogen
	gen rprice = (price/price_indexL)*100
	collapse (count) nobs=rprice (mean) mnprice=rprice (p50) mdprice=rprice (min) minprice=rprice  (max) maxprice=rprice, by(item)
	save "$dout\pricebyurbanregion.dta",replace
	
	use "$dout/daily_basket.dta", clear
	merge 1:1 item using "$dout\pricebyurbanregion.dta"
	keep if _merge==3
	drop _merge
	gen value = q_adj*mdprice
	collapse (sum) d_upline = value
	gen m = 1
	tab d_upline
	save "$dout/upline_ihs5", replace 

*------------------------------------------------------------------------------*
*11) Create poverty line out of food poverty line
*------------------------------------------------------------------------------*

	use "$dout\refgroup", clear
	gen m = 1
	merge m:1 m using "$dout/upline_ihs5", nogen
	gen logyz = log(rexpaggpc/d_upline)
	gen foodshr=rexp_cat01/rexpagg
	sum foodshr, d
	regress foodshr logyz [aw=hhsize*hh_wgt]
	gen nfoodshr=(1-_b[_cons])
	label var nfoodshr "Share of non-food expenditure in total exp"
	sum nfoodshr,d		
	gen m_pline= d_upline*(1+nfoodshr)
	collapse m_pline
	gen m = 1
	save "$dout\pline_ihs5", replace 
	
	
	