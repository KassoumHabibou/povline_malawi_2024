
*------------------------------------------------------------------------------*
** 	  National Statistical Office (NSO) & World Bank Poverty and Equity GP 	  **
*------------------------------------------------------------------------------*
** PROJECT			2019-20 Poverty measurement
** COUNTRY			Malawi
** COUNTRYCODE  	MWI
** YEAR				2019-2020
** SURVEY NAME		IHS5
** SECTION 			Food expenditure
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
*Additional commands (Uncomment only winsor2 if not installed) 
*------------------------------------------------------------------------------*

quietly ssc install winsor2

*------------------------------------------------------------------------------*
	
	use "$din/HH_MOD_G1", clear	

*------------------------------------------------------------------------------*   
*1) Drop records with zero or no consumption information
*------------------------------------------------------------------------------*
	
	*--------------------------------------------------------------------------*   
	*1a) Recode as missing if both the amount and the unit are either zero or missing
	*--------------------------------------------------------------------------*

	foreach n of numlist 3 4 6 7 {
	gen x = (hh_g0`n'a==0 | hh_g0`n'a==.) & (hh_g0`n'b=="")
	recode hh_g0`n'a 0=. if x==1                         
	drop x                                                
	}
	
	*--------------------------------------------------------------------------*  
    *1b) Recode as missing if either the amount or the unit are missing
	*--------------------------------------------------------------------------*      

	foreach n of numlist 3 4 6 7 {
	gen x = ((hh_g0`n'a==0 | hh_g0`n'a==.) & hh_g0`n'b!="") | (hh_g0`n'a!=. & hh_g0`n'b=="")
	tab x
	replace hh_g0`n'a = .  if x==1                      
	replace hh_g0`n'b = "" if x==1                      
	replace hh_g0`n'b_label = .  if x==1                
	drop x
	}		
	preserve
	foreach n of numlist 3 4 6 7 {
	replace hh_g0`n'b = "" if hh_g0`n'b=="a"
	}
	restore 
	replace hh_g05=. if hh_g05==.a
	replace hh_g05=. if hh_g05==240000

	*--------------------------------------------------------------------------*  
    *1c) Drop records with no consumption information
	*--------------------------------------------------------------------------*  

	egen x = rownonmiss(hh_g03a hh_g04a hh_g05 hh_g06a hh_g07a)
	egen x2 = rownonmiss(hh_g03b hh_g04b hh_g06b hh_g07b), strok
	drop if x==0 & x2==0                                   
	drop x x2                                               
	recode hh_g05 0=.                                       

