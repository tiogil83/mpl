Tsub jtag_est_timing => << 'END';
    DESC {
            To estimate the jtag timing from prelayout
            Examples :
                jtag_est_timing -wsi -plot                          # dump the timing estimation reports and plot the fly lines only for wsi paths
                jtag_est_timing -wsc -viol_only                     # dump the violated timing estimation reports only for wsc paths
                jtag_est_timing -wsi -retime -dump_order            # dump the timing estimation reports and data/clock path ordering for both wsi and retime paths  
                jtag_est_timing -wsi -order_file <order_file_name>  # estimate the wsi timing based on a new order file with format : <par1> => <par2> => <par3>
                jtag_est_timing                                     # not any options, it equals to "jtag_est_timing -wsi -wsc -retime"
    }
    ARGS {
        -plot                           # to plot the fly lines of paths
        -o:$output                      # to sepcify the output file
        -wsi                            # only check the wci paths
        -wsc                            # only check the wsc paths
        -retime                         # only check the inter_chiplet retime paths
        -viol_only                      # to only plot or show the violated paths
        -order_file:$order_file         # check the data path with custom ordering file
        -dump_order                     # will dump data/clock path ordering
        -debug                          # to print more infos for debugging
    }

my $top  = get_top ;
my $type = $ENV{NAHIER_TYPE} ;
my $rev  = $ENV{USE_LAYOUT_REV} ;
my $date = `date +%Y%b%d` ;

# to define the default reports files.

$rev =~ s/\./_/g ;
chomp $date ;
if (!(defined $output)) {
    $output = "jtag_est_${rev}.$type.$date.rep" ;
}

open (O, "> $output") or die "ERROR: cannot write to file $output!\n";

my $dump_order_file ;
if (defined $opt_dump_order) {
    $dump_order_file = $output ;
    $dump_order_file =~ s/rep$/order/ ;
    open (ORD, "> $dump_order_file") or die "ERROR: cannot open file $dump_order_file!\n";
}

my $debug_out ;
if (defined $opt_debug) {
    $debug_out = $output ;
    $debug_out =~ s/rep$/debug/ ;
    open (DEBUG, "> $debug_out") or die "ERROR: cannot write to the debug log file $debug_out!\n" ;
} 

my $start_time_stamp = `date` ;
print DEBUG "Job started @ $start_time_stamp" ;

# to set the default value for checking wsi/wsc/retime
if (!(defined $opt_wsi) && !(defined $opt_wsc) && !(defined $opt_retime)) {
    $opt_wsi    = 1 ;
    $opt_wsc    = 1 ;
    $opt_retime = 1 ;
}

# need to specify the ordering file is for wsc, wsi or retime
if (((($opt_wsi && $opt_wsc) || ($opt_wsc && $opt_retime) || ($opt_wsi && $opt_retime)) || !($opt_wsi || $opt_wsc || $opt_retime)) && $order_file) {
    die "ERROR: please specify the order_file with -wsi or -wsc or -retime.\n" ;
}

# just plot one type of paths for wsi/wsc/retime.
# to make the plot more clear.
if ( (defined $opt_plot) && (($opt_wsi && $opt_wsc) || ($opt_wsi && $opt_retime) || ($opt_wsc && $opt_retime))) {
    die "ERROR: it is not good to plot all the wsc/wsi/retime paths at the same time.\nERROR: please choose one type first.\n" ;
}

# preparation for the def/region files ;
my @def_files = get_files (-type => def) ;

if ($#def_files == -1) {
    # hacked for the bbox timing arc through
    if ($type eq 'noscan') {
        set_timing_corner ssg_0c_0p6v ;
        print "Loading BLKBOX lib ... \n\n" ;
        load_once "/home/scratch.gp104_master/gp104/gp104/timing/gp104/lib/NV_BLKBOX_BUFFER_tsmc16ff_t9_svt_std_ssg_0c_0p6v.lib" ;
    }
    # loading all the def/region files
    load_def_region_files ;
}


# plot all the partitions 

if (defined $opt_plot) {
    plot_macros -no_labels ;
    clear_plot ;
    plot_all_partitions ;
}

# to define the corner for delay per distance
# also to define the ratio for clock_delay/data_delay, currently 0.25. will adjust when correlation

my $tech = attr_of_process leff ;
my $corner = "" ;
my $clk_data_delay_ratio ;

if ($tech == 16) {
    $corner = "ssg_0c_0p6v_bin_max_si" ;
    $clk_data_delay_ratio = 0.25 ;
} elsif ($tech == 7) {
    $corner = "ssg_0c_0p55v_bin_max_si" ;
    $clk_data_delay_ratio = 0.25 ;
} else {
    die "No tech file found.\n" ;
}

print "Basic infos : \nTech   : ${tech}nm\nCorner : $corner\n\n" ;

$delay_per_dist = get_yaml_corner_attr ($corner, mender_delay_per_dist) ;
print DEBUG "\nINFO : Tech   : ${tech}nm\nINFO : Corner : $corner\n\n" if (defined $opt_debug) ;
print DEBUG "\nINFO : Delay  : $delay_per_dist per 1000um\n\n" if (defined $opt_debug) ; 

# define the clock sources
my @jtag_clk_biports      = () ;
my @jtag_clock_source_top = () ;
my %jtag_clock_source     = () ;
my %all_chiplets_inst     = () ;

