use strict ;
use ProjectSetup ;

Tsub shdp_foo  => << 'END';
    DESC {
        foo for mender Tsub
    }

    ARGS {
        -arg1: $arg1
        -arg2: @arg1
    }

END

Tsub aft => << 'END' ;
    DESC {
        alias of all_fanin -to $pin -flat -start
    }
    ARGS {
        $pin
    }

    all_fanin (-flat, -start, -to => $pin) ;

END

Tsub aff => << 'END' ;
    DESC {
        alias of all_fanout -from $pin -flat -end
    }
    ARGS {
        $pin
    }

    all_fanout (-end, -flat, -from => $pin) ;

END

Tsub get_root_pin => << 'END' ;
    DESC {
        alias of get_root -pin
    }
    ARGS {
        $pin
    }

    get_driver (get_root $pin) ; 

END

Tsub load_retime_region_files => << 'END' ;
    DESC {
        load the retime region tcl files.
    }
    ARGS {

    }

    my @all_modules = get_modules "*" ;
    my %all_mods    = map  ({$_ => 1} @all_modules) ;
    my @parts       = grep ((exists $all_mods{$_}), (all_partitions)) ;
    my $top         = get_top ;
    my @loaded_pars = () ;
    my @unload_pars = () ;
    my $proj        = $ENV{NV_PROJECT} ;
    my $rev         = $ENV{USE_LAYOUT_REV} ;
    my $ipo_dir     = "/home/${proj}_layout/tot/layout/${rev}/blocks" ;
 
    foreach my $part (@parts) {
        if (-e "${ipo_dir}/${part}/control/${part}_RETIME.tcl") {
            set_top $part ;
            push @loaded_pars, $part ;
            load "${ipo_dir}/${part}/control/${part}_RETIME.tcl" ;
            set_top $top ;
        } else {
            push @unload_pars, $part ;
        }
    }

    print "Loaded RETIME tcl for pars:\n" ;
    foreach (@loaded_pars) {
        print "\t$_\n" ;
    }
    print "No RETIME tcl for pars:\n" ;
    foreach (@unload_pars) {
        print "\t$_\n" ;
    }

    return 1 ;

END

Tsub load_def_region_files => << 'END' ;
    DESC {
        load all the def and region files for prelayout timing
    }
    ARGS {
        -ipo_dir: $ipo_dir   # netlists dir
        -top: $top           # top module name
        -replace             # to replace the def files  
        -skip: $skip_pattern # to skip some patterns for loading
        -z: $zero            # to place the unplaced instances to 0,0. default is at the centre point
        -all                 # to load all the regions files, including dft regions. only load retime regions by default.
    }
    
    # dont care about legal placement
    set_eco_legal_placement never ;

    # get macros, partitions, chiplets
    if (!(defined $top)) {
        $top = get_top ;
    }
    if (!(defined $ipo_dir)) {
        $ipo_dir = $ENV{IPO_DIR} ;
    }

    my $project    = $ENV{NV_PROJECT} ;
    my $common_dir = "${ipo_dir}/${project}_top/control";

    my @all_modules = get_modules "*" ; 
    my @sel_modules = @all_modules ;
    if (defined $skip_pattern) {
        @sel_modules = grep (($_ !~ /$skip_pattern/), @all_modules) ;
    }
    my %all_mods = map  ({$_ => 1} @sel_modules) ;
    my @macros   = grep ((exists $all_mods{$_}), (all_macros)) ;
    my @parts    = grep ((exists $all_mods{$_}), (all_partitions)) ;
    my @chiplets = grep ((exists $all_mods{$_}), (all_chiplets)) ;

    # report
    print "# top : $top\n";
    print "# Start to load def/region files ... \n" ;

    # load macros defs:
    foreach my $part (@macros) {

     # full_def
        if  (-e "${ipo_dir}/macros/${part}/control/${part}.def.gz") {
            if (defined $opt_replace) {
                load (-replace, "${ipo_dir}/macros/${part}/control/${part}.def.gz") ;
            } else {
                load_once "${ipo_dir}/macros/${part}/control/${part}.def.gz" ;
            }
        } elsif  (-e "${ipo_dir}/macros/${part}/control/${part}.def") {
            if (defined $opt_replace) {
                load (-replace, "${ipo_dir}/macros/${part}/control/${part}.def") ;
            } else {
                load_once "${ipo_dir}/macros/${part}/control/${part}.def" ;
            }
        } else {
            # print "# no def file found for ${part}\n";
        }
    }

    # load partition _fp defs and regioning files
    foreach my $part (@parts) {

     # full_def
        if  (-e "${ipo_dir}/${part}/control/${part}.def.gz") {
            if (defined $opt_replace) {
                load (-replace, "${ipo_dir}/${part}/control/${part}.def.gz") ;
            } else {
                load_once "${ipo_dir}/${part}/control/${part}.def.gz" ;
            }
        } elsif  (-e "${ipo_dir}/${part}/control/${part}.def") {
            if (defined $opt_replace) {
                load (-replace, "${ipo_dir}/${part}/control/${part}.def") ;
            } else {
                load_once "${ipo_dir}/${part}/control/${part}.def" ;
            }
     # full_def from hfp
        } elsif  (-e "${ipo_dir}/${part}/control/${part}.hfp.fulldef.gz") {
            if (defined $opt_replace) {
                load (-replace, "${ipo_dir}/${part}/control/${part}.hfp.fulldef.gz") ;
            } else {
                load_once "${ipo_dir}/${part}/control/${part}.hfp.fulldef.gz" ;
            }
        } elsif  (-e "${ipo_dir}/${part}/control/${part}.hfp.fulldef") {
            if (defined $opt_replace) {
                load (-replace, "${ipo_dir}/${part}/control/${part}.hfp.fulldef") ;
            } else {
                load_once "${ipo_dir}/${part}/control/${part}.hfp.fulldef" ;
            }
     # fp.def
        } elsif  (-e "${ipo_dir}/${part}/control/${part}_fp.def") {
            if (defined $opt_replace) {
                load (-replace, "${ipo_dir}/${part}/control/${part}_fp.def") ;
            } else {
                load_once "${ipo_dir}/${part}/control/${part}_fp.def" ;
            }
     # retime regions
            if (-e "${ipo_dir}/${part}/control/${part}_ICC.tcl") {
                # hack for ga100
                if ($part !~ /GAAL0LNK/) {
                    load_once "${ipo_dir}/${part}/control/${part}_ICC.tcl" ;
                }
            }
     # partition pins
            if (-e "${ipo_dir}/${part}/control/${part}.hfp.pins.def") {
                if (defined $opt_replace) {
                    load (-replace, "${ipo_dir}/${part}/control/${part}.hfp.pins.def") ;
                } else {
                    load_once (-add => "${ipo_dir}/${part}/control/${part}.hfp.pins.def") ;
                }
            }
     # sm hfp.rams_macros.def
            if (-e "${ipo_dir}/${part}/control/${part}.hfp.rams_macros.def") {
                if (defined $opt_replace) {
                    load (-replace, "${ipo_dir}/${part}/control/${part}.hfp.rams_macros.def") ;
                } else {
                    load_once (-add => "${ipo_dir}/${part}/control/${part}.hfp.rams_macros.def") ;
                }
            }
     # dft_regions
            if (defined $opt_all) {
                if (-e "${ipo_dir}/${part}/control/${part}.dft_regions.tcl") {
                    set_top $part ;
                    load "${ipo_dir}/${part}/control/${part}.dft_regions.tcl" ;
                    set_top $top ;
                }
                if (-e "${ipo_dir}/${part}/control/${part}_RETIME.tcl") {
                    set_top $part ;
                    load "${ipo_dir}/${part}/control/${part}_RETIME.tcl" ;
                    set_top $top ;
                }
            } else {
                if (-e "${ipo_dir}/${part}/control/${part}_RETIME.tcl") {
                    set_top $part ;
                    load "${ipo_dir}/${part}/control/${part}_RETIME.tcl" ;
                    set_top $top ;
                }
            }
        } else {
            print "# No def or ICC.tcl file found for ${part}\n";
        }
    }

    # if there a chiplet _fp.def?
    foreach my $part (@chiplets) {
     # fp.def
        if  (-e "${ipo_dir}/${part}/control/${part}_fp.def")         {
            if (defined $opt_replace) {
                load (-replace, "${ipo_dir}/${part}/control/${part}_fp.def") ;
            } else {
                load_once "${ipo_dir}/${part}/control/${part}_fp.def" ;
            }
     # Chiplet pins
            if (-e "${ipo_dir}/${part}/control/${part}.hfp.pin.def") {
                if (defined $opt_replace) {
                    load (-replace, "${ipo_dir}/${part}/control/${part}.hfp.pin.def") ;
                } else {
                    load_once "${ipo_dir}/${part}/control/${part}.hfp.pin.def" ;
                }
            }
        } else {
            print "# No def or ICC.tcl file found for ${part}\n";
        }
    }

    #of top is nv_top , will read top fp.def
    my $top_level_inst ;
    foreach my $chiplet (keys $CONFIG->{partitioning}{chiplets}) {
        if (exists $CONFIG->{partitioning}{chiplets}{$chiplet}{is_toplevel}) {
            my $top_level_inst = $chiplet ;
        }
        if ($top eq $top_level_inst) {
            if  (-e "${ipo_dir}/${top_level_inst}/control/${top_level_inst}_fp.def") {
                if (defined $opt_replace) {
                    load (-replace, "${ipo_dir}/${top_level_inst}/control/${top_level_inst}_fp.def") ;
                } else {
                    load_once "${ipo_dir}/${top_level_inst}/control/${top_level_inst}_fp.def" ;
                }
            } else {
                print "#No dft file find for $top_level_inst\n" ;
            }
        }
    }
    # load hcoff.data
    load_once "${common_dir}/hcoff.data" ;

    # catch all for any missing amcro - assumes they are 10 x 10
    set_cell_size_default (-use_square) ;

    set_rc_default_estimated ;
    if ($zero) {
        set_xy_default -zero ;
    } else {
        set_xy_default -centroid ;
    }

    print "All the def/region files loaded.\n" ;

    return 1 ;

END

