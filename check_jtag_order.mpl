Tsub check_wsi_order => << 'END';
    DESC {
         To check the jtag order.
         check_wsi_order -chiplet <nv_top|chiplet> 
    }
    ARGS {
        -chiplet:$top # to specify the top block 
    }


if (!defined $top) {
  $top = get_top ; 
}

set_top $top ;

if ($top eq 'nv_top') {
  $chip_uc = nv_top ;
} else {
  $chip_lc = $top ;
  $chip_lc =~ s/NV_(.*)/$1/ ;
  $chip_uc = uc $chip_lc ;
  if ($chip_uc =~ /STPC/) {
    $chip_uc =~ s/(.*)STPC0/$1STPC/ ;
  }
}

$ieee1500_order = $CONFIG->{partitioning}->{chiplets}->{$chip_uc}->{ieee1500_ordered_insts} ;
@ieee1500_orders = split (/,/, $ieee1500_order) ; 

%coor = () ;

$i = 0 ;
foreach (@ieee1500_orders) {
  if (/^\\/) {
     s/^\\(.*)/$1/ ;
  }
  if (! (/i1500_data_pipe_/)) {
     $xy = attr_of_cell ('phys_centroid_point' => $_); 
     $x = $xy->[0] ; 
     $y = $xy->[1] ;
     $coor{$_}{x} = $x ;
     $coor{$_}{y} = $y ;
     #print "$_ $i par $coor{$_}{x} $coor{$_}{y}\n" ;
     $i = $i + 1 ;
  }else{
     $par = $_ ;
     $par =~ s/i1500_data_pipe_(.*)_0/$1/ ;
     $xy = attr_of_cell ('phys_centroid_point' => $par);
     $x = $xy->[0] ;
     $y = $xy->[1] ;
     $coor{$_}{x} = $x ;
     $coor{$_}{y} = $y ;
     #print "$_ $i $par $coor{$_}{x} $coor{$_}{y}\n" ;
     $i = $i + 1 ;
  }
}

plot_macros -no_labels ;

$j = 1 ;

while ($j <= $#ieee1500_orders) {
#print "iee $j $ieee1500_orders[$j]" ;
#}
  if ($ieee1500_orders[$j] =~ /i1500_data_pipe_/) {
    if ($coor{$ieee1500_orders[$j]}{x} > $coor{$ieee1500_orders[$j-1]}{x}) {
        $coor{$ieee1500_orders[$j]}{x} = $coor{$ieee1500_orders[$j]}{x} - 300 ;
    } 
    if ($coor{$ieee1500_orders[$j]}{x} < $coor{$ieee1500_orders[$j-1]}{x}) {
        $coor{$ieee1500_orders[$j]}{x} = $coor{$ieee1500_orders[$j]}{x} + 300 ;
    } 
    if ($coor{$ieee1500_orders[$j]}{y} > $coor{$ieee1500_orders[$j-1]}{y}) {
        $coor{$ieee1500_orders[$j]}{y} = $coor{$ieee1500_orders[$j]}{y} - 300 ;
    }
    if ($coor{$ieee1500_orders[$j]}{y} < $coor{$ieee1500_orders[$j-1]}{y}) {
        $coor{$ieee1500_orders[$j]}{y} = $coor{$ieee1500_orders[$j]}{y} + 300 ;
    } 
  }
  $new_x_1 = $coor{$ieee1500_orders[$j-1]}{x}+100 ; 
  $new_y_1 = $coor{$ieee1500_orders[$j-1]}{y}+100 ;
  $new_x_2 = $coor{$ieee1500_orders[$j]}{x}+100 ; 
  $new_y_2 = $coor{$ieee1500_orders[$j]}{y}+100 ;
  print "$ieee1500_orders[$j-1], $coor{$ieee1500_orders[$j-1]}{x}, $coor{$ieee1500_orders[$j-1]}{y}, $new_x_1, $new_y_1\n" ;
  print "$ieee1500_orders[$j], $coor{$ieee1500_orders[$j]}{x}, $coor{$ieee1500_orders[$j]}{y}, $new_x_2, $new_y_2\n" ;
  plot_rect($ieee1500_orders[$j-1], $coor{$ieee1500_orders[$j-1]}{x}, $coor{$ieee1500_orders[$j-1]}{y}, $new_x_1, $new_y_1) ;
  plot_rect($ieee1500_orders[$j], $coor{$ieee1500_orders[$j]}{x}, $coor{$ieee1500_orders[$j]}{y}, $new_x_2, $new_y_2);
  plot_line(-arrow=>"last", -name => "jtag_wsi_wso_order", $coor{$ieee1500_orders[$j-1]}{x}, $coor{$ieee1500_orders[$j-1]}{y},  $new_x_2, $new_y_2, -color => "red");  
  $j = $j + 1 ;
}


