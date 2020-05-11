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