Tsub load_def_files => << 'END' ;
    DESC {
        load all the def files for prelayout timing
    }
    ARGS {
        -ipo_dir: $ipo_dir   # netlists dir
        -top: $top           # top module name
        -replace             # to replace the def files  
        -skip: $skip_pattern # to skip some patterns for loading
        -z: $zero            # to place the unplaced instances to 0,0. default is at the centre point
        -all                 # to load all the regions files, including dft regions. only load retime regions by default.
    }
    
    # dont care about legal placement
    set_eco_legal_placement never ;

    # get macros, partitions, chiplets
    if (!(defined $top)) {
        $top = get_top ;
    }
    if (!(defined $ipo_dir)) {
        $ipo_dir = $ENV{IPO_DIR} ;
    }

    my $project    = $ENV{NV_PROJECT} ;
    my $common_dir = "${ipo_dir}/${project}_top/control";

    my @all_modules = get_modules "*" ; 
    my @sel_modules = @all_modules ;
    if (defined $skip_pattern) {
        @sel_modules = grep (($_ !~ /$skip_pattern/), @all_modules) ;
    }
    my %all_mods = map  ({$_ => 1} @sel_modules) ;
    my @macros   = grep ((exists $all_mods{$_}), (all_macros)) ;
    my @parts    = grep ((exists $all_mods{$_}), (all_partitions)) ;
    my @chiplets = grep ((exists $all_mods{$_}), (all_chiplets)) ;

    # report
    print "# top : $top\n";
    print "# Start to load def/region files ... \n" ;

    # load macros defs:
    foreach my $part (@macros) {

     # full_def
        if  (-e "${ipo_dir}/macros/${part}/control/${part}.def.gz") {
            if (defined $opt_replace) {
                load (-replace, "${ipo_dir}/macros/${part}/control/${part}.def.gz") ;
            } else {
                load_once "${ipo_dir}/macros/${part}/control/${part}.def.gz" ;
            }
        } elsif  (-e "${ipo_dir}/macros/${part}/control/${part}.def") {
            if (defined $opt_replace) {
                load (-replace, "${ipo_dir}/macros/${part}/control/${part}.def") ;
            } else {
                load_once "${ipo_dir}/macros/${part}/control/${part}.def" ;
            }
        } else {
            # print "# no def file found for ${part}\n";
        }
    }

    # load partition _fp defs and regioning files
    foreach my $part (@parts) {

     # full_def
        if  (-e "${ipo_dir}/${part}/control/${part}.def.gz") {
            if (defined $opt_replace) {
                load (-replace, "${ipo_dir}/${part}/control/${part}.def.gz") ;
            } else {
                load_once "${ipo_dir}/${part}/control/${part}.def.gz" ;
            }
        } elsif  (-e "${ipo_dir}/${part}/control/${part}.def") {
            if (defined $opt_replace) {
                load (-replace, "${ipo_dir}/${part}/control/${part}.def") ;
            } else {
                load_once "${ipo_dir}/${part}/control/${part}.def" ;
            }
     # full_def from hfp
        } elsif  (-e "${ipo_dir}/${part}/control/${part}.hfp.fulldef.gz") {
            if (defined $opt_replace) {
                load (-replace, "${ipo_dir}/${part}/control/${part}.hfp.fulldef.gz") ;
            } else {
                load_once "${ipo_dir}/${part}/control/${part}.hfp.fulldef.gz" ;
            }
        } elsif  (-e "${ipo_dir}/${part}/control/${part}.hfp.fulldef") {
            if (defined $opt_replace) {
                load (-replace, "${ipo_dir}/${part}/control/${part}.hfp.fulldef") ;
            } else {
                load_once "${ipo_dir}/${part}/control/${part}.hfp.fulldef" ;
            }
     # fp.def
        } elsif  (-e "${ipo_dir}/${part}/control/${part}_fp.def") {
            if (defined $opt_replace) {
                load (-replace, "${ipo_dir}/${part}/control/${part}_fp.def") ;
            } else {
                load_once "${ipo_dir}/${part}/control/${part}_fp.def" ;
            }
     # retime regions
            #if (-e "${ipo_dir}/${part}/control/${part}_ICC.tcl") {
            #    # hack for ga100
            #    if ($part !~ /GAAL0LNK/) {
            #        load_once "${ipo_dir}/${part}/control/${part}_ICC.tcl" ;
            #    }
            #}
     # partition pins
            if (-e "${ipo_dir}/${part}/control/${part}.hfp.pins.def") {
                if (defined $opt_replace) {
                    load (-replace, "${ipo_dir}/${part}/control/${part}.hfp.pins.def") ;
                } else {
                    load_once (-add => "${ipo_dir}/${part}/control/${part}.hfp.pins.def") ;
                }
            }
     # sm hfp.rams_macros.def
            if (-e "${ipo_dir}/${part}/control/${part}.hfp.rams_macros.def") {
                if (defined $opt_replace) {
                    load (-replace, "${ipo_dir}/${part}/control/${part}.hfp.rams_macros.def") ;
                } else {
                    load_once (-add => "${ipo_dir}/${part}/control/${part}.hfp.rams_macros.def") ;
                }
            }
     # dft_regions
            #if (defined $opt_all) {
            #    if (-e "${ipo_dir}/${part}/control/${part}.dft_regions.tcl") {
            #        set_top $part ;
            #        load "${ipo_dir}/${part}/control/${part}.dft_regions.tcl" ;
            #        set_top $top ;
            #    }
            #    if (-e "${ipo_dir}/${part}/control/${part}_RETIME.tcl") {
            #        set_top $part ;
            #        load "${ipo_dir}/${part}/control/${part}_RETIME.tcl" ;
            #        set_top $top ;
            #    }
            #} else {
            #    if (-e "${ipo_dir}/${part}/control/${part}_RETIME.tcl") {
            #        set_top $part ;
            #        load "${ipo_dir}/${part}/control/${part}_RETIME.tcl" ;
            #        set_top $top ;
            #    }
            #}
        } else {
            print "# No def file found for ${part}\n";
        }
    }

    # if there a chiplet _fp.def?
    foreach my $part (@chiplets) {
     # fp.def
        if  (-e "${ipo_dir}/${part}/control/${part}_fp.def")         {
            if (defined $opt_replace) {
                load (-replace, "${ipo_dir}/${part}/control/${part}_fp.def") ;
            } else {
                load_once "${ipo_dir}/${part}/control/${part}_fp.def" ;
            }
     # Chiplet pins
            if (-e "${ipo_dir}/${part}/control/${part}.hfp.pin.def") {
                if (defined $opt_replace) {
                    load (-replace, "${ipo_dir}/${part}/control/${part}.hfp.pin.def") ;
                } else {
                    load_once "${ipo_dir}/${part}/control/${part}.hfp.pin.def" ;
                }
            }
        } else {
            print "# No def or ICC.tcl file found for ${part}\n";
        }
    }

    #of top is nv_top , will read top fp.def
    my $top_level_inst ;
    foreach my $chiplet (keys $CONFIG->{partitioning}{chiplets}) {
        if (exists $CONFIG->{partitioning}{chiplets}{$chiplet}{is_toplevel}) {
            my $top_level_inst = $chiplet ;
        }
        if ($top eq $top_level_inst) {
            if  (-e "${ipo_dir}/${top_level_inst}/control/${top_level_inst}_fp.def") {
                if (defined $opt_replace) {
                    load (-replace, "${ipo_dir}/${top_level_inst}/control/${top_level_inst}_fp.def") ;
                } else {
                    load_once "${ipo_dir}/${top_level_inst}/control/${top_level_inst}_fp.def" ;
                }
            } else {
                print "#No dft file find for $top_level_inst\n" ;
            }
        }
    }
    # load hcoff.data
    load_once "${common_dir}/hcoff.data" ;

    # catch all for any missing amcro - assumes they are 10 x 10
    set_cell_size_default (-use_square) ;

    set_rc_default_estimated ;
    if ($zero) {
        set_xy_default -zero ;
    } else {
        set_xy_default -centroid ;
    }

    print "All the def files loaded.\n" ;

    return 1 ;

END

Tsub load_blk_box_lib => << 'END' ;
    DESC {
        to load the block blox libs for noscan NLs
    }
    ARGS {
    }
    
    my $type = $ENV{NAHIER_TYPE} ;
     
    if ($type ne 'noscan') {
        die "no need to load blk_box lib for non-noscan netlists.\n" ;
    } else {
        my @BlkBoxLibs = glob "/home/junw/mpl/NV_BLKBOX_BUFFER_tsmc16ff_t9_svt_std*lib" ;
        my @LibFiles   = get_files (-type => 'lib') ;
        foreach my $BlkBoxLib (@BlkBoxLibs) {
            if (grep ($BlkBoxLib eq $_, @LibFiles)) {
                next ;
            } else {
                load_once "$BlkBoxLib" ;
            }
        }
    }

    return 1 ;

END

Tsub plot_all_partitions => << 'END' ;
    DESC {
        Plot all the partitions in the current design.
    }
    ARGS {
        -no_label 
    }
    
    my %allModules = map  ({$_ => 1} (get_modules ("*"))) ;
    my @partRefs    = grep (exists $allModules{$_}, (all_partitions)) ;
    plot_macros -no_labels ;
    clear_plot ;
    foreach my $partRef (@partRefs) {
        my @partInsts = get_cells_of $partRef ;
        if ($opt_no_label) {
            plot (-no_label => @partInsts) ;
        } else {
            plot (@partInsts) ;
        }
    }

    return 1 ;

END

Tsub plot_all_modules => << 'END' ;
    DESC {
        Plot all the partitions/macros/rams/analog cells.
        Need to plot_all_partitions first.
    }
    ARGS {
    }
    
    my $type = $ENV{NAHIER_TYPE} ;
    my $rev  = $ENV{USE_LAYOUT_REV} ;
    my $proj = $ENV{NV_PROJECT} ;

    my $layout_dir   = "/home/${proj}_layout/tot/layout/${rev}" ;
    my @ramlib_lef   = glob "${layout_dir}/libs/lef/nvgen_rams_*_mixvt_std.lef" ;
    my $dummy_macros = "${layout_dir}/libs/lef/macros_dummy.lef" ;
    my $coff_data    = "${layout_dir}/blocks/${proj}_top/control/coff.xml" ;

    if ($type ne 'anno') {
        load_once @ramlib_lef ;
        load_once $dummy_macros ;
        load_once $coff_data ;
    }

    my %allModules = map  ({$_ => 1} (get_modules ("*"))) ;
    my @moduleRefs = grep (exists $allModules{$_}, (all_macros)) ; 
    push @moduleRefs, (grep (attr_of_ref (is_ram => $_), (sort keys %allModules))) ;
    push @moduleRefs, (grep (attr_of_ref (is_analog => $_), (sort keys %allModules))) ;
    push @moduleRefs, (grep (attr_of_ref (Prop_IsPad => $_), (sort keys %allModules))) ;

    my @plot_insts = () ;
    
    foreach my $ref (@moduleRefs) {
        my @insts = get_cells_of $ref ;
        foreach my $inst (@insts) {
            if (attr_of_cell (is_placed => $inst)) {
                push @plot_insts, $inst ; 
                #print "$ref $inst\n" ;
            } else {
                next ;
            }
        }
    }

    plot @plot_insts ;
    
    return 1 ;
    
