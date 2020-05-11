use strict ;

Tsub jtag_prelayout => << 'END';
    DESC {
            To estimate the jtag timing from prelayout
            Examples :
                jtag_prelayout -wsi -plot                          # dump the timing estimation reports and plot the fly lines only for wsi paths
                jtag_prelayout -wsc -cal_slk -slack_lesser_than -1 # dump the timing estimation reports only for wsc paths worse than the slack limitation
                jtag_prelayout -wsc -dist_longer_than 4000         # dump the timing estimation reports only for wsc paths longer than the distance limitation 
                jtag_prelayout -wsi -retime -dump_order            # dump the timing estimation reports and data/clock path ordering for both wsi and retime paths
                jtag_prelayout -wsi -order_file <order_file_name>  # estimate the wsi timing based on a new order file with format : <par1> => <par2> => <par3>
                jtag_prelayout                                     # no any options, it equals to "jtag_est_timing -wsi -wsc -retime"
    }
    ARGS {
        -plot                               # to plot the fly lines of paths
        -cal_slk                            # to enable calculating path delay and slack
        -dist: $dist_rep                    # to sepcify the distance report file
        -slack: $slack_rep                  # to sepcify the slack report file
        -wsi                                # only check the wci paths
        -wsc                                # only check the wsc paths
        -retime                             # only check the retime paths
        -slack_lesser_than: $slack_limit    # to only plot or show the paths worse than the slack limitation 
        -dist_longer_than: $dist_limit      # to only plot or show the paths longer than the distance limitation 
        -order_file:$order_file             # check the data path with custom ordering file
        -dump_order                         # will dump data/clock path ordering
        -debug                              # to print more infos for debugging
    }

######################
# input :
#   1. netlists (in mender session)
#   2. user-defined ordering
#       a. wsi
#       b. wsc
#       c. retime
# plot :
#   1. pure wsi
#   2. pure wsc
#   3. pure retime
# output files :
#   1. distance report
#       a. wsi
#       b. wsc
#       c. retime
#   2. slack report
#       a. wsi
#       b. wsc
#       c. retime
#   3. ordering report
#       a. wsi
#       b. wsc
#       c. retime
#   4. debug report
######################

###################
# Environment 
###################
my $top  = get_top ;
my $type = $ENV{NAHIER_TYPE} ;
my $rev  = $ENV{USE_LAYOUT_REV} ;
my $date = `date +%Y%b%d` ;
my $proj = $ENV{NV_PROJECT} ;

###################
# Options 
###################
# default report files :
$rev =~ s/\./_/g ;
chomp $date ;
if (!(defined $dist_rep)) {
    $dist_rep = "${proj}/rep/${top}.JtagPreLayout_${rev}.$type.$date.dist.txt" ;
}

open (DIST, "> $dist_rep") or die "ERROR: cannot write to file $dist_rep.\n";

if (!(defined $dist_limit)) {
    $dist_limit = 0 ;
    print DIST "Reporting the distatace. \n\n" ;
} else {
    print DIST "Reporting the paths for distance longer than $dist_limit um.\n\n" ;
}

if (!(defined $slack_rep)) {
    $slack_rep = "${proj}/rep/${top}.JtagPreLayout_${rev}.$type.$date.slack.txt" ;
} else {
    $opt_cal_slk = 1 ;
}

if (defined $slack_limit) {
    $opt_cal_slk = 1 ;
}

if (defined $opt_cal_slk) {
    open (SLACK, "> $slack_rep") or die "ERROR: cannot write to file $slack_rep.\n";
    if (defined $slack_limit) {
        print SLACK "Reporting the paths for slack worse than $slack_limit ns.\n\n" ;
    } else {
        $slack_limit = 100 ;
        print SLACK "Reporting the paths slack.\n\n" ;
    }
}

# default file for dumping out ordering in NL.
my $dump_order_file ;
if (defined $opt_dump_order) {
    $dump_order_file = "${proj}/rep/${top}.JtagPreLayout_${rev}.$type.$date.order.txt" ;
    open (ORDER, "> $dump_order_file") or die "ERROR: cannot open file $dump_order_file.\n";
}

# default file for debugging 
my $dbg ;
if (defined $opt_debug) {
    $dbg = "${proj}/rep/${top}.JtagPreLayout_${rev}.$type.$date.debug.txt" ; 
    open (DEBUG, "> $dbg") or die "ERROR: cannot write to the debug log file $dbg.\n" ;
}

