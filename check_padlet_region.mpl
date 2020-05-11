Tsub check_padlet_region => << 'END';
    DESC {
          check the placement for the region'ed insts. load this script in post_placement mender session. 
          usage : check_padlet_region -od <output_file_dir>
    }
    ARGS {
          -od:$fo_dir # just specify the outpust dir 
    }

if (! (defined $fo_dir)) {
   $fo_dir = "." ;
}

my $tot = `depth` ;
my $rev = $ENV{USE_LAYOUT_REV}; 
my @region_files = glob "$tot/layout/$rev/blocks/GV*PAD0*0/control/*PAD0*.dft_regions.tcl" ;

foreach my $region_f (@region_files) {
  print "$region_f\n" ;
  $region_f =~ /.*scan\/(\S+)\.dft_regions.tcl/ ;
  my $par = $1 ;
  open IN, "$region_f" ;
  my $fo = "${fo_dir}/${par}.region_check.rep" ;
  open OUT, "> $fo" ;
  print "$fo\n" ;
  set_top $par ;
  print "$par\n" ;
  my %par_region ;
  while (<IN>) {
    if (/nvb_create_region\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/) {
      my $region_name = $1 ;
      $par_region{$region_name}{x} = $2 ;
      $par_region{$region_name}{y} = $3 ;
      $par_region{$region_name}{dx} = $4 ;
      $par_region{$region_name}{dy} = $5 ;
    }elsif (/nvb_add_to_region\s+(\S+)\s+ [get_cells {(.*)}]/) {
      my $pattern = $1 ;
      my $inst = $2 ;
      my @insts = split (/ /, $inst) ;
      foreach my $inst (@insts) {
        my ($inst_x, $inst_y) = get_cell_xy $inst ;
        if (in_box ($inst_x, $inst_y, $par_region{$pattern}{x}, $par_region{$pattern}{y},$par_region{$pattern}{dx}, $par_region{$pattern}{dy})) {
          print OUT "$inst ($inst_x,$inst_y) is in the region $pattern ($par_region{$pattern}{x}, $par_region{$pattern}{y}, $par_region{$pattern}{dx}, $par_r
egion{$pattern}{dy})\n" ;
        }else{
          print OUT "$inst ($inst_x,$inst_y) NOT in the box $pattern ($par_region{$pattern}{x}, $par_region{$pattern}{y}, $par_region{$pattern}{dx}, $par_reg
ion{$pattern}{dy})\n" ;
        }
      }

    }elsif (/nvb_add_to_region\s+(\S+)\s+(\S+)/) {
      print "$1\n$2\n" ;
      my $pattern = $1 ;
      my @insts = get_cells "$2" ; 
      foreach my $inst (@insts) {
        my ($inst_x, $inst_y) = get_cell_xy $inst ;
        if (in_box ($inst_x, $inst_y, $par_region{$pattern}{x}, $par_region{$pattern}{y},$par_region{$pattern}{dx}, $par_region{$pattern}{dy})) {
          print OUT "$inst ($inst_x,$inst_y) is in the region $pattern ($par_region{$pattern}{x}, $par_region{$pattern}{y}, $par_region{$pattern}{dx}, $par_region{$pattern}{dy})\n" ;
        }else{
          print OUT "$inst ($inst_x,$inst_y) NOT in the box $pattern ($par_region{$pattern}{x}, $par_region{$pattern}{y}, $par_region{$pattern}{dx}, $par_region{$pattern}{dy})\n" ;
        }
      }
    } 
  }
  close IN ;
  close OUT ;
}

END

sub in_box {
  my ($inst_x, $inst_y, $box_x, $box_y, $box_dx, $box_dy) = @_ ;
  my $box_nx = $box_x + $box_dx ;
  my $box_ny = $box_y + $box_dy ;
  if (($inst_x > ($box_x - 50) ) && ($inst_y > ($box_y -50) ) && ($inst_x < ($box_nx + 50)) && (inst_y < ($box_ny + 50))) {
    return 1 ;
  }else{
    return 0 ;
  }
}