if (exists $CONFIG->{clock_timing_specification}{clock}{jtag_reg_clk}{clock_configs}{cfg_func}{biport_sources}) { 
    @jtag_clk_biports = @{$CONFIG->{clock_timing_specification}{clock}{jtag_reg_clk}{clock_configs}{cfg_func}{biport_sources}} ;
} elsif (exists $CONFIG->{clock_timing_specification}{clock}{jtag_reg_tck}{clock_configs}{cfg_func}{biport_sources}) {
    @jtag_clk_biports = @{$CONFIG->{clock_timing_specification}{clock}{jtag_reg_tck}{clock_configs}{cfg_func}{biport_sources}} ;
} else {
    die "No jtag_reg_tck/jtag_reg_clk biports defined. Please double check.\n" ;
}


foreach my $chiplet (keys $CONFIG->{partitioning}{chiplets}) {
    if (exists $CONFIG->{partitioning}{chiplets}{$chiplet}{top_instance_names}) {
        my $chiplet_top_name  = $CONFIG->{partitioning}{chiplets}{$chiplet}{top_instance_names} ;
        my $chiplet_ref_name  = $CONFIG->{partitioning}{chiplets}{$chiplet}{layout_toplevel} ;
        my @chiplet_top_names = split (',', $chiplet_top_name) ;
        foreach (@chiplet_top_names) {
            $all_chiplets_inst{$_} = $chiplet_ref_name ;
        }
    }
}

foreach my $chiplet_name (keys %all_chiplets_inst) { 
    foreach my $jtag_biport (@jtag_clk_biports) {
        if ($jtag_biport =~ /$chiplet_name/ && $jtag_biport !~ /\/.*\//) {
            $jtag_biport =~ /$chiplet_name\/(\S+)/ ;
            $jtag_clock_source{$all_chiplets_inst{$chiplet_name}} = $1 ; 
        }
    } 
}

if (exists $CONFIG->{clock_timing_specification}{clock}{jtag_reg_tck}{clock_configs}{cfg_func}{pin_sources}) {
    @jtag_clock_source_top = @{$CONFIG->{clock_timing_specification}{clock}{jtag_reg_tck}{clock_configs}{cfg_func}{pin_sources}} ;
} elsif (exists $CONFIG->{clock_timing_specification}{clock}{jtag_reg_clk}{clock_configs}{cfg_func}{pin_sources}) {
    @jtag_clock_source_top = @{$CONFIG->{clock_timing_specification}{clock}{jtag_reg_clk}{clock_configs}{cfg_func}{pin_sources}} ;
} else {
    die "No jtag_reg_tck/jtag_reg_clk pin source defined. Please double check.\n" ;
}
 
$jtag_clock_source{nv_top} = $jtag_clock_source_top[0] ;
foreach my $chiplet_top_name (keys %all_chiplets_inst) {
    if ($jtag_clock_source_top[0] =~ /^$chiplet_top_name/) {
        $jtag_clock_source_top[0] =~ s/^$chiplet_top_name\/(\S+)/$1/ ;
        $jtag_clock_source{$all_chiplets_inst{$chiplet_top_name}} = $jtag_clock_source_top[0];
    }
}

if (defined $opt_debug) {
    print "INFO : jtag clock pin source and biport sources for each chiplets :\n" ;
    print DEBUG "INFO : jtag clock pin source and biport sources for each chiplets :\n" ;
    foreach (keys %jtag_clock_source) {
        printf ("INFO : %15s => %s\n", $_, $jtag_clock_source{$_}) ;
        printf DEBUG ("INFO : %15s => %s\n", $_, $jtag_clock_source{$_}) ;
    }
} else {
    print "The jtag clock pin source/biport sources for $top:\n" ;
    print "$top\t=>\t$jtag_clock_source{$top}\n\n" ;
}

print "\n" ;

#jtag clock period

my $jtag_period ;
if (exists $CONFIG->{clock_timing_specification}{clock}{jtag_clk}{clock_configs}{cfg_func}{period}{sv_base_corner}) {
    $jtag_period = $CONFIG->{clock_timing_specification}{clock}{jtag_clk}{clock_configs}{cfg_func}{period}{sv_base_corner} ;
    print "jtag clock period : $jtag_period ns\n\n" ;
    print DEBUG "INFO : jtag clock period : $jtag_period ns\n\n" if ($opt_debug) ;
} else {
    die "jtag clock period not defined.\n" ;
}

####Starting to estimate the wsi/wso/wsc slack
my %all_wsi_paths      = () ;
my %all_wsc_paths      = () ;
my %all_retime_paths   = () ;

my %all_wsi_pairs      = () ;
my %all_wsc_pairs      = () ;
my %all_retime_pairs   = () ;

my %wsi_order          = () ;
my %wsc_order          = () ;
my %retime_order       = () ;

my @i1500_cells = () ;