my $TimeStamp = `date` ;
if (defined $opt_debug) {
    print DEBUG "TimeStamp : Job Start $TimeStamp\n" ;
} 

# to set the default value for checking wsi/wsc/retime
if (!(defined $opt_wsi) && !(defined $opt_wsc) && !(defined $opt_retime)) {
    $opt_wsi    = 1 ;
    $opt_wsc    = 1 ;
    $opt_retime = 1 ;
}

# just plot one type of paths for wsi/wsc/retime.
# to make the plotting more clear.
if ( (defined $opt_plot) && ($opt_wsi && $opt_wsc)) {
    die "ERROR: it is not good to plot all the wsc/wsi/retime paths at the same time.\nERROR: please choose one type first.\n" ;
}

######################
# def/region/lib files
######################

# preparation for the def/region files ;
my @def_files = get_files (-type => def) ;

if ($#def_files == -1) {
    print "Loading def and region files.\n" ;
    load_def_region_files (-top => $top);
}


#######################
# infos from yaml
#######################

# to define the corner for delay per distance
# also to define the ratio for clock_delay/data_delay, currently 0.25. will adjust when correlation

my $tech = attr_of_process leff ;
my $corner = "" ;

if ($tech == 16) {
    $corner = "ssg_0c_0p6v_bin_max_si" ;
} elsif ($tech == 7) {
    $corner = "ssg_0c_0p55v_bin_max_si" ;
} else {
    die "No tech file found.\n" ;
}

set_timing_corner $corner ;

# hacked for the bbox timing arc through
if ($type eq 'noscan') {
    if (grep (/\/NV_BLKBOX_BUFFER_tsmc16ff_t9_svt_std_ssg/, (get_files (-type => 'lib')))) {
        print "Loaded the NV_BLKBOX_BUFFER libs already.\n\n" ;   
    } else {
        print "Loading NV_BLKBOX_BUFFER lib ...\n\n" ;
        load "/home/scratch.ga100_test_NV_gaa_s0/ga100/ga100/timing/ga1xx/timing_scripts/test_timing/custom_check/BLK_BOX_LIB/NV_BLKBOX_BUFFER_tsmc16ff_t9_svt_std_ssg_0c_0p55v.lib" ;
        load "/home/scratch.ga100_test_NV_gaa_s0/ga100/ga100/timing/ga1xx/timing_scripts/test_timing/custom_check/BLK_BOX_LIB/NV_BLKBOX_BUFFER_tsmc16ff_t9_svt_std_ssg_0c_0p6v.lib" ;
        load "/home/scratch.ga100_test_NV_gaa_s0/ga100/ga100/timing/ga1xx/timing_scripts/test_timing/custom_check/BLK_BOX_LIB/NV_BLKBOX_BUFFER_tsmc16ff_t9_svt_std_ssg_105c_0p8v.lib" ;
    }
}
# loading all the def/region files

print "Basic infos : \nTech   : ${tech}nm\nCorner : $corner\n\n" ;


$delay_per_dist = get_yaml_corner_attr ($corner, mender_delay_per_dist) ;
print "Model delay per distance : 1000um => $delay_per_dist ns for corner $corner\n\n" ;
model_delay_per_dist (1000, $delay_per_dist) ;

if (defined $opt_debug) {
    print DEBUG "\nINFO : Tech   : ${tech}nm\nINFO : Corner : $corner\n\n" ;
    print DEBUG "\nINFO : Delay  : ${delay_per_dist}ns per 1000um\n\n"  ; 
}

#########################
# infos from chip config
#########################

# to get the jtag clock sources from chip_config.
my @jtag_clk_chiplet_biports = () ;
my @top_jtag_clock_source    = () ;
my %jtag_clock_sources       = () ;
my %all_chiplets_inst        = () ;
my $top_level                = "" ;

# check both jtag_reg_clk and jtag_reg_tck sources for not defined correctly at very early stage.
if (exists $CONFIG->{clock_timing_specification}{clock}{jtag_reg_clk}{clock_configs}{cfg_func}{biport_sources}) {
    @jtag_clk_chiplet_biports = @{$CONFIG->{clock_timing_specification}{clock}{jtag_reg_clk}{clock_configs}{cfg_func}{biport_sources}} ;
} elsif (exists $CONFIG->{clock_timing_specification}{clock}{jtag_reg_tck}{clock_configs}{cfg_func}{biport_sources}) {
    @jtag_clk_chiplet_biports = @{$CONFIG->{clock_timing_specification}{clock}{jtag_reg_tck}{clock_configs}{cfg_func}{biport_sources}} ;
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
    if (exists $CONFIG->{partitioning}{chiplets}{$chiplet}{is_toplevel}) {
        $top_level = $chiplet ;
    }
}