END

Tsub plot_all_regions => << 'END' ;
    DESC {
        to plot all the regions loaded
    }
    ARGS {
    }

    my $top = get_top ;
    if (is_partition_module $top || is_macro_module $top) {
        return "should be run at chiplet level\n" ;
    }

    # to start the plot gui
    plot_all_partitions ;
    plot_all_modules ;
    
    print "\n" ;

    my %blockage_coor      = () ;
    my %region_coor        = () ;

    my %overlap_blockages  = () ;
    my %overlap_multi_rams = () ;

    # to get the blockages coordinates 
    foreach my $par (sort keys %M_blockage) {
        if ($par ne "") {
            foreach my $par_inst (get_cells_of $par) {
                my @blockages = map ([m_get_xy_p2f ($_)], map (@{$_}, values (%{$M_blockage{$par}{PLACEMENT}}))) ;
                my $i = 0 ;
                foreach my $blockage (@blockages) {
                    my @top_blgs_coor = top_rects_of_base_rects (cell_of_name ($par_inst), $blockage) ;
                    my $blockage_name = "blockage_${par}_$i" ;
                    $blockage_coor{$par_inst}{$blockage_name} = $top_blgs_coor[0] ; 
                    $i = $i + 1 ;
                }
            }
        }
    }

    # to get the regions coordinates 
    foreach my $par (sort keys %M_nvb_region) {
        foreach my $region_name (sort keys %{$M_nvb_region{$par}}) {
            my @coor = @{$M_nvb_region{$par}{$region_name}} ;
            foreach my $par_inst (get_cells_of $par) { 
                my @top_coor = top_rects_of_base_rects (cell_of_name ($par_inst), @coor) ;
                $region_coor{$par_inst}{$region_name} = $top_coor[0] ; 
            }
        }
    }

    
    # start to plot the blockages and regions ;
    foreach my $par_inst (sort keys %blockage_coor) {
        foreach my $blkg_name (sort keys %{$blockage_coor{$par_inst}}) {
            plot_rect ($blkg_name, @{$blockage_coor{$par_inst}{$blkg_name}}, -fill => green, -outline => red) ; 
        }
    }


    foreach my $par_inst (sort keys %region_coor) {
        foreach my $region_name (sort keys %{$region_coor{$par_inst}}) {
            plot_rect ($region_name, @{$region_coor{$par_inst}{$region_name}}, -outline => red) ;
        }
    }

    # some check for regions:
    # 1. overbound of the partitions ;
    # 2. overlap with mulitple rams ;
    # 3. overlap with blockage ;

    # 1. overbound of the partitions
    print "\nCheck 1 : region overbound the partitions : \n\n" ;
    foreach my $par_inst (sort keys %region_coor) {
        foreach my $region_name (sort keys %{$region_coor{$par_inst}}) {
            my ($x1, $y1, $x2, $y2) =  @{$region_coor{$par_inst}{$region_name}} ;
            #print ("$x1, $y1, $x2, $y2\n") ;
            if (is_point_in_par ($x1, $y1, $par_inst) && is_point_in_par ($x2, $y1, $par_inst) && is_point_in_par ($x1, $y2, $par_inst) && is_point_in_par ($x2, $y2, $par_inst)) {
            } else {
                print "WARNING : $region_name is over the bounds of $par_inst\n" ;
                hilite (-fill => red, $region_name) ;
            }
        }
    }

    # 2. overlap with mulitple rams
    # to get all the rams/macros/analog cells ;
    my %allModules = map  ({$_ => 1} (get_modules ("*"))) ;
    my @moduleRefs = grep (exists $allModules{$_}, (all_macros)) ;
    push @moduleRefs, (grep (attr_of_ref (is_ram => $_), (sort keys %allModules))) ;
    push @moduleRefs, (grep (attr_of_ref (is_analog => $_), (sort keys %allModules))) ;
    push @moduleRefs, (grep (attr_of_ref (Prop_IsPad => $_), (sort keys %allModules))) ;
    
    my %macros = () ;
    foreach my $ref (@moduleRefs) {
        my @insts = get_cells_of $ref ;
        foreach my $inst (@insts) {
            if (attr_of_cell (is_placed => $inst)) {
                my @list = get_hier_list_txt $inst ;
                my $par = $list[0][1] ;
                foreach my $par_inst (get_cells_of $par) {
                    $macros{$par_inst}{$inst} = rect_of_bound (bound_of_cell $inst) ;
                }
            } else {
                next ;
            }
        }
    }

    print "\nCheck 2  : region overlaps multiple rams : \n\n" ;

    foreach my $par_inst (sort keys %region_coor) {
        foreach my $region_name (sort keys %{$region_coor{$par_inst}}) {
            my $i = 0 ;
            foreach my $inst (sort keys %{$macros{$par_inst}}) {
                my @overlap_rect = rects_of_overlap_rects ($region_coor{$par_inst}{$region_name}, $macros{$par_inst}{$inst}) ; 
                if (@overlap_rect) {
                    $i = $i + 1 ;
                }
            }
            if ($i > 1) {
                $overlap_multi_rams{$par_inst}{$region_name} = $i ;
            }
        }
    }

    foreach my $par_inst (sort keys %overlap_multi_rams) {
        foreach my $region_name (sort keys %{$overlap_multi_rams{$par_inst}}) {
            print "WARINING : $region_name overlaps $overlap_multi_rams{$par_inst}{$region_name} rams/macros/analog/pads\n" ;
            hilite ($region_name, -fill => red) ;
        }
    }

    # 3. overlap with blockage ;
    print "\nCheck 3 : region overlaps blockages : \n\n" ;
    
    foreach my $par_inst (sort keys %blockage_coor) {
        foreach my $blkg_name (sort keys %{$blockage_coor{$par_inst}}) {
            foreach my $region_name (sort keys %{$region_coor{$par_inst}}) {
                my @overlap_rect = rects_of_overlap_rects ($region_coor{$par_inst}{$region_name}, $blockage_coor{$par_inst}{$blkg_name}) ;
                if (@overlap_rect) {
                    print "WARINING : $region_name overlaps blockage\n" ; 
                    hilite ($region_name, -fill => red) ;
                    next ;
                }
            }
        }
    }

    # plot all the macros/rams again for not masked by region rects.
    plot_all_modules ;

    return 1 ;

END

Tsub _get_clk_pin => << 'END' ; 
    DESC {
        get the clock pin of the cell
    }
    ARGS {
        -inst: $inst_name   # specified instance name 
    }

    my @cp_pin_name = grep (attr_of_pin("is_clock",$_),get_pins (-of => $inst_name));
    if ($#cp_pin_name == 0) {
        return $cp_pin_name[0] ;
    } else {
        print "ERROR: $inst_name had multi-cp\n";
        return ;
    }
    
    return 1 ;

END

Tsub _get_d_pin => << 'END' ; 
    DESC {
        get the data pin of the cell
    }
    ARGS {
        -inst: $inst_name    # specified instance name
    }
    my @d_pins = grep (attr_of_pin("is_data",$_),get_pins (-of => $inst_name));
    foreach (@d_pins) {
        my @pin_context  = get_pin_context $_ ;
        my $lib_pin_name = @pin_context[-1] ;
        if ($lib_pin_name eq 'E') {
            pop @d_pins, $_ ;
        }
    }
    if ($#d_pins == 0) {
        return $d_pins[0] ;
    } else {
        print "ERROR: $pin_name had multi-d\n" ;
    }

    return 1 ;

END

Tsub _get_pin_par => << 'END' ; 
    DESC {
        get the partition of the pin
    }
    ARGS {
        -pin: $pin    # specified pin name 
    }

    my @all_refs  = get_hier_list_txt ( "-ref", -of_pin => $pin);
    my @all_insts = get_hier_list_txt ( "-inst", -of_pin => $pin);
    my $par_name = "";
    while (my ($index, $value) = each @all_refs) {
        if (attr_of_ref("is_partition",$value)) {
            $par_name = $par_name."$all_insts[$index]";
            return $par_name ;
        } else {
            $par_name = $par_name."$all_insts[$index]/" ;
        }
    }

    return 1 ;

END

Tsub _get_delay_by_dist => << 'END' ;
    DESC {
        get the delay value by distance from start_pin to end_pin
    }
    ARGS {
        -start: $start_pin      # specified the start pin name
        -end: $end_pin          # specified the end pin name 
        -delay_f: $delay_factor # delay factor to ajust delay for correlating the real anno timing session. 1 by default
    }
    
    if (!(defined $delay_factor)) {
        $delay_factor = 1 ;
    }
    
    my $path_delay = get_path_delay (-from => $start_pin, -to => $end_pin, -wire_model => 'dist', -rtn_delay) ;
    my $rtn_delay  = $path_delay * $delay_factor ;
    return $rtn_delay ;

END

Tsub _calc_slack => << 'END' ;
    DESC {
        calculate the path slack 
    }
    ARGS {
        -l_cp_lat: $laun_clk_lat    # launch clock latency
        -c_cp_lat: $capt_clk_lat    # capture clock latency
        -cp_period: $clk_period     # clock period
        -data_delay: $dp_delay      # data path delay
    }

    my $rtn_slack = $clk_period + $capt_clk_lat - $laun_clk_lat -$dp_delay ;
    return $rtn_slack ;

END

Tsub _stop_i1500_bypass_pins => << 'END' ;
    DESC {
        stop the timing arc of i1500 bypass anchor buffers, to aviod bogus paths.
    }
    ARGS {
    }

    my @i1500_byp_anc_buf_pins = get_pins (-quiet, -of => (get_cells (-quiet, -hier => "*/UJ_i1500_bypass_pipe_*"), -dir => 'in')) ;
    foreach my $pin (@i1500_byp_anc_buf_pins) {
        if (is_power_net $pin) {
            next ;
        } else {
            if (x_case_of_pin (pin_of_name ($pin)) eq "D") {
                next ;
            } else {
                set_disable_timing $pin ;
            }
        }
    }

END

