Tsub gen_jtag_flops_map_willow => << 'END';
    DESC {
         To generate the flops mapping file. Please generate the flops clock files first. 
         get_flops_map_willow -i <input_file> 
    }
    ARGS {
        -i:$input_name   # to specify the input file
    }

open IN, "$input_name" or die "$!" ;

$base = $input_name ;
$file = $input_name ;
chomp $base ;
$base =~ s/(.*)\/.*/$1/ ;
chomp $file ;
$file =~ s/.*\/(.*)/$1/ ;

$par_output = "$base/par.$file" ;
$macro_output = "$base/macro.$file" ;

open OUT_par, "> $par_output" ;
open OUT_macro, "> $macro_output" ;

%macro_ports = () ;

while(<IN>){
  (m/(.*?)\/(\S+) (.*?) (.*)/) ;
  $par = $1 ;
  $pin = $2 ;
  $par = uc $par ;
  $ori_ref = $3 ;
  #print "$par $pin $ori_ref\n" ;
  if (!(attr_of_ref (is_std => $ori_ref))){
    next ;
  }
  $clocks = $4 ;
  $clock_postfix = "jtag_reg_tck" ;

  set_top $par ; 
  if ((attr_of_pin ("is_local", $pin)) == 1) {
    $root_net = get_root (-pin => $pin) ;
    $block = $par ;
    $block_output = "$base/$block.flop_jtagclk.map" ;
    $par = lc $par ;
    #if ((attr_of_net ("is_port_conn", $root_net)) == 1) {
    #   print OUT_par "$par/$pin $root_net is_port_conn\n" ;
    if ($root_net =~ /UJ_0.\/DOUT$/) {
      print OUT_par "$par/$pin $root_net is lvl net\n" ;
      if (!(-e "$par_output.$par")) {
        open OUT_PARTITION, "> $par_output.$par" ;
        print OUT_PARTITION "$pin $clocks\n" ;   
        close OUT_PARTITION ;
      }else{
        open OUT_PARTITION, ">> $par_output.$par" ;
        print OUT_PARTITION "$pin $clocks\n" ;  
        close OUT_PARTITION ;
      }
      if (!(-e "$block_output")) {
        open OUT_BLK, "> $block_output" ; 
        print OUT_BLK "$pin $clock_postfix\n" ;
        close OUT_BLK ;
      }else{
        open OUT_BLK, ">> $block_output" ;
        print OUT_BLK "$pin $clock_postfix\n" ; 
        close OUT_BLK ;
      }
   }else{
     print "$pin $root" ;
     $root = get_driver (-inst => $root_net) ;
     $ref = get_ref $root ;
     if ($ref =~ /CKL/) {
       print OUT_par "$par/$pin $root_net is_not_lvl_cg_conn\n" ;
     }else{
       print OUT_par "$par/$pin $root_net is_not_lvl_conn_not_cg\n" ;
       }
    }
  }else{
    @cons = get_pin_context_whier $pin ;
    $par = lc $par ;
    $macro_inst = $cons[0] ;
    $macro = $cons[1] ;
    $macro_pin = "$cons[2]/$cons[4]" ;
    set_top $macro ;
    $macro_net = get_root $macro_pin ;
    $macro_port = get_driver $macro_net ;
    $inst = $cons[2] ;
    $ref = get_ref $inst ;
    if ((attr_of_net ("is_port_conn", $macro_net)) == 1) {
      print OUT_macro "$par/$macro_inst/$macro_pin $par/$macro_inst/$macro_port is_port_conn\n" ;
      $macro_port = "$par/$macro_inst/$macro_port"  ;
      $macro_ports{$macro_port} = 1 ;
    }elsif($macro_port =~ /DOUT$/){
      $macro_ls_net = $macro_port ;
      $macro_ls_net =~ s/(.*)\/DOUT/$1\/DIN/ ;
      $macro_net = get_root $macro_ls_net ;
      $macro_port = get_driver $macro_net ; 
      if((attr_of_net ("is_port_conn", $macro_net)) == 1) {
        print OUT_macro "$par/$macro_inst/$macro_pin $par/$macro_inst/$macro_port is_ls_conns\n" ;
        $macro_port = "$par/$macro_inst/$macro_port"  ;
        $macro_ports{$macro_port} = 1 ;
      }else{
        print OUT_macro "$par/$macro_inst/$macro_pin $par/$macro_inst/$macro_port double_check\n" ;
      }
    }elsif($ref =~ /CKL/){
      print OUT_macro "$par/$macro_inst/$macro_pin $par/$macro_inst/$macro_port not_a_port_cg\n" ;
    }else{
      print OUT_macro "$par/$macro_inst/$macro_pin $par/$macro_inst/$macro_port not_a_port_not_cg\n" ;
    } 
  }
}

foreach (keys %macro_ports) {
  print ;
  $port = $_ ;
  $partition = $port ;
  $partition =~ s/(.*?)\/.*/$1/ ;
  $block = uc $partition ;
  $block_output = "$base/$block.flop_jtagclk.map" ; 
  $port =~ s/.*?\/(.*)/$1/ ;
  if (!(-e "$macro_output.$partition")) {
    open OUT_MACRO, "> $macro_output.$partition" ;
    print OUT_MACRO "$port\n" ;
    close OUT_MACRO ;
  }else{
    open OUT_MACRO, ">> $macro_output.$partition" ;
    print OUT_MACRO "$port\n" ;
    close OUT_MACRO ;
  }   
  if (!(-e "$block_output")) {
    open OUT_BLK, "> $block_output" ;
    print OUT_BLK "$port $clock_postfix\n" ;
    close OUT_BLK ;
  }else{
    open OUT_BLK, ">> $block_output" ;
    print OUT_BLK "$port $clock_postfix\n" ;
    close OUT_BLK ;
  }
}


close IN ;
close OUT_par ;
close OUT_macro ;

END
