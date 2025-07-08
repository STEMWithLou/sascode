*infile "&WORKSPACE_PATH./sas-viya-workbench-examples/data/bonus.csv" dsd firstobs=2;


proc import datafile="&WORKSPACE_PATH./sascode/data/Outside.csv" dbms=csv out=temptrend  replace ;
    getnames = yes ;
run;

proc contents data=temptrend ;
run;

data outside_with_date;
    set work.temptrend;
    /* Change variable names below if yours are different! */
    date = datepart(timestamp);
    format date yymmdd10.;
run;

proc sql ;
create table summtemp as 
    (select  date,
            max(Temperature_Fahrenheit) as MaxTmp

            from outside_with_date

            group by date
    )
            order by date
 ;

quit ;


proc sort data=summtemp;
    by date;
run;

/* Find the cutoff date for the last 30 days */
proc sql noprint;
    select max(date) - 29 into :cutoff_date
    from summtemp;
quit;

data train test;
    set summtemp;
    if date < &cutoff_date then output train;
    else output test;
run;

/* Identify best ARIMA model automatically (simple case) */
proc arima data=train;
    identify var=maxtmp nlag=20;
    estimate p=1 q=1;   /* Common starting point; change p/q for your data's autocorrelation */
    forecast lead=30 out=arima_forecast id=date interval=day;
run;
quit;

proc sql;
    create table compare as
    select a.date, a.maxtmp as actual, b.forecast as predicted
    from test as a
    left join arima_forecast as b
    on a.date = b.date
    where b.forecast is not null;
quit;

data metrics;
    set compare;
    error = actual - predicted;
    abs_error = abs(error);
    sq_error = error**2;
run;

proc means data=metrics mean;
    var abs_error sq_error;
    output out=results mean=MAE RMSE;
run;

proc sgplot data=compare;
    series x=date y=actual / lineattrs=(color=blue) legendlabel="Actual";
    series x=date y=predicted / lineattrs=(color=red) legendlabel="Forecast";
    xaxis label="Date";
    yaxis label="Max Temp (F)";
    keylegend / location=inside position=topright across=1;
run;

proc ucm data=train;
    id date interval=day;
    model maxtmp;
    irregular;
    level;
    slope;
    season length=95 type=trig;
    estimate;
    forecast back=30 lead=30 outfor=ucm_fcst;
run;

data metrics;
    set ucm_fcst;
    if forecast <> . ;
    abs_error = abs(residual);
    sq_error = residual**2;
run;

proc means data=metrics mean;
    var abs_error sq_error;
    output out=results mean=MAE RMSE;
run;

proc print data=results ;
run;
