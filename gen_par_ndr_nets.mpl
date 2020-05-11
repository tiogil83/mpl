Tsub gen_par_ndr_nets => << 'END';
    DESC {
         gen_par_ndr_nets -in <input> -out <output>
    }
    ARGS {
        -in:$in # to specify input file
        -out:$out # to specify output file
    }

open IN, "$in" ;
open OUT, "> $out" ;

my %nets = () ;

while (<IN>) {
  my $line = $_ ;
  chomp $line ;
  if (get_net $line) {
  } else {
    print "no net found for $line\n" ;
    next ;
  }
  $line =~ /(.*?)\/(.*)/ ;
  my $par = $1 ;
  $par = uc $par ;
  my $net = $2 ;
  $nets{$par}{$net} = 1 ;  
}

foreach (sort (keys %nets)) {
  my $par = $_ ;
  print OUT "$par : \n" ;
  foreach (sort (keys %{$nets{$par}})){
    my $net_name = $_ ;
    print OUT "  $net_name\n" ;
  } 
  print OUT "\n" ;
}

close IN ;
close OUT ;

END