foreach my $chiplet_name (keys %all_chiplets_inst) {
    foreach my $jtag_biport (@jtag_clk_chiplet_biports) {
        if ($jtag_biport =~ /$chiplet_name/ && $jtag_biport !~ /\/.*\//) {
            $jtag_biport =~ /$chiplet_name\/(\S+)/ ;
            $jtag_clock_sources{$all_chiplets_inst{$chiplet_name}} = $1 ;
        }
    }
}

if (exists $CONFIG->{clock_timing_specification}{clock}{jtag_reg_tck}{clock_configs}{cfg_func}{pin_sources}) {
    @top_jtag_clock_source = @{$CONFIG->{clock_timing_specification}{clock}{jtag_reg_tck}{clock_configs}{cfg_func}{pin_sources}} ;
} elsif (exists $CONFIG->{clock_timing_specification}{clock}{jtag_reg_clk}{clock_configs}{cfg_func}{pin_sources}) {
    @top_jtag_clock_source = @{$CONFIG->{clock_timing_specification}{clock}{jtag_reg_clk}{clock_configs}{cfg_func}{pin_sources}} ;
} else {
    die "No jtag_reg_tck/jtag_reg_clk pin source defined. Please double check.\n" ;
}

$jtag_clock_sources{$top_level} = $top_jtag_clock_source[0] ;
foreach my $chiplet_top_name (keys %all_chiplets_inst) {
    if ($top_jtag_clock_source[0] =~ /^$chiplet_top_name/) {
        $top_jtag_clock_source[0] =~ s/^$chiplet_top_name\/(\S+)/$1/ ;
        $jtag_clock_sources{$all_chiplets_inst{$chiplet_top_name}} = $top_jtag_clock_source[0];
    }
}

if (defined $opt_debug) {
    print "INFO : jtag clock pin source and biport sources for each chiplets :\n" ;
    print DEBUG "INFO : jtag clock pin source and biport sources for each chiplets :\n" ;
    foreach (keys %jtag_clock_sources) {
        printf ("INFO : %15s => %s\n", $_, $jtag_clock_sources{$_}) ;
        printf DEBUG ("INFO : %15s => %s\n", $_, $jtag_clock_sources{$_}) ;
    }
} else {
    print "The jtag clock pin source/biport sources for $top:\n" ;
    print "$top\t=>\t$jtag_clock_sources{$top}\n\n" ;
}

print "\n" ;

#jtag clock period

my $jtag_period ;
if (exists $CONFIG->{clock_timing_specification}{clock}{jtag_clk}{clock_configs}{cfg_func}{period}{sv_base_corner}) {
    $jtag_period = $CONFIG->{clock_timing_specification}{clock}{jtag_clk}{clock_configs}{cfg_func}{period}{sv_base_corner} ;
    print "jtag clock period : $jtag_period ns\n\n" ;
    if (defined $opt_debug) {
        print DEBUG "INFO : jtag clock period : $jtag_period ns\n\n" ;
    }
} else {
    die "jtag clock period not defined.\n" ;
}

#######################
# special Mender config
#######################

if ($type eq "noscan") {
    # Note: this error may be suppressed using set_timing_skip_unknown, but this may result in unreliable results, so it is only recommended for early trials
    set_timing_skip_unknown ;
}

# to honor the ndr nets delay when get delay from ndr
if (defined $opt_cal_slk) {
    auto_set_wide_net_model_delay_per_dist() ;
}

# to stop the bypass pipe paths
_stop_i1500_bypass_pins ;

#######################
# plot in Mender gui
#######################

# plot all path partitions
# need to load def and region files

if (defined $opt_plot) {
    plot_macros -no_labels ;
    clear_plot ;
    plot_all_partitions ;
}

