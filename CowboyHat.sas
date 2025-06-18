
 
/* DATA step to create the "hat" data */
data hat; 
 do x = -5 to 5 by .1;
  do y = -5 to 5 by .1;
   /* z = sin(sqrt(y*y + x*x)); *Cowboy Hat ;  */
   z = sin(tanh(y*y + x*x));  * Hyperbolic tangent ;
   output;
  end;
 end;
run;	
 
proc g3d;
    plot x*y=z ;
run;