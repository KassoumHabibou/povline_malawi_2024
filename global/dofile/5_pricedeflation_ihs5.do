
*------------------------------------------------------------------------------*
** 	  National Statistical Office (NSO) & World Bank Poverty and Equity GP 	  **
*------------------------------------------------------------------------------*
** PROJECT			2019-20 Poverty measurement
** COUNTRY			Malawi
** COUNTRYCODE  	MWI
** YEAR				2019-2020
** SURVEY NAME		IHS5
** SECTION 			Price deflation
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
*1) Calculate food budget shares/weights for all items using IHS5 dataset
*------------------------------------------------------------------------------*
   
	use "$dout\food_ihs5", clear  			               
	merge m:1 HHID using "$dout\basicvars_ihs5.dta",nogen   
	drop if inrange(item,913,915) | inlist(item,908) | inlist(item,911)                             
	preserve
	bys HHID: egen tfoodexp=total(value)                                
	gen share=value/tfoodexp  
	//valor del item/ gasto total del hogar                                            
	collapse (mean) sharemean=share (p99) share99=share (p95) share95=share (p50) sharemedian=share [aw=hh_wgt], by(item urban_region)
	//sharemean proporcion gastada en un item por region en  todos los hogares
	save "$dout\food_share_stat_urbr", replace
	restore
	keep HHID value urban_region urban item hh_wgt hhsize
	drop if item==.
	reshape wide value,i(HHID) j(item)
	reshape long value, i(HHID) j(item)
	//base ampliada para los 131 items que hay para todas los hagares
	save "$dout\food_ihs5_reshaped", replace  			  
	replace value=0 if value==.
	bys HHID: egen tfoodexp=total(value) 
	gen share=value/tfoodexp                                         
	merge m:1 item urban_region using "$dout\food_share_stat_urbr"
	// se juntan con la base de share del item por region 
	replace share=share95 if share >share95 
	drop if _merge==2
	drop _merge
	save "$dout\food_ihs5_share", replace
	preserve
	collapse (mean) share [aw=hh_wgt], by(urban_region item) //share por region de los items
	save "$dout\share_ihs5", replace  			         
	restore
	preserve
	collapse (mean) share [aw=hh_wgt], by(item)  // share nacional de los items 
	save "$dout\share_ihs5_nat", replace 
	restore

*------------------------------------------------------------------------------*
*2) Calulate temporal food CPI within IHS-5 survey period  (By urban region)
*------------------------------------------------------------------------------*

	use "$dout\unitvalue_ihs5_month", clear //precio mediano por mes (precio por kg)
	merge m:1 urban_region item using "$dout\share_ihs5" 
	keep if _m==3
	sort urban_region item syear smonth
	gen time=ym(syear, smonth)                                               
	label var time "Year and Month of survey, GC"
	format %tm   time
	drop syear smonth _merge
	reshape wide price_ihs5, i(urban_region item) j(time) //precios por mes
	egen rmprice_ihs5=rowmean(price_ihs5711 price_ihs5712) //precios medios de mayo19 a abril20
	gen rprice_ihs5711=1   //precio de referencia abril19                                                  
	forval i= 712/723 {
	gen rprice_ihs5`i'=(price_ihs5`i'/rmprice_ihs5) //tasa de precios = dividir los precios de cada mes sobre los precios promedios del a;o                      
	replace rprice_ihs5`i'=r(p95) if rprice_ihs5`i'>=r(p95) & rprice_ihs5`i'!=.                        
	}
	reshape long rprice_ihs5, i(urban_region item) j(time)                      
	drop if rprice_ihs5==.                                               
	bys urban_region time : egen tshare=total(share) //por periodo y area se hace el total de los share, cercanoa a 1              
	gen food_index=rprice_ihs5*(share/tshare)*100 //los share sobre la suma de shares
    save "$dout\food_itemindex_temporal_ihs5", replace  	 
	collapse (sum) food_index, by(urban_region time)                     
	format %tm   time
	save "$dout\food_index_temporal_ihs5", replace

*------------------------------------------------------------------------------*	
*3) Import temporal non food CPI within IHS-5 survey period  (By urban region)
*------------------------------------------------------------------------------*	

	import excel "$din\Non-food_CPI.xlsx", sheet("Sheet1") firstrow clear
	keep urban_region- w_nonfood
	label var time "Year and Month of survey, GC"
	label var non_food_cpi "Official Non-food CPI" 
	format %tm   time                                             
	drop urban_region2 time2
	bys urban_region: egen non_food_cpim=mean(non_food_cpi) if inlist(time,711,712)
	bys urban_region: egen non_food_cpim2=mean(non_food_cpim)                              
	gen non_food_cpif=(non_food_cpi/non_food_cpim2)*100                    
	drop non_food_cpim2 non_food_cpim non_food_cpi                         
	replace non_food_cpif=100 if time==711                                
	ren non_food_cpif non_food_index                                      
	save "$dout\non_food_index_temporal_ihs5", replace  	   

