Tsub check_jtag_conns => << 'END';
    DESC {
         To check the jtag ports connection from wsc/wso mapping files. 
         tran_analysis -i <input_file> -o <output_file>
    }
    ARGS {
        -i:$input_file   # to specify the input file
        -o:$output_file  # to specify the output file 
    }


open IN, "$input_file" ;

if (!(defined $output_file)) {
  $output_file = $input_file.".conns_rep.txt" ;
}

open OUT, "> $output_file" ;

#GPYPAD0PEX0  PR_WSC_captureWR_buffer_in output      u_GPY_T0_1500_wrapper/captureWR_out__GPYPAD0PEX0cli_top0

while(<IN>) {
  m/(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s*/ ;
  my $par = $1 ;
  $par = lc $par ;
  my $sig = $2 ;
  my $dir = $3 ;
  my $port = $4 ;
  $port = "$par/$port" ;
  my $dri ; 
  my @loads ;
  if ($input_file =~ /wsc/) {
    if( $dir eq "input" ) {
      $dri = get_driver $port ;
      print OUT "$port\t\t$dri\n" ;
    }else{
      @loads = get_loads $port ;
      print OUT "$port\t\t$loads[0]\n" ; 
    }
  }elsif($input_file =~ /wso/) {
    if( $dir eq "output" ) {
      $dri = get_driver $port ;
    print "$input_file $output_file $par $sig $dir $port $dri\n" ;
      print OUT "$port\t\t$dri\n" ;
    }else{
      @loads = get_loads $port ;
    print "$input_file $output_file $par $sig $dir $port $loads[0]\n" ;
      print OUT "$port\t\t$loads[0]\n" ;
    }
  }
}

close IN ;
close OUT ;

END