Tsub plot_path => << 'END' ;
    DESC {
        plot the flyline from start_pin to end_pin
    }
    ARGS {
        -from: $start_pin      # from the start pin
        -to: $end_pin          # to the end pin
        -comment: $comment     # adding comment for the flyline
        -color: $color         # specify the flyline color, red by default
    }

    if (!(defined $color)) {
        $color = "red" ;
    }

    my $start_inst = "" ;
    my $end_inst   = "" ;
    my ($start_x, $start_y, $end_x, $end_y) = () ;

    if (is_port $start_pin) {
        $start_inst = $start_pin ;
    } else {
        $start_inst = get_cells (-of => $start_pin) ;
    }

    if (is_port $end_pin) {
        $end_inst = $end_pin ;
    } else {
        $end_inst = get_cells (-of => $end_pin) ;
    }

    ($start_x, $start_y) = get_pin_xy $start_pin ;
    ($end_x, $end_y)     = get_pin_xy $end_pin ;

    if ($start_inst ne $end_inst) {
        _plot_virtual_cell_rect (-inst => $start_inst) ; 
        _plot_virtual_cell_rect (-inst => $end_inst) ; 
        plot_line(-arrow=>"last", -name => "$comment", $start_x, $start_y, $end_x, $end_y, -color => "$color");
    }


END

Tsub _plot_virtual_cell_rect => << 'END' ;
    DESC {
        plot a virtual cell rectagle
    }
    ARGS {
        -inst: $inst_name     # name the rectangle 
        -dx: $dx              # rectangle delta x, 2 by default 
        -dy: $dy              # rectangle delta y, 0.5 by default 
        -fill: $fill_color    # fill color, red by default
        -out: $out_color      # outline color, black by default
    }
    
    my ($x, $y)   = () ;
    my ($nx, $ny) = () ; 

    if (!(defined $dx)) {
        $dx = 2 ;
    }
    
    if (!(defined $dy)) {
        $dy = 0.5 ;
    }

    if (!(defined $fill_color)) {
        $fill_color = "red" ; 
    }
    
    if (!(defined $out_color)) {
        $out_color = "black" ;
    }

    if (is_port $inst_name) {
        ($x, $y) = get_pin_xy $inst_name ;
        $inst_name = "PORT :".$inst_name ;
        $nx = $x + 0.3 ;
        $ny = $y + 0.3 ;
    } else { 
        ($x, $y) = get_cell_xy $inst_name ; 
        $nx = $x + $dx ;
        $ny = $y + $dy ;
    }

    plot_rect ($inst_name, $x, $y, $nx, $ny, -fill => "$fill_color", -outline => "$out_color") ;
     
    return 1 ;

END