if (!(defined $order_file) && (defined $opt_wsi || defined $opt_retime)) {
    @i1500_cells = find_objs (-cell, -quiet, -hier => "*wby_reg_reg"); 
    push @i1500_cells, find_objs (-cell, -quiet, -hier => "*i1500_data_pipe_*/UJ_pos_pipe_reg") ;
    foreach my $i1500_cell (@i1500_cells) {
        #get all start pin info
        my $start_clk_pin = get_cell_cp_name ($i1500_cell) ;
        my $start_q_pin   = get_cell_q_name  ($i1500_cell) ;
        my $start_par     = get_pin_par_name ($start_q_pin)    ;
        #get all end pin info
        my @all_fo_pins = get_fan2 (-fanout => $start_clk_pin, -end, -pins) ;
        my @end_pins = () ;
        foreach my $fo_pin (@all_fo_pins) {
            my $fo_inst = find_objs (-cell, -quiet, -of => $fo_pin) ;
            if (attr_of_cell ("is_seq", $fo_inst) and $fo_inst =~ /\/wby_reg_reg$|i1500_data_pipe_.*\/UJ_pos_pipe_reg$/) {
                push @end_pins, $fo_pin ;
            }
        }
        foreach my $end_pin (@end_pins) {
            my $end_clk_pin = get_cell_cp_name (get_cell (-of, $end_pin)) ;
            my $end_par    = get_pin_par_name ($end_pin) ;

            # to skip the intra partition path
            if ($start_par eq $end_par) {next ;}
            # to skip the paths through both UJ_i1500_bypass_pipe_* and UJ_i1500_nobypass_pipe_*
            if (filter_path_by_cons (get_all_pins_of_path ($start_q_pin, $end_pin))) {next} ;

            # to filter the inter_chiplet paths.
            my $flag_retime = 0 ;
            if ($top eq 'nv_top') {
                my @start_par_list = get_hier_list_txt (-inst, $start_par) ;
                my @end_par_list   = get_hier_list_txt (-inst, $end_par) ;
                if ($start_par_list[0] ne $end_par_list[0]) {
                    $flag_retime = 1 ;
                }
            }
            if ($start_clk_pin !~ /retime_path_/ && $end_clk_pin !~ /retime_path_/ && !$flag_retime) {
                $all_wsi_paths{$start_clk_pin}{$end_clk_pin} = 1 ;
                print DEBUG "wsi initial $start_clk_pin $end_clk_pin\n" if (defined $opt_debug) ;
            } else {
                $all_retime_paths{$start_clk_pin}{$end_clk_pin} = 1 ;
                print DEBUG "wsi retime $start_clk_pin $end_clk_pin\n" if (defined $opt_debug) ;
            }
        }
    }
}

if (!defined($order_file) && (defined $opt_wsc || defined $opt_retime)) {
    @i1500_cells = find_objs (-cell, -quiet, -hier => "*wso_pos_reg" );
    push @i1500_cells, find_objs (-cell, -quiet, -hier => "*wby_reg_reg" ); 
    foreach my $i1500_cell (@i1500_cells) {
        my $end_pin     = get_cell_d_name ($i1500_cell) ; 
        my $end_clk_pin = get_cell_cp_name ($i1500_cell) ;
        my @start_clk_pins = () ;

        #get all fanin flop infos
        my @all_fanins = get_fan2 (-fanin, -end => $end_pin, -pins) ;
        foreach (@all_fanins) {
            if ($end_pin =~ /wby_reg_reg/) {
                if (/.*pipe_out_to_client_reg/ and attr_of_cell ("is_seq", get_cell(-of => $_))) {
                    push @start_clk_pins, $_ ;
                } 
            } else {
                if (/wso_pipe_out_to_cluster_reg|wso_pipe_out_reg/  and attr_of_cell ("is_seq", get_cell(-of => $_))) {
                    push @start_clk_pins, $_ ;
                }
            }
        }
        
        foreach my $start_clk_pin (@start_clk_pins) {
            my $start_par   = get_pin_par_name ($start_clk_pin) ;
            my $end_par     = get_pin_par_name ($end_pin) ;
            my $end_clk_pin = get_cell_cp_name (get_cell (-of => $end_pin)) ;
            my $start_q_pin = get_cell_q_name  (get_cell (-of => $start_clk_pin)) ;

            # to skip the intra partition path
            if ($start_par eq $end_par) {next ;}
            # to skip the paths through both UJ_i1500_bypass_pipe_* and UJ_i1500_nobypass_pipe_*
            if (filter_path_by_cons (get_all_pins_of_path ($start_q_pin, $end_pin))) {next} ;

            # to filter the inter_chiplet paths.
            my $flag_retime ;
            if ($top eq 'nv_top') {
                my @start_par_list = get_hier_list_txt (-inst, $start_par) ;
                my @end_par_list   = get_hier_list_txt (-inst, $end_par) ;
                if ($start_par_list[0] ne $end_par_list[0]) { 
                    $flag_retime = 1 ;
                }
            }
            if (!($start_clk_pin =~ /retime_path_/ || $end_clk_pin =~ /retime_path_/) && ($flag_retime == 0)) {
                $all_wsc_paths{$start_clk_pin}{$end_clk_pin} = 1 ;
                print DEBUG "wsc initial $start_clk_pin $end_clk_pin\n" if (defined $opt_debug) ;
            } else {
                $all_retime_paths{$start_clk_pin}{$end_clk_pin} = 1 ;
                print DEBUG "wsc retime $start_clk_pin $end_clk_pin\n" if (defined $opt_debug) ;
            }
        }
    }
}

