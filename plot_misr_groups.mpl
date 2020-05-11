Tsub plot_misr_groups => << 'END';
    DESC {
          To plot the misr groups ordering. 
    }
    ARGS {
        -i:$infile #To specify the input file, this should be the yaml file. eg : //layout/ga100/revP2.6/blocks/NV_gaa_s0/dft/NV_gaa_s0.misrgroup.noscan.flat.yml 
        -plot      #To plot the ordering
    }

open IN, "$infile" or die "can't open file $infile\n"; 
my %misr_groups = () ;
my $group_num = 0 ;

while (<IN>) {
    chomp ;
    my $line = $_ ;
    my $par ;
    my $i ;
    if ($line =~ /^  group(.*):/) {
        $group_num = $1 ;
        $i = 0 ;
        next; 
    } elsif ($line =~ /^  - (.*):/) {
        $par = $1 ; 
        if ($par =~ /\\|\s+/) {
            $par =~ s/\\//g ;
            $par =~ s/\s+//g ;    
        }
        $misr_groups{$group_num} = $misr_groups{$group_num}." $par" ;
        next ;
    } else {
        next ;
    }
}

close IN ;

if (defined $opt_plot) {
    plot_macros -no_labels ;
    clear_plot ;
    plot_all_partitions ;
}

my @def_files = get_files (-type => def) ;
if ($#def_files == -1) {
    load_def_region_files ;
}

foreach (0..$group_num) {
    my $grp = $misr_groups{$_} ;
    $grp =~ s/^ // ;
    $grp =~ s/ / => /g ;
    print "group $_ : $grp\n" ;

}
my @misr_order = () ; 
my @color = qw (blue black green red) ;

# to get the longest partition name for printing.
my $max_leng = 0 ;

foreach (0..$group_num) {
    my @arr = split (" ", $misr_groups{$_}) ;
    my $length = get_array_max_length (@arr) ;
    if ($length > $max_leng) {
        $max_leng = $length ;
    }  
}

my $print_length = $max_leng + 3 ;  

foreach (0..$group_num) {
    @misr_order = split (" ", $misr_groups{$_}) ;
    my $line_color = $color[-$_] ;
    my $par_num = $#misr_order + 1 ;
    print "group $_ $line_color : $par_num partitions\n" ;

    my %misr_cell_coor = () ;
          
    printf ("%-${print_length}s%10s%10s%-10s\n", "partition", "coor_x", "coor_y", " distance") ;
    
    foreach $i (0..$#misr_order) {
       my $cell = $misr_order[$i] ;
       my $cell_xy = attr_of_cell ("phys_centroid_point" => $cell) ;
       $misr_cell_coor{$i}{x} = $cell_xy->[0] ;
       $misr_cell_coor{$i}{y} = $cell_xy->[1] ; 
       if ($i > 0) {
          if (defined $opt_plot) {
            plot_line(-arrow=>"last", -name => "misr_ordering_group_$i", $misr_cell_coor{$i-1}{x}, $misr_cell_coor{$i-1}{y}, $misr_cell_coor{$i}{x}, $misr_cell_coor{$i}{y}, -color => "$line_color");
          }
          my $dist = get_dist ($misr_cell_coor{$i-1}{x}, $misr_cell_coor{$i-1}{y}, $misr_cell_coor{$i}{x}, $misr_cell_coor{$i}{y}) ;
          printf ("%-${print_length}s%10.3f%10.3f distance : %10.3f\n", $cell, $misr_cell_coor{$i}{x}, $misr_cell_coor{$i}{y}, $dist ) ;
       } else {
          printf ("%-${print_length}s%10.3f%10.3f\n", $cell, $misr_cell_coor{$i}{x}, $misr_cell_coor{$i}{y})  ;
       }
    } 
}

END

sub plot_all_partitions {
    plot_macros -no_labels ;
    clear_plot ;
    my %all_mods = map  ({$_ => 1} (get_modules ("*"))) ;
    my @pars_ref = grep (exists $all_mods{$_}, (all_partitions)) ;
    foreach my $par_ref (@pars_ref) {
        my @par_cells = get_cells_of $par_ref ;
        plot (-no_label => @par_cells) ;
    }
}

sub get_array_max_length {
    my @input = @_ ;
    my $max   = 0  ;
    foreach (@input) {
        my $length = length ($_) ;
        #print "$length\n" ;
        if ($length > $max) {
            $max = $length ;
        }
    }
    return $max ;
}

