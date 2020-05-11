Tsub  dump_jtag_clk_src => << 'END';
    DESC {
         dump_jtag_clk_src -o <out_file>
    }
    ARGS {
        -o:$out_file   # to specify the output file
    }

open OUT, "> $out_file" or die "$!" ;

my @clks = () ;

foreach (keys $CONFIG -> {clock_timing_specification}{clock}) {
  if ((/jtag/) and (grep (/func/, @{$CONFIG -> {clock_timing_specification}{clock}{$_}{apply_clocks_timing_mode}}))) {
    push @clks, $_ ;
  } 
}

push @clks, "pex_refclk" ;

#my @clks = qw "
#pex_refclk
#jtag_clk
#jtag_reg_clk
#jtag_reg_clk_bsi
#jtag_reg_clk_sci
#jtag_reg_tck
#jtag_reg_tck_bsi
#jtag_reg_tck_sci
#" ;


foreach my $clk (@clks) {
  @clk_port_sources = @{$CONFIG -> {clock_timing_specification}{clock}{$clk}{port_sources}} ;
  @clk_pin_sources = @{$CONFIG -> {clock_timing_specification}{clock}{$clk}{pin_sources}} ;
  @clk_biport_sources = @{$CONFIG -> {clock_timing_specification}{clock}{$clk}{biport_sources}} ;
  print OUT "$clk port sources:\n" ;
  foreach (sort @clk_port_sources){
    print OUT "\t$_\n" ;
  }
  print OUT "$clk pin sources:\n" ;
  foreach (sort @clk_pin_sources){
    print OUT "\t$_\n" ;
  }
  print OUT "$clk biport sources:\n" ;
  foreach (sort @clk_biport_sources){
    print OUT "\t$_\n" ;
  }
}

close OUT ;

END
