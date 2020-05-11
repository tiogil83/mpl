Tsub driver_net => << 'END';
    DESC {
        write out the transition net list  
    }
    ARGS {
        -i:$file_name    # input file name 
    }
    open IN, "$file_name" ;
    $file_name =~ /(.*)\/.*/ ;
    my $dir = $1 ;
    @pins = <IN> ;
    my $date = `date '+%b%d'` ;
    chomp $date ;
    
    my %viols ;
    
    foreach (@pins) {
      chomp ;
      if(/    (gmgpad0.*?)\/(.*?)\s+(\S+)\s+\S+\s+(-.*?) (.*?) NV_gmg_t0/){ ;
        my $par = $1 ;
        my $pin = $2 ;
        my $target = $3 ;
        my $viol = $4 ;
        my $corner = $5 ;
        $par = uc $par ;
        set_top $par ;
        $net = get_net (-of => "$pin") ;
        $driver = get_top_net $net  ;
        chomp $driver ;
        if(exists $viols{$driver}){
          next ;
        }else{
          $viols{$driver} = $viol ;
        }
        if (!(-e "$dir/driver_net.list.$date.$par")){
          open OUT, ">> $dir/driver_net.list.$date.$par" ;
          print OUT "$driver $target $viols{$driver} $corner\n" ;
        }else{
          print OUT "$driver $target $viols{$driver} $corner\n" ;
        }
      }
    }
    
    close OUT ;
    1; 
END
