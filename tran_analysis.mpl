Tsub tran_analysis => << 'END';
    DESC {
         To generate the analysis report for transition path_end reports. 
         tran_analysis -i <input_file> -o <output_file>
    }
    ARGS {
        -i:$input_file   # to specify the input file
        -o:$output_file  # to specify the output file 
    }

open IN, "$input_file" or die "can't open file $input_file" ; 

if (!(defined $output_file)) {
   $output_file = $input_file ;
   $output_file = $output_file.".tran_analysis.csv" ;
}

if (-e "$output_file") {
  unlink $output_file ;
}

open OUT, ">> $output_file" ;

#42    gpypad0fba0/top_pads/u_fba/u_padlet/u_bcells/fb_cal_VDDP_SEL0_jtag/jtag_clkinv/I                          0.2  0.205  -0.0050 tt_105c_0p99v_max_si.std_max NV_gpy_t0 (VIOLATED)

my %tran_info ;
my $pin ;
my $dri ;

print OUT "VIOL_PIN,PIN_BLK,REQ,SLACK,DRI_PIN,DRI_BLK,DRI_REF,NET_LENG,ROUTE_LENG,COMMENT,\n" ;

while (<IN>) {
  if (/^\d+\s+(\S+)\s+(\S+)\s+\S+\s+(\S+)/) {
    $pin = $1 ;
    $tran_info{$pin}{req} = $2 ;
    $tran_info{$pin}{slack} = $3 ;
    $dri = get_driver $pin ;
  }else{
    next ;
  }
  
  print "$_ $pin $dri $tran_info{$pin}{req} $tran_info{$pin}{slack}\n" ; 
  
  my @pin_cont = get_pin_context_whier $pin ;  
  my $pin_cont_inst = $pin_cont[0] ;
  my $pin_cont_ref = $pin_cont[1] ;
  my $pin_cont_cell_ref = $pin_cont[3] ;

  if (attr_of_pin ("is_port" => $dri)) {
     print OUT "$pin,$pin_cont_ref,$tran_info{$pin}{req},$tran_info{$pin}{slack},$dri,,,,,port_conn,;\n" ;
  } else {
     my @dri_cont = get_pin_context_whier $dri ;
     my $dri_cont_inst = $dri_cont[0] ;
     my $dri_cont_ref = $dri_cont[1] ;
     my $dri_cont_cell_ref = $dri_cont[3] ;

     if ((is_macro_module $pin_cont_ref) and (is_macro_module $dri_cont_ref) and ($pin_cont_inst eq $dri_cont_inst)) {
        $tran_info{$pin}{comment} = "macro_inside;" ;
     } elsif ((is_macro_module $pin_cont_ref) and (attr_of_ref ('is_partition' => $dri_cont_ref))) {
        $tran_info{$pin}{comment} = "partition2macro;" ; 
     } elsif ((is_macro_module $dri_cont_ref) and (attr_of_ref ('is_partition' => $pin_cont_ref))) {
        $tran_info{$pin}{comment} = "macro2partition;" ;
     } else {
        $tran_info{$pin}{comment} = "partition_inside;" ;
     }
     
     if (is_pad_cell $pin_cont_cell_ref) {
        $tran_info{$pin}{comment} .= "is_pad_pin;" ; 
     }

     my @loads = get_loads $pin ;
     my $loads_num = $#loads + 1 ;
     if ($loads_num > 15) {
        $tran_info{$pin}{comment} .= "hi_fo_${loads_num};" ;
     }
     
     my $net_dist = 0 ;
     $net_dist = get_dist ("$pin" => "$dri") ;

     my @conns = get_conns $pin ;
     my $conns_num = $#conns + 1 ;
     my $length_sum = 0 ;
     foreach my $i (0..$conns_num) {
       if ($conns[$i][1] eq 'net') {
          my $length = get_route_length (-quiet => $conns[$i][0]) ; 
          #my $net_leng = get_net_length (-quiet => $conns[$1][0])  ;
          #$net_dist += $net_leng ;
          $length_sum += $length ;
       }
     }

     if ($net_dist > 250) {
        $tran_info{$pin}{comment} .= "long_net_${net_dist};" ;
     }

     if ($length_sum > ($net_dist + 200)) {
        $tran_info{$pin}{comment} .= "long_route_${length_sum};" ;
     }
     print OUT "$pin,$pin_cont_ref,$tran_info{$pin}{req},$tran_info{$pin}{slack},$dri,$dri_cont_ref,$dri_cont_cell_ref,$net_dist,$length_sum,$tran_info{$pin}{comment},\n" ;
  }
}


close IN ;
close OUT ;

END
