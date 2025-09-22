
*------------------------------------------------------------------------------*
** 	  National Statistical Office (NSO) & World Bank Poverty and Equity GP 	  **
*------------------------------------------------------------------------------*
** PROJECT			2019-20 Poverty measurement
** COUNTRY			Malawi
** COUNTRYCODE  	MWI
** YEAR				2019-2020
** SURVEY NAME		IHS5
** SECTION 			Non food expenditure
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

	*quietly ssc install winsor2

*------------------------------------------------------------------------------*

*------------------------------------------------------------------------------*
*1) Education expenditure
*------------------------------------------------------------------------------*

	use "$din/HH_MOD_B", clear
	gen age = hh_b05a															
	replace age = hh_b05a+ hh_b05b/12 if hh_b05b!=.								
	gen male = hh_b03==1 if inrange(hh_b03,1,2) 								
	keep HHID PID age male 														
	sort HHID PID
	save "$dout\agemale", replace

	use "$din/HH_MOD_C", clear
	merge 1:1 HHID PID using "$dout\agemale",nogen 								
	merge m:1 HHID using "$dout\basicvars_ihs5" , nogen							

	*--------------------------------------------------------------------------*
	*1.1) Components of Education Exp	
	*--------------------------------------------------------------------------*
	
	egen temp = rownonmiss(hh_c22?) 				
	drop if temp==0 								
	drop temp 
	recode hh_c22* (0 999 9999 99999 999999 9999999 = .) 						     	 
	egen temp = rownonmiss(hh_c22?)
	drop if temp==0   
	drop temp
	egen edut = rsum(hh_c22a - hh_c22i)	
	label var edut "Total educational expenditure as sum of components"

 	*--------------------------------------------------------------------------*
	*1.2) Expenditure Reported as Total
	*--------------------------------------------------------------------------*
	
	egen x = rownonmiss(hh_c22a - hh_c22i) 
	gen edux = hh_c22j if x==0 //no me es claro por que se usa c22j si este aunque aparece total en el cuestionario aparece que es Pocket money and shopping al hacer un br hh_c22* x edux if x==0 se observa que hay missings en el c22j pero no en el c22l que es el total
	label var edux "Total expenditure in education when no component was reported"
	drop x
	recode hh_c22? edut (.=0) 

	*--------------------------------------------------------------------------*	
	*1.3) Fix misclassification of school attended 
	*--------------------------------------------------------------------------*
	
	recode hh_c16 (.=99) 
	gen temp = inrange(hh_c16,11,15)& inrange(hh_c08,9,23) & inrange(hh_c12,9,23) & age>13 //c16 primaria, c8 secundaria, c12 secundaria y unviversidad 
	recode hh_c16 11=21 if temp==1           									
	//From gov pri to gov sec 
	recode hh_c16 12=26 if temp==1           									
	//From private non-rel to other sec
	recode hh_c16 13=23 if temp==1           									
	//From church pri to church sec 
	recode hh_c16 14=24 if temp==1  									
	//From Islamic pri to Islamic sec
	recode hh_c16 15=26 if temp==1           									
	//From other pri to other sec
	drop temp
	recode hh_c16 (.=99) if inrange(hh_c16,31,33) & inrange(hh_c08,0,11) & inrange(hh_c12,0,11)

	*--------------------------------------------------------------------------*	
	*1.4) Correct for misclassification of educ exp.  
	*--------------------------------------------------------------------------*	

	replace hh_c22i=hh_c22i+hh_c22a if hh_c16==11 & hh_c22a!=.	
	//Reclassify tuition fee into others for gov primary
	recode hh_c22a 0/max=0 if hh_c16==11                
	//Recode tuition fees as zero for gov school
	replace hh_c22i = hh_c22i + hh_c22e if hh_c16==11 & hh_c22e>0 & hh_c22e!=.
	//Add boarding fees to "other" expenditure for government schools 
	recode hh_c22e 0/max=0 if hh_c16==11                 
	//Recode boarding fees as zero for gov school
	replace hh_c22i = hh_c22i + hh_c22e if hh_c16==25    
	//Add boarding fees to "other" expenditure for night schools
	recode hh_c22e 0/max = 0 if hh_c16==25               
	//Recode boarding fees as zero for night school
	replace hh_c22i = hh_c22i + hh_c22h if inrange(hh_c16,31,33)                
	//Add parent/teacher association fees to "other" fees for universities
	recode hh_c22h 0/max = 0 if inrange(hh_c16,31,33)    
	//Recode parent/teacher association fees to zero for universities 
	replace hh_c22i = hh_c22i + hh_c22d if inrange(hh_c16,31,33)
	//Add school uniform fees to "other" for universities
	recode hh_c22d 0/max = 0 if inrange(hh_c16,31,33)    
	//Recode school uniform fees to zero for universities 

	*--------------------------------------------------------------------------*	
	*1.5) Trim expenditre
	*--------------------------------------------------------------------------*

	rename edut hh_c22t                             
	rename edux hh_c22x	 
	foreach val in a b c d e f g h i j t x{
	replace hh_c22`val' = . if hh_c22`val'==0
	winsor2 hh_c22`val', replace by(hh_c16) cuts (5 95)
	}
	save "$dout\nonfood_educa_precategorize", replace 
	
	*--------------------------------------------------------------------------*
	*1.6) Agregate expenditure and collapse
	*--------------------------------------------------------------------------*	
	
	egen edut = rsum(hh_c22a - hh_c22i)                   
	replace edut = hh_c22x if hh_c22x!=.                 
	gen exp_cat101 = edut                          
	collapse (sum) exp_cat101, by(HHID)  
	label var exp_cat10 "Annual expenditure on education" 
	sort HHID
	save "$dout\nonfood_educa", replace  

*------------------------------------------------------------------------------*
*2) Health expenditure 
*------------------------------------------------------------------------------*

	use "$din/HH_MOD_D", clear
	merge m:1 HHID using "$dout\basicvars_ihs5" , nogen
  
 	*--------------------------------------------------------------------------*
	*2.1) Drop records with zero or no exp data (for cleaning purposes) 
	*--------------------------------------------------------------------------*
	gl healthexp hh_d10-hh_d12 hh_d14-hh_d16 hh_d19-hh_d21 
	//Represent health exp variables in gl 'healthexp' 
	recode $healthexp (0=.)                              
	//Recode zero exp as missing
	egen temp = rownonmiss($healthexp)                   
	//temp counts number of non-missing exp variables per row 
	drop if temp==0                                      
	drop temp
	foreach n in 10 11 12 14 15 16 19 20 21 {
	rename hh_d`n' exp`n'
	}
	
	*--------------------------------------------------------------------------*
	*2.2) Trim expenditure
	*--------------------------------------------------------------------------*
	
	foreach n in 10 11 12 14 15 16 19 20 21 {
	winsor2 exp`n', replace cuts (5 95)
	}
	
	*--------------------------------------------------------------------------*
	*2.3) Convert 4 week (monthly) exp to annual exp 
	*--------------------------------------------------------------------------*	
	
	foreach v of varlist exp10 exp11 exp12 {
	replace `v' = `v'*13                            	 
	}
	save "$dout\nonfood_health_precategorize", replace 
	
	*--------------------------------------------------------------------------*	
	*2.4) Categorize health exp by assigning COICOP codes
	*--------------------------------------------------------------------------*
	
	gen  exp_cat061 = exp12
	label var exp_cat061 "Annual expenditure on non-prescription medicines" 
	egen exp_cat062 = rsum(exp10 exp11 exp19 exp20 exp21)
	label var exp_cat062 "Annual expenditure on Out-patient services"
	egen exp_cat063 = rsum(exp14 exp15 exp16)
	label var exp_cat063 "Annual expenditure on hospital services"
		
	*--------------------------------------------------------------------------*
	*2.5) Aggregate exp to HH level and save data in temporary folder 
	*--------------------------------------------------------------------------*
	
	collapse (sum) exp_cat*, by(HHID) 
	save "$dout\nonfood_health", replace  