#####################
# Main
#####################
#### all the out files 
print "\tdistance report    : $ENV{PWD}/$dist_rep\n" ;
print "\tslack report       : $ENV{PWD}/$slack_rep\n" if (defined $opt_cal_slk) ;
print "\tdebug file         : $ENV{PWD}/$dbg\n" if (defined $opt_debug) ;
print "\tdumped order file  : $ENV{PWD}/$dump_order_file\n" if (defined $opt_dump_order) ;

####Starting to estimate the wsi/wso/wsc slack
my %all_wsi_paths    = () ;
my %all_wsc_paths    = () ;
my %all_retime_paths = () ;


if ($opt_dump_order) {
    if (defined $opt_debug) {
        $TimeStamp = `date` ;
        print DEBUG "TimeStamp : Dumping Jtag Clock Ordering.  Start $TimeStamp\n" ;
    }

    print ORDER "Jtag clock ordering :\n\n" ;
    my @i1500_end_pins = get_pins (-hier, "*wby_reg_reg/CP") ;
    my @jtag_clk_ordering = () ;
    my @jtag_clk_uniq_ord = () ;
    my %jtag_clk_ord      = () ;
    foreach my $end_pin (@i1500_end_pins) {
        my @clk_ordering  = _get_clk_dist_ordering (-from => $jtag_clock_sources{$top}, -to => $end_pin) ;
        my $dist_ordering  = "" ;  
        my @dist_orders    = () ;
        foreach (@clk_ordering) {
            my $par = _get_pin_par (-pin => $_) ;
            push @dist_orders, $par ;
        } 
        foreach my $i (0..$#dist_orders) {
            if ($i == 0) {
                $dist_ordering = $dist_orders[0] ;
            } elsif ($dist_orders[$i] ne $dist_orders[$i-1]) {
                $dist_ordering = $dist_ordering . " => $dist_orders[$i]"; 
            } else {
                next ;
            }
        }
        push @jtag_clk_ordering, $dist_ordering ;
        print DEBUG "End Pin : $end_pin Ordering : $dist_ordering\n" if (defined $opt_debug);
        print "End Pin : $end_pin Ordering : $dist_ordering\n" if (defined $opt_debug);
    } 

    foreach my $ord (@jtag_clk_ordering) {
        my @temp = grep ($_ =~ /$ord/, @jtag_clk_ordering) ;
        if ($#temp == 0) {
            push @jtag_clk_uniq_ord, $ord ;
        }
    }

    foreach (@jtag_clk_uniq_ord) {
        print ORDER "$_\n" ;
        my $start_p = $_ ;
        my $end_p   = $_ ;
        $end_p =~ s/.* => (\S+)/$1/ ;
        if ($start_p =~ /^(\S+?) => (\S+?) .*/) {
            my $s1 = $1 ;
            my $s2 = $2 ;
            if (is_port $s1) {
                $jtag_clk_ord{$s2}{$end_p} = 1 ; 
            } else {
                $jtag_clk_ord{$s1}{$end_p} = 1 ;
            }
        }
    }

    print ORDER "\n" ;

    if (defined $opt_debug) {
        $TimeStamp = `date` ;
        print DEBUG "TimeStamp : Dumping Jtag Clock Ordering.  Done  $TimeStamp\n" ;
    }
}

    
if (defined $opt_wsi) {
    print "Dumping the WSI paths report...\n" ;

    print DIST "WSI paths distance reports : \n" ;

    if (defined $opt_debug) {
        $TimeStamp = `date` ;
        print DEBUG "TimeStamp : Finding WSI Paths.  Start $TimeStamp\n" ;
        print "TimeStamp : Finding WSI Paths.  Start $TimeStamp\n" ;
    }

    %all_wsi_paths = _get_all_wsi_paths ;

    if (defined $opt_debug) {
        $TimeStamp = `date` ;
        print DEBUG "TimeStamp : Finding WSI Paths.  Done  $TimeStamp\n" ;
        print "TimeStamp : Finding WSI Paths.  Done  $TimeStamp\n" ;
        print DEBUG "TimeStamp : Reporting WSI Paths Dist and Slack.  Start $TimeStamp\n" ;
        print "TimeStamp : Reporting WSI Paths Dist and Slack.  Start $TimeStamp\n" ;
    }

    foreach my $sp (sort keys %all_wsi_paths) {
        foreach my $ep (sort keys %{$all_wsi_paths{$sp}}) {
            if (defined $opt_debug) {
                $TimeStamp = `date` ;
                printf ("Start : %s End : %s \@ %s", $sp, $ep, $TimeStamp) ;
            }
            my $dist  = get_dist ($sp, $ep) ; 
            if ($dist > $dist_limit) {
                printf DIST ("Distance : %9.3fum\nStart : %s End : %s\n", $dist, $sp, $ep) ;
                if (defined $opt_plot) {
                    plot_path (-from => $sp, -to => $ep, -comment => "WSI : $sp => $ep") ;
                }
            }

            if (defined $opt_cal_slk) {

                if (is_port $sp or is_port $ep) {
                    next ;
                }

                my $ep_cp = _get_clk_pin (-inst => (get_cells (-of => $ep))) ;

                my $path_period = $jtag_period ;
                if (($sp =~ /\/CPN$/ and $ep_cp =~ /\/CP$/) or ($ep_cp =~ /\/CPN$/ and $sp =~ /\/CP$/)) {
                    $path_period = $jtag_period * 0.5 ;
                }

                my $laun_clk_lat = _get_delay_by_dist (-from => $jtag_clock_sources{$top}, -to => $sp, -delay_f => 3) ; 
                my $capt_clk_lat = _get_delay_by_dist (-from => $jtag_clock_sources{$top}, -to => $ep_cp, -delay_f => 3) ; 
                my $d_path_delay = _get_delay_by_dist (-from => $sp, -to => $ep, -delay_f => 1) ;
                my $path_slack   = _calc_slack (-l_cp_lat => $laun_clk_lat, -c_cp_lat => $capt_clk_lat, -cp_period => $path_period, -data_delay => $d_path_delay) ;

                if ($path_slack < $slack_limit) {
                    printf SLACK ("Slack : %9.3fns Start : %s End : %s\n", $path_slack, $sp, $ep) ;
                    print "$jtag_clock_sources{$top} $sp $ep S: $path_slack, L: $laun_clk_lat C: $capt_clk_lat D: $d_path_delay\n" ;
                }

                if (defined $opt_debug) {
                    printf ("Distance : %9.3fum L : %7.3fns C : %7.3fns D : %7.3fns P : %sns\n", $dist, $laun_clk_lat, $capt_clk_lat, $d_path_delay, $path_period) ;
                    printf ("Slack    : %9.3fns\n\n", $path_slack) ;
                    printf DEBUG ("Start : %s End : %s \@ %s", $sp, $ep, $TimeStamp) ;
                    printf DEBUG ("Distance : %9.3fum L : %7.3fns C : %7.3fns D : %7.3fns P : %sns\n", $dist, $laun_clk_lat, $capt_clk_lat, $d_path_delay, $path_period) ;
                    printf DEBUG ("Slack    : %9.3fns\n\n", $path_slack) ;
                }
            }
        }
    } 

    if (defined $opt_dump_order) {
        print ORDER "WSI paths ordering :\n\n" ; 
        my @wsi_ordering = _get_wsi_ordering (%all_wsi_paths) ;
        foreach (@wsi_ordering) {
            print ORDER "$_\n" ;
        } 
    }

    if (defined $opt_debug) {
        $TimeStamp = `date` ;
        print DEBUG "TimeStamp : Reporting WSI Paths Dist and Slack.  Done  $TimeStamp\n" ;
    }
}
if (defined $opt_wsc) {

    print "Dumping the WSC paths report...\n" ;

    print DIST "WSC paths distance reports : \n" ;

    if (defined $opt_debug) {
        $TimeStamp = `date` ;
        print DEBUG "TimeStamp : Finding WSC Paths.  Start $TimeStamp\n" ;
    }

    %all_wsc_paths = _get_all_wsc_paths ;

    if (defined $opt_debug) {
        $TimeStamp = `date` ;
        print DEBUG "TimeStamp : Finding WSC Paths.  Done  $TimeStamp\n" ;
        print DEBUG "TimeStamp : Reporting WSC Paths Dist and Slack.  Start $TimeStamp\n" ;
    }

    foreach my $sp (sort keys %all_wsc_paths) {
        foreach my $ep (sort keys %{$all_wsc_paths{$sp}}) {
            if (defined $opt_debug) {
                $TimeStamp = `date` ;
                printf ("Start : %s End : %s \@ %s", $sp, $ep, $TimeStamp) ;
            }
            my $dist  = get_dist ($sp, $ep) ;
            if ($dist > $dist_limit) {
                printf DIST ("Distance : %9.3fum\nStart : %s End : %s\n", $dist, $sp, $ep) ;
                if (defined $opt_plot) {
                    plot_thr_path (-path_pin_array => (_get_i1500_ordering (-from => $sp, -to => $ep))) ;
                }
            }

            if (defined $opt_cal_slk) {

                if (is_port $sp or is_port $ep) {
                    next ;
                }

                my $ep_cp = _get_clk_pin (-inst => (get_cells (-of => $ep))) ;

                my $path_period = $jtag_period ;
                if (($sp =~ /\/CPN$/ and $ep_cp =~ /\/CP$/) or ($ep_cp =~ /\/CPN$/ and $sp =~ /\/CP$/)) {
                    $path_period = $jtag_period * 0.5 ;
                }

                my $laun_clk_lat = _get_delay_by_dist (-from => $jtag_clock_sources{$top}, -to => $sp, -delay_f => 3) ;
                my $capt_clk_lat = _get_delay_by_dist (-from => $jtag_clock_sources{$top}, -to => $ep_cp, -delay_f => 3) ;
                my $d_path_delay = _get_delay_by_dist (-from => $sp, -to => $ep, -delay_f => 1) ;
                my $path_slack   = _calc_slack (-l_cp_lat => $laun_clk_lat, -c_cp_lat => $capt_clk_lat, -cp_period => $path_period, -data_delay => $d_path_delay) ;

                printf SLACK ("Slack : %9.3fns Start : %s End : %s\n", $path_slack, $sp, $ep) ;

                if (defined $opt_debug) {
                    printf ("Distance : %9.3fum L : %7.3fns C : %7.3fns D : %7.3fns P : %dns\n", $dist, $laun_clk_lat, $capt_clk_lat, $d_path_delay, $path_period) ;
                    printf ("Slack    : %9.3fns\n\n", $path_slack) ;
                    printf DEBUG ("Start : %s End : %s \@ %s", $sp, $ep, $TimeStamp) ;
                    printf DEBUG ("Distance : %9.3fum L : %7.3fns C : %7.3fns D : %7.3fns P : %sns\n", $dist, $laun_clk_lat, $capt_clk_lat, $d_path_delay, $path_period) ;
                    printf DEBUG ("Slack    : %9.3fns\n\n", $path_slack) ;
                }
            }
        }
    }

    if (defined $opt_dump_order) {
        print ORDER "WSC paths ordering :\n\n" ;
        my %wsc_uniq_ord = () ;
        foreach my $sp (sort keys %all_wsc_paths) {
            foreach my $ep (sort keys %{$all_wsc_paths{$sp}}) {
                my @wsc_ordering = () ;
                my $ordering     = "" ;
                my $start_par       = _get_pin_par (-pin => $sp) ;
                my $end_par         = _get_pin_par (-pin => $ep) ;
                if ($sp !~ /retime_path_/ and $ep !~ /retime_path_/ and !(is_port $sp) and !(is_port $ep)) {
                    my @i1500_wsc_order = _get_i1500_ordering (-from => $sp, -to => $ep) ;  
                    foreach (@i1500_wsc_order) {
                        my $par = _get_pin_par (-pin => $_) ;
                        push @wsc_ordering, $par; 
                    }
                    foreach my $i (0..$#wsc_ordering) {
                        if ($i == 0) {
                            $ordering = $wsc_ordering[0] ; 
                        } elsif ($wsc_ordering[$i] ne $wsc_ordering[$i-1]) {
                            $ordering = $ordering . " => $wsc_ordering[$i]" ;
                        } else {
                            next ;
                        }
                    }
                    print DEBUG "Start : $sp End : $ep Order : $ordering\n" if (defined $opt_debug);
                } else {
                    next ;
                }
                $wsc_uniq_ord{$start_par}{$end_par} = $ordering ;
            }
        }
        print DEBUG "Dumping the wsc ordering :\n" ;
        foreach my $key1 (sort keys %wsc_uniq_ord) {
            foreach my $key2 (sort keys %{$wsc_uniq_ord{$key1}}) {
                print ORDER "$wsc_uniq_ord{$key1}{$key2}\n" ;
                print DEBUG "$key1 $key2 $wsc_uniq_ord{$key1}{$key2}\n" ;
            }
        }
    }

    if (defined $opt_debug) {
        $TimeStamp = `date` ;
        print DEBUG "TimeStamp : Reporting WSC Paths Dist and Slack.  Done  $TimeStamp\n" ;
    }
    
}

