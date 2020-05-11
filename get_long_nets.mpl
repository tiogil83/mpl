Tsub get_long_nets => << 'END';
    DESC {
         get_long_nets -o <out_file>
    }
    ARGS {
        -o:$out_file   # to specify the output file
    }

open OUT, "> $out_file" or die "can't write to file $out_file" ;

my $top = get_top ;
chomp $top ;

my @all_nets = get_nets (-hier => "*") ;
my %net_leng ;
my %sum_leng ;

foreach my $net (@all_nets) {
  if 
  print "Net $net\n" ;
  my @conns = get_conns $net ;
  my $leng_sum = 0 ;
  foreach (@conns) {
    if (($_[1] eq 'net') and !(exists $net_leng{$_[0]})) {
      my $leng = get_route_length $_[0] ; 
      $leng_sum = $leng_sum + $leng ;
      $net_leng{$_[0]} = $leng ;
      print "Net $_[0] Length $leng\n" ;
    }  
  }
  $sum_leng{$net} = $leng_sum ;
}

foreach (keys %sum_leng) {
  print OUT "$_ $sum_leng{$_}\n" ;
}

close OUT ;

END