*------------------------------------------------------------------------------*  
*2) Make all sourcers and total counsumption info match
*------------------------------------------------------------------------------*  
	
	gen info = 0 if missing(hh_g03a) & missing(hh_g04a) & missing(hh_g06a) & missing(hh_g07a)
	replace info = 1 if !missing(hh_g03a) & missing(hh_g04a) & missing(hh_g06a) & missing(hh_g07a)
	replace info = 2 if !missing(hh_g03a) & !missing(hh_g04a) & missing(hh_g06a) & missing(hh_g07a)
	replace info = 3 if !missing(hh_g03a) & missing(hh_g04a) & !missing(hh_g06a) & missing(hh_g07a)
	replace info = 4 if !missing(hh_g03a) & missing(hh_g04a) & missing(hh_g06a) & !missing(hh_g07a)
	replace info = 5 if !missing(hh_g03a) & !missing(hh_g04a) & !missing(hh_g06a) & missing(hh_g07a)
	replace info = 6 if !missing(hh_g03a) & !missing(hh_g04a) & missing(hh_g06a) & !missing(hh_g07a)
	replace info = 7 if !missing(hh_g03a) & missing(hh_g04a) & !missing(hh_g06a) & !missing(hh_g07a)
	replace info = 8 if missing(hh_g03a) & !missing(hh_g04a) & missing(hh_g06a) & missing(hh_g07a)
	replace info = 9 if missing(hh_g03a) & missing(hh_g04a) & !missing(hh_g06a) & missing(hh_g07a)
	replace info = 10 if missing(hh_g03a) & missing(hh_g04a) & missing(hh_g06a) & !missing(hh_g07a)
	replace info = 11 if missing(hh_g03a) & !missing(hh_g04a) & !missing(hh_g06a) & missing(hh_g07a)
	replace info = 12 if missing(hh_g03a) & !missing(hh_g04a) & !missing(hh_g06a) & !missing(hh_g07a)
	tab info
	lab def infoa 2 "Total & Purchased (2)" 3 "Total & Own produced (3)" 4 "Total & Others (4)" 5 "Total, Purchased & Own produced (5)" 6 "Total, Purchased & Other (6)" 7 "Total, Own produced & Other (7)" 8 "Purchased Only (8)" 
	lab val info infoa
	foreach var in a b b_label{
	replace hh_g03`var' = hh_g04`var' if info==8
	}
	replace info = 2 if info==8
	egen tot=rowtotal(hh_g04a hh_g06a hh_g07a)
	recast double tot
	gen disc = 1 if tot!=hh_g03a
	replace disc = 0 if missing(disc)
	foreach var in a b_label b{
	replace hh_g03`var'=hh_g04`var' if info==2 & disc==1
	}
	foreach var in a b b_label{
	replace hh_g03`var' = hh_g06`var' if info==3 & disc==1
	}
	foreach var in a b b_label{
	replace hh_g03`var' = hh_g07`var' if info==4 & disc==1
	}
	forvalues val = 5(1)7{
	drop if info==`val' & disc==1
	}
	drop tot disc
	drop if missing(hh_g05) & !missing(hh_g04a) & !missing(hh_g04b)

*------------------------------------------------------------------------------*  
*3) Reclassify "others" to standrd item code
*------------------------------------------------------------------------------*
	
	rename hh_g02 item 
			*These cereals represent refined maize
			replace item=102 if item==117 & (hh_g01_oth=="GRAIN MEAL" | hh_g01_oth=="GRANMILL" | hh_g01_oth=="MAIZEMEAL") 	
			*These are pumpkin types	
			replace item=410 if item==209 & (hh_g01_oth=="MAUNGU" | hh_g01_oth=="MAWUNGU" )		
			*These are peas	
			replace item=308 if item==310 & (hh_g01_oth=="COW PEAS" | hh_g01_oth=="COWPEAS" | hh_g01_oth=="MSEWURA" | hh_g01_oth=="PEAS" | hh_g01_oth=="CHIPELE(PEAS)" | hh_g01_oth=="DRIED PEAS" | hh_g01_oth=="PEASSHELLED" | hh_g01_oth=="CHICKPEAS(CHANA)")	
			*added "SOYA PIECES, SOYA PEACES,..." MAX
			replace item=306 if (item==310 & (hh_g01_oth=="SOYA"| hh_g01_oth=="SOYA  PIECES" | hh_g01_oth=="SOYA PEACES")) | (item==515 & (hh_g01_oth=="SOYA"|hh_g01_oth=="SOYA  PIECES" | hh_g01_oth=="SOYA PEACES" |hh_g01_oth=="SOYA PICES" | hh_g01_oth=="SOYA PIECE" | hh_g01_oth=="SOYA PIECECE" | hh_g01_oth=="SOYA PIECES" | hh_g01_oth=="SOYAPEACES" | hh_g01_oth=="SOYAPIECES" | hh_g01_oth=="YSOYA PIECES")) | (item==830 & (hh_g01_oth=="SOYA" | hh_g01_oth=="SOYA  PIECES" | hh_g01_oth=="SOYA PEACES" | hh_g01_oth=="SOYA PICES" | hh_g01_oth=="SOYA PIECE" | hh_g01_oth=="SOYA PIECECE" | hh_g01_oth=="SOYA PIECES" | hh_g01_oth=="SOYAPEACES" | hh_g01_oth=="SOYAPIECES" | hh_g01_oth=="YSOYA PIECES"))
			*We think it is "grainmill", put it under maize flour (refined)
			replace item=102 if item==310 & hh_g01_oth=="GRANMILL" 	
			*Put under pigean peas
			replace item=301 if item==310 & hh_g01_oth=="PIGEON PEAS"
			*Put under brown beans *add YELLOW BEANS* MAX
			replace item=302 if item==310 & (hh_g01_oth=="FRESHBEANS"|hh_g01_oth=="YELLOW BEANS")
			*Put under ground beans
			replace item=307 if item==310 & hh_g01_oth=="GROUND AND COOKED BEANS"
			*Put under groundnuts		
			replace item=304 if item==310 & hh_g01_oth=="PEANUT"
			*Put under Gathered wild green leaves *added ZIMBAMBA/MAKWERA* MAX
			replace item=307 if (item==412 & (hh_g01_oth=="DENJE"))| (item==310 & hh_g01_oth=="ZIMBAMBA/MAKWERA") 
			replace item=205 if (item==412 & (hh_g01_oth=="IRISH POTATOES"))
			*These can be classified under chicken, which has the same/comparable price
			replace item=508 if item==515 & (hh_g01_oth=="DUCK" | hh_g01_oth=="DUCKMEAT" ) 	
			*Put under Goat	
			replace item=505 if item==515 & hh_g01_oth=="GOATOFFALS"
			*Put under dried small fish
			replace item=5023 if item==515 & hh_g01_oth=="SMALL FISH"
			*Put under 'chicken pieces', we assume it is internal organ
			replace item=522 if item==515 & hh_g01_oth=="CHICKEN INTESTINES"
			*Put under cucumber *added ZIPWETE* MAX	
			replace item=409 if (item==610 & (hh_g01_oth=="CUCUMBER" | hh_g01_oth=="NKHAKA"))| (item==414 & hh_g01_oth=="ZIPWETE")
			*Put under apple
			replace item=609 if item==610 & (hh_g01_oth=="MIPOZA" | hh_g01_oth=="MEXICAN APPLE")
			*Put under "Mandazi, doughnut (vendor", *added ZITUMBUWA* MAX
			replace item=827 if item==830 & (hh_g01_oth=="FRIED MIXTURE OF MAIZE FLOUR/BANANA AND SODA" | hh_g01_oth=="MIXTURE OF MAIZE FLOUR/BANANA/SUGAR" | hh_g01_oth=="ZITUMBUWA")
			*Put under "samosa". HH trying to explain samosa //Put under IRISH POTATOES *added ZIBWENTE* MAX	
			replace item=828 if item==830 & (hh_g01_oth=="IRISH POTATOES AND FLOUR"|hh_g01_oth=="ZIBWENTE") 	
			*Put under "fried fish" (vendor), in Chichewa	
			replace item=826 if item==830 & hh_g01_oth=="KANYENYAWANSOMBA"
			*Put under "buns, scones
			replace item=112 if item==830 & hh_g01_oth=="SCONES"
			*Put under "tea"
			replace item=901 if item==830 & hh_g01_oth=="TEA"
			*Put under "samosa". HH trying to explain samosa in chichewa
			replace item=828 if item==830 & hh_g01_oth=="ZIMBWENTE"
			*Put under "pouder milk". It is a coffee creamer
			replace item=702 if item==709 & hh_g01_oth=="CREMORA"
			*Put under "pouder milk". It is a coffee creamer
			replace item=802 if item==804 & hh_g01_oth=="MISALE"
			*Put under "bottled beer". It is beer brand MANICA AND IMPALA 
			replace item=911 if item==916 & hh_g01_oth=="MANIKAANDIMPALA"
			*Put under "Soft drinks". * Added POWDERED FRUIT JUICE, WAKAWAKA POWDER JUICE* MAX
			replace item=907 if item==916 & (hh_g01_oth=="SODA" | hh_g01_oth=="POWDERED JUICE" | hh_g01_oth=="POWDERJUICE"| hh_g01_oth=="POWDERED  FRUIT  JUICE"|hh_g01_oth=="WAKAWAKA POWDER JUICE"|hh_g01_oth=="FROZY"|hh_g01_oth=="ENERGY DRINK"|hh_g01_oth=="DRAGON FROZY") 
			*Put under "WINE".Added WINE SHOOTER
			replace item=914 if item==916 & (hh_g01_oth=="WINE"|hh_g01_oth=="WINE SHOOTER")
			*Put under "Yeast, baking powder, bicarbonate of soda".
			replace item=812 if item==818 & hh_g01_oth=="SODA"
			*Add to Okra *MAX
			replace item=411 if item==414 & (hh_g01_oth=="THERERE"|hh_g01_oth=="THERERE WACHINYOLOMONYA")
			*Add to sorghum *MAX
			replace item=108 if item==117 & (hh_g01_oth=="SORGHUM GLOUR"|hh_g01_oth=="SORGHUM FLOUR"| hh_g01_oth=="SOHGUM FLOUR (UFA)"|hh_g01_oth=="SIRGHUM FLOUR")		
			*Put under wild fruits *MAX
			replace item=608 if item==610 & (hh_g01_oth=="NTHUDZA"|hh_g01_oth=="MATOWO")
			*Put NSAWAWA /PEAS under pigeon peas * MAX
			replace item=303 if item==310 & (hh_g01_oth=="NSAWAWA")
			*Put NKHUNGUZU,NKHUNGUDZU,NKHUNGUZI  under beans
			replace item=301 if item==310 & (hh_g01_oth=="NKHUNGUZU"|hh_g01_oth=="NKHUNGUDZU"|hh_g01_oth=="NKHUNGUZI")
			replace item=830 if item==830 & (hh_g01_oth=="ROASTED SWEET POTATO"|hh_g01_oth=="MBALAGA (FRIED SWEETPOTATOES)"|hh_g01_oth=="MBALAGA")
			replace item=302 if item==310 & (hh_g01_oth=="RED BEANS")
			replace item=404 if item==414 & (hh_g01_oth=="PRESERVED NKHWANI"|hh_g01_oth=="PRESERVED NKHWANI (MFUTSO)")
			replace item=407 if item==414 & (hh_g01_oth=="MPILU"|hh_g01_oth=="MOLINGA LEAVES"|hh_g01_oth=="MOLINA LEAVES")
			rename item hh_g02

*------------------------------------------------------------------------------*  
*4) Add up duplicates
*------------------------------------------------------------------------------*  
	
	*--------------------------------------------------------------------------*  
	*4.1) Make conversion factors suitable for merge to add up duplicates
	*--------------------------------------------------------------------------*  

			preserve
			use "$din\IHS_Conversion_Factor_2020.dta",clear
			rename unit_code unit
			drop if unit=="23"
			rename item_code item 
			rename factor_ihs5 factor
			keep region item unit factor 
			save "$din\IHS_Conversion_Factor_formerge.dta",replace
			restore
			
			preserve
			use "$din\IHS_Conversion_Factor_2020.dta",clear
			rename unit_code unit
			keep if unit=="23"
			rename item_code item
			rename(Otherunit factor_ihs5)(unit_other o_factor)
			keep region item unit_other o_factor
			save "$din\IHS_Other_Conversion_Factor_formerge.dta",replace
			restore

	*--------------------------------------------------------------------------* 
	*4.2) transform units to Kg and add up
	*--------------------------------------------------------------------------* 
			
			quietly bysort HHID hh_g02:  gen dup = cond(_N==1,0,_n)
			replace dup = 1 if dup>1
			merge m:1 HHID using "$dout\basicvars_ihs5" ,  keepusing(region)
			keep if _merge==3
			drop _merge
			rename hh_g02 item
			foreach var in 3 4 6 7{
			rename hh_g0`var'b unit
			merge m:1 region item unit using "$din\IHS_Conversion_Factor_formerge.dta", keepusing(factor)
			drop if _merge==2
			drop _merge
			replace factor = . if dup==0
			rename(unit factor)(hh_g0`var'b factor`var')
			}
			foreach var in 3 4 6 7{
			replace hh_g0`var'a = hh_g0`var'a*factor`var' if !missing(factor`var')
			replace hh_g0`var'b = "1" if !missing(factor`var')
			replace hh_g0`var'b_label = 1 if !missing(factor`var')
			drop factor`var'
			}
			foreach var in 3 4 6 7{
			quietly bysort HHID item hh_g0`var'b:  gen dup`var' = cond(_N==1,0,_n)
			bysort HHID item hh_g0`var'b: egen g0`var'a = sum(hh_g0`var'a)
			}
			bysort HHID item hh_g04b: egen g05 = sum(hh_g05)
			replace hh_g05 = g05 if dup4>0 & !missing(dup4)
			foreach var in 3 4 6 7{
			replace hh_g0`var'a = g0`var'a if dup`var'>0 & !missing(dup`var')
			}	
			duplicates drop HHID item, force
			drop region dup3 g03a dup4 g04a dup6 g06a dup7 g07a g05
			tab info if dup==1
			foreach var in a b_label b{
			replace hh_g03`var'=hh_g04`var' if info==2 & dup==1
			}
			foreach var in a b_label b{
			replace hh_g03`var'=hh_g06`var' if info==3 & dup==1
			}
			foreach var in a b_label b{
			replace hh_g03`var'=hh_g07`var' if info==7 & dup==1
			}
			rename item hh_g02
			drop dup
			
	*--------------------------------------------------------------------------* 
	*4.3) Replace if new missing
	*--------------------------------------------------------------------------* 

			foreach var in 3 4 6 7{
			replace hh_g0`var'a = . if hh_g0`var'a==0
			replace hh_g0`var'b ="" if hh_g0`var'a==.
			}
			replace hh_g05 = . if hh_g04a==.

