
*------------------------------------------------------------------------------*
** 	  National Statistical Office (NSO) & World Bank Poverty and Equity GP 	  **
*------------------------------------------------------------------------------*
** PROJECT			2019-20 Poverty measurement
** COUNTRY			Malawi
** COUNTRYCODE  	MWI
** YEAR				2019-2020
** SURVEY NAME		IHS5
** SECTION 			Rent expenditure
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
/*
*quietly ssc install winsor2
*/
*------------------------------------------------------------------------------*

	use "$din/HH_MOD_F", clear
	merge m:1 HHID using "$dout\basicvars_ihs5" ,nogen

*------------------------------------------------------------------------------*	
*1) Convert estimated/imputed and actual rent into monthly corresponding rent
*------------------------------------------------------------------------------*

	gen imputedrentrent = .                                        
	//create variable for imputedrent rent
	replace imputedrent = hh_f03a*30.4 if hh_f03b==3               
	//Convert daily to monthly imputed rent
	replace imputedrent = hh_f03a*4.3  if hh_f03b==4               
	//Convert weekly to monthly imputed rent
	replace imputedrent = hh_f03a      if hh_f03b==5              
	//Keep monthly imputed rent
	replace imputedrent = hh_f03a/12   if hh_f03b==6               
	//Convert yearly to monthly imputed rent

	gen actualrent = .                                             
	//create variable for actual rent
	replace actualrent = hh_f04a*30.4 if hh_f04b==3                
	//Convert daily to monthly actual rent
	replace actualrent = hh_f04a*4.3  if hh_f04b==4                
	//Convert weekly to monthly actual rent
	replace actualrent = hh_f04a      if hh_f04b==5                
	//Keep monthly actual rent
	replace actualrent = hh_f04a/12   if hh_f04b==6                
	//Convert yearly to monthly actual rent

*------------------------------------------------------------------------------*
*2) Identify renters
*------------------------------------------------------------------------------*

	quietly tabstat imputedrent actualrent, by(hh_f01)
	gen renter = hh_f01==6 if inrange(hh_f01,1,6)
	label var renter "=1 if HH is renter and 0 otherwise"

*------------------------------------------------------------------------------*
*3) Clean general construction material of housing variable (hh_f06)
*------------------------------------------------------------------------------*

	gen wall_perm  = inlist(hh_f07,5,6)                            
	//wall_perm=1 if wall is made of burnt bricks or concrete                              
	gen roof_perm  = inlist(hh_f08,2,3,4)                          
	//roof_perm=1 if roof is made of iron sheets or clay tiles or concrete
	egen x = rsum(wall_perm roof_perm)                             
	//x=0 if both wall and roof are not permanent, x=1 if either is permanent, x=2 if both are permanent 
	recode hh_f06 nonmiss = 1 if x==2                              
	//Recode hh_f06=1 (permanent) if x=2
	recode hh_f06 nonmiss = 2 if x==1                              
	//Recode hh_f06=1 (semi-permanent) if x=1
	recode hh_f06 nonmiss = 3 if x==0                              
	//Recode hh_f06=1 (traditional) if x=0
	drop wall_perm roof_perm x 

*------------------------------------------------------------------------------*
*4) Trim actual and imputed rent values
*------------------------------------------------------------------------------* 

	winsor2 actualrent, replace by(hh_f06 urban_region) cut(5 95) 
	winsor2 imputedrent, replace by(hh_f06 urban_region) cut(5 95) 

*------------------------------------------------------------------------------*
*5) Create independent variables for the hedonic rental regression
*------------------------------------------------------------------------------*
	
	gen walls = hh_f07
	recode walls (1=9) (7/8=9)		
	gen roof = hh_f08                                  
	recode roof (2/4=2) (5/6=1)
	gen floor = hh_f09 
	recode floor (3/5=3) 
	gen rooms = hh_f10
	gen electricity = hh_f19==1 if inrange(hh_f19,1,2)
	gen electricitytown = electricity==1 | hh_f27==1 if electricity!=. 
	tab electricity electricitytown, m
	gen dwater = hh_f36 
	replace dwater=16 if inlist(dwater,4, 6, 9) | inrange(dwater, 11,15)
	gen toilet = hh_f41
	recode toilet (5/6=6)
	recode urban 2=0
	global charact  i.walls i.roof i.floor rooms
	global services i.dwater i.toilet electricity electricitytown
	global survey   i.region urban i.district i.smonth i.syear

*------------------------------------------------------------------------------*
*6) Hedonic rental regression for renters
*------------------------------------------------------------------------------* 

	gen lnrent = ln(actualrent)
	label var lnrent "Log of actual rent per month"
	gen pimputedrent=.
	label var pimputedrent "Predicted imputed rent"
	quietly regress lnrent $charact $services $survey if renter==1 [aw=hh_wgt*hhsize]
	dis e(rmse)                                                 
	predict yhat
	replace pimputedrent=exp(yhat + 0.5*(e(rmse))^2) 
    drop yhat

*------------------------------------------------------------------------------*
*7) Replace imputed by estimation if dif grater than 2
*------------------------------------------------------------------------------*
 
	quietly compare pimputedrent imputedrent if renter==0 
	replace imputedrent=pimputedrent if (imputedrent>2*pimputedrent | imputedrent<pimputedrent/2) & imputedrent!=. & pimputedrent!=.
	replace imputedrent = pimputedrent if renter==0 & missing(imputedrent)

*------------------------------------------------------------------------------*	
*8) Convert monthly rent into annual rent and categorize and save
*------------------------------------------------------------------------------*                                  
	
	gen exp_cat041 = actualrent*12   
	gen exp_cat042 = imputedrent*12     
	recode exp_cat041 exp_cat042 (.=0)                          
	keep HHID exp_cat041 exp_cat042                                       
	save "$dout\rent", replace                     