*------------------------------------------------------------------------------*	
*4) Combine food and non food temporal CPI
*------------------------------------------------------------------------------* 
	
	use "$dout\food_index_temporal_ihs5", replace
	merge 1:1 urban_region time using "$dout\non_food_index_temporal_ihs5",nogen
	sort urban_region time
	bys urban_region: egen food_cpim=mean(food_index) if inlist(time,714,716)
	bys urban_region: egen food_cpim2=mean(food_cpim)                               
	replace food_index=food_cpim2 if food_index==. & time==715
	drop food_cpim food_cpim2
	gen cpi=(non_food_index*w_nonfood + food_index*(100-w_nonfood))/100
	keep urban_region time cpi                                            
	save "$dout\cpi_temporal_ihs5", replace 

*------------------------------------------------------------------------------*
*5) Create Spatial regional food CPI
*------------------------------------------------------------------------------*

	use "$dout\unitvalue_ihs5_nat_rm", clear
	ren price_ihs5 price_ihs5nat
	save "$dout\unitvalue_ihs5_month_nattemp", replace
	
	use "$dout\unitvalue_ihs5_rm", clear
	merge m:1 item using "$dout\unitvalue_ihs5_month_nattemp",nogen
	merge 1:1 urban_region item using "$dout\share_ihs5"
	keep if _m==3  
	drop _m
    gen rprice_ihs5=(price_ihs5/price_ihs5nat)                     
	quietly sum rprice_ihs5,d 
	bys urban_region: egen tshare=total(share)
	gen food_index=rprice_ihs5*(share/tshare)*100
	save "$dout\food_itemindex_spatial_ihs5", replace
	
	collapse (sum) food_index, by(urban_region)
	gen spatial=1                           
	reshape wide food_index, i(spatial) j(urban_region)
	ren food_index1 urbanrpr_food
	ren food_index2 northrurrpr_food
	ren food_index3 centralrurrpr_food
	ren food_index4 southrurrpr_food
	save "$dout\food_index_spatial_ihs5", replace

*------------------------------------------------------------------------------*
*6) Import Non food CPI
*------------------------------------------------------------------------------*	 

	import excel "$din\Non-food_CPI_IHS5.xlsx", sheet("Sheet1") firstrow clear
	ren time month
	keep if month==711 | month==712  
	keep urban_region month non_food_cpi w_nonfood
	collapse (mean) non_food_cpi w_nonfood,by(urban_region)
	gen spatial=1                              
	reshape wide non_food_cpi w_nonfood,i(spatial) j(urban_region) 	   		   
	gen urbanrpr_nonfood=(non_food_cpi1/non_food_cpi5)*100 //divide las regiones respecto al nacional
	gen northrurrpr_nonfood=(non_food_cpi2/non_food_cpi5) *100  
	gen centralrurrpr_nonfood=(non_food_cpi3/non_food_cpi5)*100  
	gen southrurrpr_nonfood=(non_food_cpi4/non_food_cpi5)*100  
	keep spatial urbanrpr_nonfood northrurrpr_nonfood centralrurrpr_nonfood southrurrpr_nonfood

*------------------------------------------------------------------------------*
*7) Combine food and non food spatial regional CPI
*------------------------------------------------------------------------------*	

	merge 1:1 spatial using "$dout\food_index_spatial_ihs5",nogen
	reshape long urbanrpr southrurrpr centralrurrpr northrurrpr, i(spatial) j(food_cat) str
	replace food_cat="1" if food_cat=="_food"
	replace food_cat="2" if food_cat=="_nonfood"
	destring food_cat,replace
	gen weight_urban=.
	replace weight_urban=.453 if food_cat==1 
	replace weight_urban=(1-.453) if food_cat==2 
	gen weight_northrur=.
	replace weight_northrur=.453 if food_cat==1 
	replace weight_northrur=1-.453 if food_cat==2 
	gen weight_centralrur=.
	replace weight_centralrur=.453 if food_cat==1 
	replace weight_centralrur=1-.453 if food_cat==2 
	gen weight_southrur=.
	replace weight_southrur=.453 if food_cat==1 
	replace weight_southrur=1-.453 if food_cat==2 
	gen spatial_indexL1=urbanrpr*weight_urban
	gen spatial_indexL2=northrurrpr*weight_northrur
	gen spatial_indexL3=centralrurrpr*weight_centralrur
	gen spatial_indexL4=southrurrpr*weight_southrur
	collapse (sum) spatial* 
	expand 13
	gen month = _n + 3
	reshape long spatial_indexL, i(month) j(urban_region)
	label define urban_region 1 "Urban" 2 "Rural North" 3 "Rural Centre" 4 "Rural South"
	label values urban_region urban_region

*------------------------------------------------------------------------------*
*8) Merge temporal and spatial CPI
*------------------------------------------------------------------------------*	

	gen syear = .
	replace syear = 2019 if inrange(month,4,12)  
	replace syear = 2020 if inrange(month,13,16)   
	gen smonth = .
	replace smonth = month if syear==2019
	replace smonth = month-12 if syear==2020
	drop month
	label var syear "Calender year of the fieldwork"
	label var urban_region "4 geographical domains with price series"
	label var smonth "Calendar month of the fieldwork"
	sort urban syear smonth
	order urban syear smonth
	gen time=ym(syear, smonth)
	label var time "Year and Month of survey, GC"
	format %tm   time
	merge 1:1 urban_region time using "$dout\cpi_temporal_ihs5",nogen
	gen price_indexL = (spatial_indexL*cpi)/100
	label var price_indexL  "Laspeyres monthly Spatial and Temporal Price Index (Base National April 2019)"
	save "$dout\Price_index_ihs5.dta", replace