# start to dump the debug and report files.

if (!defined($order_file) && $opt_wsi) {
    foreach my $start_clk_pin (sort keys %all_wsi_paths) {
        my $end_clk_pins = $all_wsi_paths{$start_clk_pin} ;
        foreach my $end_clk_pin (sort keys %$end_clk_pins) {
            my $root_pin = $jtag_clock_source{$top} ;
            my ($path_slack, $end_pin, $start_par, $end_par, $data_path_dist, $launch_path_dist, $capt_path_dist) = calc_path_slack ($start_clk_pin, $end_clk_pin, $root_pin) ;
            my $start_q_pin = get_cell_q_name (get_cell (-of => $start_clk_pin)) ;
            my $end_d_pin   = get_cell_d_name (get_cell (-of => $end_clk_pin)) ;

            if (defined $opt_debug) {
                print DEBUG "WSI SLACK: $path_slack $start_clk_pin => $end_pin ($start_par $end_par) (data_dist : $data_path_dist, launch dist : $launch_path_dist, capt dist : $capt_path_dist)\n" ;
            }

            if (!(defined $opt_viol_only) || $path_slack < 0) {
                if ($top eq 'nv_top') {
                    my $chiplet_name = $start_par ;
                    $start_par       =~ s/(\S+?)\/(\S+)/$2/ ; 
                    $end_par         =~ s/(\S+?)\/(\S+)/$2/ ; 
                    $chiplet_name    =~ s/(\S+?)\/(\S+)/$1/ ; 
                    $all_wsi_pairs{$chiplet_name}{$start_par}{$end_par} = $path_slack ;
                    if (defined $opt_dump_order) {
                        $wsi_order{$chiplet_name}{$start_par}{$end_par} = get_ordering ($start_clk_pin, $end_clk_pin, $root_pin) ; 
                    }
                }else{
                    $all_wsi_pairs{$start_par}{$end_par} = $path_slack ;
                    if (defined $opt_dump_order) {
                        $wsi_order{$start_par}{$end_par} = get_ordering ($start_clk_pin, $end_clk_pin, $root_pin) ; 
                    }    
                }
                if (defined $opt_plot) {
                    plot_path ($start_clk_pin, $end_clk_pin, "wsi_ordering", "red") ;
                }
            }
        }
    }
}

if (!defined($order_file) && $opt_wsc) {
    foreach my $start_clk_pin (sort keys %all_wsc_paths) {
        my $end_clk_pins = $all_wsc_paths{$start_clk_pin} ;
        foreach my $end_clk_pin (sort keys %$end_clk_pins) {
            my $root_pin = $jtag_clock_source{$top} ;
            my ($path_slack, $end_pin, $start_par, $end_par, $data_path_dist, $launch_path_dist, $capt_path_dist) = calc_path_slack ($start_clk_pin, $end_clk_pin, $root_pin) ;
            my $start_q_pin = get_cell_q_name (get_cell (-of => $start_clk_pin)) ;
            my $end_d_pin   = get_cell_d_name (get_cell (-of => $end_clk_pin)) ;

            if (defined $opt_debug) {
                print DEBUG "WSC SLACK: $path_slack $start_clk_pin => $end_pin ($start_par $end_par) (data_dist : $data_path_dist, launch dist : $launch_path_dist, capt dist : $capt_path_dist)\n" ;
            }

            if (!(defined $opt_viol_only) || $path_slack < 0) {
                if ($top eq 'nv_top') {
                    my $chiplet_name = $start_par ;
                    $start_par       =~ s/(\S+?)\/(\S+)/$2/ ;
                    $end_par         =~ s/(\S+?)\/(\S+)/$2/ ;
                    $chiplet_name    =~ s/(\S+?)\/(\S+)/$1/ ;
                    $all_wsc_pairs{$chiplet_name}{$start_par}{$end_par} = $path_slack ;
                    if (defined $opt_dump_order) {
                        $wsc_order{$chiplet_name}{$start_par}{$end_par} = get_ordering ($start_clk_pin, $end_clk_pin, $root_pin) ;
                    }
                }else{
                    $all_wsc_pairs{$start_par}{$end_par} = $path_slack ;
                    if (defined $opt_dump_order) {
                        $wsc_order{$start_par}{$end_par} = get_ordering ($start_clk_pin, $end_clk_pin, $root_pin) ;
                    }
                }
                if (defined $opt_plot) {
                    plot_wsc_path ((get_path_ordering_pin (get_all_pins_of_path ($start_q_pin, $end_d_pin))), "wsc_ordering", "red") ;
                }
            }
        }
    }
}