if (defined $opt_retime) {
    my %wsi_paths = _get_all_wsi_paths ;
}

close DIST ;

if (defined $opt_cal_slk) {
    close SLACK ;
}
if (defined $opt_dump_order) {
    close ORDER ;
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

    my %all_mods = map  ({$_ => 1} (get_modules ("*"))) ;
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
                # hack for ga100
                if ($part !~ /GAAL0LNK/) {
                    load_once "${ipo_dir}/${part}/control/${part}_ICC.tcl" ;
                }
            }
     # partition pins
            if (-e "${ipo_dir}/${part}/control/${part}.hfp.pins.def") {
                load_once (-add => "${ipo_dir}/${part}/control/${part}.hfp.pins.def") ;
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
    my $top_level_inst ;
    foreach my $chiplet (keys $CONFIG->{partitioning}{chiplets}) {
        if (exists $CONFIG->{partitioning}{chiplets}{$chiplet}{is_toplevel}) {
            my $top_level_inst = $chiplet ;
        }
        if ($top eq $top_level_inst) {
            if  (-e "${ipo_dir}/${top_level_inst}/control/${top_level_inst}_fp.def") {
                load_once "${ipo_dir}/${top_level_inst}/control/${top_level_inst}_fp.def" ;
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
    set_xy_default -centroid ;

    print "All the def/region files loaded.\n" ;

    return 1 ;

END

Tsub plot_all_partitions => << 'END' ;
    DESC {
        Plot all the partitions in the current design.
    }
    ARGS {
    }
    
    my %allModules = map  ({$_ => 1} (get_modules ("*"))) ;
    my @partRefs    = grep (exists $allModules{$_}, (all_partitions)) ;
    foreach my $partRef (@partRefs) {
        my @partInsts = get_cells_of $partRef ;
        plot (-no_label => @partInsts) ;
    }

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
        print "ERROR: $pin_name had multi-cp\n";
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

    my $par_name = "";
    if (is_port $pin) {
        $par_name = $pin ;
        return $par_name ;
    } else {
        my @all_refs  = get_hier_list_txt ( "-ref", -of_pin => $pin);
        my @all_insts = get_hier_list_txt ( "-inst", -of_pin => $pin);
        while (my ($index, $value) = each @all_refs) {
            if (attr_of_ref("is_partition",$value)) {
                $par_name = $par_name."$all_insts[$index]";
                return $par_name ;
            } else {
                $par_name = $par_name."$all_insts[$index]/" ;
            }
        }
    }

    return 1 ;

END

Tsub _get_delay_by_dist => << 'END' ;
    DESC {
        get the delay value by distance from start_pin to end_pin
    }
    ARGS {
        -from: $start_pin      # specified the start pin name
        -to: $end_pin          # specified the end pin name 
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

    my $rtn_slack = 0 ;
    $rtn_slack = $clk_period + $capt_clk_lat - $laun_clk_lat -$dp_delay ;

    return $rtn_slack ;

END

Tsub _stop_i1500_bypass_pins => << 'END' ;
    DESC {
        stop the timing arc of i1500 bypass anchor buffers, to aviod bogus paths.
    }
    ARGS {
    }

    print "Stopping the bypass pipe buffers if needed.\n" ;
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

    my $top = get_top ;
    chomp $top ;
    if ($top =~ /nv.*_top/) {
        my @DPD_pins = get_pins (-quiet, -hier, "*/DPD") ;
        foreach my $pin (@DPD_pins) {
            if (x_case_of_pin (pin_of_name ($pin)) eq "D") {
                next ;
            } else {
                set_disable_timing $pin ;
            }
        }
    }

    return 1 ;

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

    return 1 ;

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

    return 1 ;

END

Tsub plot_hash_path => << 'END' ;
    DESC {
        plot the flylines from the hash
    }

    my %input_hash = @_ ;

    foreach my $sp (sort keys %input_hash) {
        foreach my $ep (sort keys %{$input_hash{$sp}}) {
            plot_path (-from => $sp, -to => $ep, -comment => "$sp => $ep", -color => 'red') ;
        }
    }
    
    return 1 ;

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
    my $top              = get_top ;
    chomp $top ;

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
            if ((is_port $end_pin and $top !~ /nv.*_top/) or ((is_port $i1500_start_pin and $top !~ /nv.*_top/) and $end_pin =~ /\/D$/)) {
                $all_wsi_paths{$i1500_start_pin}{$end_pin} = 1 ;
            } elsif ($end_pin =~ /\/wby_reg_reg\D|_1500_pipeline\/wso_pipe_out_to_cluster_reg\/D|\/wso_pipe_out_reg\/D|\/UJ_pos_pipe_reg\/D|\/wso_pos_reg\/D|\/wsi_pipe_out_to_client_reg\/D/) {
                if (($end_pin =~ /^$i1500_start_par.*\/i1500_data_pipe_|^$i1500_start_par.*\/wso_pipe_out_reg\/D|^$i1500_start_par.*\/wso_pos_reg\/D|^$i1500_start_par.*_1500_pipeline\/wso_pipe_out_to_cluster_reg\/D/) || ($end_pin !~ /^$i1500_start_par/)) {
                    my $start_inst = get_cell (-of => $i1500_start_pin) ; 
                    my $end_inst   = get_cell (-of => $end_pin) ;
                    if ($start_inst ne $end_inst) {
                        $all_wsi_paths{$i1500_start_pin}{$end_pin} = 1;
                    } else {
                        next ;
                    }
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

Tsub _get_wsi_ordering => << 'END' ;
    DESC {
        get the ordering from wsi paths hash
    }

    my %wsi_hash = @_ ;    
    my %out_hash = () ;
    my $stime    = `date` ;

    # to get the entry partitions, there might be virtual clusters in one chiplet
    my @entry_pins = get_pins (-hier, "*_1500_pipeline/wso_pipe_out_to_cluster_reg/D") ;
    my @entry_pars = () ;
    foreach (@entry_pins) {
        my $entry_par = _get_pin_par (-pin => $_) ;
        push @entry_pars, $entry_par ;
    }
    my @orders = () ;
    my $top    = get_top ; 
    chomp $top ;
    
    if ($top eq 'nv_top') {
        $wsi_ordering = $CONFIG->{partitioning}{chiplets}{nv_top}{ieee1500_ordered_insts} ;
        $wsi_ordering =~ s/,/=>/g ;
        push @orders, $wsi_ordering ;
    } else {
        foreach my $sp (sort keys %wsi_hash) {
            if ($sp =~ /\/retime_path_/) {
                next ;
            } elsif (is_port $sp) {
                next ;
            } else {
                my $start_p = "" ;
                if ($sp =~ /i1500_data_pipe/) {
                    my $spar = _get_pin_par (-pin => $sp) ;
                    $start_p = $sp ;
                    $start_p =~ s/.*\/(i1500_data_pipe_\S+?)\/.*/$1/ ;
                    $start_p = "$spar/$start_p" ;
                } else {
                    $start_p = _get_pin_par (-pin => $sp) ;
                }
                foreach my $ep (sort keys %{$wsi_hash{$sp}}) {
                    if ($ep =~ /i1500_data_pipe/) {
                        my $epar = _get_pin_par (-pin => $ep) ;
                        $end_p = $ep ;
                        $end_p =~ s/.*\/(i1500_data_pipe_\S+?)\/.*/$1/ ; 
                        $end_p = "$epar/$end_p" ;
                    } elsif ((is_port $ep) || ($ep =~ /\/retime_path_/)) {
                        next ;
                    } else {
                        $end_p = _get_pin_par (-pin => $ep) ;
                    }
                    if ($start_p ne $end_p) {
                        $out_hash{$start_p}{$end_p} = 1 ;
                    } else {
                        next ;
                    } 
                }
            }
        }
        foreach my $i (0..$#entry_pars) {
            my $entry_p = $entry_pars[$i] ;
            $i = $i + 1 ;
            push @orders, "Ordering for Cluster $i :" ;
            my $start_par = $entry_p ;
            $wsi_ordering = $entry_p ;
            while (1) {
                foreach my $key (sort keys %{$out_hash{$start_par}}) {
                    if ($key ne $start_par) {
                        $wsi_ordering = $wsi_ordering . " => $key" ;
                        $start_par = $key ; 
                    } else {
                        last ;
                    }
                }
                if ($start_par eq $entry_p) {
                    last ;
                }
            }
            push @orders, "$wsi_ordering\n" ; 
        }
    }

    return @orders ;    

END
