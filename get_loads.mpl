open IN, "t0.noclock.rpt2" ;
open OUT, "> t0.noclock.pin" ;

while(<IN>){
  m/ (.*) is/ ;
  $net = $1 ;
  @pins = get_loads $net ;
  $pin = $pins[-1] ;
  print OUT "$net $pin" ;
  print OUT "\n" ;
}

close IN ;
close OUT ;
