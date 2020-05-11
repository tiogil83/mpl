Tsub jtag_est_timing => << 'END';
    DESC {
          To estimate the jtag timing from prelayout
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
if (defined $dump_order) {
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

# to set the default value for checking wsi/wsc/retime
if (!(defined $opt_wsi) && !(defined $opt_wsc) && !(defined $opt_retime)) {
    $opt_wsi    = 1 ;
    $opt_wsc    = 1 ;
    $opt_retime = 1 ;
}

# need to specify the ordering file is for wsc, wsi or retime
if ($opt_wsi && $opt_wsc && $opt_retime && $order_file) {
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

if (defined $opt_debug) {
    print DEBUG "INFO : files loaded : \n" ;
    foreach (get_files) {
        chomp ;
        print DEBUG "\t$_\n" ;
    }
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

print "Tech   : ${tech}nm\nCorner : $corner\n\n" ;
print DEBUG "\nINFO : Tech   : ${tech}nm\nINFO : Corner : $corner\n\n" if (defined $opt_debug);

$delay_per_dist = get_yaml_corner_attr ($corner, mender_delay_per_dist) ;

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
    print "$_\t=>\t$jtag_clock_source{$top}\n\n" ;
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

# start to pasing the ordering file ;

if (defined $order_file) {
    $par_order_hash = parse_ordering_file ($order_file) ;
}

####Starting to estimate the wsi/wso/wsc slack
my %all_wsi_paths      = () ;
my %all_wsc_paths      = () ;
my %all_retime_paths   = () ;

my %all_wsi_pairs      = () ;
my %all_wsc_pairs      = () ;
my %all_retime_pairs   = () ;

my @i1500_cells = () ;

if (defined $opt_wsi || defined $opt_retime) {
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
        if (attr_of_cell ("is_seq", $cell_name) and $fo_inst =~ /\/wby_reg_reg$|i1500_data_pipe_.*\/UJ_pos_pipe_reg$/) {
            push @end_pins, $fo_pin ;
        }
    }
    foreach my $end_pin (@end_pins) {
        my $end_clk_pin = get_cell_cp_name (get_cell (-of, $end_pin)) ;
        my $end_par    = get_pin_par_name ($end_pin) ;

        # to skip the intra partition path
        if ($start_par eq $end_par) {next ;}
        # to skip the paths through both UJ_i1500_bypass_pipe_* and UJ_i1500_nobypass_pipe_*
        if (filter_path_by_cons ($start_q_pin, $end_pin)) {next} ;

        # to filter the inter_chiplet paths.
        my @start_par_list = get_hier_list_txt (-inst, $start_par) ;
        my @end_par_list   = get_hier_list_txt (-inst, $end_par) ;
        if ($start_clk_pin !~ /retime_path_/ && $end_clk_pin !~ /retime_path_/) {
            $all_wsi_paths{$start_clk_pin}{$end_clk_pin} = 1 ;
        } else {
            $all_retime_paths{$start_clk_pin}{$end_clk_pin} = 1 ;
        }
    }
}

if (defined $opt_wsc || defined $opt_retime) {
    @i1500_cells = find_objs (-cell, -quiet, -hier => "*wso_pos_reg" );
    push @i1500_cells, find_objs (-pin, -quiet, -hier => "*wby_reg_reg/D" ); 
    my @start_clk_pins = () ;
    foreach my $i1500_cell (@i1500_cells) {
        my $end_pin = $i1500_cell."/D" ; 
        my $end_clk_pin = get_cell_cp_name ($i1500_cell) ;

        #get all fanin flop infos
        my @all_fanins = get_fan2 (-fanin, -end => $end_pin, -pins) ;
        foreach (@all_fanins) {
            if ($end_pin =~ /wby_reg_reg/) {
                if (/.*pipe_out_to_client_reg/ and attr_of_cell ("is_seq", get_cell(-of => $_))) {
                    push @start_clk_pins, $_ ;
                } 
            } else {
                if (/i1500_wsc_pipe/ and attr_of_cell ("is_seq", get_cell(-of => $_))) {
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
            if (filter_path_by_cons ($start_q_pin, $end_pin)) {next} ;

            # to filter the inter_chiplet paths.
            my @start_par_list = get_hier_list_txt (-inst, $start_par) ;
            my @end_par_list   = get_hier_list_txt (-inst, $end_par) ;
            if ($start_clk_pin !~ /retime_path_/ && $end_clk_pin !~ /retime_path_/) {
                $all_wsc_paths{$start_clk_pin}{$end_clk_pin} = 1 ;
            } else {
                $all_retime_paths{$start_clk_pin}{$end_clk_pin} = 1 ;
            }
        }
    }
}

        # to get the path distance and estimate the path slack
        my $data_path_pins   = get_all_pins_of_path($start_q_pin, $end_pin) ;
        my $data_path_dist   = get_path_dist($data_path_pins) ; 
        my $launch_path_pins = get_all_pins_of_path($jtag_clock_source{$top}, $start_clk_pin) ;
        my $launch_path_dist = get_path_dist($launch_path_pins) ;
        my $capt_path_pins   = get_all_pins_of_path($jtag_clock_source{$top}, $end_clk_pin)
        my $capt_path_dist   = get_path_dist($capt_path_pins) ; 
        my $path_slack       = estimate_path_slack($start_clk_pin, $end_clk_pin, $data_path_dist, $launch_path_dist, $capt_path_dist) ;

        # to dump out the timing report ;
        if ((!defined $opt_viol_only) or $path_slack < 0) {
            if (defined $opt_debug) {
                print DEBUG "SLACK: $path_slack $start_clk_pin => $end_pin ($start_par $end_par) ($data_path_dist, $launch_path_dist, $capt_path_dist)\n" ;
            }
        }
    }


#if (defined $opt_wsi) {
#    #wsi/wso
#    print "\nChecking wsi/wso for $top ...\n";
#    print DEBUG "WSI/WSO paths:\n" if (defined $opt_debug);
#    
#    my @all_wsi =  find_objs (-cell, -quiet, -hier => "*wby_reg_reg" );
#    push @all_wsi, find_objs (-cell, -quiet, -hier => "*i1500_data_pipe_*/UJ_pos_pipe_reg") ;
#  
#    
#    if (defined $opt_dump_order) {
#        print "Dumping wsi/wso orering to file : $dump_order_file ...\n" ;
#        print ORD "wsi/wso paths order:\n";
#    }
#    
#    foreach my $cell (@all_wsi) {
#        #get all from cell info
#        my $from_pin_cp = get_cell_cp_name ($cell);
#        my $from_pin_Q = get_cell_q_name ($cell);
#        my $start_par = get_pin_par_name ($from_pin_Q);
#    
#        #get all to cell info
#        my %fanout_seqs = ();
#        my @all_fanout_pins = get_fan2 (-fanout => $from_pin_cp, -end, -pins);
#        foreach my $pin (@all_fanout_pins) {
#            my $cell_name = find_objs (-cell, -quiet, -of => $pin);
#            if (attr_of_cell ("is_seq", $cell_name) and $cell_name =~ /\/wby_reg_reg$|i1500_data_pipe_.*\/UJ_pos_pipe_reg$/) {
#                $fanout_seqs{$cell_name} = $pin;
#            };
#        };
#        while (my ($fanout_seq, $to_pin) = each %fanout_seqs) {
#            my $to_pin_cp          = get_cell_cp_name($fanout_seq);
#            my $end_par            = get_pin_par_name ($to_pin);
#            #skip the intra partition paths
#            if ($start_par eq $end_par) {next};
#            #skip the fp cons paths
#            if (filter_path_by_cons($from_pin_Q, $to_pin)) {next};
#            #checked the path dist
#            my $pins_of_data_path       = get_all_pins_of_path($from_pin_Q, $to_pin);
#            my $data_path_dist          = get_path_dist ($pins_of_data_path);
#            my $pins_of_launch_path     = get_all_pins_of_path($jtag_clock_source{$top}, $from_pin_cp);
#            my $launch_clock_path_dist  = get_path_dist ($pins_of_launch_path);
#            my $pins_of_capture_path    = get_all_pins_of_path($jtag_clock_source{$top}, $to_pin_cp);
#            my $capture_clock_path_dist = get_path_dist ($pins_of_capture_path);
#            my $path_slack              = estimate_path_slack($from_pin_cp, $to_pin_cp, $data_path_dist, $launch_clock_path_dist,$capture_clock_path_dist, $clk_data_delay_ratio);
#
#            # to filter the inter_chiplet paths.
#            my @start_par_list = get_hier_list_txt (-inst, $start_par) ;
#            my @end_par_list   = get_hier_list_txt (-inst, $end_par) ;
#            $flag_retime = 0 ;
#            if ($top eq 'nv_top') {
#                if ($start_par_list[0] ne $end_par_list[0]) {
#                    $flag_retime = 1 ;
#                } 
#            }
#            if ($from_pin_cp =~ /retime_path_/ || $to_pin_cp =~ /retime_path_/) {
#                $flag_retime = 1 ;
#            }
#            
#            # only print/plot the violations 
#            if (!(defined $opt_viol_only) or $path_slack < 0) {
#                if (defined $opt_dump_order) {
#                    print ORD "Slack: $path_slack $from_pin_cp =>  $to_pin\n";
#                    my $path_order_string = get_path_order_str ($data_path_dist);
#                    print ORD "DATA path order: $path_order_string\n";
#                    my $launch_order_string = get_path_order_str ($pins_of_launch_path);
#                    print ORD "Launch path order: $launch_order_string\n";
#                    my $capture_order_string = get_path_order_str ($pins_of_capture_path);
#                    print ORD "Capture path order: $capture_order_string\n";
#                    print ORD "\n";
#                }
#                if (defined $opt_debug) {
#                    print DEBUG "SLACK: $path_slack $from_pin_cp =>  $to_pin ($start_par => $end_par) (data_path_dist: $data_path_dist; launch_clock_path_dist: $launch_clock_path_dist; capture_clock_path_dist: $capture_clock_path_dist)\n";
#                }
#                if (defined $opt_plot && !$flag_retime) {
#                    plot_path ($from_pin_Q, $to_pin, "wsi_ordering", "black") ;
#                }
#                if (defined $opt_plot && $flag_retime && $opt_retime) {
#                    plot
#                }
#                if (!$flag_retime and $top ne 'nv_top') {
#                    $all_wsi_paths{$start_par}{$end_par} = $path_slack ; 
#                } elsif (!$flag_retime and $top eq 'nv_top'){
#                    my $top_start_par = $start_par ;
#                    my $top_end_par   = $end_par ;
#                    my $chiplet_name  = $start_par ;
#                    $top_start_par    =~ s/(\S+)\/(\$S+)/$2/ ;
#                    $top_end_par      =~ s/(\S+)\/(\$S+)/$2/ ;
#                    $chiplet_name     =~ s/(\S+)\/(\$S+)/$1/ ;
#                    my $chiplet_ref   = $all_chiplets_inst{$chiplet_name} ;
#                    $all_wsi_paths{$chiplet_ref}{$top_start_par}{$top_end_par} = $path_slack ;
#                } else {
#                    $all_retime_paths{$start_par}{$end_par} = $path_slack ;
#                }
#            }
#            if (defined $order_file) {
#                my $est_slack_by_order = estimate_data_path_by_ordering ($from_pin_cp, $to_pin_cp,$par_order_hash,$launch_clock_path_dist,$capture_clock_path_dist);
#                my $slack = $est_slack_by_order -> {"slack"};
#                my $order_ref = $est_slack_by_order -> {"path_order"};
#                my $order = join("=>",@$order_ref);
#                my $dist =  $est_slack_by_order -> {"path_dist"};
#                if (!(defined $opt_viol_only) or $slack < 0) {
#                    print DEBUG "SLACK: $slack $from_pin_cp =>  $to_pin ($start_par => $end_par) (data_path_order: $order($dist) launch_clock_path_dist: $launch_clock_path_dist;capture_clock_path_dist: $capture_clock_path_dist)\n" ;
#                }
#            }
#        };
#    };
#}
#
#if (defined $opt_wsc) {
#    #wsc
#    print "\nChecking wsc for $top ...\n";
#    my @all_wsc_to =  find_objs (-pin, -quiet, -hier => "*wso_pos_reg/D" );
#    push @all_wsc_to, find_objs (-pin, -quiet, -hier => "*wby_reg_reg/D" );
#    
#    if (defined $opt_dump_order) {
#        print ORD "WSC paths' order:\n";
#    }
#    my @wsc_seqs_pins = ();
#    foreach my $wsc_to (@all_wsc_to) {
#        #print "wsc_to: $wsc_to\n";
#        #get fan in flop info
#        my @fan2_list = get_fan2 (-fanin, -end => $wsc_to , -pins);
#        my @fanin_pins = ();
#        foreach (@fan2_list) {
#            if ($wsc_to =~ /wby_reg_reg/) {
#                if ($_ =~ /.*pipe_out_to_client_reg/ and attr_of_cell ("is_seq",find_objs(-cell, -of => $_))) {
#                    push @fanin_pins, $_;
#                }
#            } else {
#                if ($_ =~ /i1500_wsc_pipe/ and attr_of_cell ("is_seq",find_objs(-cell, -of => $_))) {
#                    push @fanin_pins, $_;
#                }
#            }
#        }
#        foreach my $fanin_cp (@fanin_pins) {
#            #print "cell_name: $cell_name\n";
#            push @wsc_seqs_pins, "$fanin_cp"."=>"."$wsc_to";
#        };
#    };
#    #print "@wsc_seqs_pins\n";
#    foreach (@wsc_seqs_pins) {
#        my @tmp = split("=>",$_);
#        my $fanin_cp = $tmp[0];
#    
#        my $fanin_Q = get_pin_q_name ($fanin_cp);
#    
#        my $to_pin  = $tmp[1];
#        #print "to_pin: $to_pin\n";
#    
#        my $to_pin_cp = get_pin_cp_name ($to_pin);
#        #checked the path dist
#        my $start_par = get_pin_par_name($fanin_Q);
#        my $end_par = get_pin_par_name($to_pin);
#
#        if ($start_par eq $end_par) {next};
#        my $all_data_path_pins  = get_all_pins_of_path($fanin_Q, $to_pin);
#        if (filter_path_by_cons($all_data_path_pins)) {next};
#    
#        my $data_path_dist = get_path_dist ($all_data_path_pins);
#        my $all_launch_path_pins = get_all_pins_of_path($jtag_clock_source{$top}, $fanin_cp);
#        my $all_capture_path_pins = get_all_pins_of_path($jtag_clock_source{$top}, $to_pin_cp);
#        my $launch_clock_path_dist  = get_path_dist ($all_launch_path_pins);
#        my $capture_clock_path_dist = get_path_dist ($all_capture_path_pins);
#        my $path_slack = estimate_path_slack($fanin_cp, $to_pin_cp, $data_path_dist, $launch_clock_path_dist, $capture_clock_path_disti, $clk_data_delay_ratio);
#
#        # to filter the retime paths.
#        my @start_par_list = get_hier_list_txt (-inst, $start_par) ;
#        my @end_par_list   = get_hier_list_txt (-inst, $end_par) ;
#        $flag_retime = 0 ;
#        if ($top eq 'nv_top') {
#            if ($start_par_list[0] ne $end_par_list[0]) {
#                $flag_retime = 1 ;
#            }
#        }
#        if ($fanin_cp =~ /retime_path_/ || $to_pin_cp =~ /retime_path_/) {
#            $flag_retime = 1 ;
#        }
#    
#        if (!(defined $opt_viol_only) or $path_slack < 0) {
#            if (defined $opt_dump_order) {
#                print ORD "SLACK: $path_slack $fanin_cp =>  $to_pin\n";
#                my $path_order_string = get_path_order_str ($all_data_path_pins);
#                print ORD "DATA path order: $path_order_string\n";
#                my $launch_order_string = get_path_order_str ($all_launch_path_pins);
#                print ORD "Launch path order: $launch_order_string\n";
#                my $capture_order_string = get_path_order_str ($all_capture_path_pins);
#                print ORD "Capture path order: $capture_order_string\n";
#                print ORD "\n";
#            }
#            if (defined $opt_debug) {
#                print DEBUG "SLACK: $path_slack $fanin_cp => $to_pin ($start_par => $end_par) (data_path_dist: $data_path_dist; launch_clock_path_dist: $launch_clock_path_dist; capture_clock_path_dist: $capture_clock_path_dist)\n";
#            }
#            if (defined $opt_plot) {
#                my $wsc_path_order = get_path_ordering_pin ($all_data_path_pins);
#                plot_wsc_path ($wsc_path_order, "wsc_ordering", "red") ;
#            }
#            if (!$flag_retime and $top ne 'nv_top') {
#                $all_wsc_paths{$start_par}{$end_par} = $path_slack ;
#            } elsif (!$flag_retime and $top eq 'nv_top'){
#                my $top_start_par = $start_par ;
#                my $top_end_par   = $end_par ;
#                my $chiplet_name  = $start_par ;
#                $top_start_par    =~ s/(\S+)\/(\$S+)/$2/ ;
#                $top_end_par      =~ s/(\S+)\/(\$S+)/$2/ ;
#                $chiplet_name     =~ s/(\S+)\/(\$S+)/$1/ ;
#                my $chiplet_ref   = $all_chiplets_inst{$chiplet_name} ;
#                $all_wsc_paths{$chiplet_ref}{$top_start_par}{$top_end_par} = $path_slack ;
#            } else {
#                $all_retime_paths{$start_par}{$end_par} = $path_slack ;
#            }
#
#        }
#        if ((defined $order_file) && (defined $opt_retime)) {
#            my $est_slack_by_order = estimate_data_path_by_ordering ($fanin_cp, $to_pin_cp,$par_order_hash,$launch_clock_path_dist,$capture_clock_path_dist);
#            my $slack = $est_slack_by_order -> {"slack"};
#            my $order_ref = $est_slack_by_order -> {"path_order"};
#            my $order = join("=>",@$order_ref);
#            my $dist =  $est_slack_by_order -> {"path_dist"};
#            if (!(defined $opt_viol_only) or $slack < 0) {
#                print DEBUG "SLACK: $slack $fanin_cp => $to_pin ($start_par => $end_par) (data_order: $order($dist); launch_clock_path_dist: $launch_clock_path_dist; capture_clock_path_dist: $capture_clock_path_dist)\n";
#            }
#        }
#        if (defined $opt_order_file) {
#            my $clock_source = $jtag_clock_source{$top};
#            my $est_slack_by_order = estimate_data_clock_path_by_ordering($fanin_cp, $to_pin_cp,$par_order_hash,$clock_source);
#            my $slack = $est_slack_by_order -> {"slack"};
#            my $path_order_ref = $est_slack_by_order -> {"data_order"};
#            my $path_order = join("=>",@$path_order_ref);
#            my $data_dist = $est_slack_by_order -> {"data_dist"};
#            my $launch_clock_order_ref = $est_slack_by_order -> {"launch_order"};
#            my $launch_clock_order = join("=>",@$launch_clock_order_ref);
#            my $launch_clock_path_dist = $est_slack_by_order -> {"launch_dist"};
#            my $capture_clock_order_ref = $est_slack_by_order -> {"capture_order"};
#            my $capture_clock_order = join("=>",@$capture_clock_order_ref);
#            my $capture_clock_path_dist = $est_slack_by_order -> {"capture_dist"};
#            if (!(defined $opt_viol_only) or $slack < 0) {
#                print DEBUG "SLACK: $slack $fanin_cp => $to_pin ($start_par => $end_par) (data_order: $path_order($data_dist); launch_clock_path: $launch_clock_order($launch_clock_path_dist) capture_clock_path: $capture_clock_order($capture_clock_path_dist)\n";
#            }
#        }
#    };
#}

# to print out the reports for wsi/wsc/retime.
if ($opt_wsi) {
    print O "intra_chiplet wsi/wso paths:\n" ;
    if ($top ne 'nv_top') {
        print O "$top:\n" ;
        print_double_hashing (\*O, %all_wsi_pairs) ;
    } else {
        foreach my $chiplet_ref (sort keys %all_wsi_pairs) {
            print O "$chiplet_ref:\n" ;
            my $chiplets = $all_wsi_pairs{$chiplet_ref} ;    
            print_double_hashing (\*O, %$chiplets) ;            
        }
    }
}

if ($opt_wsc) {
    print O "intra_chiplet wsc paths:\n" ;
    if ($top ne 'nv_top') {
        print O "$top:\n" ;
        print_double_hashing (\*O, %all_wsc_pairs) ;
    } else {
        foreach my $chiplet_ref (sort keys %all_wsc_pairs) {
            print O "$chiplet_ref:\n" ;
            my $chiplets = $all_wsc_pairs{$chiplet_ref} ;
            print_double_hashing (\*O, %$chiplets) ;
        }
    }
}


if ($opt_retime) {
    print O "inter_chiplet retime paths:\n" ;
    if ($top ne 'nv_top') {
        print O "$top:\n" ;
        print_double_hashing (\*O, %all_retime_pairs) ;
    } else {
        foreach my $chiplet_ref (sort keys %all_retime_pairs) {
            print O "$chiplet_ref:\n" ;
            my $chiplets = $all_retime_pairs{$chiplet_ref} ;
            print_double_hashing (\*O, %$chiplets) ;
        }
    }
}

close O ;
print "INFO: dumped the slack info file $output\n";
if (defined $opt_dump_order) {
    close ORD;
    print "INFO: dumped the ordering infos to file $order_file\n" ;
}
if (defined $opt_debug) {
    print DEBUG "\nINFO: Infomations done. \n" ;
    close DEBUG ;
    print "INFO: dumped the debug infos to file $debug_out\n" ;
}

END

sub print_double_hashing {
    my ($filehandle, %input_hash) = @_ ;
    foreach my $key1 (sort keys %input_hash) {
        my $keys2 = $input_hash{$key1} ; 
        foreach my $key2 (sort keys %$keys2){
            printf $filehandle ("\t%.3f\t%.20s => %.20s\n", $input_hash{$key1}{$key2}, $key1, $key2) ;
        }
    }
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

#parsing odering file
sub parse_ordering_file {
    my $file = shift;
    my $order_hash_ref = {};
    open (IN, $file) or die "ERROR: Couldn't open ordering file $file!";
    while (<IN>) {
        my @spls = map(trim($_), split ("=>",$_));
        my @spls = @spls[1..$#spls];
        $order_hash_ref -> {"source_par"} = $spls[0]  unless (exists $order_hash_ref -> {"source_par"});
        parse_list (\@spls, $order_hash_ref)
    }
    return $order_hash_ref
    close IN ;
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

sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

#estimate the slack by override the data paths with ordering
sub estimate_data_path_by_ordering {
    my $est_order_result = {};
    my $start_cp = shift;
    my $end_cp = shift;
    my $start_par = get_pin_par_only($start_cp);
    my $end_par = get_pin_par_only($end_cp);

    my $data_path_hash = shift;
    my $launch_clock_path_dist = shift;
    my $capture_clock_path_dist = shift;
    $path_order = $data_path_hash -> {"$start_par=>$end_par"};
    $data_path_dist = get_path_dist_by_par_order ($path_order);

    my $path_delay_by_dist = (($launch_clock_path_dist- $capture_clock_path_dist)*$delay_per_dist*$clk_data_delay_ratio + $data_path_dist*$delay_per_dist)/1000;
    my $period;
    if (attr_of_pin ("is_rise_edge_clock",$start_cp) and attr_of_pin ("is_rise_edge_clock",$end_cp)) {
        $period = $jtag_period ;
    } elsif ( attr_of_pin ("is_fall_edge_clock",$start_cp) and attr_of_pin ("is_fall_edge_clock",$end_cp)) {
        $period = $jtag_period
    } else { $period = $jtag_period/2.0 }
    my $slack = $period - $path_delay_by_dist;
    $est_order_result -> {"slack"} = $slack;
    if (exists $data_path_hash -> {"$start_par=>$end_par"}) {
        $est_order_result -> {"path_order"} = $path_order;
    } else {
        $est_order_result -> {"path_order"} = ["None"]
    }
    $est_order_result -> {"path_dist"} = $data_path_dist;
    return $est_order_result
}

#estimate the slack by override the data/clock paths with ordering
sub estimate_data_clock_path_by_ordering {
    my $est_order_result = {};
    my $start_cp = shift;
    my $end_cp = shift;
    my $start_par = get_pin_par_only($start_cp);
    my $end_par = get_pin_par_only($end_cp);

    my $data_path_hash = shift;
    my $clock_source = shift;

    my $source_par = get_pin_par_only $clock_source;

    my $path_order = $data_path_hash -> {"$start_par=>$end_par"};
    my $data_path_dist = get_path_dist_by_par_order ($path_order);

    my $launch_clock_order = $data_path_hash -> {"${source_par}=>${start_par}"};
    my $launch_clock_path_dist = get_path_dist_by_par_order($launch_clock_order);

    my $capture_clock_order = $data_path_hash -> {"${source_par}=>${end_par}"};
    my $capture_clock_path_dist = get_path_dist_by_par_order($capture_clock_order);

    my $path_delay_by_dist = (($launch_clock_path_dist- $capture_clock_path_dist)*$delay_per_dist*$clk_data_delay_ratio + $data_path_dist*$delay_per_dist)/1000;
    my $period;
    if (attr_of_pin ("is_rise_edge_clock",$start_cp) and attr_of_pin ("is_rise_edge_clock",$end_cp)) {
        $period = $jtag_period ;
    } elsif ( attr_of_pin ("is_fall_edge_clock",$start_cp) and attr_of_pin ("is_fall_edge_clock",$end_cp)) {
        $period = $jtag_period
    } else { $period = $jtag_period/2.0 }
    my $slack = $period - $path_delay_by_dist;
    $est_order_result -> {"slack"} = $slack;
    $est_order_result -> {"data_order"} = $path_order;
    $est_order_result -> {"data_dist"} = $data_path_dist;
    $est_order_result -> {"launch_order"} = $launch_clock_order;
    $est_order_result -> {"launch_dist"} =  $launch_clock_path_dist;
    $est_order_result -> {"capture_order"} = $capture_clock_order;
    $est_order_result -> {"capture_dist"} = $capture_clock_path_dist;
    return $est_order_result
}

sub get_path_dist_by_par_order {
    my $path_order = shift;
    my $dist = 0;
    return $dist if ((scalar @$path_order) == 1);
    foreach my $index (0..$#$path_order-1) {
        my ($x, $y) = attr_of_cell ("x_y_orient_local",$path_order->[$index]);
        my ($x1,$y1) = attr_of_cell ("x_y_orient_local",$path_order->[$index+1]);
        $dist += abs($x-x1) + abs($y-$y1)
    }
    return $dist
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
        my $cur_par = get_pin_par_only $_;
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
    foreach (0..$order_num-2) {
        my ($from_x, $from_y) = get_pin_xy ($order->[$_]);
        my ($to_x, $to_y)     = get_pin_xy ($order->[$_+1]);
        #print "$from_x, $from_y, $to_x, $to_y\n";
        plot_line(-arrow=>"last", -name => "$comment", $from_x, $from_y, $to_x, $to_y, -color => "$color");
    }
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