if (!defined($order_file) && $opt_retime) {
    foreach my $start_clk_pin (sort keys %all_retime_paths) {
        my $end_clk_pins = $all_retime_paths{$start_clk_pin} ;
        foreach my $end_clk_pin (sort keys %$end_clk_pins) {
            my $root_pin = $jtag_clock_source{$top} ;
            my ($path_slack, $end_pin, $start_par, $end_par, $data_path_dist, $launch_path_dist, $capt_path_dist) = calc_path_slack ($start_clk_pin, $end_clk_pin, $root_pin) ;
            my $start_q_pin = get_cell_q_name (get_cell (-of => $start_clk_pin)) ;
            my $end_d_pin   = get_cell_d_name (get_cell (-of => $end_clk_pin)) ;

            if (defined $opt_debug) {
                print DEBUG "RETIME SLACK: $path_slack $start_clk_pin => $end_pin ($start_par $end_par) (data_dist : $data_path_dist, launch dist : $launch_path_dist, capt dist : $capt_path_dist)\n" ;
            }

            if (!(defined $opt_viol_only) || $path_slack < 0) {
                $all_retime_pairs{$start_par}{$end_par} = $path_slack ;
                if (defined $opt_dump_order) {
                    $retime_order{$start_par}{$end_par} = get_ordering ($start_clk_pin, $end_clk_pin, $root_pin) ;
                }
                if (defined $opt_plot) {
                    plot_wsc_path ((get_path_ordering_pin (get_all_pins_of_path ($start_q_pin, $end_d_pin))), "retime_ordering", "red") ;
                }
            }
        }
    }
}

# to start the estimation with new order file.

if ((defined $order_file)) {
    open IN, $order_file or die "Error : Cannot open the order file $order_file\n" ; 
    while (<IN>) {
        chomp ;
        my $line = $_ ;
        $line =~ s/\s+//g ;
        my @ordering = split ("=>", $line) ;    
        my @i1500_cells   = () ;
        my @clk_path_dist = () ;
        my $dump_data_order = "";
        my @dump_clk_order  = "" ;
        foreach my $i (0..$#ordering) {
            my $i1500_cell     = get_cells (-quiet, "$ordering[$i]/*/wby_reg_reg" ) ;
            my $i1500_clk_pin  = get_cell_cp_name ($i1500_cell) ;
            my $i1500_clk_dist = get_path_dist (get_all_pins_of_path($jtag_clock_source{$top}, $i1500_clk_pin)) ;
            push @i1500_cells, $i1500_cell ; 
            push @clk_path_dist, $i1500_clk_dist;
            $dump_clk_order[0] = get_path_order_str (get_all_pins_of_path ($jtag_clock_source{$top}, $i1500_clk_pin)) ;  
            if ($i > 0) {
                my $start_par      = $ordering[$i-1] ;
                my $end_par        = $ordering[$i] ;
                my $start_clk_pin  = get_cell_cp_name ($i1500_cells[$i-1]) ; 
                my $end_clk_pin    = get_cell_cp_name ($i1500_cells[$i]) ; 
                my $start_par_xy   = attr_of_cell ("phys_centroid_point" => $start_par) ; 
                my $end_par_xy     = attr_of_cell ("phys_centroid_point" => $end_par) ; 
                my $data_path_dist = get_dist ($start_par_xy->[0], $start_par_xy->[1], $end_par_xy->[0], $end_par_xy->[1]) ; 
                my $data_path_dly  = $delay_per_dist * $data_path_dist * 0.001 ; 
                $dump_data_order   = "$start_par => $end_par" ; 
                if ($opt_wsi || $opt_retime) {
                    $clk_path_dist[$i] = get_path_dist (get_all_pins_of_path($jtag_clock_source{$top}, $end_clk_pin)) ;
                } 
                if ($opt_wsc) {
                    $clk_path_dist[$i] = $clk_path_dist[$i-1] + $data_path_dist ;
                }
                my $launch_clk_dly = ($delay_per_dist * $clk_path_dist[$i-1] * $clk_data_delay_ratio)*0.001 ;
                my $capt_clk_dly   = ($delay_per_dist * $clk_path_dist[$i] * $clk_data_delay_ratio)*0.001 ;
                my $path_slack     = $jtag_period + $capt_clk_dly - $launch_clk_dly - $data_path_dly;   
                if (!defined($opt_viol_only) || $path_slack < 0) {
                    if ($opt_wsi) {
                        $all_wsi_pairs{$start_par}{$end_par} = $path_slack ;
                        if ($opt_debug) {
                            print DEBUG "NEW WSI ORDER SLACK: $path_slack $start_par => $end_par (data_dist : $data_path_dist, launch dist : $clk_path_dist[$i-1], capt dist : $clk_path_dist[$i])\n" ;
                        }
                        if ($opt_dump_order) {
                            $dump_clk_order[$i] = get_path_order_str (get_all_pins_of_path ($jtag_clock_source{$top}, $end_clk_pin)) ; 
                            $wsi_order{$start_par}{$end_par} = "\n\tdata path order   : $dump_data_order\n\tlaunch path order : $dump_clk_order[$i-1]\n\tcapt path order   : $dump_clk_order[$i]\n" ;
                        }
                    }
                    if ($opt_wsc) {
                        $all_wsc_pairs{$start_par}{$end_par} = $path_slack ;
                        if ($opt_debug) {
                            print DEBUG "NEW WSC ORDER SLACK: $path_slack $start_par => $end_par (data_dist : $data_path_dist, launch dist : $clk_path_dist[$i-1], capt dist : $clk_path_dist[$i])\n" ;
                        }
                        if ($opt_dump_order) {
                            $dump_clk_order[$i] = $dump_launch_order[$i-1]. "=> $end_par" ; 
                            $wsc_order{$start_par}{$end_par} = "\n\tdata path order   : $dump_data_order\n\tlaunch path order : $dump_clk_order[$i-1]\n\tcapt path order   : $dump_clk_order[$i]\n" ;
                        }
                    }
                    if ($opt_retime) {
                        $all_retime_pairs{$start_par}{$end_par} = $path_slack ;
                        if ($opt_debug) {
                            print DEBUG "NEW RETIME ORDER SLACK: $path_slack $start_par => $end_par (data_dist : $data_path_dist, launch dist : $clk_path_dist[$i-1], capt dist : $clk_path_dist[$i])\n" ;
                        }
                        if ($opt_dump_order) {
                            $dump_clk_order[$i] = get_path_order_str (get_all_pins_of_path ($jtag_clock_source{$top}, $end_clk_pin)) ;
                            $retime_order{$start_par}{$end_par} = "\n\tdata path order   : $dump_data_order\n\tlaunch path order : $dump_clk_order[$i-1]\n\tcapt path order   : $dump_clk_order[$i]\n" ;
                        }
                    }
                    if ($opt_plot) {
                        plot_path ($start_clk_pin, $end_clk_pin, "wsi_ordering", "red") ;
                    }
                }
            }
        }
    }  
    close IN ;
}

