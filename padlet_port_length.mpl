Tsub gen_port_net_leng => << 'END';
    DESC {
         gen_port_net_leng -l <log_file> -o <out_file>
    }
    ARGS {
        -l:$log_file   # to specify the log  file
        -o:$out_file   # to specify the output file 
    }

unless (defined $log_file) {
  $log_file = "gen_port_net_leng.log" ;
}

unless (defined $out_file) {
  $out_file = "gen_port_net_leng.rep" ;
}

open_log "$log_file" ;
open OUT, "> $out_file";

my $top = get_top ;

my @all_ports = get_port "*" ;
foreach my $port(@all_ports) {
  if (attr_of_pin ("is_input", $port) == 1) {
    my @loads = get_loads $port ;
    if ($#loads == -1) {
      lprint "Dangling input port on $port.\n" ;
    }else{
      my @all_nets = get_conns (-net => $port) ;  
      my $route_length = 0 ;
      my $i = 0 ;
      for $i (0..$#all_nets) {
        my $length = get_route_length (-quiet => $all_nets[$i][0]) ; 
        $route_length = $route_length + $length ;
      }
      if ($route_length < 200) {
        lprint "Route length is ok with port : $port $route_length.\n" ;
        print OUT "Route length is ok with port : $port $route_length.\n" ;
      } elsif ($route_length < 400) {
        lprint "Route length is a bit long with port : $port $route_length.\n" ; 
        print OUT "Route length is a bit long with port : $port $route_length.\n" ;
      } else {
        lprint "Route lenghth is too long with port : $port $route_length.\n" ; 
        print OUT "Route length is too long with port : $port $route_length.\n" ;
      }
    } 
  } elsif (attr_of_pin ("is_output", $port) == 1) {
    my $driver = get_driver -quiet -pin $port ;
    if ($driver eq "") {
      lprint "Dangling output port on $port.\n" ;
    }else{
      my @all_nets = get_conns (-net => $port) ;
      my $route_length = 0 ;
      for my $i (0..$#all_nets) {
        my $length = get_route_length (-quiet => $all_nets[$i][0]) ;
        $route_length = $route_length + $length ;
      }
      if ($route_length < 200) {
        lprint "Route length is ok with port : $port $route_length.\n" ;
        print OUT "Route length is ok with port : $port $route_length.\n" ;
      } elsif ($route_length < 400) {
        lprint "Route length is a bit long with port : $port $route_length.\n" ;
        print OUT "Route length is a bit long with port : $port $route_length.\n" ;
      } else {
        lprint "Route lenghth is too long with port : $port $route_length.\n" ;
        print OUT "Route lenghth is too long with port : $port $route_length.\n" ;
      }
    }
  }
}

close OUT ;
close_log ;

END
