Tsub plot_all_modules => << 'END' ;
    DESC {
        Plot all the partitions/macros/rams/analog cells.
        Need to plot_all_partitions first.
    }
    ARGS {
    }

    #plot_macros -no_labels ;

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
    push @moduleRefs, (grep (attr_of_ref (is_ram, $_), (sort keys %allModules))) ;
    push @moduleRefs, (grep (attr_of_ref (is_analog, $_), (sort keys %allModules))) ;

    foreach my $ref (@moduleRefs) {
        my @insts = get_cells_of $ref ;
        foreach my $inst (@insts) {
            if (attr_of_cell (is_placed => $inst)) {
                #plot ($inst) ;
                print "$inst\n" ;
            } else {
                next ;
            }
        }
    }

    return 1 ;

END