# to print out the reports for wsi/wsc/retime.
if ($opt_wsi) {
    print "Dumping wsi/wso paths to file $output ...\n" ;
    print O "intra_chiplet wsi/wso paths:\n" ;
    if ($top ne 'nv_top') {
        print O "$top:\n" ;
        print_double_hashing_report (\*O, %all_wsi_pairs) ;
        if (defined $opt_dump_order) {
            print "Dumping wsi/wso ordering to file $dump_order_file ...\n" ; 
            print_double_hashing_order (\*ORD, %wsi_order) ;
        }
    } else {
        foreach my $chiplet_ref (sort keys %all_wsi_pairs) {
            print O "$chiplet_ref:\n" ;
            my $chiplets    = $all_wsi_pairs{$chiplet_ref} ;    
            print_double_hashing_report (\*O, %$chiplets) ;            
            if (defined $opt_dump_order) {
                my $chiplets_order = $wsi_order{$chiplet_ref} ;
                print "Dumping wsi/wso ordering to file $dump_order_file ...\n" ; 
                print_double_hashing_order (\*ORD, %$chiplets_order) ;
            }
        }
    }
}

if ($opt_wsc) {
    print "Dumping wsi/wso paths to file $output ...\n" ;
    print O "intra_chiplet wsc paths:\n" ;
    if ($top ne 'nv_top') {
        print O "$top:\n" ;
        print_double_hashing_report (\*O, %all_wsc_pairs) ;
        if (defined $opt_dump_order) {
            print "Dumping wsc ordering to file $dump_order_file ...\n" ;
            print_double_hashing_order (\*ORD, %wsc_order) ;
        }
    } else {
        foreach my $chiplet_ref (sort keys %all_wsc_pairs) {
            print O "$chiplet_ref:\n" ;
            my $chiplets = $all_wsc_pairs{$chiplet_ref} ;
            print_double_hashing_report (\*O, %$chiplets) ;
            if (defined $opt_dump_order) {
                my $chiplets_order = $wsc_order{$chiplet_ref} ;
                print "Dumping wsc ordering to file $dump_order_file ...\n" ;
                print_double_hashing_order (\*ORD, %$chiplets_order) ;
            }
        }
    }
}


if ($opt_retime) {
    print O "inter_chiplet retime paths:\n" ;
    print O "$top:\n" ;
    print_double_hashing_report (\*O, %all_retime_pairs) ;
    if (defined $opt_dump_order) {
        print "Dumping retime ordering to file $dump_order_file ...\n" ;
        print_double_hashing_order (\*ORD, %retime_order) ;
    }
}

close O ;
print "INFO: dumped the slack infos to file $output .\n";
if (defined $opt_dump_order) {
    close ORD;
    print "INFO: dumped the ordering infos to file $dump_order_file .\n" ;
}

if (defined $opt_debug) {
    print DEBUG "INFO : files loaded : \n" ;
    foreach (get_files) {
        chomp ;
        print DEBUG "\t$_\n" ;
    }
    my $end_time_stamp = `date` ;
    print DEBUG "Job ended @ $end_time_stamp" ;
    print DEBUG "\nINFO: Infomations done. \n" ;
    close DEBUG ;
    print "INFO: dumped the debug infos to file $debug_out .\n" ;
}

END

sub calc_path_slack {
    my ($start_clk_pin, $end_clk_pin, $root_pin) = @_ ;
    my $start_q_pin      = get_cell_q_name  (get_cell (-of => $start_clk_pin)) ;
    my $end_pin          = get_cell_d_name  (get_cell (-of => $end_clk_pin)) ;
    my $start_par        = get_pin_par_name ($start_clk_pin) ;
    my $end_par          = get_pin_par_name ($end_clk_pin) ;
    my $data_path_pins   = get_all_pins_of_path($start_q_pin, $end_pin) ;
    my $data_path_dist   = get_path_dist($data_path_pins) ;
    my $launch_path_pins = get_all_pins_of_path($root_pin, $start_clk_pin) ;
    my $launch_path_dist = get_path_dist($launch_path_pins) ;
    my $capt_path_pins   = get_all_pins_of_path($root_pin, $end_clk_pin) ;
    my $capt_path_dist   = get_path_dist($capt_path_pins) ;
    my $path_slack       = estimate_path_slack($start_clk_pin, $end_clk_pin, $data_path_dist, $launch_path_dist, $capt_path_dist) ;
    return ($path_slack, $end_pin, $start_par, $end_par, $data_path_dist, $launch_path_dist, $capt_path_dist) ;
}

