
gl folder "C:\Users\edson\Downloads\Katherin EAFIT\WoldBank\2019 Poverty Measurement"
	gl ddo "$folder\Do files"
	gl din "$folder\Input files"
	gl dout "$folder\Output files"
	


use "C:\Users\edson\Downloads\Katherin EAFIT\WoldBank\Datos originales\Output files originals\preconvertfood_ihs5.dta", clear

	sort item district smonth syear

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
	
	keep if price!=.  
	
	
	****** PRUEBAS **************
	
	preserve
	set seed 1234
	gen seed = runiform()
	sort item district smonth syear HHID seed //no funciona si el HHID y el seed van al inicio
	unique report item district smonth syear
	collapse (p50) price1=price (count) c1=price [aw=hh_wgt], by(item district smonth syear)  //aqui internamente debe reorganizar la base y por eso da resultados diferentes por los duplicates report item district smonth syear
	sum item district smonth syear price1 c1 
	restore
	
	
	************************
	  
	preserve
	set seed 1234
	gen seed = runiform()
	sort seed HHID item district smonth syear //no funciona, igual sigue dado resultados diferentes cada vez que se corre
	unique seed HHID item district smonth syear
	collapse (p50) price1=price (count) c1=price [aw=hh_wgt], by(item district smonth syear)  //aqui internamente debe reorganizar la base y por eso da resultados diferentes duplicates report item district smonth syear
	sum item district smonth syear price1 c1 //ni siquiera se mantienen resultados
	restore
	  
	***********************
	  
	preserve
	bysort item district smonth syear: egen p50 = median(price) //no se puede poderar por peso 
	collapse (mean) price1 = p50 (count) c1= p50 [aw=hh_wgt], by(item district smonth syear) 
	sum item district smonth syear price1 c1
	restore
	
	*************************** armando la mediana desde 0*****************
	
	preserve
	set seed 1234
	gen seed = runiform()
	sort item district smonth syear seed HHID 
	gen pricew = price * hh_wgt
	bysort item district smonth syear: egen sumw = total(hh_wgt)
	

	
	bysort item district smonth syear: egen pricew = price 
	collapse (mean) price1 = p50 (count) c1= p50 [aw=hh_wgt], by(item district smonth syear) 
	sum item district smonth syear price1 c1
	restore
	
	
	
	bysort item district smonth syear: egen total_weight = total(hh_wgt)      // Sumar pesos por grupo
bysort item district smonth syear: gen cumulative_weight = sum(hh_wgt)    // Peso acumulado
bysort item district smonth syear: egen median_price = median(price)       // Mediana simple (sin peso)

* Identificar la mediana ponderada
bysort item district smonth syear: gen weight_threshold = total_weight/2    // Umbral de peso
bysort item district smonth syear: gen median_weighted = (cumulative_weight >= weight_threshold) & (cumulative_weight < weight_threshold + hh_wgt)

* Reemplazar valores en la mediana ponderada con la mediana real
bysort item district smonth syear: egen final_median = mean(price * median_weighted)  // Multiplicar por el valor de precio donde se alcanza el umbral