*------------------------------------------------------------------------------*
*3) Household utility expenditure
*------------------------------------------------------------------------------*
	
	use "$din/HH_MOD_F", clear
	merge 1:1 HHID using "$dout\basicvars_ihs5" , nogen
	
	*--------------------------------------------------------------------------*	  
	*3.1) Extract data and convert to monthly exp
	*--------------------------------------------------------------------------*

	recode hh_f18 (0=.)                                
	gen exp18 = hh_f18*4.33       // por que son 4.33 la transformacion de semana a mes                      
	label var exp18 "Monthly expenditure on firewood"
	recode hh_f25 (0 9999 = .)
	gen exp25 = .
	replace exp25 = hh_f25/hh_f26a if hh_f26b==5 
	replace exp25 = (hh_f25*4.33)/hh_f26a if hh_f26b==4
	replace exp25 = hh_f25*30.4/hh_f26a if hh_f26b==3
	label var exp25 "Monthly expenditure on electricity" 
	recode hh_f35 (0 = .)                              
	gen exp35 = hh_f35
	label var exp35 "Monthly expenditure on cell phone services" 
	recode hh_f37 (0 = .)                    
	gen exp37 = hh_f37
	label var exp37 "Monthly expenditure on drinking water" 

	*--------------------------------------------------------------------------*
	*3.2) Trim expenditure
	*--------------------------------------------------------------------------*
		
	foreach n in 18 25 35 37{
	winsor2 exp`n', replace cuts (5 95)
	}

	*--------------------------------------------------------------------------*
	*3.3) Change from monthly to annual exp
	*--------------------------------------------------------------------------*
	
	foreach v in 18 25 35 37{
	replace exp`v' = exp`v'*12                  
	}
	label var exp18 "Annual expenditure on firewood" 
	label var exp25 "Annual expenditure on electricity" 
	label var exp35 "Annual expenditure on cell phone services" 
	label var exp37 "Annual expenditure on drinking water" 
	save "$dout\nonfood_house_precategorize", replace   
	
	*--------------------------------------------------------------------------*	
	*3.4) Categorize utility exp by assigning COICOP codes
	*--------------------------------------------------------------------------*
	
	egen exp_cat045_f = rsum(exp18 exp25)
	gen  exp_cat083   = exp35
	gen  exp_cat044   = exp37
	label var exp_cat045_f "Annual expenditure on firewood and electricity" 
	label var exp_cat083   "Annual expenditure on cell phone services" 
	label var exp_cat044   "Annual expenditure on drinking water" 

	*--------------------------------------------------------------------------*
	*3.5) Aggregate exp to HH level and save data in temporary folder 
	*--------------------------------------------------------------------------*
	collapse (sum) exp_cat*, by(HHID)
	sort HHID
	save "$dout\nonfood_house", replace 