END


Tsub check_wsc_order => << 'END';
    DESC {
         To check the jtag wsc order.
         check_jtag_order -file <order_file> -chiplet <nv_top|chiplet>  
    }
    ARGS {
         -file:$file_name # To specify the input ordering file name.
         -chiplet:$chiplet_name # To specify the top name : nv_top or chiplet name.
    }

#clear_plot ;

open IN1, "$file_name" ;

if (!(defined $chiplet_name)) {
  $top = get_top ;
  $chiplet_name = $top ;
}

set_top $chiplet_name ;
plot_macros -no_labels ;

%ieee1500_order = () ;

open IN2, "$file_name" ;

while(<IN2>) {
  print $_."\n" ;
  my @line = split / => /, "$_" ; 
  $i = 1 ;
  while ($i <= $#line) {
    print "$line[$i]\n" ;
    #if ($i == 0) {
    #  $line[$i] =~ s/\s+//g ;
    #  if ((!(get_port (-quiet => $line[$i]))) and (!(get_cell (-quiet => $line[$i])))) {
    #    print "can't find the instance or port $line[$i].\n" ;
    #    $i = $i + 1 ; 
    #  }
    #  if (is_port $line[$i]) {
    #    @xy = get_pin_xy $line[$i] ;
    #    ($x[$i] , $y[$i]) = @xy ;
    #    $i = $i + 1 ;
    #  } elsif (is_cell $line[$i]) {
    #    @xy = get_cell_xy $line[$i] ;
    #    ($x[$i] , $y[$i]) = @xy ;
    #    $i = $i + 1 ;
    #  }
    #} else {
      $line[$i] =~ s/\s+//g ;
      $xy_c = attr_of_cell ('phys_centroid_point' => $line[$i]);
      ($x[$i] , $y[$i]) = ($xy_c->[0], $xy_c->[1]) ;
      if ($i > 1) {
        plot_line(-arrow=>"last", -name => "jtag_wsc_order", $x[$i-1], $y[$i-1], $x[$i], $y[$i], -color => "red") ; 
      }
      print "$line[$i] $x[$i] $y[$i] $line[$i-1] $x[$i-1] $y[$i-1]\n" ;
      $i = $i + 1 ;
    #}
  }
}

close IN2 ;

END

Tsub check_clk_order => << 'END';
    DESC {
         To check the jtag clk order.
         check_jtag_order -port <order_file> 
    }
    ARGS {
         -port:$port_name # To specify the port name.
    }

my @pars = all_partitions ;

foreach (@pars) {
  #print "$_\n" ;
  my @par_insts = get_cells_of $_ ;
  foreach my $par_inst (@par_insts) {
    plot (-no_label => $par_inst) ;
  }
}

my @fo = get_fan2 (-fanout => -unate => $port_name) ;

foreach (@fo) {
  if (/NV_CLK_ELEM/) {
     chomp ;
     (m/\s*(\S+)\s+\(\S+\) from\s*(\S+)/) ;
     my $load = $1 ;
     my $dri = $2 ; 
     my ($x_l, $y_l) = get_pin_xy $load ;
     my ($x_d, $y_d) = get_pin_xy $dri ;
     plot_line(-arrow=>"last", -name => "jtag_clk_order", $x_d, $y_d, $x_l, $y_l, -color => "red") ; 
  }
}

END

#sub get_jtag_clk_loads {
#  my ($curr) = @_;
#  my @rtn = qw();
#  my @loads = get_loads($curr);
#
#  # get_net -of
#  # get_net_context
#  # get_pin_context_whier
#
#  foreach my $load (@loads) {
#    print "Working on the load : $load\n" ;
#    next if (is_port($load));
#    my ($inst, $pin) = get_inst_and_pin($load);
#    my ($net) = get_net (-of => $load);
#    my ($net_hier, $net_module, $mnet) = get_net_context ($net);
#
#    my $ref = get_ref $inst ;
#    if ($net_module =~ /^NV_CLK_ELEM|lvlshift/) {
#      my @next = get_output_pins($inst);
#      push (@rtn, get_jtag_clk_loads($_)) foreach @next;
#    } elsif (is_partition_module($net_module)) {                                                                                                                   push (@rtn, $load);                                                                                                                                        } else {
#      push (@rtn, $net);
#    }
#  }
#}