*------------------------------------------------------------------------------* 
*5) Clean to work with total consumption
*------------------------------------------------------------------------------* 

	foreach val in 4 6 7{
	gen s_`val' = hh_g0`val'a/hh_g03a
	replace s_`val' = 0 if missing(s_`val') 
	}
	foreach h in 10 25 27 37 4 6 7 8 9{
	foreach val in 3 4 6 7{
	replace hh_g0`val'b = hh_g0`val'b+"A" if hh_g0`val'b=="`h'" & hh_g0`val'c==1
	replace hh_g0`val'b = hh_g0`val'b+"B" if hh_g0`val'b=="`h'" & hh_g0`val'c==2
	replace hh_g0`val'b = hh_g0`val'b+"C" if hh_g0`val'b=="`h'" & hh_g0`val'c==3	
	}
	}
	keep HHID info hh_g02 hh_g03a hh_g03b hh_g03b_label hh_g03b_oth hh_g05 s_4 s_6 s_7
	replace hh_g05 = hh_g05*(2-s_4)	// no entiendo ese 2 - el share de los item comprados
	rename(hh_g02 hh_g03a hh_g03b hh_g03b_label hh_g03b_oth hh_g05)(item quant unit unit_label unit_other value)
	lab var s_4 "Purchased share"
	lab var s_6 "Produced share"
	lab var s_7 "Other surces share"		
	keep HHID info item quant unit unit_label unit_other value s_4 s_6 s_7
	
*------------------------------------------------------------------------------* 
*7) Merging with basic variables and conversion factors
*------------------------------------------------------------------------------*      
	
	merge m:1 HHID using "$dout\basicvars_ihs5" ,nogen
	drop if missing(item)
	merge m:1 region item unit using "$din\IHS_Conversion_Factor_formerge.dta"
	drop if _merge==2
	drop _merge
	merge m:1 item region unit_other using "$din\IHS_Other_Conversion_Factor_formerge.dta"
	replace factor = o_factor if unit=="23" & missing(factor)
	drop o_factor _merge	

*------------------------------------------------------------------------------* 
*8) Replace missing factors
*------------------------------------------------------------------------------* 

	*--------------------------------------------------------------------------* 	
	*8.1) Weight explicit in "unit" variable 
	*--------------------------------------------------------------------------* 	
	
	replace factor = 1 if unit=="1" & missing(factor)
	replace factor = 0.001 if unit=="18" & missing(factor)	
	replace factor = 0.3 if unit=="31" & missing(factor)
	replace factor = 0.6 if unit=="32" & missing(factor)	
	replace factor = 0.7 if unit=="33" & missing(factor)	
	replace factor = 0.15 if unit=="34" & missing(factor)	
	replace factor = 0.4 if unit=="35" & missing(factor)	
	replace factor = 0.5 if unit=="36" & missing(factor)	
	replace factor = 1 if unit=="37" & missing(factor)	
	replace factor = 0.025 if unit=="41" & missing(factor)	
	replace factor = 0.05 if unit=="42" & missing(factor)
	replace factor = 0.1 if unit=="43" & missing(factor)
	replace factor = 0.25  if unit=="65" & missing(factor)
	replace factor = 0.025 if unit=="70" & missing(factor)
	replace factor = 0.1 if unit=="71" & missing(factor)
	replace factor = 0.25 if unit=="72" & missing(factor)
	replace factor = 0.5 if unit=="73" & missing(factor)	
	
	*--------------------------------------------------------------------------* 	
	*8.2)  Weight explicit in "other unit" variable 
	*--------------------------------------------------------------------------* 	
	
	merge m:1 unit_other using "$din\IHS_Other_Units_2020"
	replace factor = o_factor if missing(factor) & !missing(o_factor)
	drop o_chang o_unit o_factor _merge
	
	*--------------------------------------------------------------------------*
	*8.3) Liquid specific (based on IHS4 do file)
	*--------------------------------------------------------------------------*
		
	replace factor = 1 if unit=="15" & (inlist(item,705,706,813) | inrange(item,904,915)) & missing(factor)	   
	replace factor = 0.001 if unit=="19" & (inlist(item,705,706,813)| inrange(item,904,915)) & missing(factor)	 
	*815 Jam, jelly, 817 Honey
	replace factor = 1*1.4     if unit=="15" & inlist(item,815,817) & missing(factor)	 
	replace factor = 0.001*1.4 if unit=="19" & inlist(item,815,817) & missing(factor)	 
	*701 Fresh milk
	replace factor = 1*1.1     if unit=="15" & inlist(item,701) & missing(factor)	  
	replace factor = 0.001*1.1 if unit=="19" & inlist(item,701) & missing(factor)	 
	*803 Cooking oil
	replace factor = 1*0.92     if unit=="15" & inlist(item,803) & missing(factor)	 
	replace factor = 0.001*0.92 if unit=="19" & inlist(item,803) & missing(factor)	 
	*814 Hot sauce
	replace factor = 1*1.08     if unit=="15" & inlist(item,814) & missing(factor)	     
	replace factor = 0.001*1.08 if unit=="19" & inlist(item,814) & missing(factor)	 

	*--------------------------------------------------------------------------*
	*8.4)  Cooking oil & Biscuits (based on IHS4 do file)
	*--------------------------------------------------------------------------*

	gen misskg = missing(factor)
	*803: Cooking oil
	qui sum quant if item==803 & misskg==1 , det
	replace factor=0.0245 if item==803 & misskg==1 & quant<r(p50) & missing(factor) 
	replace factor=0.07 if item==803 & misskg==1 & inrange(quant,r(p50),r(p99)) & missing(factor) 
	replace misskg=0 if item==803 & misskg==1 & inrange(quant,r(min),r(p99)) & missing(factor)
	*113: Biscuits
	qui sum quant if item==113 & misskg==1 , det
	replace factor=0.091 if item==113 & misskg==1 & inrange(quant,r(min),r(p99)) & missing(factor)	
	
	*gen pqkg = quant*factor 
	*winsor2 pqkg, replace by(item) cuts (5 95)
	
	save "$dout\preconvertfood_ihs5", replace 
	
*------------------------------------------------------------------------------*
*9) Consumption quantities and values
*------------------------------------------------------------------------------*
	
	*--------------------------------------------------------------------------*
	*9.1) Quantity
	*--------------------------------------------------------------------------*
	use "$dout\preconvertfood_ihs5", clear
	
	gen qkg = quant*factor 
	*13,249 beacuse of missing factor
	winsor2 qkg, replace by(item) cuts (5 95)
	gen pcqkg = qkg/hhsize
	label var pcqkg "Quantity in kgs per person per week"
	
	*--------------------------------------------------------------------------*
	*9.2) Value
	*--------------------------------------------------------------------------*
	
	winsor2 value, replace by(item) cuts (5 95)
	gen pcval = value/hhsize                                    
	label var pcval "Value in MK per person per week"
	*55,798 because of non purchased
			
*------------------------------------------------------------------------------*
*10) Calculate prices
*------------------------------------------------------------------------------*
		
	gen price = value/qkg             
	*66,923 missing price: 55,798 because no value. 11,125 because not able to convert
	label var price "Price per kg"	
	winsor2 price, replace by(item) cuts (5 95)	
	gen reported_price = price

	
*------------------------------------------------------------------------------*
*11) Lowest level price 
*------------------------------------------------------------------------------*

	*--------------------------------------------------------------------------*
	*11.1) item district smonth syear level
	*--------------------------------------------------------------------------*
		
		preserve
		keep if price!=. 
		set seed 1234
		gen seed = runiform()
		sort item district smonth syear HHID seed //no funciona si el HHID y el seed van al inicio
		unique report item district smonth syear
		collapse (p50) price1=price (count) c1=price [aw=hh_wgt], by(item district smonth syear)
		save "$dout\temporal_price1.dta", replace 
		restore
		merge m:1 item district smonth syear using "$dout\temporal_price1.dta",nogen
		replace price1=. if c1<10 
		erase "$dout\temporal_price1.dta"	

	*--------------------------------------------------------------------------*
	*11.2) item urban_region smonth syear level
	*--------------------------------------------------------------------------*
		
		preserve
		keep if price!=. 
		set seed 1234
		gen seed = runiform()
		sort item district smonth syear HHID seed //no funciona si el HHID y el seed van al inicio
		unique report item district smonth syear
		collapse (p50) price2=price (count) c2=price [aw=hh_wgt], by(item urban_region smonth syear)
		save "$dout\temporal_price2.dta", replace           
		restore
		merge m:1 item urban_region smonth syear using "$dout\temporal_price2.dta",nogen
		replace price2=. if c2<10
		erase "$dout\temporal_price2.dta"
		
	*--------------------------------------------------------------------------*
	*11.3) item urban_region level
	*--------------------------------------------------------------------------*
		
		preserve
		keep if price!=.   
		set seed 1234
		gen seed = runiform()
		sort item district smonth syear HHID seed //no funciona si el HHID y el seed van al inicio
		unique report item district smonth syear
		collapse (p50) price3=price (count) c3=price [aw=hh_wgt], by(item urban_region)
		save "$dout\temporal_price3.dta", replace            
		restore
		merge m:1 item urban_region using "$dout\temporal_price3.dta", nogen
		replace price3=. if c3<10
		erase "$dout\temporal_price3.dta"

	*--------------------------------------------------------------------------*
	*11.4) item level
	*--------------------------------------------------------------------------*
		
		preserve
		keep if price!=. 
		set seed 1234
		gen seed = runiform()
		sort item district smonth syear HHID seed //no funciona si el HHID y el seed van al inicio
		unique report item district smonth syear
		collapse (p50) price4=price (count) c4=price [aw=hh_wgt] , by(item)
		save "$dout\temporal_price4.dta", replace            
		restore
		merge m:1 item using "$dout\temporal_price4.dta", nogen 
		erase "$dout\temporal_price4.dta"	
		
	*--------------------------------------------------------------------------*
    *11.5) Generate lower level price posible 
	*--------------------------------------------------------------------------*
		
		gen pricenat = price1                                     
		replace pricenat = price2 if pricenat==.                 
		replace pricenat = price3 if pricenat==.                  
		replace pricenat = price4 if pricenat==.                  
		drop price1 price2 price3 price4 c1 c2 c3 c4
		
	*--------------------------------------------------------------------------*
	*11.6) Replace unit values with median unit values
	*--------------------------------------------------------------------------*	
		
		replace price = pricenat   
		drop pricenat

*------------------------------------------------------------------------------*
*12) Replace q based on value  (and prices) for missing Q
*------------------------------------------------------------------------------*
	
	gen qkgfromval=value/price                               
	gen pcqkgfromval=qkgfromval/hhsize	
	replace qkg = qkgfromval if missing(qkg)
	replace pcqkg = pcqkgfromval if missing(pcqkg)	
	drop qkgfromval pcqkgfromval
	*out of 12,485, 10,780 could be restored
	
*------------------------------------------------------------------------------*
*11) Replace value by Q * price
*------------------------------------------------------------------------------*
	
	gen reported_value = value
	replace value=qkg*price
	replace pcval=value/hhsize

*------------------------------------------------------------------------------* 
*14) Save for poverty line
*------------------------------------------------------------------------------*
	
	drop if missing(qkg)
	save "$dout\food_ihs5_forpovline", replace

*------------------------------------------------------------------------------* 
*15) Save median prices by month for CPI 
*------------------------------------------------------------------------------* 
	
	*--------------------------------------------------------------------------*
	*15.1) At the regional level
	*--------------------------------------------------------------------------*
	preserve
	drop if missing(price)
	collapse (p50) price [aw=hh_wgt], by(urban_region item syear smonth)
	sort urban_region syear smonth item
	foreach i in syear smonth price {
	rename `i' `i'_ihs5
	}
	order urban_region syear smonth item
	save "$dout\unitvalue_ihs5_month", replace
	restore

	*--------------------------------------------------------------------------*
	*15.2) At the national level
	*--------------------------------------------------------------------------*
	
	preserve
	drop if missing(price)
	collapse (p50) price [aw=hh_wgt], by(item syear smonth)
	sort  syear smonth item
	foreach i in syear smonth price {
	rename `i' `i'_ihs5
	}
	decode item, gen(itemstr)
	order  syear smonth item itemstr	
	save "$dout\unitvalue_ihs5_month_nat", replace
	restore 
	
	*--------------------------------------------------------------------------*
	*15.3) Item regional
	*--------------------------------------------------------------------------*
	
	preserve
	drop if missing(price)
	collapse (p50) price [aw=hh_wgt], by(item urban_region)
	sort   item
	foreach i in price {
	rename `i' `i'_ihs5
	}
	decode item, gen(itemstr)
	order item itemstr	
	save "$dout\unitvalue_ihs5", replace
	restore 
	
	*--------------------------------------------------------------------------*
	*15.4) Item national
	*--------------------------------------------------------------------------*
	
	preserve
	drop if missing(price)
	collapse (p50) price [aw=hh_wgt], by(item)
	sort   item
	foreach i in price {
	rename `i' `i'_ihs5
	}
	decode item, gen(itemstr)
	order item itemstr	
	save "$dout\unitvalue_ihs5_nat", replace
	restore 	
	
	*--------------------------------------------------------------------------*
	*15.5) Item regional
	*--------------------------------------------------------------------------*
	
	preserve
	drop if missing(price)
	collapse (p50) price [aw=hh_wgt], by(item urban_region)
	sort   item
	foreach i in price {
	rename `i' `i'_ihs5
	}
	decode item, gen(itemstr)
	order item itemstr	
	save "$dout\unitvalue_ihs5", replace
	restore 
	
	*--------------------------------------------------------------------------*
	*15.6) Item national reference month
	*--------------------------------------------------------------------------*
	
	preserve
	keep if inlist(smonth,4,5) & inlist(syear,2019)
	drop if missing(price)
	collapse (p50) price [aw=hh_wgt], by(item)
	sort  item
	foreach i in price {
	rename `i' `i'_ihs5
	}
	decode item, gen(itemstr)
	order item itemstr	
	save "$dout\unitvalue_ihs5_nat_rm", replace
	restore 
	
	*--------------------------------------------------------------------------*
	*15.7) Item regional reference month
	*--------------------------------------------------------------------------*
	
	preserve
	keep if inlist(smonth,4,5) & inlist(syear,2019)
	drop if missing(price)
	collapse (p50) price [aw=hh_wgt], by(item urban_region)
	sort item
	foreach i in price {
	rename `i' `i'_ihs5
	}
	decode item, gen(itemstr)
	order item itemstr	
	save "$dout\unitvalue_ihs5_rm", replace
	restore 	
	
	*--------------------------------------------------------------------------*
	*15.8) Number of items purchased
	*--------------------------------------------------------------------------*
	
	preserve
	drop if value==.
	keep if syear==2019 & (smonth==4 | smonth==5)
	gen n_ihs5=1  
	collapse (sum) n_ihs5, by(item)
	save "$dout\number_purchasers_ihs5.dta", replace 
	restore	
	
*------------------------------------------------------------------------------* 
*16) Save for consumption
*------------------------------------------------------------------------------* 
	
	keep item HHID reported_value value s_4 s_6 s_7
	foreach j in 4 6 7 {
	gen value_`j'=value*s_`j'
	}
	keep HHID item reported_value value value_4 value_6 value_7
	save "$dout\food_ihs5", replace 