*------------------------------------------------------------------------------*
*4) Non food expendiutre (IJK)
*------------------------------------------------------------------------------*
	
	*--------------------------------------------------------------------------*
	*4.1) Load data for each recall period and make iteady for appending
	*--------------------------------------------------------------------------*
	
		*4.1.1) Load Module I1, One week recall period
		
		use "$din/HH_MOD_I1", clear // trasnporte cigarrillos objetos para la casa
		decode hh_i02, gen(hh_i00)                    
		//Store value labels in a separate variable
		label copy item set1                           
		//Make a copy of the value lables for hh_i02
		label val hh_i02 set1                         
		//Change value label name for hh_i02 from set to set1  
		save "$dout\last7dx", replace   

		*4.1.2) Load Module I2, One month recall period
		
		use "$din/HH_MOD_I2", clear // aseo, vestido zapatos, cremas, entretenimeinto 
		decode hh_i05, gen(hh_i00)                    
		//Store value labels in a separate variable
		rename hh_i04 hh_i01                          
		//Rename varible to match variable in Module I1
		rename hh_i06 hh_i03                          
		//Rename varible to match variable in Module I1
		label copy item2 set2                           
		//Make a copy of the value lables for hh_i02
		label val hh_i05 set2                         
		//Change value label name for hh_i02 from set to set2
		save "$dout\last1mx", replace 

		*4.1.3) Load Module J, three months recall period
		
		use "$din/HH_MOD_J", clear //ropa de ni;os y cosas de bebes
		decode hh_j02, gen(hh_i00)                    
		//Store value labels in a separate variable
		rename hh_j01 hh_i01                          
		//Rename varible to match variable in Module I1
		rename hh_j03 hh_i03                          
		//Rename varible to match variable in Module I1
		label copy item3 set3                           
		//Make a copy of the value lables for hh_i02
		label val hh_j02 set3                         
		//Change value label name for hh_i02 from set to set3
		save "$dout\last3mx", replace


		*4.1.4) Load Module K1, 12 months recall period
		
		use "$din/HH_MOD_K1", clear   
		cap count if hh_k03==. & hh_k04!=.                
		rename hh_k01 hh_i01                          
		//Rename varible to match variable in Module I1
		rename hh_k03 hh_i03                          
		//Rename varible to match variable in Module I1
		decode hh_k02, gen(hh_i00)                    
		//Store value labels in a separate variable
		label copy item4 set4                          
		//Change value label name for hh_i02 from set to set4
		label val hh_k02 set4                         
		//Change value label name for hh_i02 from set to set4

	*--------------------------------------------------------------------------*		
	*4.2) Append the exp files for one week, one month, and 3 months recall period
	*--------------------------------------------------------------------------*
	
	append using "$dout\last7dx"
	erase "$dout\last7dx.dta"
	append using "$dout\last1mx"
	erase "$dout\last1mx.dta"
	append using "$dout\last3mx"
	erase "$dout\last3mx.dta"
	merge m:1 HHID using "$dout\basicvars_ihs5" , nogen
	
	*--------------------------------------------------------------------------*
	*4.3) Store the item code information in one variable  
	*--------------------------------------------------------------------------*
		
	gen item=.
	replace item=hh_i02
	replace item=hh_i05 if item==. & hh_i05!=.
	replace item=hh_j02 if item==. & hh_j02!=.
	replace item=hh_k02 if item==. & hh_k02!=. 
	drop hh_i02 hh_i05 hh_j02 hh_k02
	keep if hh_i03>0 & hh_i03!=.

	*--------------------------------------------------------------------------*
	*4.4) Drop non-consumption categories or those that involve double-counting.
	*--------------------------------------------------------------------------*
	
	drop if inlist(item,211,216,217)                    
	drop if inlist(item,408,409,410,411,412,413,414,415,416,417,418,419,420)

	*--------------------------------------------------------------------------*
	*4.5) Trim expenditure
	*--------------------------------------------------------------------------*
	
	bysort item: inspect hh_i03
	winsor2 hh_i03, replace by(item) cuts (5 95)
	bysort item: inspect hh_i03
	save "$dout\nonfood_ijk_precategorize", replace   
	
	*--------------------------------------------------------------------------*	
	*4.6) Categorize exp components by assigning COICOP codes
	*--------------------------------------------------------------------------*
	
	gen exp_cat045_i1 = hh_i03 if inlist(item,101,102,104,105)
	//Electricity, gas and other fuels: COICOP 3-DIGIT CODE 045	
	gen exp_cat022    = hh_i03 if item==103                  
	//Tobacco: COICOP 3-DIGIT CODE 022
	gen exp_cat073    = hh_i03 if inrange(item,107,109)      
	//Public transport: COICOP 3-DIGIT CODE 073
	gen exp_cat095_i1 = hh_i03 if item==106                  
	//Newspapers,magazines, stationery: COICOP 3-DIGIT CODE 095
	gen exp_cat056_i2 = hh_i03 if inlist(item,201,215)       
	//Milling fees, wages to servants: COICOP 3-DIGIT 056
	gen exp_cat121    = hh_i03 if inrange(item,202,207)      
	//Personal care: COICOP 3-DIGIT 121
	gen exp_cat045_i2 = hh_i03 if item==209                  
	//Lightbulbs: COICOP 3-DIGIT 045
	gen exp_cat081    = hh_i03 if item==210                  
	//Postal services: COICOP 3-DIGIT 081 
	gen exp_cat072    = hh_i03 if inrange(item,212,214)      
	//Operation of vehicles: COICOP 3-DIGIT 072 
	gen exp_cat053_i2 = hh_i03 if inlist(item,218)           
	//Repairs to household & personal items: COICOP 3-digit 053
	gen exp_cat093    = hh_i03 if item==219                  
	//Exp on pets: COICOP 3-DIGIT 093
	gen exp_cat055_i  = hh_i03 if inlist(item,220,221)       
	//Batteries, recharging batteries : COICOP 3-digit 055
	gen exp_cat031 = hh_i03 if inrange(item,301,321) | inrange(item,326,327)
	//Clothing : COICOP 3-DIGIT 031 
	gen exp_cat032   = hh_i03 if inrange(item,322,325)      
	//Shoes: COICOP 3-DIGIT 032
	gen exp_cat054   = hh_i03 if inlist(item,328,329,342)
	//Bowls, cooking utensils: COICOP 3-DIGIT 054	
	gen exp_cat056_j = hh_i03 if inlist(item,330,340)
	//Cleaning utensils: COICOP 3-DIGIT 056	
	gen exp_cat055_j = hh_i03 if inlist(item,331,333)       
	//Torch, lamp: COICOP 3-DIGIT 055
	gen exp_cat123   = hh_i03 if item==332                  
	//Umbrella: COICOP 3-DIGIT 123
	gen exp_cat095_j = hh_i03 if  inrange(item,334,335)     
	//Stationery, books: COICOP 3-DIGIT 095
	gen exp_cat091_j = hh_i03 if item==336                  
	//Music/video cassette: COICOP 3-DIGIT 091
	gen exp_cat094   = hh_i03 if item==337                  
	//Sports tickets: COICOP 3-DIGIT 094
	gen exp_cat051_j = hh_i03 if item==338                  
	//House decorations  : COICOP 3-DIGIT 051                  
	gen exp_cat112   = hh_i03 if inlist(item,339,341)
	//Nights lodging: COICOP 3-DIGIT 112	
	gen exp_cat051_k = hh_i03 if inlist(item,401,403,404,405)
	//Carpets, mattresses, mats, mosq. nets: COICOP 3-DIGIT 051	
	gen exp_cat052   = hh_i03 if item==402                  
	//Linens: COICOP 3-DIGIT 052
	gen exp_cat092   = hh_i03 if item==406                  
	//Sports: COICOP 3-DIGIT 092
	gen exp_cat091_k = hh_i03 if item==407                  
	//Film processing: COICOP 3-DIGIT 091 

	*--------------------------------------------------------------------------*
	*4.7) Convert exp values over different recall periods to annual exp
	*--------------------------------------------------------------------------*
	
	qui foreach v of varlist exp_cat* {
	replace `v' = `v'*52 if inrange(item,101,199) 
	replace `v' = `v'*12 if inrange(item,201,299)
	replace `v' = `v'*4  if inrange(item,301,399)
	}

	*--------------------------------------------------------------------------*
	*4.8) Aggregate exp to HH level and save data in temporary folder 
	*--------------------------------------------------------------------------*
	
	collapse (sum) exp_cat*, by(HHID)
	sort HHID
	save "$dout\nonfood_ijk", replace