sub print_double_hashing_report {
    my ($filehandle, %input_hash) = @_ ;
    foreach my $key1 (sort keys %input_hash) {
        my $keys2 = $input_hash{$key1} ; 
        foreach my $key2 (sort keys %$keys2){
            printf $filehandle ("\t%.3f\t%s => %s\n", $input_hash{$key1}{$key2}, $key1, $key2) ;
        }
    }
}

sub print_double_hashing_order {
    my ($filehandle, %input_hash) = @_ ;
    foreach my $key1 (sort keys %input_hash) {
        my $keys2 = $input_hash{$key1} ;
        foreach my $key2 (sort keys %$keys2){
            print $filehandle "$key1 $key2 $input_hash{$key1}{$key2}\n" ;
        }
    }
}

sub get_ordering  {
    my ($start_clk_pin, $end_clk_pin, $root_pin) = @_ ;
    my $start_q_pin       = get_cell_q_name (get_cell (-of => $start_clk_pin)) ;
    my $end_d_pin         = get_cell_d_name (get_cell (-of => $end_clk_pin)) ;
    my $dump_data_order   = get_path_order_str (get_all_pins_of_path ($start_q_pin, $end_d_pin)) ;
    my $dump_launch_order = get_path_order_str (get_all_pins_of_path ($root_pin, $start_clk_pin)) ;
    my $dump_capt_order   = get_path_order_str (get_all_pins_of_path ($root_pin, $end_clk_pin)) ;
    my $order             = "\n\tdata path order   : $dump_data_order\n\tlaunch path order : $dump_launch_order\n\tcapt path order   : $dump_capt_order\n" ;
    return $order ;
}

sub plot_all_partitions {
    my %all_mods = map  ({$_ => 1} (get_modules ("*"))) ;
    my @pars_ref = grep (exists $all_mods{$_}, (all_partitions)) ;
    foreach my $par_ref (@pars_ref) {
        my @par_cells = get_cells_of $par_ref ;
        plot (-no_label => @par_cells) ;
    }
}

sub plot_path {

    my $from_pin = shift;
    my $to_pin   = shift;
    my $comment  = shift ;
    my $color    = shift ;
    my ($from_x, $from_y) = get_pin_xy $from_pin ;
    my ($to_x, $to_y)     = get_pin_xy $to_pin ;
    plot_line(-arrow=>"last", -name => "$comment", $from_x, $from_y, $to_x, $to_y, -color => "$color"); 
}

sub get_path_dist {

    my $all_pins = shift;
    my $sum_dist = 0;
    my $len = scalar @$all_pins;
    foreach my $index (0..$len-2) {
        $sum_dist += get_dist($all_pins->[$index],$all_pins->[$index+1]);
    }
    return $sum_dist;
};

#filter the paths with the fp constrain, fp path -through UJ_i1500_nobypass_pipe -through UJ_i1500_bypass_pipe
sub filter_path_by_cons {
    my %cons_flag = (
                      UJ_i1500_bypass_pipe => 0,
                      UJ_i1500_nobypass_pipe => 0,
                     );
    my $all_pin_paths = shift;
    foreach (@$all_pin_paths) {
        if (/UJ_i1500_nobypass_pipe/) {
            $cons_flag{UJ_i1500_nobypass_pipe} = 1
        } elsif (/UJ_i1500_bypass_pipe/) {
            $cons_flag{UJ_i1500_bypass_pipe} = 1;
        }
        if ($cons_flag{UJ_i1500_nobypass_pipe} and $cons_flag{UJ_i1500_bypass_pipe}) {return 1}
    }
    return 0
}

sub get_pin_par_name {
    my $pin = shift;
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
};

sub estimate_path_slack {
    my $start_cp = shift;
    my $end_cp = shift;
    my $data_path_dist = shift;
    my $launch_clock_path_dist = shift;
    my $capture_clock_path_dist = shift;
    my $clk_data_delay_ratio = shift ;
    #my $path_delay_by_dist = (($launch_clock_path_dist + $data_path_dist - $capture_clock_path_dist)/1000)*$delay_per_dist;
    my $path_delay_by_dist = (($launch_clock_path_dist- $capture_clock_path_dist)*$delay_per_dist*${clk_data_delay_ratio} + $data_path_dist*$delay_per_dist)/1000;
    my $period;
    if (attr_of_pin ("is_rise_edge_clock",$start_cp) and attr_of_pin ("is_rise_edge_clock",$end_cp)) {
        $period = $jtag_period ;
    } elsif ( attr_of_pin ("is_fall_edge_clock",$start_cp) and attr_of_pin ("is_fall_edge_clock",$end_cp)) {
        $period = $jtag_period
    } else { $period = $jtag_period/2.0 }
    my $slack = $period - $path_delay_by_dist;
    return $slack
}

