Tsub jtag_clock_nl => << 'END';
    DESC {
         jtag_clock_nl -in <input>
    }
    ARGS {
        -in:$in # to specify input file  
    }

my $top = get_top ;
chomp $top ;

#$in = "/home/junw/a" ;

open IN, "$in" ;
foreach (<IN>) {
  chomp ;
  my $pin = $_ ;
  my $dri = get_driver $pin ;
  chomp $dri ;
  my ($xl, $yl) = get_pin_xy $pin ;
  my ($xd, $yd) = get_pin_xy $dri ; 
  print "$pin\n" ; 
  plot_line(-arrow=>"last", -name => "jtag_clk_order", $xd, $yd, $xl, $yl, -color => "red") ;
}

END