*------------------------------------------------------------------------------*
*5) Durable goods
*------------------------------------------------------------------------------*
	
	*--------------------------------------------------------------------------*
	*5.1) Load data on durable goods and keep relevant non-missing variables
	*--------------------------------------------------------------------------*
	
	use "$din/HH_MOD_L", clear
	ret li                                                  
	rename hh_l02 item                                     
	quietly bys hh_l01 : summ hh_l01 hh_l03-hh_l07                 
	recode hh_l03 hh_l05 hh_l07  (0=.)
	
		*5.1.1) Keep records that have age, quantity, and value information
		
		egen temp = rowmiss(hh_l03 hh_l04 hh_l05)
		keep if temp==0 
		drop temp
		
		*5.1.2) Keep durable goods considered in IHS4

		keep if inrange(item,501,518) | inrange(item,529,532)| item==5081
		keep HHID item hh_l03 hh_l04 hh_l05 hh_l01
		
	*--------------------------------------------------------------------------*	
	*5.2) Trim value
	*--------------------------------------------------------------------------*	
	
	forvalues h = 3(1)5{
	winsor2 hh_l0`h', replace by(item) cuts (5 95)
	}
	
	*--------------------------------------------------------------------------*	
	*5.3) Get average age to estimate lifespans
	*--------------------------------------------------------------------------*
	
		*5.3.1) Average age
		bys item: egen meanage=mean(hh_l04)                   
		label var meanage "The average age of the durable item" 

		*5.3.2) Lifespans
		gen lifetime_yrs=2* meanage if item!=517 & item!=518
		label var lifetime_yrs "Lifetime (years)"
		gen lifetime_yrs2=3* meanage if item==517 | item==518
		replace lifetime_yrs=lifetime_yrs2 if item==517 | item==518

	*--------------------------------------------------------------------------*
	*5.4) Calculate the number of useful years left 
	*--------------------------------------------------------------------------*	

	gen yearsleft=2*meanage-hh_l04 if item!=517 & item!=518
	label var yearsleft "The number of useful years left of the durable item" 
	recode yearsleft min/2 = 2  
	gen yearsleft2=3*meanage-hh_l04 if item==517 | item==518
	recode yearsleft2 min/2 = 2                          
	replace yearsleft=yearsleft2 if item==517 | item==518
	
	*--------------------------------------------------------------------------*
	*5.5) Calculate the annual value of the durable items owned
	*--------------------------------------------------------------------------*	
	
	gen value = (hh_l05/yearsleft)*hh_l03
	label var value "Annual value of durable item(s) owned"
	quietly summ value, det 
	save "$dout\nonfood_durables_precategorize", replace 
	
	*--------------------------------------------------------------------------*
	*5.6) Categorize durable items by assigning them COICOP
	*--------------------------------------------------------------------------*
	
	gen exp_cat055_l = value if item==501                  
	//Mortar/pestle: COICOP 3-digit code 055    
	gen exp_cat051_l = value if inlist(item,502, 503, 504)               
	//Furniture: COICOP 3-digit code 051 
	gen exp_cat053_l = value if inlist(item,505, 506, 511, 512, 513, 514, 515)
	//Appliances: COICOP 3-digit code 053
	gen exp_cat091_l = value if inlist(item,507,5081, 508, 509, 510, 529, 530)
	//Radio/tape & cd player/television: COICOP 3-digit code 091
	gen exp_cat071 = value if inlist(item,516, 517, 518)                 
	//Bike/scooter/motorcycle: COICOP 3-digit code 071
	gen exp_cat045_l = value if inlist(item, 531, 532)     
	//Solar panel, generator COICOP 3-digit code 045

	*--------------------------------------------------------------------------*
	*5.7) Aggregate value of durable items to HH level and save
	*--------------------------------------------------------------------------*	
	
	collapse (sum) exp_cat*, by(HHID)
	sort HHID
	save "$dout\nonfood_durables", replace 