#functions for the small usage
sub get_pin_cp_name {
    my $pin_name = shift;
    if (attr_of_pin("is_clock", $pin_name)) {return $pin_name}

    my $cell_name = get_cells (-of => $pin_name);
    my @cp_name = grep (attr_of_pin("is_clock",$_),get_pins (-of => $cell_name));
    if (scalar @cp_name == 1) {return $cp_name[0]} else {print "ERROR: $pin_name had multi-cp\n"};
}

sub get_cell_cp_name {
    my $cell_name = shift;
    my @cp_name = grep (attr_of_pin("is_clock",$_),get_pins (-of => $cell_name));
    if (scalar @cp_name == 1) {return $cp_name[0]} else {print "ERROR: $pin_name had multi-cp\n"};
}

sub get_pin_q_name {
    my $pin_name = shift;
    if (attr_of_pin("is_q", $pin_name)) {return $pin_name}

    my $cell_name = get_cells (-of => $pin_name);
    my @q_name = grep (attr_of_pin("is_q",$_),get_pins (-of => $cell_name));
    if (scalar @q_name == 1) {return $q_name[0]} else {print "ERROR: $pin_name had multi-q\n"};
}


sub get_cell_q_name {
    my $cell_name = shift;
    my @q_name = grep (attr_of_pin("is_q",$_),get_pins (-of => $cell_name));
    if (scalar @q_name == 1) {return $q_name[0]} else {print "ERROR: $pin_name had multi-q\n"};
}

sub get_cell_d_name {
    my $cell_name = shift;
    my @d_name = grep (attr_of_pin("is_data",$_),get_pins (-of => $cell_name));
    foreach (@d_name) {
        my @pin_context  = get_pin_context $_ ;
        my $lib_pin_name = @pin_context[-1] ; 
        if ($lib_pin_name eq 'E') {
            pop @d_name, $_ ;
        } 
    }
    if (scalar @d_name == 1) {return $d_name[0]} else {print "ERROR: $pin_name had multi-d\n"};
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

sub parse_list {
    my $l_ref = shift;
    my $hash_ref = shift;
    my @l = @$l_ref;
    while ((scalar @l) > 0) {
        foreach (0..$#l) {
            my $key = $l[0]."=>".$l[$_];
            my @order = @l[0..$_];
            $hash_ref -> {$key} = \@order  unless (exists $hash_ref -> {$key});
        }
        shift @l
    }

}

sub get_pin_par_only {
    my $pin = shift;
    my $tmp_cell = get_cell (-of => $pin);
    return $tmp_cell if (attr_of_ref ("is_partition",ref_of_cell ($tmp_cell)));
    my @all_refs = get_hier_list_txt ( "-ref", -of_pin => $pin);
    my @all_insts = get_hier_list_txt ( "-inst", -of_pin => $pin);
    my $par_name = "";
    while (my ($index, $value) = each @all_refs) {
        if (attr_of_ref("is_partition",$value)) {
            return $all_insts[$index]
        }
    }
};

sub get_path_ordering {

    my $all_pins_of_path = shift;
    my @all_pars = ();
    foreach (@$all_pins_of_path) {
        next if (attr_of_pin ("is_hier",$_));
        my $cur_par = get_pin_par_name $_;
        push (@all_pars,$cur_par) unless ($cur_par eq $all_pars[$#all_pars]);
    }
    return \@all_pars;
};

sub get_path_ordering_pin {

    my $all_pins_of_path = shift; 
    my @all_pars = ();
    my @order_pins = ();
    foreach (@$all_pins_of_path) {
        next if (attr_of_pin ("is_hier",$_));
        my $cur_par = get_pin_par_only $_;
        unless ($cur_par eq $all_pars[$#all_pars]) {
            push @order_pins,$_;
            push (@all_pars,$cur_par);
        }
    }
    return \@order_pins;
};



sub plot_wsc_path {
    my($order, $comment, $color) = @_;
    my $order_num = scalar @$order;
    foreach (0..$order_num-3) {
        my ($from_x, $from_y) = get_pin_xy ($order->[$_]);
        my ($to_x, $to_y)     = get_pin_xy ($order->[$_+1]);
        #print "$from_x, $from_y, $to_x, $to_y\n";
        plot_line(-arrow=>"", -name => "$comment", $from_x, $from_y, $to_x, $to_y, -color => "$color");
    }
    my ($from_x, $from_y) = get_pin_xy ($order->[-2]) ;
    my ($to_x, $to_y)     = get_pin_xy ($order->[-1]) ;
    plot_line(-arrow=>"last", -name => "$comment", $from_x, $from_y, $to_x, $to_y, -color => "$color");
};

sub get_path_order_str {
    my $all_pins = shift;
    my $order = get_path_ordering($all_pins);
    return join ("=>",@$order)
}

sub get_all_pins_of_path {
    my $from_pin = shift;
    my $to_pin   = shift;
    #print "INFO: get pins of $from_pin => $to_pin\n";
    my @path_lists = get_path_delay (-from => $from_pin => -to => $to_pin => -rtn_from_in => -wire_model => none);
    my @pin_lines = grep (/^\s\s\S*\s\([^(net)]+\)\s/,@path_lists);
    my @pins = map (get_pins_from_path_line($_),@pin_lines);
    return \@pins
}
sub get_pins_from_path_line {
    my @li = split;
    return $li[0]
}

