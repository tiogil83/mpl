Tsub plot_sdp_chains => << 'END';
    DESC {
          To plot the sdp chains. 
    }
    ARGS {
        -i:$infile        #To specify the input file, chain file dumped from pt.
        -plot             #To plot the ordering
        -chain:$chain_num #To plot the sepcified chain 
        -dist:$distance   #To get the sdp distance larger than some value
        -o:$outfile       #To specify the output file
    }

my @def_files = get_files (-type => def) ;
if ($#def_files == -1) {
    load_def_region_files ;
}

if (!(defined $outfile)) {
    $outfile = $infile.".detail.rep" ;
}

if (defined $opt_plot) {
    plot_macros -no_labels ;
    clear_plot ;
    plot_all_partition ;
}


open IN, "$infile" or die "can't open file $infile\n"; 

my @chain_pins = () ;
my $i = 0 ;

while (<IN>) {
    my $line = $_ ; 
    chomp ;
    my @pins = split (" ", $line) ; 
    $chain_pins[$i] = [@pins] ; 
    $i = $i + 1 ;
}

close IN ;

if (defined $chain_num && ($chain_num < 0 || $chain_num > $#chain_pins)) {
    die "the chain number should be at 0 ~ $#chain_pins\n" ;
}

open OUT, "> $outfile" or die "can't write to file $outfile\n" ; 

my @dist    = () ;
my @cell    = () ;
my @coor_x  = () ;
my @coor_y  = () ; 

for my $i (0..$#chain_pins) {
    print OUT "Chain $i:\n" ;
    my $max_len = get_array_max_length (@{$chain_pins[$i]}) ;
    #print "$max_len\n" ;
    #print (Dumper @{$chain_pins[$i]}) ;
    for my $j (0..$#{$chain_pins[$i]}) {
        if (is_port $chain_pins[$i][$j]) {
            $cell[$i][$j] = $chain_pins[$i][$j] ;
            ($coor_x[$i][$j], $coor_y[$i][$j]) = get_port_xy ("$chain_pins[$i][$j]") ;
        } else {
            $cell[$i][$j] = get_cells (-of => "$chain_pins[$i][$j]") ;
            ($coor_x[$i][$j], $coor_y[$i][$j]) = get_pin_xy ("$chain_pins[$i][$j]") ;
        }
        if ($j == 0) {
            printf OUT ("\tSDP%-3s: %-${max_len}s [ %.3s , %.3s ] \t[%.4s]\n", " ", "Cell name", "x", "y", "dist") ; 
            printf OUT ("\tSDP%-3d: %-${max_len}s [ %.3f , %.3f ]\n", $j, $cell[$i][$j], $coor_x[$i][$j], $coor_y[$i][$j]) ; 
        } else {
            $dist[$i][$j] = get_dist ($coor_x[$i][$j], $coor_y[$i][$j],$coor_x[$i][$j-1], $coor_y[$i][$j-1]) ;
            printf OUT ("\tSDP%-3d: %-${max_len}s [ %.3f , %.3f ]  [%.3f]\n", $j, $cell[$i][$j], $coor_x[$i][$j], $coor_y[$i][$j], $dist[$i][$j]) ;
        }
    }
}

if (defined $distance) {
    print "To get the chains with long distance larger than $distance\n" ; 
    print "Can plot the chains with the cmds as below : \n" ;
    for my $i (0..$#chain_pins) {
        if (grep (($_ > $distance), @{$dist[$i]})) {
            print "plot_sdp_chains -i $infile -chain $i -plot\n" ;
        }
    }
}

if (defined $chain_num) {
    print "Chain $chain_num:\n" ;
    my $max_len = get_array_max_length (@{$chain_pins[$chain_num]}) ;
    printf ("\tSDP%-3s: %-${max_len}s [ %.3s , %.3s ] \t[%.4s]\n", " ", "Cell name", "x", "y", "dist") ;
    printf ("\tSDP%-3d: %-${max_len}s [ %.3f , %.3f ]\n", "0", $cell[$chain_num][0], $coor_x[$chain_num][0], $coor_y[$chain_num][0]) ;
    for my $i (1..$#{$chain_pins[$chain_num]}) {
        printf ("\tSDP%-3d: %-${max_len}s [ %.3f , %.3f ] [%.3f]\n", "$i", $cell[$chain_num][$i], $coor_x[$chain_num][$i], $coor_y[$chain_num][$i], $dist[$chain_num][$i], $dist[$chain_num][$i]) ; 
    }
}

if (defined $opt_plot) {
    if (!(defined $chain_num)) {
        for my $i (0..$#chain_pins) {
            plot (-color => "red", $celll[$i][0]) unless (is_port $cell[$i][0]) ;
            for my $j (1..$#{$chain_pins[$i]}) {
                plot_line (-arrow => "last", $coor_x[$i][$j-1], $coor_y[$i][$j-1],$coor_x[$i][$j], $coor_y[$i][$j], -name => "Chain_$i_SDP_$j", -color => "red" ) ;
                plot (-color => "red", $cell[$i][$j]) unless (is_port $cell[$i][$j]);    
            }
        }
    } else {
        plot ($cell[$chain_num][0], -color => "red") unless (is_port $cell[$chain_num][0]) ;
        for my $i (1..$#{$chain_pins[$chain_num]}) {
            plot_line (-arrow => "last", $coor_x[$chain_num][$i-1], $coor_y[$chain_num][$i-1], $coor_x[$chain_num][$i], $coor_y[$chain_num][$i], -name => "Chain_${chain_num}_SDP_$i", -color => "red" ) ;
            plot (-color => "red", $cell[$chain_num][$i]) unless (is_port $cell[$chain_num][$i]);
        }
    }
}

close OUT ;

END

sub plot_all_partition {
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
            if (-e "${ipo_dir}/${part}/control/${part}_ICC.tcl") {
                load_once "${ipo_dir}/${part}/control/${part}_ICC.tcl" ;
            }
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