Tsub _get_clk_dist_ordering => << 'END' ;
    DESC {
        get the clock distribution ordering 
    }
    ARGS {
        -from: $start_pin      # clock path start pin
        -to: $end_pin          # clock path end pin
    }

    my @clk_dist_ordering = () ;
    push @clk_dist_ordering, $start_pin ;

    my @clk_dist_path = get_path_delay (-from => $start_pin, -to => $end_pin, -rtn_from_in, -wire_model => 'none') ;
    my @clk_dist_pins = grep ($_ =~ / \(NV_CLK_ELEM/, @clk_dist_path) ;
    foreach my $pin (@clk_dist_pins) {
        $pin =~ s/\s*(\S+)\s+.*/$1/ ;
        if (is_input_pin (pin_of_name $pin)) {
            push @clk_dist_ordering, $pin ;
        } else {
            next ;
        }
    }
    
    push @clk_dist_ordering, $end_pin ;

    return @clk_dist_ordering ;

END

Tsub _get_i1500_ordering => << 'END' ;
    DESC {
        get the i1500 ordering, especially for wsc signals
    }
    ARGS {
        -from: $start_pin   # i1500 start pin
        -to: $end_pin       # i1500 end pin
    }
    
    my @i1500_ordering = () ;
    push @i1500_ordering, $start_pin ;

    my @i1500_path      = get_path_delay (-from => $start_pin, -to => $end_pin, -rtn_from_in, -wire_model => 'none') ;
    my @i1500_path_pins = grep ($_ =~ /_cli\/ieee_1500_cli_ao_inst\/UJ_i1500_cli_ao_/, @i1500_path) ;
    foreach my $pin (@i1500_path_pins) {
        $pin =~ s/\s*(\S+)\s+.*/$1/ ;
        if (is_input_pin (pin_of_name $pin)) {
            push @i1500_ordering, $pin ;
        } else {
            next ;
        }
    }

    push @i1500_ordering, $end_pin ; 

    return @i1500_ordering ;

END

Tsub plot_thr_path => << 'END' ;
    DESC {
        plot the flyline through the logics  
    }
    ARGS {
        -path_pin_array: @path_pins # path pins array from get_path_delay 
        -color: $color              # specify the flylines color, read by default
    }

    if (!(defined $color)) {
        $color = "red" ;
    }

    foreach my $i (1..$#path_pins) {
        plot_path (-from => $path_pins[$i-1], -to => $path_pins[$i], -comment => "$path_pins[$i-1] => $path_pins[$i]", -color => "$color") ;
    }

END

Tsub _get_all_wsi_paths => << 'END' ;
    DESC {
        get all the wsi paths in current design
    }
    ARGS {
        -debug    # print out the debug files  
    }
    
    my %all_wsi_paths    = () ;
    my @i1500_wsi_starts = () ;

    # to find all the i1500 cells
    push @i1500_wsi_starts, (get_cells (-quiet, -hier => "*wby_reg_reg")) ;
    push @i1500_wsi_starts, (get_cells (-quiet, -hier => "*wso_pos_reg")) ;
    push @i1500_wsi_starts, (get_cells (-quiet, -hier => "*i1500_data_pipe_*/UJ_pos_pipe_reg")) ;
    push @i1500_wsi_starts, (get_cells (-quiet, -hier => "*retime_path_*/i1500_wsc_pipe_*/wso_pipe_out_reg")) ;
    push @i1500_wsi_starts, (get_cells (-quiet, -hier => "*_1500_pipeline/wso_pipe_out_to_cluster_reg")) ;
    push @i1500_wsi_starts, (grep ($_ =~ /wsc_inpd\[[0-4]\]$/, (get_ports (-quiet, "*wsc_inpd*")))) ;

    foreach my $inst (@i1500_wsi_starts) {
        my $i1500_start_pin = "" ;
        my $i1500_start_par = "" ;

        if (is_port $inst) {
            $i1500_start_pin = $inst ;
            $i1500_start_par = $inst ;
        } else {
            $i1500_start_pin = _get_clk_pin (-inst => $inst) ;
            $i1500_start_par = _get_pin_par (-pin  => $i1500_start_pin) ;
        }

        my @all_fo_pins = get_fanout_case (-end => "$i1500_start_pin") ;

        foreach my $end_pin (@all_fo_pins) {
            $end_pin =~ s/(\S+)\s+.*/$1/ ;
            if ((is_port $end_pin) or (is_port $i1500_start_pin) and $end_pin =~ /\/D$/) {
                $all_wsi_paths{$i1500_start_pin}{$end_pin} = 1 ;
                next ;
            } elsif ($end_pin =~ /\/wby_reg_reg\D|_1500_pipeline\/wso_pipe_out_to_cluster_reg\/D|\/UJ_pos_pipe_reg\/D|\/wso_pos_reg\/D|\/wsi_pipe_out_to_client_reg\/D/) {
                if (($end_pin =~ /^$i1500_start_par.*\/i1500_data_pipe_/) || ($end_pin !~ /^$i1500_start_par/)) {
                    $all_wsi_paths{$i1500_start_pin}{$end_pin} = 1;
                } else {
                    next ;
                }
            } else {
                next ;
            }
        }
    }

    if (defined $opt_debug) {
        print "DEBUG : all the WSI path pairs :\n" ;
        foreach my $key1 (sort keys %all_wsi_paths) {
            foreach my $key2(sort keys %{$all_wsi_paths{$key1}}) {
                print "S: $key1 E: $key2\n" ;
            } 
        }
    }
    
    return %all_wsi_paths;

END

Tsub _get_all_wsc_paths => << 'END' ;
    DESC {
        get all the wsc paths in current design
    }
    ARGS {
        -debug         # dump out the debug file
    }

    my %all_wsc_paths  = () ;
    my @i1500_wsc_ends = () ;
    
    # to find all the wsc ends 
    push @i1500_wsc_ends, (get_cells (-quiet, -hier => "*wso_pos_reg"));
    push @i1500_wsc_ends, (get_cells (-quiet, -hier => "*wby_reg_reg"));
    push @i1500_wsc_ends, (get_cells (-quiet, -hier => "*retime_path_*/i1500_wsc_pipe_*/wso_pipe_out_reg")) ;
    push @i1500_wsc_ends, (grep ($_ =~ /wsc_outpd\[[0-4]\]$/, (get_ports (-quiet, "*wsc_outpd*")))) ; 

    foreach my $inst (@i1500_wsc_ends) {
        my $i1500_d_pin   = "" ;
        my $i1500_end_par = "" ; 

        if (is_port $inst) {
            $i1500_d_pin   = $inst ;
            $i1500_end_par = $inst ;
        } else {
            $i1500_d_pin   = _get_d_pin (-inst => $inst) ;
            $i1500_end_par = _get_pin_par (-pin => $i1500_d_pin) ;
        }

        my @all_fanin_pins = get_fanin_case (-end, $i1500_d_pin) ;

        foreach my $start_pin (@all_fanin_pins) {
            $start_pin =~ s/(\S+)\s+.*/$1/ ;
            if (((is_port $start_pin) or (is_port $i1500_d_pin)) and ($start_pin =~ /wsc_inpd\[[0-4]\]$/)) {
                $all_wsc_paths{$start_pin}{$i1500_d_pin} = 1 ;
            } elsif (($i1500_d_pin =~ /\/wby_reg_reg\//) and ($start_pin =~ /.*pipe_out_to_client_reg/)) {
                $all_wsc_paths{$start_pin}{$i1500_d_pin} = 1;  
            } elsif (($i1500_d_pin !~ /\/wby_reg_reg\//) and ($start_pin =~ /wso_pipe_out_to_cluster_reg|wso_pipe_out_reg|wso_pos_reg/)) {
                $all_wsc_paths{$start_pin}{$i1500_d_pin} = 1 ;
            } else {
                next ;
            } 
        }
    }

    if (defined $opt_debug) {
        foreach my $key1 (sort keys %all_wsc_paths) {
            foreach my $key2 (sort keys %{$all_wsc_paths{$key1}}) {
                print "S: $key1 E: $key2\n" ;
            }
        }
    }
    
    return %all_wsc_paths ; 

END

Tsub plot_paths_thr_net => << 'END' ;
    DESC {
        To plot the paths fly lines through one net
    }
    ARGS {
        $net_name  # to specify the net name for plotting
        -plot           # to plot the fly lines 
    }

    my %path  = () ;
    my @fis   = get_fan2 (-end, -fanin => $net_name) ; 
    my @fos   = get_fan2 (-end, -fanout => $net_name) ; 

    foreach my $fi (@fis) {
        $fi =~ s/(\S+)\s+.*/$1/ ;
        foreach my $fo (@fos) {
            $fo =~ s/(\S+)\s+.*/$1/ ;
            my $rtn_d = get_path_delay (-from => $fi, -to => $fo, -rtn_delay, -quiet) ;
            my $dist  = get_dist ($fi, $fo) ;
            if ($rtn_d ne "") {
                $path{$fi}{$fo} = $dist ;
            } 
        }
    }
    
    if (defined $opt_plot) {
        plot_all_partitions ;
    }

    my $fi_len = get_array_max_length (@fis) ;
    my $fo_len = get_array_max_length (@fos) ; 

    print "Fanin to Fanout through $net_name\n" ;
    foreach my $fi (sort keys %path) {
        foreach my $fo (sort keys %{$path{$fi}}) {
            printf ("Dist : %.3fum Start : %-${fi_len}s End : %-${fo_len}s\n", $path{$fi}{$fo}, $fi, $fo) ;
            if (defined $opt_plot) {
                plot_path (-from => $fi, -to => $fo, -comment => "$fi => $fo DIST : $path{$fi}{$fo}", -color => 'red') ; 
            }
        }
    }

    return 1 ;

END

Tsub plot_full_path => << 'END' ;
    DESC {
        to plot all the path pins
    }
    ARGS {
        -from:$sp 
        -to:$ep
    }
    
    my @full_path_pins = grep ($_ !~ /(net)/, (get_path_delay (-from => $sp, -to => $ep))) ;

    my @pin_list = () ;
    my @ref_list = () ;

    foreach my $line (@full_path_pins) {
        if ($line =~ /^\s+Point|^\s+-/) {
            next ;
        } else {
            $line =~ /^\s+(\S+)\s+\((\S+)\)\s+.*/ ;
            my $pin = $1 ;
            my $ref = $2 ;
            push @pin_list, $pin ;
            push @ref_list, $ref ;
        }
    }

    plot_all_partitions ;
    
    foreach my $i (1..$#pin_list) {
        if (attr_of_ref (is_std => $ref_list[$i])) {
            my $inst   = get_cell (-of => $pin_list[$i]) ;
            my $inst_p = get_cell (-of => $pin_list[$i-1]) ;
            if ($inst ne $inst_p) {
                plot $inst_p ;
            }
        } 
        my ($sx, $sy) = get_pin_xy ($pin_list[$i-1]) ;
        my ($ex, $ey) = get_pin_xy ($pin_list[$i]) ;
        my $comment = "$pin_list[$i-1] => $pin_list[$i]" ;
        plot_line (-arrow => "last", -name => "$comment", $sx, $sy, $ex, $ey, -color => "red") ;
    }

END

Tsub get_array_max_length => << 'END' ; 
    DESC {
        to get the array longest element length 
    }

    my @input = @_ ;
    my $max   = 0  ;
    foreach (@input) {
        my $length = length ($_) ;
        if ($length > $max) {
            $max = $length ;
        }
    }
    return $max ;

END

Tsub sum_rep => << 'END';
    DESC {
        auto load filter mpl and report setup/hold/transition 
    }

    ARGS {
        -top: $top   # to specify the top for loading chiplet filter mpl file.
    }

    if ($top eq "") {
        die "Please specify a top module.\n"
    }

    my $top_level = "" ;   
    if ($top =~ /^nv.*_top/) {
        $top_level = "top" ;
    } elsif (grep ($top eq $_, all_chiplets)) {
        $top_level = "chiplet" ;
    } elsif (grep ($top eq $_, all_partitions)) {
        $top_level = "partition" ;
    } elsif (grep ($top eq $_, all_macros)) {
        $top_level = "macro" ;
    } else {
        die "Wrong module name. Please double check.\n" ;
    }


    # load the violation process script
    load_mpl "/home/nvtools/latest/nvtools/timing/vioProcessing/vioFilter/violsFilterSub.v2.mpl" ;
    defineCustomAttr ;

    # to get the filter file ;
    my $timing_scripts_dir = "$ENV{NV_PROJECT}/timing_scripts" ;
    my $global_filter      = "${timing_scripts_dir}/$ENV{NV_PROJECT}.filter.mpl" ;
    my $chiplet_filter     = "${timing_scripts_dir}/$top.filter.mpl" ;
    my @filter_files       = () ;
    
    if ($top =~ /^nv.*_top$/) {
        @filter_files = glob "${timing_scripts_dir}/*.filter.mpl" ;
    } else { 
        if (-e $global_filter) {
            push @filter_files, "$global_filter" ;
        }
        if (-e $chiplet_filter) {
            push @filter_files, "$chiplet_filter" ;
        }
    }
    
    foreach (@filter_files) {
        load_mpl "$_" ;
    } 

    print "\nfilter files:\n" ;
    foreach (@filter_files) {
        print "\t$_\n" ;
    } 

    my %mode_corners         = () ;
    my %missing_mode_corners = () ;

    foreach my $file (get_files (-type => 'vios')) {
        my $corner   = (attr_of_file ('project_corner' => $file)) ;
        my $mode     = (attr_of_file ('mode' => $file)) ;
        my $datecode = (attr_of_file ('datecode' => $file)) ;
        $mode_corners{$datecode}{$mode}{$corner} = 1 ; 
    }
   
    foreach my $datecode (sort keys %mode_corners) { 
        foreach my $mode (sort keys %{$mode_corners{$datecode}}) {
            my @modes = () ;  
            $mode =~ s/(.*)_max$/$1/ ;
            $mode =~ s/(.*)_min$/$1/ ;
            push @modes, "${mode}_max" ;
            push @modes, "${mode}_min" ;
            @modes = remove_duplicates @modes ;
            foreach my $mode_name (@modes) {
                my @all_corners = () ;
                push @all_corners, (get_phase_corners (-top => $top_level, -mode => $mode_name)); 
                foreach my $corner (@all_corners) {
                    if (exists $mode_corners{$datecode}{$mode_name}{$corner}) {
                        next ;
                    } else {
                        $missing_mode_corners{$datecode}{$mode_name}{$corner} = 1 ;
                    }
                }
            }
        }
    }
    print "\nMissing corners : \n" ;
    
    foreach my $datecode (sort keys %missing_mode_corners) {
        foreach my $mode (sort keys %{$missing_mode_corners{$datecode}}) {
            print "$datecode\t$mode : \n" ;
            foreach my $corner (sort keys %{$missing_mode_corners{$datecode}{$mode}}) {
                print "\t$corner\n" ;
            }
        } 
    }
    
    get_viol_file_pattern_by_datecode ;

    # to print out the histogram 
    print "\nSetup :\n\n" ;
    print "MENDER > report_vios -filter \"slack < 0 and type eq \'max\' and disabled == 0\" -by \"mode end_clk\" -show \"bin(setup) wns(setup) count(end_pin)\"\n\n" ;
    print (join "\n", (report_vios (-filter => "slack < 0 and type eq \'max\' and disabled == 0", -by => "mode end_clk", -show => "bin(setup) wns(setup) count(end_pin)"))) ;

    print "\nHold :\n\n" ;
    print "MENDER > report_vios -filter \"slack < 0 and type eq \'min\' and disabled == 0\" -by \"mode start_par end_par end_par_ipo project_corner\" -show \"bin(hold) wns(hold) tns(hold) count(end_pin) worst(id)\"\n\n" ;
    print (join "\n", (report_vios (-filter => "slack < 0 and type eq \'min\' and disabled == 0", -by => "mode start_par end_par end_par_ipo project_corner", -show => "bin(hold) wns(hold) tns(hold) count(end_pin) worst(id)"))) ;

    print "\nTransition :\n\n" ;
    print "MENDER > report_vios -class tran -filter \"slack < 0 and disabled == 0\" -by \"mode type_class\" -show \"bin(slack) wns(slack) tns(slack) count(end_pin) worst(id)\"\n\n" ;
    print (join "\n", (report_vios (-class => tran, -filter => "slack < 0 and disabled == 0", -by => "mode type_class", -show => "bin(slack) wns(slack) tns(slack) count(end_pin) worst(id)"))) ;

    print "\n\n" ;

    return 1 ;

END

Tsub get_viol_file_pattern_by_datecode => << 'END';
    DESC {
        to get the violation pattern 
    }

    my @viol_files = get_files (-type => "vios") ;

    # PBA and GBA reports
    my %pba_reps = () ;
    my %gba_reps = () ;

    my $rep_dir = "$ENV{NV_PROJECT}/rep" ;

    # /home/scratch.ga100_test_NV_gaa_s0_capture/ga100/ga100/timing/ga100/rep/NV_gaa_s0..anno560000.pt.tt_105c_0p94v_max_si.capture_ftm_xtr_max.flat.none.2019May05_07_39_revP5p0_ftm_xtr.unified.pba.viol.gz
    # /home/scratch.ga100_test_NV_gaa_s0/ga100/ga100/timing/ga100/rep/NV_gaa_s0..anno560000.pt.ssg_m40c_0p72v_min_si.ram_access_min.hs_ctx.TOP_FGNLXSP_UNIQ__107.2019May05_07_37_revP5p0_ra.unified.pba.viol.gz
    foreach my $file (@viol_files) {
        my $dir      = attr_of_file ("full_dir" => $file) ;
        my $module   = attr_of_file ("file_module" => $file) ;
        my $ipo      = attr_of_file ("anno" => $file) ;
        my $corner   = attr_of_file ("project_corner" => $file) ;
        my $mode     = attr_of_file ("mode" => $file) ;
        my $datecode = attr_of_file ("datecode" => $file) ;
        
        my $vio_key  = "$dir/$module..anno$ipo.pt.$datecode" ;

        if ($file =~ /pba/) {
            my $vio_val = "$dir/$module..anno$ipo.pt.*.$datecode.unified.pba.viol.gz" ;
            $pba_reps{$vio_key} = $vio_val ;
        } else {
            my $vio_val = "$dir/$module..anno$ipo.pt.*.$datecode.unified.viol.gz" ;
            $gba_reps{$vio_key} = $vio_val ;
        }
    }
    
    # dump the vios
    print "\npba reports : \n" ;
    foreach my $vio (sort keys %pba_reps) {
        print "load_vios $pba_reps{$vio}\n"
    }
    print "\ngba reports : \n" ;
    foreach my $vio (sort keys %gba_reps) {
        print "load_vios $gba_reps{$vio}\n"
    }
    print "\n" ;

    return 1 ;

END

Tsub get_phase_corners => << 'END' ;
    DESC {
        to get all the corners for phase 
    }

    ARGS {
        -top:$top           # to specify the top level : [nv_top|chiplet|partition|macro] 
        -mode:$mode_name    # to specify the mode.
        -phase:$phase_name  # to specify the phase, signoff by default . 
    }

    if (!(defined $phase_name)) {
        $phase_name = "dgpu_timing_signoff" ;
    }
    
    if (!(defined $mode_name)) {
        $mode_name = "std_max" ;
    }
    
    if (!(defined $top))  {
        $top = "chiplet" ;
    }

    my %corners = () ;

    my $yaml_file = "$ENV{NV_PROJECT}/project_setup.yaml" ;
    my $chip      = "$ENV{NV_PROJECT}" ;

    my $ps = new ProjectSetup(-yamlFile => $yaml_file, -debug => 0, -project => $chip) ;
    my $phases = $ps->GetProject(-project => $chip, -param => "phases") ;

    foreach my $corner (sort keys %{${$phases}{$phase_name}{corners}}) {
        #print "$phase_name $mode_name $corner $top\n" ;
        if (exists ${$phases}{$phase_name}{corners}{$corner}{constraint_modes}{tool_defaults}{$mode_name}{block_levels}{$top}) {
            if (${$phases}{$phase_name}{corners}{$corner}{constraint_modes}{tool_defaults}{$mode_name}{block_levels}{$top} eq 'true') {
                $corners{$corner} = 1 ;
            }
        }
    }

    my @phase_corners = (sort keys %corners) ;

    return @phase_corners ;

END

Tsub is_clk_pin_source => << 'END' ; 
    DESC {
        to check if clock pin_sources and return the clock names.
    }
    ARGS {
        -pin: $pin_name
    }

    my @rtn      = () ;
    my %clocks   = %{$CONFIG->{clock_timing_specification}{clock}} ; 

    foreach my $clk (sort keys %clocks){
        if (exists $clocks{$clk}{pin_sources}) {
            if (grep ($_ eq $pin_name, @{$clocks{$clk}{pin_sources}})) {
                if (grep ($_ eq $clk, @rtn)) {
                    next ;
                } else {
                    push @rtn, $clk ;
                }
            } elsif (grep ($_ eq $pin_name, @{$clocks{$clk}{biport_sources}})) {
                if (grep ($_ eq $clk, @rtn)) {
                    next ;
                } else {
                    push @rtn, $clk ;
                }
            }
        } elsif (exists $clocks{$clk}{clock_configs}) {
            foreach my $cfg (keys %{$clocks{$clk}{clock_configs}}) {
                if (exists $clocks{$clk}{clock_configs}{$cfg}{pin_sources}) {
                    if (grep ($_ eq $pin_name, @{$clocks{$clk}{clock_configs}{$cfg}{pin_sources}})) {
                        if (grep ($_ eq $clk, @rtn)) {
                            next ;
                        } else {
                            push @rtn, $clk ;
                        }
                    } elsif (grep ($_ eq $pin_name, @{$clocks{$clk}{clock_configs}{$cfg}{biport_sources}})) {
                        if (grep ($_ eq $clk, @rtn)) {
                            next ;
                        } else {
                            push @rtn, $clk ;
                        }
                    }
                } 
            }
        } 
    }

    return @rtn ;

END

Tsub get_fan2_fanin_thr_ls => << 'END' ;
    DESC {
        to get the fan2 fanin through level shifters
    }
    ARGS {
        -pin: $pin_name 
    }

    my @rtn = () ;
    
    my @fins = get_fan2 (-in, -out, -pins, -fanin, -unate_cg, -end, $pin_name) ; 
    while (1) {
        if (grep ($_ =~ /\/DOUT$/, @fins)) {
            my @int_fis   = () ;
            my @douts     = grep ($_ =~ /\/DOUT$/, @fins) ;
            my @non_douts = grep ($_ !~ /\/DOUT$/, @fins) ; 
            push @rtn, @non_douts ;
            foreach my $dout_pin (@douts) {
                my $din_pin = $dout_pin ;
                $din_pin =~ s/\/DOUT$/\/DIN/ ;
                push @int_fis, (get_fan2 (-in, -out, -pins, -fanin, -unate_cg, $din_pin)) ; 
            }
            @fins = @int_fis ;
        } else {
            push @rtn, @fins;
            last ;
        }
    }
    
    return @rtn ;

END

Tsub _get_function_clks => << 'END' ;
    DESC {
        to get all the function clocks.
    }
    
    my @clks = () ;
    my %clocks = %{$CONFIG->{clock_timing_specification}{clock}} ;
    foreach my $clk (sort keys %clocks) {
        if (exists $clocks{$clk}{apply_clocks_timing_mode}) {
            my @modes = @{$clocks{$clk}{apply_clocks_timing_mode}} ;
            if (grep ($_ eq 'default_func', @modes)) {
                if (grep ($_ eq $clk, @clks)) {
                    next ;
                } else {
                    push @clks, $clk ;
                }
            } else {
                next ;
            }
        } elsif (exists $CONFIG->{clock_timing_specification}{clock}{$clk}{clock_configs}) {
            foreach my $cfg (sort keys %{$CONFIG->{clock_timing_specification}{clock}{$clk}{clock_configs}}) {
                my @modes = @{$CONFIG->{clock_timing_specification}{clock}{$clk}{clock_configs}{$cfg}{apply_clocks_timing_mode}} ;
                if (grep ($_ eq 'default_func', @modes)) {
                    if (grep ($_ eq $clk, @clks)) {
                        next ;
                    } else {
                        push @clks, $clk ;
                    }
                } else {
                    next ;
                }
            }
        } else {
            next; 
        }
    }

    return @clks ; 

END

Tsub get_root_cg => << 'END' ;
    DESC {
        to get the root cg pins 
    }
    ARGS {
        $pin      # pin name 
    }

    my $root_pin = get_driver (get_root $pin) ;
    my $root_clk_pin ;
    
    if ($pin =~ /\/UI_latch_nvvdd2pexvdd\//) {
        return $pin ;
    }
    if ($root_pin =~ /xtal_clk_mux\/u_NV_CLK_mux2\/UI_mx0\/Z/) {
        return $root_pin ;
    }
    foreach (0..100) {
        if ($root_pin !~ /\/u_NV_CLK_clk_gate_clktree_root\/UI_cg_clktree_root\/Q/) {
            if ($root_pin =~ /\/DOUT$/) {
                $root_clk_pin = $root_pin ;
                $root_clk_pin =~ s/\/DOUT$/\/DIN/ ;
            } elsif ($root_pin =~ /\/u_NV_CLK_switch2\/clk_path\/UI_clkpath_or_final\/ZN/) {
                return $root_pin ;
            } elsif (is_port $root_pin) {
                $root_clk_pin = $root_pin ;
            } else {
                $root_clk_pin = _get_clk_pin (-inst => (get_cell (-of, $root_pin))) ; 
            }
            $root_pin = get_driver (get_root $root_clk_pin) ;
        } else {
            break ;
        }
    }

    return $root_pin ;

END

Tsub get_root_cg_clk => << 'END' ;
    DESC  {
        to get the clock name from root cg name
    }
    ARGS {
        $cg_pin  # cg pin name
    }
    
    my $clk_name = "" ;

    if ($cg_pin =~ /.*cts_root_gate_(\S+?)_(\S+?clk).*\/u_NV_CLK_clk_gate_clktree_root\/UI_cg_clktree_root.*/) {
        $clk_name = $2 ;
    } elsif ($cg_pin =~ /.*cts_root_gate_(\S+?clk).*\/u_NV_CLK_clk_gate_clktree_root\/UI_cg_clktree_root.*/){
        $clk_name = $1 ;
    } elsif ($cg_pin =~ /.*cts_root_gate_\S+_xtal_in_.*\/u_NV_CLK_clk_gate_clktree_root\/UI_cg_clktree_root.*/) {
        $clk_name = "xtal_in" ;
    } elsif ($cg_pin =~ /.*cts_root_gate_\S+_TS_CLK_gpc\/u_NV_CLK_clk_gate_clktree_root\/UI_cg_clktree_root.*/) {
        $clk_name = "ts_clk_gpc" ;
    } elsif ($cg_pin =~ /\/xtal_clk_mux\/u_NV_CLK_mux2\/UI_mx0\/Z/) {
        $clk_name = "xtal_in" ;
    } elsif ($cg_pin =~ /\/u_NV_CLK_switch2\/clk_path\/UI_clkpath_or_final\/ZN/) {
        $clk_name = "jtag_reg_tck" ;
    } elsif ($cg_pin =~ /u_NV_CLK_FR_counter_v2\/UI_fr_counter_iso_clk_/) {
        $clk_name = "debug_clk_fr" ;
    } else {
        $clk_name = "" ;
        #print "Double check $cg_pin\n" ;
    } 

    if ((is_port $cg_pin) && ($cg_pin =~ /Jtag_reg_clk/)) {
        $clk_name = "jtag_reg_tck" ; 
    }
    
    if ($clk_name eq "xtal_clk") {
        $clk_name = "xtal_in" ;
    }
    
    return $clk_name ;

END

Tsub gpc => << 'END' ;
    DESC {
        get clock_name of the cp pin
    }

    ARGS {
        $pin
    }

    my $clk_name ;
    $clk_name = get_root_cg_clk (get_root_cg ($pin)) ;
    
    return $clk_name ;

END

Tsub get_net_fi_fo_clks => << 'END' ;
    DESC {
        To get the fanin and fanout clocks in mender session
    }
    ARGS {
        $net_name  # net name or pin name
    }

    my %path  = () ;
    #my @fis   =  all_fanin (-flat, -start, -to => $net_name) ;
    #my @fos   =  all_fanout (-flat, -end, -from => $net_name) ;
    my @fis = get_fan2 (-end, -fanin => (get_nets $net_name)) ;
    my @fos = get_fan2 (-end, -fanout => (get_nets $net_name)) ;
    

    foreach my $fi (@fis) {
        $fi =~ s/(\S+)\s+.*/$1/ ;
        unless (is_port $fi) {
            foreach my $fo (@fos) {
                $fo =~ s/(\S+)\s+.*/$1/ ;
                unless (is_port $fo) {
                    my $rtn_d = get_path_delay (-from => $fi, -to => $fo, -rtn_delay, -quiet) ;
                    if ($rtn_d ne "") {
                        $path{$fi}{$fo} = 1 ;
                    }
                }
            }
        }
    }

    my %fi_clks = () ;
    my %fo_clks = () ;

    foreach my $fi (sort keys %path) {
        my $fi_clk = get_root_cg_clk (get_root_cg $fi) ;
        $fi_clks{$fi_clk} =1 ;
        foreach my $fo (sort keys %{$path{$fi}}) {
            my $fo_inst   = get_cell (-of => $fo) ;
            my $fo_cp_pin = _get_clk_pin (-inst => $fo_inst) ;
            my $fo_clk    = get_root_cg_clk (get_root_cg $fo_cp_pin) ;
            $fo_clks{$fo_clk} = 1 ;
        }
    }

    my $out_fi_clks = join (" ", (sort keys %fi_clks)) ;
    my $out_fo_clks = join (" ", (sort keys %fo_clks)) ;

    print "$net_name\n" ;
    print "\tFanin Clks  : $out_fi_clks\n" ;
    print "\tFanout Clks : $out_fo_clks\n" ;


END

Tsub get_fi_fo_clks => << 'END' ;
    DESC {
        to get all the fanin and fanout clocks from netLength report.
    }
    ARGS {
        -block:$chiplet # to specify the chiplet name. 
        -in:$in         # the input file, netLength file from fpshell.
        -out:$out       # the output file, netLength.clks.txt by default.
    }

    unless (defined $out) {
        $out = $in . ".clks.txt" ;
    }
    open (IN, "$in") or die "Can't open file $in\n" ; 
    open (OUT, "> $out") or die "Can't write to file $out\n" ;

    while (<IN>) {
        my $line = $_ ;
        chomp $line ;
        my @chiplets = get_cells_of ($chiplet) ;
        my $prefix   = $chiplets[0] ;
        if ($line =~ /^NET: (\S+).*/) {
            my $sig = $1 ;
            my $net = "$prefix/$sig" ;
            print "$net\n" ;
            my @fis = get_fan2 (-fanin, -end, -pins, $net) ;
            my @fos = get_fan2 (-fanout, -end, -pins, $net) ;
            my %fi_clks = () ;
            my %fo_clks = () ;
            foreach my $fi (@fis) {
                my $fi_cg_pin = get_root_cg (-pin => $fi) ;
                my $fi_clk    = get_root_cg_clk (-pin => $fi_cg_pin) ;
                print "$net $fi_cg_pin $fi_clk\n" ;
                $fi_clks{$fi_clk} = 1 ;
            }
            foreach my $fo (@fos) {
                my $fo_cell   = get_cell (-of => $fo) ;
                print "$net $fo_cell" ; 
                my $fo_ck_pin = _get_clk_pin (-inst => $fo_cell) ;
                my $fo_cg_pin = get_root_cg (-pin => $fo_ck_pin) ;
                my $fo_clk    = get_root_cg_clk (-pin => $fo_cg_pin) ;
                print "$fo_clk\n" ;
                $fo_clks{$fo_clk} = 1 ;
            }
            my $all_fi_clks = join (" ", (sort keys %fi_clks)) ; 
            my $all_fo_clks = join (" ", (sort keys %fo_clks)) ;

            if ($all_fi_clks ne $all_fo_clks) {
                print OUT "ASYNC : $sig FI_CLKS : $all_fi_clks FO_CLKS: $all_fo_clks\n" ;
            } else {
                print OUT "SYNC : $sig FI_CLKS : $all_fi_clks FO_CLKS: $all_fo_clks\n" ;
            }
        }
    } 
    
    close IN ;
    close OUT ;

END

our %rt_flops     ;
our %rt_out_flops ;

Tsub get_fanin_retime => << 'END' ;
    DESC {
        get all the fanins through retime flops
    }
    ARGS {
        $pin
    }
    
    %rt_flops     = () ;
    %rt_out_flops = () ;

    my %rtn = get_fanin_retime_core ($pin) ;
    return (sort keys %rtn) ;

END

Tsub get_fanin_retime_core => << 'END';
    DESC {
        core function to get all the non-retime fanins through retime flops
    }
    ARGS {
        $pin
        -debug
    }

    print "Pin : $pin\n" if (defined $opt_debug);

    if ($pin !~ /_retime_.*_RT.*_reg|_retime_.*\/u_retime_clkgate/) {
        my $cp_pin = _get_clk_pin (-inst => (get_cells (-of => $pin))) ;
        $rt_out_flops{$cp_pin} = 1 ;
        return %rt_out_flops ;
    }

    my @all_fis = get_fan2 (-end, -fanin, $pin) ;
    my @fis = grep ($_ !~ /test|JTAG|i1500|shift_en_mux|Jreg_lat/, @all_fis) ;

    print "Fanins of $pin :\n" if (defined $opt_debug) ;
    print (Dumper @fis) if (defined $opt_debug) ;
    
    $rt_flops{$pin} = 1 ;    

    my @rt_fis  = grep ($_ =~ /_retime_.*_RT.*_reg|_retime_.*\/u_retime_clkgate/, @fis) ;
    my @nrt_fis = grep ($_ !~ /_retime_.*_RT.*_reg|_retime_.*\/u_retime_clkgate/, @fis) ;
    print "RT Fanins of $pin :\n" if (defined $opt_debug) ;
    print (Dumper @rt_fis) if (defined $opt_debug) ;
    print "non-RT Fanins of $pin :\n" if (defined $opt_debug) ;
    print (Dumper @nrt_fis) if (defined $opt_debug) ;

    foreach my $nrt_fi (@nrt_fis) {
        $nrt_fi =~ s/(\S+).*/$1/ ;
        if (is_power_net $nrt_fi) {
            next ;
        } else {
            $rt_out_flops{$nrt_fi} = 1 ;
            print "Non-RT flops : $nrt_fi\n" if (defined $opt_debug) ;
        }
    }

    foreach my $rt_fi (@rt_fis) {
        $rt_fi =~ s/(\S+).*/$1/ ;
        my $fi_inst  = get_cell (-of => $rt_fi) ;
        my $fi_d_pin = "$fi_inst/D" ;
        print "RT flops/D : $fi_d_pin\n" if (defined $opt_debug) ;

        $rt_flops{$fi_d_pin} = 1 ;

        my @all_rt_fanins = get_fan2 (-end, -fanin, $fi_d_pin) ;
        my @rt_fanins     = grep ($_ !~ /test|JTAG|i1500|shift_en_mux|Jreg_lat/, @all_rt_fanins) ;
        foreach my $rt_fi (@rt_fanins) {
            $rt_fi =~ s/(\S+).*/$1/ ;
            if ($rt_fi !~ /_retime_.*_RT.*_reg|_retime_*\/u_retime_clkgate/) {
                if (is_power_net $rt_fi) {
                    next ;
                } else {
                    $rt_out_flops{$rt_fi} = 1 ;
                }
            } else { 
                my $rt_fi_inst = get_cell (-of => $rt_fi) ;
                my $rt_d_pin   = "$rt_fi_inst/D" ;
                if (exists $rt_flops{$rt_d_pin}) {
                    next ;
                } else {
                    $rt_flops{$rt_d_pin} = 1 ;
                    my %rt_rtn = get_fanin_retime_core ($rt_d_pin) ;
                    foreach my $rt (sort keys %rt_rtn) {
                        if (is_power_net $rt) {
                            next ;
                        } else {
                            $rt_out_flops{$rt} = 1 ;
                        }
                    }
                }
            } 
        }    
    }
    
    return %rt_out_flops ;

END

Tsub get_fanout_retime => << 'END' ;
    DESC {
        get all the non-RT fanouts through retime flops
    }
    ARGS {
        $pin
    }

    %rt_flops     = () ;
    %rt_out_flops = () ;

    my %rtn = get_fanout_retime_core ($pin) ;
    return (sort keys %rtn) ;

END

Tsub get_fanout_retime_core => << 'END';
    DESC {
        core function to get all the non-retime fanouts through retime flops
    }
    ARGS {
        $pin
        -debug
    }

    print "Pin : $pin\n" if (defined $opt_debug);

    my $cp_pin = _get_clk_pin (-inst => (get_cells (-of => $pin))) ;

    if ($pin !~ /_retime_.*_RT.*_reg|_retime_.*\/u_retime_clkgate/) {
        $rt_out_flops{$cp_pin} = 1 ;
        return %rt_out_flops ;
    }

    my @all_fos = get_fan2 (-end, -fanout, $cp_pin) ;
    my @fos = grep ($_ !~ /\/SI|\/QN|JTAG|i1500|shift_en_mux|Jreg_lat/, @all_fos) ;

    print "Fanouts of $pin :\n" if (defined $opt_debug) ;
    print (Dumper @fos) if (defined $opt_debug) ;

    $rt_flops{$pin} = 1 ;

    my @rt_fos  = grep ($_ =~ /_retime_.*_RT.*_reg|_retime_.*\/u_retime_clkgate/, @fos) ;
    my @nrt_fos = grep ($_ !~ /_retime_.*_RT.*_reg|_retime_.*\/u_retime_clkgate/, @fos) ;
    print "RT Fanins of $pin :\n" if (defined $opt_debug) ;
    print (Dumper @rt_fos) if (defined $opt_debug) ;
    print "non-RT Fanins of $pin :\n" if (defined $opt_debug) ;
    print (Dumper @nrt_fos) if (defined $opt_debug) ;

    foreach my $nrt_fo (@nrt_fos) {
        $nrt_fo =~ s/(\S+).*/$1/ ;
        my $nrt_fo_cp = _get_clk_pin (-inst => (get_cells (-of => $nrt_fo))) ;
        $rt_out_flops{$nrt_fo_cp} = 1 ;
        print "Non-RT flops : $nrt_fo_cp\n" if (defined $opt_debug) ;
    }

    foreach my $rt_fo (@rt_fos) {
        $rt_fo =~ s/(\S+).*/$1/ ;
        my $rt_fo_cp = _get_clk_pin (-inst => (get_cells (-of => $rt_fo))) ;
        if (exists $rt_flops{$rt_fo}) {
            next ;
        } else {
            $rt_flops{$rt_fo_cp} = 1 ;
            my @rt_fanouts = grep ($_ !~ /\/SI|\/QN|JTAG|i1500|shift_en_mux|Jreg_lat/, (get_fan2 (-fanout, -end, $rt_fo_cp))) ;
            foreach my $rt_fanout (@rt_fanouts) {
                $rt_fanout =~ s/(\S+).*/$1/ ;
                my $rt_fanout_cp = _get_clk_pin (-inst => (get_cells (-of => $rt_fanout))) ;
                if ($rt_fanout !~ /_retime_.*_RT.*_reg|_retime_.*\/u_retime_clkgate/) {
                    $rt_out_flops{$rt_fanout_cp} = 1 ;
                    $rt_flops{rt_fanout} = 1 ;
                } else {
                    my %rt_rtn = get_fanout_retime_core ($rt_fanout) ; 
                    foreach my $rt (sort keys %rt_rtn) {
                        $rt_out_flops{$rt} = 1 ;
                        $rt_flops{$rt} = 1 ;
                    } 
                }
            }
        } 
    }

    return %rt_out_flops ;

END

Tsub list_fanin_clks => << 'END';
    DESC {
        To get all the clocks for get_fanin_retime hash.
    }
    ARGS {
        $pin 
    }

    my @pins = get_fanin_retime $pin ;
    my $leng = get_array_max_length (@pins) ;
    foreach my $pin (@pins) {
        if (is_port $pin) {
            next ;
        } else {
            my $clk = gpc ($pin) ;   
            printf ("%-15s %-${leng}s\n", $clk, $pin) ;
        }
    }

END

Tsub list_fanout_clks => << 'END';
    DESC {
        To get all the clocks for get_fanout_retime hash.
    }
    ARGS {
        $pin
    }

    my @pins = get_fanout_retime $pin ;
    my $leng = get_array_max_length (@pins) ;
    foreach my $pin (@pins) {
        if (is_port $pin) {
            next ;
        } else {
            my $clk = gpc ($pin) ;
            printf ("%-15s %-${leng}s\n", $clk, $pin) ;
        }
    }

END

Tsub plot_vio => << 'END' ;
    DESC {
        to plot the violation b id
    }
    ARGS {
        $id   # violation id
    }

    plot_all_partitions ;

    my @vios     = all_vios (-filter => "id eq '$id' and (type eq 'max' or type eq 'min')") ;
    my $pin_list = attr_of_vio ('pin_list' => $vios[0]) ;
    my @pins     = split (" ", $pin_list);
    my $sp       = attr_of_vio ('start_pin' => $vios[0]) ;
    my $ep       = attr_of_vio ('end_pin' => $vios[0]) ;
    my $dist     = get_dist ($sp, $ep) ;
    print "DIST : $dist $sp $ep\n" ;
    show_path ('$id') ;

    foreach my $i (1..$#pins) {
        my $inst   = get_cell (-of => $pins[$i]) ;
        my $ref    = get_ref $inst ;
        my $inst_p = get_cell (-of => $pins[$i-1]) ;
        my $ref_p  = get_ref $inst_p ;
        if (is_partition_module $ref || is_partition_module $ref_p || $inst eq $inst_p) {
        } else {
            plot $inst_p ;
        }
        my ($start_x, $start_y) = get_pin_xy $pins[$i-1] ;
        my ($end_x, $end_y) = get_pin_xy $pins[$i] ;
        my $comment = "$pins[$i-1] => $pins[$i]" ;
        plot_line(-arrow=>"last", -name => "$comment", $start_x, $start_y, $end_x, $end_y, -color => "red");
    }

END

our %M_retime_interf ;
our $chiplet_uc ;

Tsub parse_retime_interface => << 'END' ;
    DESC {
        to parese all the retime interface files
    } 
    ARGS {
    }

    %M_retime_interf  = () ;

    my @chiplets      = all_chiplets ;
    my $litter        = $CONFIG->{LITTER_NAME} ;
    my $tot           = `depth` ;
    my @interf_files  = () ;
    my $interface_dir = "$tot/ip/retime/retime/1.0/vmod/include/interface_retime" ;

    foreach my $chiplet (@chiplets) {
        $chiplet_uc = $chiplet ;
        $chiplet_uc =~ s/^NV_// ;
        $chiplet_uc = uc $chiplet_uc ;

        my @interf_files = glob "$interface_dir/interface_retime_${litter}_${chiplet_uc}_*.pm" ;
        foreach my $interf_file (@interf_files) {
            if ($interf_file ne "$interface_dir/interface_retime_${litter}_${chiplet_uc}_routeRules.pm") {
                `p4 sync "$interf_file"` ;
                load "$interf_file" ;
            }
        } 
    }

END

Tsub AddInterface => << 'END' ;
    DESC {
        a dummy function for parsing the interface_retime_*.pm files
    }
    ARGS {
        @args
    }

    my %in = @args ;
   
    my $rule_name = $in{pipelining} ;
    $rule_name =~ s/^rule:// ;   

    foreach my $key (sort keys %in) {
        if (exists $M_retime_interf{$chiplet_uc}{$rule_name}{$key} && $M_retime_interf{$chiplet_uc}{$rule_name}{$key} ne $in{$key}) {
            $M_retime_interf{$chiplet_uc}{$rule_name}{$key} = $M_retime_interf{$chiplet_uc}{$rule_name}{$key} . "," . $in{$key} ;
        } else {
            $M_retime_interf{$chiplet_uc}{$rule_name}{$key} = $in{$key} ;
        }
    }

    return %M_retime_interf ;

END

Tsub AddRouteRule => << 'END' ;
    DESC {
        a dummy function for parsing the interface_retime_*.pm files
    }
    ARGS {
        @args    
    }


END

Tsub get_neighbor_par_net => << 'END' ;
    DESC {
        to get the neighbor partitions nets in the netLength.rpt
    }
    ARGS {
        -i:$input       # netLength.rpt
    }

    # to get all the neighbor partitions

    my %allModules    = map  ({$_ => 1} (get_modules ("*"))) ;
    my @parRefs       = grep (exists $allModules{$_}, (all_partitions)) ;
    my %neighbor_pars = () ;
    
    my $top = get_top ;
    set_chip_top $top ;

    foreach my $par_ref (@parRefs) {
        foreach my $par_inst (get_cells_of $par_ref) {
            my @n_pars = tl_get_abutments $par_inst ; 
            foreach my $n_par (@n_pars) {
                $neighbor_pars{$par_inst}{$n_par} = 1 ;
            }
        }
    }

    # parsing the netLength reports 

END

Tsub get_rule_of_rtl_net => << 'END' ;
    DESC {
        to check if the rtl net is in the rule already.
    }
    ARGS {
        $net
    }

    my $flg = 0 ;

    foreach my $chiplet (sort keys %M_retime_interf) {
        foreach my $rule (sort keys %{$M_retime_interf{$chiplet}}) {
            if ($M_retime_interf{$chiplet}{$rule}{rtl_net_name} =~ /$net/) {
                print "rtl_net : $net  \@ rule $chiplet $rule\n" ;
                print "\t rtl_net_name => $M_retime_interf{$chiplet}{$rule}{rtl_net_name}\n" ;
                $flg = 1 ;
            }
        }
    }

    if ($flg == 0) {
        print "rtl_net : $net not found, double check\n" ;
    }

END

our %routeRules ;

Tsub load_routeRules_files => << 'END' ;
    DESC  {
        to parse the route Rule files in mender session
    }
    ARGS {
    }

    %routeRules = () ;
    my %all_mods = map  ({$_ => 1} (get_modules "*")) ;
    my @chiplets = grep ((exists $all_mods{$_}), (all_chiplets)) ;

    my $litter = $CONFIG->{LITTER_NAME} ;
    my $chip_root = `depth` ;
    chomp $chip_root ;

    my $routeRulesdir = "$chip_root/ip/retime/retime/1.0/vmod/include/interface_retime" ;
    foreach my $block (@chiplets) {
        my $chiplet        = $block ;
        $chiplet           =~ s/NV_(.*)/$1/ ;
        my $chiplet_uc     = uc $chiplet ;
        my $routeRulesFile = "$routeRulesdir/interface_retime_${litter}_${chiplet_uc}_routeRules.pm" ;
        if (-e $routeRulesFile) {
            `p4 sync $routeRulesFile` ;
            print "Loading routeRules file : $routeRulesFile\n" ;
            my $Rule_name = "" ;
            my $Rule_pipe = "" ;

            open IN, "$routeRulesFile" or die "Can't open file $routeRulesFile\n" ;
            while (<IN>) {
                chomp ;
                my $line = $_ ;
                if ($line =~ /\s+name\s+=>\s+\"(\S+)\"/) {
                    $Rule_name = $1 ;
                } elsif ($line =~ /.*pipeline_steps.*=>\s+\"(\S+)\"/) {
                    $Rule_pipe = $1 ;
                    foreach my $pipe (split (",", $Rule_pipe)) {
                        $routeRules{$chiplet_uc}{$Rule_name}{$pipe} = 1 ;
                    }
                }
            }
            close IN ;
        } else {
            next ;
        }
    }

    #return %routeRules ;

END

Tsub get_rule_of_pin => << 'END';
    DESC {
        To get the routeRule of retime flop pin
    }
    ARGS {
        $pin   ,
        -debug:$d
    }

    if (!$pin) {
        error "No pin listed.\n" ;
        return () ;
    }

    if (!(get_pins (-quiet, $pin))) {
        error "$pin not found.\n" ;
        return () ;
    }

    print "Pin : $pin\n" if (defined $d) ;

    my @rules = sort keys %routeRules ;
    if ($#rules == -1) {
        load_routeRules_files ;
    }

    if (defined $d) {
        foreach my $key (sort keys %routeRules) {
            print "Rule : $key\n" ;
        }
    }

    my $flg  = 0 ;
    my $inst ;
    my $ref ;

    if (get_pin (-quiet, $pin)) {
        $inst = get_cell (-of => $pin) ;
        $ref  = get_ref ($inst) ;

        if (attr_of_ref ('is_merged_flop' => $ref)) {
            my $demerged_pin = get_demerged_name ($pin) ;
            $pin = $demerged_pin ;
            print "Demerged Pin : $pin\n" if (defined $d) ;
        }
    }

    if ($pin =~ /_retime_.*_RT/) {
            my $pipe = $pin ;
            $pipe =~ s/.*_RT.*?_(\S+?)\/.*\/.*/$1/ ;
            foreach my $chiplet (sort keys %routeRules) {
                foreach my $rule (sort keys %{$routeRules{$chiplet}}) {
                    if (exists $routeRules{$chiplet}{$rule}{$pipe}) {
                        return "$chiplet $rule" ;
                    }
                }
            }
            if ($flg) {
                return 0 ;
            }
    } else {
        return 0 ;
    }


END

Tsub get_end_pin_id => << 'END';
    DESC {
        To get the id of the end pin violation. 
    }
    ARGS {
        $end_pin 
    }
    
    my @vios = all_vios (-filter => "end_pin eq \'$end_pin\'") ;
    my $id   = attr_of_vio (id => $vios[0]) ;

    return $id ;

END