sub load_def_region_files {
    # dont care about legal placement
    set_eco_legal_placement never ;

    # get macros, partitions, chiplets
    my $top        = get_top ;
    my $project    = $ENV{NV_PROJECT} ;
    my $ipo_dir    = $ENV{IPO_DIR} ;    
    my $common_dir = "${ipo_dir}/${project}_top/control";


    my %all_mods = map  ({$_ => 1} (get_modules ("*"))) ;
    my @macros   = grep ((exists $all_mods{$_}), (all_macros)) ;
    my @parts    = grep ((exists $all_mods{$_}), (all_partitions)) ;
    my @chiplets = grep ((exists $all_mods{$_}), (all_chiplets)) ;
    
    # report
    print "# top : $top\n";
    print "# Start to load def/region files ... \n" ;
    #print "# chiplets: \n";
    #foreach my $mod (@chiplets) {
    #   print "#   |-> $mod\n";
    #}
    #print "# partitions:\n";
    #foreach my $mod (@parts) {
    #   print "#   |-> $mod\n";
    #}
    #print "# macros:\n";
    #foreach my $mod (@macros) {
    #   print "#   |-> $mod\n";
    #}

    # load macros defs:
    foreach my $part (@macros) {

     # full_def
        if  (-e "${ipo_dir}/macros/${part}/control/${part}.def.gz") {
            load_once "${ipo_dir}/macros/${part}/control/${part}.def.gz" ;
        } elsif  (-e "${ipo_dir}/macros/${part}/control/${part}.def") {
            load_once "${ipo_dir}/macros/${part}/control/${part}.def" ;
        } else {
            # print "# no def file found for ${part}\n";
        }
    }
    # load partition _fp defs and regioning files
    foreach my $part (@parts) {

     # full_def
        if  (-e "${ipo_dir}/${part}/control/${part}.def.gz") {
            load_once "${ipo_dir}/${part}/control/${part}.def.gz" ;
        } elsif  (-e "${ipo_dir}/${part}/control/${part}.def") {
            load_once "${ipo_dir}/${part}/control/${part}.def" ;
     # full_def from hfp
        } elsif  (-e "${ipo_dir}/${part}/control/${part}.hfp.fulldef.gz") {
            load_once "${ipo_dir}/${part}/control/${part}.hfp.fulldef.gz" ;
        } elsif  (-e "${ipo_dir}/${part}/control/${part}.hfp.fulldef") {
            load_once "${ipo_dir}/${part}/control/${part}.hfp.fulldef" ;
     # fp.def
        } elsif  (-e "${ipo_dir}/${part}/control/${part}_fp.def") {
            load_once "${ipo_dir}/${part}/control/${part}_fp.def" ;
     # retime regions
            #if (-e "${ipo_dir}/${part}/control/${part}_ICC.tcl") {
            #    load_once "${ipo_dir}/${part}/control/${part}_ICC.tcl" ;
            #}
     # partition pins
            if (-e "${ipo_dir}/${part}/control/${part}.hfp.pin.def") {
                load_once "${ipo_dir}/${part}/control/${part}.hfp.pin.def" ;
            }
     # dft_regions
            if (-e "${ipo_dir}/${part}/control/${part}.dft_regions.tcl") {
                set_top $part ;
                load "${ipo_dir}/${part}/control/${part}.dft_regions.tcl" ;
                set_top $top
            }
        } else {
            print "# No def or ICC.tcl file found for ${part}\n";
        }
    }

    # if there a chiplet _fp.def?
    foreach my $part (@chiplets) {
     # fp.def
        if  (-e "${ipo_dir}/${part}/control/${part}_fp.def")         {
            load_once "${ipo_dir}/${part}/control/${part}_fp.def" ;
     # Chiplet pins
            if (-e "${ipo_dir}/${part}/control/${part}.hfp.pin.def") {
                load_once "${ipo_dir}/${part}/control/${part}.hfp.pin.def" ;
            }
        } else {
            print "# No def or ICC.tcl file found for ${part}\n";
        }
    }

    #of top is nv_top , will read top fp.def
    if ($top eq "nv_top") {
        if  (-e "${ipo_dir}/nv_top/control/nv_top_fp.def") {
            load_once "${ipo_dir}/nv_top/control/nv_top_fp.def" ;
        } else {
            print "#No dft file find for nv_top\n" ;
        }
    }

    # load hcoff.data
    load_once "${common_dir}/hcoff.data" ;

    # catchall for any missing amcro - assumes they are 10 x 10
    set_cell_size_default (-use_square) ;

    set_rc_default_estimated ;
    set_xy_default -centroid ;
   
    print "All the def/region files loaded.\n" ;

}
