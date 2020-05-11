Tsub region_place => << 'END';
    DESC {
         To check if the regioned cells placed correct  
    }
    ARGS {
    }

my $rev  = $ENV{USE_LAYOUT_REV};
my $proj = $ENV{NV_PROJECT};

@pars = get_modules ("*PAD0*") ;

#nvb_create_region SDPipe_0 4375.000000000000000 1600.000000000000000 50.000000000000000 50.000000000000000
#nvb_add_to_region SDPipe_0 *SDPipelineIn_UFI_f0_0_0/UJ*
#nvb_add_to_region SDPipe_0 *SDPipelineIn_UFI_f1_0_0/UJ*

foreach $par (@pars) {
  $region_file = "/home/${proj}_layout/tot/layout/${rev}/netlists/scan/${par}.dft_regions.tcl" ;
  print "$region_file\n" ;
  open IN, "$region_file" ;
  open OUT, "> $par.region.rep" ;
  set_top $par ;
  
  while(<IN>) {
    if (/^nvb_create_region/) {
      m/^nvb_create_region\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/ ;
      $r_name = $1 ;
      $region{$r_name}{r_x} = $2 ;
      $region{$r_name}{r_y} = $3 ;
      $region{$r_name}{r_dx} = $4 ;
      $region{$r_name}{r_dy} = $5 ;
    }elsif(/^nvb_add_to_region/) {
      m/^nvb_add_to_region\s+(\S+)\s+(\S+)/ ;
      $r_name = $1 ;
      @cells = get_cells ("$2") ;
      foreach (@cells) {
        ($c_x, $c_y) = get_cell_xy ("$_") ;
        if (in_box ($c_x,$c_y,$r_name)) {
          print OUT "$_ $r_name $c_x $c_y in $region{$r_name}{r_x} $region{$r_name}{r_y} region.\n" ;
        }else{
          print OUT "$_ $r_name $c_x $c_y not in $region{$r_name}{r_x} $region{$r_name}{r_y} region.\n" ;
        }
      } 
    }
  }
  close IN ;
  close OUT ; 
}

sub in_box {
  ($x,$y,$r_n) = @_ ;
  $r_x_min = $region{$r_n}{r_x} - 50 ;
  $r_y_min = $region{$r_n}{r_y} - 50 ;
  $r_x_max = $region{$r_n}{r_x} + $region{$r_n}{r_dx} + 50 ;
  $r_y_max = $region{$r_n}{r_y} + $region{$r_n}{r_dy} + 50 ;
  #print OUT "$x $y $r_x_min $r_x_max $r_y_min $r_y_max\n" ;
  if (($x > $r_x_min) and ($x < $r_x_max) and ($y > $r_y_min) and ($y < $r_y_max)) {
    return 1 ;
  }else{
    return 0 ;
  }
}


END
