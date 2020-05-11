use CadConfig ;
use ChipVars ;
use Parallel::Loops ; 

# global varables for retiming attributions

our %M_noscan_port_mapping ;
our %M_routeRules ;
our %M_routeRules_pipe ;
our %chiplet_uc ;

####define the abut check threshold value, less than 10 treat as not abut partition ######
#set_abutment_dist 10; ## PR gurad band is 10, user could modify it; 
Tsub generate_report => << 'END';
        DESC {
                generate retime detour report, -histogram_min is the min cutoff for distance summary. 
                Example:
                    MENDER > generate_report NV_gaa_g1.2018Dec18_23_48_fullSM.rep.flat -ultra 1 -skip_clock "jtag*"
                    MENDER > generate_report NV_gaa_g1.2018Dec18_23_48_fullSM.rep.flat -histogram_min 700 -histogram_max 2000 -retime_distance 700 -ultra 1 
                    MENDER > generate_report nv_top.2019Jul30_20.rep.flat -inter_path_only 1
        }
        ARGS {
                -histogram_min:$histogram_min           ## min cutoff for distance historgram, use 700 as default
                -histogram_max:$histogram_max           ## max cutoff for distance historgram, use 2000 as default
                -histogram_step:$histogram_step         ## min cutoff for distance historgram, use 100 as scale step
                -retime_distance:$retime_distance       ## per retime stage distance, use 1200 as default for tsmc16ff process, use 900 as default for 7nm process
                -skip_clock:@skip_clock                 ## skip these clock when dump report, wildchard surported
                -only_clock:@only_clock                 ## only care these clocks when dump report,  wildchard surported
                -use_multi_thread_num:$multi_thread_num ## use multi-thread, default 4 thread 
                -inter_chiplet_only:$opt_inter_only     ## analysis inter-chiplet paths only for nv_top
                -ultra:$opt_ultra                       ## by default ultra mode is off , when -ultra 1, flow enables calculate MCP and mapping hier-unit
                -no_clr                                 ## no need to reload the violation files. not default. 
                @files 
        }
    ## initial vio attribute for mann_distance and detour_ratio
    define_vio_attr (-class => "path", -is_num => 1, -attr => 'man_distance') ;
    define_vio_attr (-class => "path", -is_num => 1, -attr => 'detour_ratio') ;
    define_vio_attr (-class => "path", -is_num => 1, -attr => 'feed_pars') ;
    define_vio_attr (-class => "path", -is_num => 1, -attr => 'feed_pars_num') ;
    define_vio_attr (-class => "path", -is_num => 1, -attr => 'longest_par_net') ;
    define_vio_attr (-class => "path", -is_num => 1, -attr => 'longest_par_net_length') ;
    define_vio_attr (-class => "path", -is_num => 1, -attr => 'start_unit') ;
    define_vio_attr (-class => "path", -is_num => 1, -attr => 'end_unit') ;
    define_vio_attr (-class => "path", -is_num => 1, -attr => 'par_num') ;
    define_vio_attr (-class => "path", -is_num => 1, -attr => 'module_split_by_par') ;
    define_vio_attr (-class => "path", -is_num => 1, -attr => 'real_distance') ;
    define_vio_attr (-class => "path", -is_num => 1, -attr => 'ideal_distance') ;
    define_vio_attr (-class => "path", -is_num => 1, -attr => 'is_mcp') ;
    define_vio_attr (-class => "path", -is_num => 1, -attr => 'mcp_setup_num') ;
    define_vio_attr (-class => "path", -is_num => 1, -attr => 'bin_man_distance') ;
    define_vio_attr (-class => "path", -is_num => 1, -attr => 'bin_ideal_distance') ;
    define_vio_attr (-class => "path", -is_num => 1, -attr => 'bin_real_distance') ;


    my @abc = @files;
    $rep_name = shift(@abc); 
    my $top = get_top;
    my $hist_min = $histogram_min;
    set_chip_top $top;
    $stype = session_type;
    lprint "# This is $stype session. \n\n";

    print "Loading Retime Related files : \n\n" ; 
    load_port_map_file () ;
    load_routeRules_files () ;
    print "\nDone.\n\n" ;

    $main::opt_ultra = 0;
    if ( defined $opt_ultra) {
        $main::opt_ultra = $opt_ultra;
    }

    my $inter_path_only = 0;
    if ( defined $opt_inter_only) {
        lprint "# Analysis inter-chiplet paths Only \n";
        $inter_path_only = 1;
    }

    %main::share_variables = ();
    ### Define per retime stage distance
    if ($stype eq 'ipo' || $stype eq 'flat') {
        $main::share_variables{"RETIME_DISTANCE"} = 1200 ;
    } else {
        $main::share_variables{"RETIME_DISTANCE"} = 1000 ;
    }
    if ( defined $retime_distance) {
        $main::share_variables{"RETIME_DISTANCE"} = $retime_distance;
    } 

    ### Histogram Constants
    $main::share_variables{"DIST_HISTOGRAM_MIN"} = 700;
    if ( defined $histogram_min) { 
        $main::share_variables{"DIST_HISTOGRAM_MIN"} = $hist_min;
    }
    
    $main::share_variables{"DIST_HISTOGRAM_MAX"} = 2000;
    if ( defined $histogram_max) {
        $main::share_variables{"DIST_HISTOGRAM_MAX"} = $histogram_max;
    }

    $main::share_variables{"DIST_HISTOGRAM_SCALE"} = 100; 
    if ( defined $histogram_step) {
        $main::share_variables{"DIST_HISTOGRAM_SCALE"} = $histogram_step;
    } 

    if (!defined $opt_no_clr) {
        clear_vios;
        load_vios $rep_name;
    }

    my @vios = ();
    if (($top eq "nv_top") || ($top eq "nvs_top") && ($inter_path_only == 1)) {
        @vios = all_path_vios(-filter => "is_inter_chiplet");
    } else {
        @vios = all_path_vios;
    }

    @main::selected_vios  = ();

    if (scalar (@skip_clock) && !scalar(@only_clock)) {
        print "INFO: User defined skip clocks @skip_clock\n\n";
        my $clk_regexp       = "" ; 
        foreach my $regexp (map (glob2regex_txt ($_), @skip_clock)) {
            $clk_regexp = "$regexp|$clk_regexp" ;
        }
        $clk_regexp =~ s/\|$// ;
        @main::selected_vios = all_vios (-filter => "end_clk !~ /$clk_regexp/") ;
    } elsif (scalar (@only_clock) && !scalar (@skip_clock)){
        print "INFO: User defined only clocks @only_clock\n\n";
        my $clk_regexp       = "" ;
        foreach my $regexp (map (glob2regex_txt ($_), @only_clock)) {
            $clk_regexp = "$regexp&$clk_regexp" ;
        }
        $clk_regexp =~ s/\&$// ;
        @main::selected_vios = all_vios (-filter => "end_clk =~ /$clk_regexp/") ;
    } elsif (scalar (@only_clock) && scalar (@skip_clock)) {
        error "DO not define skip_clock and only_clock at the same time which has conflict!\n\n";
        @main::selected_vios = ();
    } else {
        @main::selected_vios = @vios;
    }

    $timing_corner = get_timing_corner;
    $timing_corner =~ s/v/v_max_si/g;
    $main::mender_delay_per_dist_corner = 0;
    $main::mender_delay_per_dist_corner = get_yaml_corner_attr ($timing_corner, mender_delay_per_dist);
    print "\n# using $mender_delay_per_dist_corner ns per 1000um for $timing_corner delay estimate \n\n";

    #use multi-thread
    my $curr_vio_count = scalar(@main::selected_vios);
    my $thread_count = 4;
    if (defined $multi_thread_num) {
        $thread_count = $multi_thread_num;
    }
    my $count_per_thread = floor( $curr_vio_count / $thread_count );
    my $remainders = $curr_vio_count % $thread_count;
    my @vio_cnt_range;
    foreach my $thread (0..($thread_count - 1)) { 
        if ($thread < $remainders) {
            push (@vio_cnt_range , "1:".($count_per_thread + 1).":$thread:$thread_count") ;
        } else {
            push (@vio_cnt_range , "1:$count_per_thread:$thread:$thread_count") ;
        }
    }

    my $start_date = `date`;
    chomp $start_date;

    print ("    Use multi-thread $thread_count \n\n");
    print ("    $start_date\n\n");

    %main::unit_hier_mapping        = genUnitNameHash ;
    %main::p_feed_pars              = () ;
    %main::p_feed_pars_num          = () ;
    %main::p_start_unit             = () ;
    %main::p_end_unit               = () ;
    %main::p_par_num                = () ;
    %main::p_module_split_by_par    = () ;
    %main::p_longest_par_net        = () ;
    %main::p_longest_par_net_length = () ;
    %main::p_man_dist               = () ;
    %main::p_real_dist              = () ;
    %main::p_ideal_dist             = () ;
    %main::p_mcp_setup_num          = () ;
    %main::p_detour_ratio           = () ;
    %main::p_bin_man_dist           = () ;
    %main::p_bin_ideal_dist         = () ;
    %main::p_bin_real_dist          = () ;
    %main::p_is_mcp                 = () ;
    %main::p_sig_name               = () ;
    %main::p_start_routeRule        = () ;
    %main::p_end_routeRule          = () ;
    %main::p_source_coor            = () ;
    %main::p_dest_coor              = () ;
    %main::p_source_port_dist       = () ;
    %main::p_dest_port_dist         = () ;

    # info for dumping reps
    %main::p_dist_rep               = () ;
    %main::p_io_dist_rep            = () ;
    %main::p_mann_plot_rep          = () ;
    %main::p_detour_plot_rep       = () ;
    %main::p_retime_rep             = () ;
    %main::p_mcp_rep                = () ;
    %main::p_rd_sum_rep             = () ;

    %main::p_AdjParNRT2NRT_mcp      = () ;
    %main::p_AdjParNRT2NRT_nonmcp   = () ;
    %main::p_AdjParRT2NRT_mcp       = () ;
    %main::p_AdjParRT2NRT_nonmcp    = () ;
    %main::p_AdjParNRT2RT_mcp       = () ;
    %main::p_AdjParNRT2RT_nonmcp    = () ;
    %main::p_AdjParRT2RT_mcp        = () ;
    %main::p_AdjParRT2RT_nonmcp     = () ;

    %main::p_max_feed_pars_num      = () ;
    %main::p_max_feed_pars          = () ;
    %main::p_max_man_dist           = () ;
    %main::p_max_ideal_dist         = () ;
    %main::p_max_real_dist          = () ;
    %main::p_max_source_port_dist   = () ;
    %main::p_max_dest_port_dist     = () ;
    %main::p_max_end_clk            = () ;
    %main::p_sig_is_mcp             = () ;
    %main::p_sig_s_routeRule        = () ;
    %main::p_sig_e_routeRule        = () ;

    %main::p_max_nonrt_mcp_feed_pars_num    = () ;
    %main::p_max_nonrt_mcp_feed_pars        = () ;
    %main::p_max_nonrt_mcp_man_dist         = () ;
    %main::p_max_nonrt_mcp_ideal_dist       = () ;
    %main::p_max_nonrt_mcp_real_dist        = () ;
    %main::p_max_nonrt_mcp_source_port_dist = () ;
    %main::p_max_nonrt_mcp_dest_port_dist   = () ;
    %main::p_max_nonrt_mcp_end_clk          = () ;
    %main::p_nonrt_mcp_sig_is_mcp           = () ;

    %main::p_max_nonrt_nonmcp_feed_pars_num    = () ;
    %main::p_max_nonrt_nonmcp_feed_pars        = () ;
    %main::p_max_nonrt_nonmcp_man_dist         = () ;
    %main::p_max_nonrt_nonmcp_ideal_dist       = () ;
    %main::p_max_nonrt_nonmcp_real_dist        = () ;
    %main::p_max_nonrt_nonmcp_source_port_dist = () ;
    %main::p_max_nonrt_nonmcp_dest_port_dist   = () ;
    %main::p_max_nonrt_nonmcp_end_clk          = () ;
    %main::p_nonrt_nonmcp_sig_is_mcp           = () ;

    %main::p_max_rt_mcp_feed_pars_num    = () ;
    %main::p_max_rt_mcp_feed_pars        = () ;
    %main::p_max_rt_mcp_man_dist         = () ;
    %main::p_max_rt_mcp_ideal_dist       = () ;
    %main::p_max_rt_mcp_real_dist        = () ;
    %main::p_max_rt_mcp_source_port_dist = () ;
    %main::p_max_rt_mcp_dest_port_dist   = () ;
    %main::p_max_rt_mcp_end_clk          = () ;
    %main::p_max_rt_mcp_s_routeRule      = () ;
    %main::p_max_rt_mcp_e_routeRule      = () ;
    %main::p_rt_mcp_sig_is_mcp           = () ;

    %main::p_max_rt_nonmcp_feed_pars_num    = () ;
    %main::p_max_rt_nonmcp_feed_pars        = () ;
    %main::p_max_rt_nonmcp_man_dist         = () ;
    %main::p_max_rt_nonmcp_ideal_dist       = () ;
    %main::p_max_rt_nonmcp_real_dist        = () ;
    %main::p_max_rt_nonmcp_source_port_dist = () ;
    %main::p_max_rt_nonmcp_dest_port_dist   = () ;
    %main::p_max_rt_nonmcp_end_clk          = () ;
    %main::p_max_rt_nonmcp_s_routeRule      = () ;
    %main::p_max_rt_nonmcp_e_routeRule      = () ;
    %main::p_rt_nonmcp_sig_is_mcp           = () ;


    %main::p_FeedParNRT2NRT_mcp     = () ;
    %main::p_FeedParNRT2NRT_nonmcp  = () ;
    %main::p_FeedParRT_mcp          = () ;
    %main::p_FeedParRT_nonmcp       = () ;

    %main::p_dist_histogram_mann    = () ;
    %main::p_dist_histogram_ideal   = () ;
    %main::p_dist_histogram_real    = () ;
    %main::p_detour_histogram       = () ;

    %main::p_comb_detour_start_routeRule  = () ;
    %main::p_comb_detour_end_routeRule    = () ;
    %main::p_comb_detour_feed_pars_num    = () ;
    %main::p_comb_detour_feed_pars        = () ;
    %main::p_comb_detour_man_dist         = () ;
    %main::p_comb_detour_ideal_dist       = () ;
    %main::p_comb_detour_real_dist        = () ;
    %main::p_comb_detour_source_port_dist = () ;
    %main::p_comb_detour_dest_port_dist   = () ;
    %main::p_comb_detour_end_clk          = () ;
    %main::p_comb_detour_is_mcp           = () ;

    @main::all_partitions           = () ;
    if ($top ne "nv_top") {
        (my $useless_var,@main::all_partitions) = expand_chiplet_in_partitions("",());
    } else {
         my $useless_var = "";
         @main::all_partitions = ();
    }
    
    alarm (0); #Avoid heartbeat interference with fork manager
    my $pl = Parallel::Loops->new($thread_count);
    
    # share varibles/array/hash in multi-threads
    $pl->share(\%main::unit_hier_mapping);
    $pl->share(\%main::p_feed_pars);
    $pl->share(\%main::p_feed_pars_num);
    $pl->share(\%main::p_start_unit);
    $pl->share(\%main::p_end_unit);
    $pl->share(\%main::p_par_num);
    $pl->share(\%main::p_module_split_by_par);
    $pl->share(\%main::p_man_dist);
    $pl->share(\%main::p_real_dist);
    $pl->share(\%main::p_ideal_dist);
    $pl->share(\%main::p_detour_ratio);
    $pl->share(\%main::p_mcp_setup_num);
    $pl->share(\%main::p_bin_man_distance);
    $pl->share(\%main::p_bin_ideal_distance);
    $pl->share(\%main::p_bin_real_distance);
    $pl->share(\%main::p_longest_par_net);
    $pl->share(\%main::p_longest_par_net_length);
    $pl->share(\@main::selected_vios);
    $pl->share(\%main::share_variables);
    $pl->share(\%main::p_is_mcp);
    $pl->share(\%main::p_sig_name) ;
    $pl->share(\%main::p_start_routeRule) ;
    $pl->share(\%main::p_end_routeRule) ;
    $pl->share(\%main::p_source_coor) ;
    $pl->share(\%main::p_dest_coor) ;
    $pl->share(\%main::p_source_port_dist) ;
    $pl->share(\%main::p_dest_port_dist) ;
    $pl->share(\%main::p_dist_rep) ;
    $pl->share(\%main::p_io_dist_rep) ;
    $pl->share(\%main::p_dist_rep) ;
    $pl->share(\%main::p_io_dist_rep) ;
    $pl->share(\%main::p_mann_plot_rep) ;
    $pl->share(\%main::p_detour_plot_rep) ;
    $pl->share(\%main::p_retime_rep) ;
    $pl->share(\%main::p_mcp_rep) ;
    $pl->share(\%main::p_rd_sum_rep) ;

    $pl->share(\%main::p_AdjParNRT2NRT_mcp) ;
    $pl->share(\%main::p_AdjParNRT2NRT_nonmcp) ;
    $pl->share(\%main::p_AdjParRT2NRT_mcp) ;
    $pl->share(\%main::p_AdjParRT2NRT_nonmcp) ;
    $pl->share(\%main::p_AdjParNRT2RT_mcp) ;
    $pl->share(\%main::p_AdjParNRT2RT_nonmcp) ;
    $pl->share(\%main::p_AdjParRT2RT_mcp) ;
    $pl->share(\%main::p_AdjParRT2RT_nonmcp) ;

    $pl->share(\%main::p_max_feed_pars_num) ;
    $pl->share(\%main::p_max_feed_pars) ;
    $pl->share(\%main::p_max_feed_pars) ;
    $pl->share(\%main::p_max_man_dist) ;
    $pl->share(\%main::p_max_ideal_dist) ;
    $pl->share(\%main::p_max_real_dist) ;
    $pl->share(\%main::p_max_source_port_dist) ;
    $pl->share(\%main::p_max_dest_port_dist) ;
    $pl->share(\%main::p_max_end_clk) ;
    $pl->share(\%main::p_sig_is_mcp) ;
    $pl->share(\%main::p_sig_s_routeRule) ;
    $pl->share(\%main::p_sig_e_routeRule) ;
    $pl->share(\%main::p_FeedParNRT2NRT_mcp) ;
    $pl->share(\%main::p_FeedParNRT2NRT_nonmcp) ;
    $pl->share(\%main::p_FeedParRT_mcp) ;
    $pl->share(\%main::p_FeedParRT_nonmcp) ;

    $pl->share(\%main::p_max_nonrt_mcp_feed_pars_num) ;
    $pl->share(\%main::p_max_nonrt_mcp_feed_pars) ;
    $pl->share(\%main::p_max_nonrt_mcp_man_dist) ;
    $pl->share(\%main::p_max_nonrt_mcp_ideal_dist) ;
    $pl->share(\%main::p_max_nonrt_mcp_real_dist) ;
    $pl->share(\%main::p_max_nonrt_mcp_source_port_dist) ;
    $pl->share(\%main::p_max_nonrt_mcp_dest_port_dist) ;
    $pl->share(\%main::p_max_nonrt_mcp_end_clk) ;
    $pl->share(\%main::p_nonrt_mcp_sig_is_mcp) ;

    $pl->share(\%main::p_max_nonrt_nonmcp_feed_pars_num) ;
    $pl->share(\%main::p_max_nonrt_nonmcp_feed_pars) ;
    $pl->share(\%main::p_max_nonrt_nonmcp_man_dist) ;
    $pl->share(\%main::p_max_nonrt_nonmcp_ideal_dist) ;
    $pl->share(\%main::p_max_nonrt_nonmcp_real_dist) ;
    $pl->share(\%main::p_max_nonrt_nonmcp_source_port_dist) ;
    $pl->share(\%main::p_max_nonrt_nonmcp_dest_port_dist) ;
    $pl->share(\%main::p_max_nonrt_nonmcp_end_clk) ;
    $pl->share(\%main::p_nonrt_nonmcp_sig_is_mcp) ;

    $pl->share(\%main::p_max_rt_mcp_feed_pars_num) ;
    $pl->share(\%main::p_max_rt_mcp_feed_pars) ;
    $pl->share(\%main::p_max_rt_mcp_man_dist) ;
    $pl->share(\%main::p_max_rt_mcp_ideal_dist) ;
    $pl->share(\%main::p_max_rt_mcp_real_dist) ;
    $pl->share(\%main::p_max_rt_mcp_source_port_dist) ;
    $pl->share(\%main::p_max_rt_mcp_dest_port_dist) ;
    $pl->share(\%main::p_max_rt_mcp_end_clk) ;
    $pl->share(\%main::p_max_rt_mcp_s_routeRule) ;
    $pl->share(\%main::p_max_rt_mcp_e_routeRule) ;
    $pl->share(\%main::p_rt_mcp_sig_is_mcp) ;

    $pl->share(\%main::p_max_rt_nonmcp_feed_pars_num) ;
    $pl->share(\%main::p_max_rt_nonmcp_feed_pars) ;
    $pl->share(\%main::p_max_rt_nonmcp_man_dist) ;
    $pl->share(\%main::p_max_rt_nonmcp_ideal_dist) ;
    $pl->share(\%main::p_max_rt_nonmcp_real_dist) ;
    $pl->share(\%main::p_max_rt_nonmcp_source_port_dist) ;
    $pl->share(\%main::p_max_rt_nonmcp_dest_port_dist) ;
    $pl->share(\%main::p_max_rt_nonmcp_end_clk) ;
    $pl->share(\%main::p_max_rt_nonmcp_s_routeRule) ;
    $pl->share(\%main::p_max_rt_nonmcp_e_routeRule) ;
    $pl->share(\%main::p_rt_nonmcp_sig_is_mcp) ;

    $pl->share(\%main::p_dist_histogram_mann) ;
    $pl->share(\%main::p_dist_histogram_ideal) ;
    $pl->share(\%main::p_dist_histogram_real) ;
    $pl->share(\%main::p_detour_histogram) ;

    $pl->share(\%main::p_comb_detour_start_routeRule) ;
    $pl->share(\%main::p_comb_detour_end_routeRule) ;
    $pl->share(\%main::p_comb_detour_feed_pars_num) ;
    $pl->share(\%main::p_comb_detour_feed_pars) ;
    $pl->share(\%main::p_comb_detour_man_dist) ;
    $pl->share(\%main::p_comb_detour_ideal_dist) ;
    $pl->share(\%main::p_comb_detour_real_dist) ;
    $pl->share(\%main::p_comb_detour_source_port_dist) ;
    $pl->share(\%main::p_comb_detour_dest_port_dist) ;
    $pl->share(\%main::p_comb_detour_end_clk) ;
    $pl->share(\%main::p_comb_detour_is_mcp) ;


    my $s_type = session_type;

    ## Initialize Histogram
    my $loopCnt;
    for ($loopCnt = $main::share_variables{DIST_HISTOGRAM_MIN} ; $loopCnt < $main::share_variables{DIST_HISTOGRAM_MAX} ; $loopCnt += $main::share_variables{DIST_HISTOGRAM_SCALE}) {
        $main::p_dist_histogram_mann{$loopCnt}  = 0 ;
        $main::p_dist_histogram_ideal{$loopCnt} = 0 ;
        $main::p_dist_histogram_real{$loopCnt}  = 0 ;
    }
    $main::p_dist_histogram_mann{$main::share_variables{DIST_HISTOGRAM_MAX}}  = 0 ; 
    $main::p_dist_histogram_ideal{$main::share_variables{DIST_HISTOGRAM_MAX}} = 0 ; 
    $main::p_dist_histogram_real{$main::share_variables{DIST_HISTOGRAM_MAX}}  = 0 ; 

    for ($loopCnt = 1.0 ; $loopCnt <= 2.0 ; $loopCnt += 0.1) {
        $main::p_detour_histogram{$loopCnt} = 0 ;
    }
    $main::p_detour_histogram{2.0} = 0 ;



    # Kickoff multi-thread runs
    $pl->foreach(\@vio_cnt_range, \&cal_vio_attribute_by_index);
 
    my $mid_date = `date`;
    chomp $mid_date;
   
    my $end_date = `date`;
    chomp $end_date;
    print ("    Start Cal Attribute $start_date\n");
    print ("    Start Tag Attribute $mid_date\n");
    print ("    End   Tag Attribute $end_date\n");

    dump_reports($top,$rep_name);

    undef $main::opt_ultra;
    #undef @main::selected_vios;
    #undef %main::p_longest_par_net;
    #undef %main::p_longest_par_net_length;
    #undef @main::all_partitions;
    #undef %main::unit_hier_mapping;
    #undef %main::p_feed_pars;
    #undef %main::p_feed_pars_num;
    #undef %main::p_start_unit;
    #undef %main::p_end_unit;
    #undef %main::p_par_num;
    #undef %main::p_module_split_by_par;
    #undef %main::p_man_dist;
    #undef %main::p_real_dist;
    #undef %main::p_ideal_dist;
    #undef %main::p_detour_ratio;
    #undef %main::p_mcp_setup_num;
    #undef %main::p_detour_ratio;
    #undef %main::p_bin_man_dist;
    #undef %main::p_bin_ideal_dist;
    #undef %main::p_bin_real_dist;
    #undef %main::p_sig_name ;
    #undef %main::p_start_routeRule ;
    #undef %main::p_end_routeRule ;
    #undef %main::p_source_coor ;
    #undef %main::p_dest_coor ;
    #undef %main::p_source_port_dist ;
    #undef %main::p_dest_port_dist ;
    #undef $main::mender_delay_per_dist_corner;
    #undef @main::selected_vios;
    #undef %main::share_variables;

END

sub cal_vio_attribute_by_index {
    my ($index) = $_;
    my ($star_index,$end_index,$curr_thread,$thread_count) = split (/:/, $index);
    my $max_id = scalar(@main::selected_vios);
    #print ("\n");
    foreach my $id ($star_index..$end_index) {
        my $real_index = ($id - 1)*$thread_count + $curr_thread;
        my $status_msg ;
        if ($id > 10000) {
            $status_msg = ($id) % 10000 ;
        } else {
            $status_msg = ($id) % 1000 ;
        }
        if ($status_msg == 0) {
            print("    Processed  $id of $end_index in Thread $curr_thread  \n");
        }
        if ($id == $end_index) {
            print("    Processed  $id of $end_index in Thread $curr_thread  \n");
        }
        &cal_vio_attribute($main::selected_vios[$real_index]);
    }
}

sub cal_vio_attribute {
    my ($curr_vio) = @_;
    my $id         = attr_of_path_vio(id,$curr_vio);
    my $top        = get_top;
    my $startpoint = attr_of_path_vio(start_pin, $curr_vio);
    $startpoint    =~ s/checkpin.*//g; # this line is in order to replace the checkin(internal pin for analog cell such as PLL) due to mender can't see it 
    my $endpoint   = attr_of_path_vio(end_pin, $curr_vio);
    #if ($main::opt_ultra == 1) {
    #    $main::p_start_unit{$id} = mapPinUnit($startpoint,%main::unit_hier_mapping);
    #    $main::p_end_unit{$id}   = mapPinUnit($endpoint,%main::unit_hier_mapping);
    #}
    $main::p_start_unit{$id} = attr_of_vio (start_unit => $curr_vio) ;
    $main::p_end_unit{$id}   = attr_of_vio (end_unit => $curr_vio) ;

    my @feed_pars           = ();    
    my $capt_clk            = attr_of_path_vio(end_clk, $curr_vio);
    my $period              = attr_of_vio (period, $curr_vio);
    my $capture_time        = attr_of_vio (end_clk_edge_dly, $curr_vio);
    my $endpar              = attr_of_path_vio(end_par, $curr_vio);
    my $startpar            = attr_of_path_vio(start_par, $curr_vio);
    my $is_io               = attr_of_path_vio(is_io, $curr_vio);
    my @module_split_by_par = attr_of_path_vio(module_split_by_par,$curr_vio);
    my $module_split_by_par = join('->',@module_split_by_par);
    my $num                 = scalar @module_split_by_par;
    $main::p_par_num{$id}   = $num;
    $main::p_module_split_by_par{$id} = $module_split_by_par;

    # global variable $top and $stype
    if ( ($top ne "nv_top") && ($top ne "nvs_top") && ($stype eq "noscan" | $stype eq "feflat")) {
        my $longest_par_net = attr_of_path_vio(par_net_in_longest,$curr_vio);
        if((defined $longest_par_net)) {
            my $longest_par_net_length = attr_of_net(length_ideal => $longest_par_net);
            @feed_pars = get_vio_feeds($curr_vio,@main::all_partitions);
            $feed_pars_num = scalar @feed_pars;
            $feed_pars = join('->',@feed_pars);
            $main::p_feed_pars{$id} = $feed_pars;
            $main::p_feed_pars_num{$id} = $feed_pars_num;
            $main::p_longest_par_net{$id} = $longest_par_net;
            $main::p_longest_par_net_length{$id} = $longest_par_net_length;
        } else {
            $main::p_feed_pars{$id} = $module_split_by_par;
            $main::p_feed_pars_num{$id} = $num;
            $main::p_longest_par_net{$id} = "NA";
            $main::p_longest_par_net_length{$id} = 0;
        }
    } else {
        $main::p_feed_pars{$id} = $module_split_by_par;
        $main::p_feed_pars_num{$id} = $num;
        my $longest_par_net = attr_of_path_vio(par_net_in_longest,$curr_vio);
        # dont need this attribute on IPO package
        if((defined $longest_par_net) && ($stype eq "noscan" | $stype eq "feflat" | $stype eq "flat")) {
            my $longest_par_net_length = attr_of_net(length_ideal => $longest_par_net);
            $main::p_longest_par_net{$id} = $longest_par_net;
            $main::p_longest_par_net_length{$id} = $longest_par_net_length;
        } else {
            $main::p_longest_par_net{$id} = "NA";
            $main::p_longest_par_net_length{$id} = 0;
        }
    }
    
    ### lat/D pin as startpoint will fail real_dist()
    $startpoint_lat = attr_of_pin(is_latch, $startpoint);
    if ($startpoint_lat == 1) {
        $startpoint =~ s/\/D$/\/Q/; 
    }
    my $mann_dist = get_dist ($startpoint => $endpoint);
    $main::p_man_dist{$id} = $mann_dist;
    my @pin_list = split (/ /, attr_of_path_vio(pin_list, $curr_vio));
    map ($_ =~ s/checkpin.*//g, @pin_list); # this line is in order to replace the checkin(internal pin for analog cell such as PLL) due to mender can't see it
    my $real_dist = get_dist_pinArray (@pin_list);
    $main::p_real_dist{$id} = $real_dist;
    @pin_list = $startpoint;
    push (@pin_list => attr_of_path_vio(inter_pin_array, $curr_vio));
    push (@pin_list => $endpoint);
    my $ideal_dist = get_dist_pinArray (@pin_list);
    $main::p_ideal_dist{$id} = $ideal_dist;
    my $detour = -999;
    if ( $mann_dist > 0 ) { 
        $detour = $ideal_dist / $mann_dist ;
    }
    $main::p_detour{$id} = $detour;
    my $detour_ratio = sprintf('%.2f',$detour);
    $main::p_detour_ratio{$id} = $detour_ratio;
    
    my $mcp_num = 0;
    #if ($main::opt_ultra == 1) {
    #    my $real_setup_mcp_num = 0;
    #    my $real_hold_mcp_num = 0;
    #    if ( $mann_dist > 0 ) { 
    #       $mcp_num = ($ideal_dist / 1000) * $main::mender_delay_per_dist_corner / $period;
    #       $real_setup_mcp_num = int($capture_time / $period);
    #       $real_hold_mcp_num = $real_setup_mcp_num - 1;
    #    }
    #    $main::p_mcp_num{$id} = $mcp_num;
    #    my $mcp_hold_num = int $mcp_num;
    #    my $mcp_setup_num = $mcp_hold_num + 1;
    #    $main::p_mcp_setup_num{$id} = $mcp_setup_num;
    #    if ($real_setup_mcp_num > 1 ) {
    #        $main::p_is_mcp{$id} = 1;   
    #    } else {
    #        $main::p_is_mcp{$id} = 0;
    #    }
    #}
    my $real_setup_mcp_num = 1;
    my $real_hold_mcp_num = 0;
    
    if ($main::opt_ultra == 1) {
        if ( $mann_dist > 0 ) { 
           $mcp_num = ($ideal_dist / 1000) * $main::mender_delay_per_dist_corner / $period;
           $real_setup_mcp_num = ceil($capture_time / $period);
           $real_hold_mcp_num = $real_setup_mcp_num - 1;
        }
    } else {
        if ( $mann_dist > 0 ) { 
           $mcp_num = 0;
           #fix precision issue in clock period and capture_time
           $capture_time = int($capture_time*100);
           $period = int($period*100);
           if ($capture_time > $period) {
               $real_setup_mcp_num = 2;
           }
           $real_hold_mcp_num = 1;
        }
    }
    $main::p_mcp_num{$id} = $mcp_num;
    my $mcp_hold_num = int $mcp_num;
    my $mcp_setup_num = $mcp_hold_num + 1;
    $main::p_mcp_setup_num{$id} = $mcp_setup_num;
    if ($real_setup_mcp_num > 1 ) {
        $main::p_is_mcp{$id} = 1;   
    } else {
        $main::p_is_mcp{$id} = 0;
    }

    my $bin_man_dist   = (int ($man_dist / 100) + 1) * 100;
    my $bin_ideal_dist = (int ($ideal_dist / 100) + 1) * 100;
    my $bin_real_dist  = (int ($real_dist / 100) + 1) * 100;
    $main::p_bin_man_distance{$id} = $bin_man_dist;
    $main::p_bin_ideal_distance{$id} = $bin_ideal_dist;
    $main::p_bin_real_distance{$id} = $bin_real_dist;

    $main::p_sig_name{$id}         = GetVioSigName($curr_vio) ;
    $main::p_start_routeRule{$id}  = GetStartRouteRule($curr_vio) ;
    $main::p_end_routeRule{$id}    = GetEndRouteRule($curr_vio) ;
    $main::p_source_coor{$id}      = GetSourceCoor($curr_vio) ;
    $main::p_dest_coor{$id}        = GetDestCoor($curr_vio) ;
    $main::p_source_port_dist{$id} = GetSourcePortDist($curr_vio) ;
    $main::p_dest_port_dist{$id}   = GetDestPortDist($curr_vio) ;



    # the info for dumping reports

    $main::p_dist_rep{$id} = "$startpoint -> $endpoint, Manhattan: $mann_dist, Ideal: $ideal_dist, Real: $real_dist, detour: $main::p_detour_ratio{$id}, is_mcp: $main::p_is_mcp{$id} , clk: $capt_clk";
    
    if ($is_io) {
        $main::p_io_dist_rep{$id} = "$startpoint -> $endpoint, Manhattan: $mann_dist, Ideal: $ideal_dist, Real: $real_dist, detour: $main::p_detour_ratio{$id}, clk: $capt_clk"; 
    }

    if ( $mann_dist >= $main::share_variables{"DIST_HISTOGRAM_MIN"} ) {
        $main::p_mann_plot_rep{$id} = "\@tmp1 = get_pin_xy ${startpoint}; \@tmp2 = get_pin_xy ${endpoint} ; plot_line -color red \@tmp1 \@tmp2; ## Manhattan: $mann_dist, clk: $capt_clk," ; 
    }

    if ( $ideal_dist >= $main::share_variables{RETIME_DISTANCE}) {
        # need check chiplet level real_distance > RETIME_DISTANCE and feed_pars >=3 paths
        # need check nv_top(since all paths are inter-chiplet), man_distance > RETIME_DISTANCE
        if ($main::p_feed_pars_num{$id} >= 3 && $main::p_sig_name{$id} ne "" && $stype ne 'ipo' && $stype ne 'flat') {
            if ($mann_dist <= $main::share_variables{RETIME_DISTANCE} && ($stype eq "noscan" | $stype eq "feflat")) {
                $main::p_retime_rep{$id} = "ATTENTION : $main::p_sig_name{$id}\t\t$capt_clk\t$main::p_feed_pars{$id}\t\t$mann_dist\t$ideal_dist\tis_mcp: $main::p_is_mcp{$id}" ;    
            } else {
                $main::p_retime_rep{$id} = "$main::p_sig_name{$id}\t\t$capt_clk\t$main::p_feed_pars{$id}\t\t$mann_dist\t$ideal_dist\tis_mcp: $main::p_is_mcp{$id}" ;
            }
        } elsif ($main::p_feed_pars_num{$id} >= 2 && $main::p_sig_name{$id} ne "" && ($stype eq 'ipo' || $stype eq 'flat')) {
            $main::p_retime_rep{$id} = "$main::p_sig_name{$id}\t\t$capt_clk\t$main::p_feed_pars{$id}\t\t$mann_dist\t$ideal_dist\tis_mcp: $main::p_is_mcp{$id}" ;
        } elsif (($top eq "nv_top") || ($top eq "nvs_top")) {
        # deal with those feed_par_num == 2's inter-chiplet paths(noscan, if there's no combination, feedpars is 2 for most inter-chiplet paths)
            if ($mann_dist >= $main::share_variables{RETIME_DISTANCE}*1.5) {
                $main::p_retime_rep{$id} = "$main::p_sig_name{$id}\t\t$capt_clk\t$main::p_feed_pars{$id}\t\t$mann_dist\t$ideal_dist\tis_mcp: $main::p_is_mcp{$id}" ;
            }
        }
    }

    if ( $ideal_dist >= $main::share_variables{RETIME_DISTANCE}) {
        if ($mcp_hold_num > 0 && $main::p_feed_pars_num{$id} >= 3) {
            if ($real_setup_mcp_num > 1 ) {
                $main::p_mcp_rep{$id} = "# real mcp is $real_setup_mcp_num: nv_set_mcp -setup $mcp_setup_num -from [get_pins $startpoint] -to [get_pins $endpoint] -infor {NV_ERR: this is temporary for retime missing} \n" ; 
                $main::p_mcp_rep{$id} = $main::p_mcp_rep{$id} . "# real mcp is $real_hold_mcp_num: nv_set_mcp -hold $mcp_hold_num -from [get_pins $startpoint] -to [get_pins $endpoint] -infor {NV_ERR: this is temporary for retime missing}" ;
            } else {
                $main::p_mcp_rep{$id} = "nv_set_mcp -setup $mcp_setup_num -from [get_pins $startpoint] -to [get_pins $endpoint] -infor {NV_ERR: this is temporary for retime missing} \n" ;
                $main::p_mcp_rep{$id} = $main::p_mcp_rep{$id} . "nv_set_mcp -hold $mcp_hold_num -from [get_pins $startpoint] -to [get_pins $endpoint] -infor {NV_ERR: this is temporary for retime missing} " ;   
            }     
        }
    }    

    if ( $main::p_detour_ratio{$id} >= 1.2 && $main::p_ideal_dist{$id} >= $main::share_variables{"DIST_HISTOGRAM_MIN"} ) {
        $outStr = join(' -through ', @pin_list);
        $main::p_detour_plot_rep{$id} = "mrt \-plot -from ${outStr} ; ## detour: $main::p_detour_ratio{$id}, Ideal: $ideal_dist, clk: $capt_clk,";
    }


    
    my $start_unit = $main::p_start_unit{$id} ; 
    my $end_unit   = $main::p_end_unit{$id} ; 

    print "$startpar $endpar $main::p_sig_name{$id} \n";
    if ($startpar eq $endpar && $main::p_sig_name{$id} ne "") {
        $main::p_comb_detour_start_routeRule{$main::p_sig_name{$id}}  = $main::p_start_routeRule{$id} ;
        $main::p_comb_detour_end_routeRule{$main::p_sig_name{$id}}    = $main::p_end_routeRule{$id} ; 
        $main::p_comb_detour_feed_pars_num{$main::p_sig_name{$id}}    = $main::p_feed_pars_num{$id} ;
        $main::p_comb_detour_feed_pars{$main::p_sig_name{$id}}        = $main::p_feed_pars{$id} ;
        $main::p_comb_detour_man_dist{$main::p_sig_name{$id}}         = $main::p_man_dist{$id} ;
        $main::p_comb_detour_ideal_dist{$main::p_sig_name{$id}}       = $main::p_ideal_dist{$id} ;
        $main::p_comb_detour_real_dist{$main::p_sig_name{$id}}        = $main::p_real_dist{$id} ;
        $main::p_comb_detour_source_port_dist{$main::p_sig_name{$id}} = $main::p_source_port_dist{$id} ;
        $main::p_comb_detour_dest_port_dist{$main::p_sig_name{$id}}   = $main::p_dest_port_dist{$id} ;
        $main::p_comb_detour_end_clk{$main::p_sig_name{$id}}          = $capt_clk ; 
        $main::p_comb_detour_is_mcp{$main::p_sig_name{$id}}           = $main::p_is_mcp{$id} ;
    }

    if ($ideal_dist >= $main::share_variables{RETIME_DISTANCE}) {
        # feedthr pars ------------------- nonRT => nonRT # missing retiming
        #                    |------------- RT related    # error 
        if ($main::p_feed_pars_num{$id} > 2 && $main::p_sig_name{$id} ne "") {
            if ($start_unit !~ /_retime_partition_/ && $end_unit !~ /_retime_partition_/) {
                if ($main::p_is_mcp{$id}) {
                    if (exists $main::p_max_nonrt_mcp_feed_pars_num{$main::p_sig_name{$id}}) {
                        if ($main::p_feed_pars_num{$id} > $main::p_max_nonrt_mcp_feed_pars_num{$main::p_sig_name{$id}}) {
                            $main::p_max_nonrt_mcp_feed_pars_num{$main::p_sig_name{$id}}    = $main::p_feed_pars_num{$id} ;
                            $main::p_max_nonrt_mcp_feed_pars{$main::p_sig_name{$id}}        = $main::p_feed_pars{$id} ;
                            $main::p_max_nonrt_mcp_man_dist{$main::p_sig_name{$id}}         = $main::p_man_dist{$id} ;
                            $main::p_max_nonrt_mcp_ideal_dist{$main::p_sig_name{$id}}       = $main::p_ideal_dist{$id} ;
                            $main::p_max_nonrt_mcp_real_dist{$main::p_sig_name{$id}}        = $main::p_real_dist{$id} ;
                            $main::p_max_nonrt_mcp_source_port_dist{$main::p_sig_name{$id}} = $main::p_source_port_dist{$id} ;
                            $main::p_max_nonrt_mcp_dest_port_dist{$main::p_sig_name{$id}}   = $main::p_dest_port_dist{$id} ;
                            $main::p_max_nonrt_mcp_end_clk{$main::p_sig_name{$id}}          = $capt_clk ; 
                            $main::p_nonrt_mcp_sig_is_mcp{$main::p_sig_name{$id}}           = $main::p_is_mcp{$id} ;
                        }
                    } else {
                        $main::p_max_nonrt_mcp_feed_pars_num{$main::p_sig_name{$id}}    = $main::p_feed_pars_num{$id} ;
                        $main::p_max_nonrt_mcp_feed_pars{$main::p_sig_name{$id}}        = $main::p_feed_pars{$id} ;
                        $main::p_max_nonrt_mcp_man_dist{$main::p_sig_name{$id}}         = $main::p_man_dist{$id} ;
                        $main::p_max_nonrt_mcp_ideal_dist{$main::p_sig_name{$id}}       = $main::p_ideal_dist{$id} ;
                        $main::p_max_nonrt_mcp_real_dist{$main::p_sig_name{$id}}        = $main::p_real_dist{$id} ;
                        $main::p_max_nonrt_mcp_source_port_dist{$main::p_sig_name{$id}} = $main::p_source_port_dist{$id} ;
                        $main::p_max_nonrt_mcp_dest_port_dist{$main::p_sig_name{$id}}   = $main::p_dest_port_dist{$id} ;
                        $main::p_max_nonrt_mcp_end_clk{$main::p_sig_name{$id}}          = $capt_clk ; 
                        $main::p_nonrt_mcp_sig_is_mcp{$main::p_sig_name{$id}}           = $main::p_is_mcp{$id} ;
                    }
                    if ($stype eq 'noscan' || $stype eq 'feflat') {
                        $main::p_FeedParNRT2NRT_mcp{$main::p_sig_name{$id}} = $mann_dist ;
                    } elsif ($stype eq 'flat') {
                        $main::p_FeedParNRT2NRT_mcp{$main::p_sig_name{$id}} = $ideal_dist ;
                    } elsif ($stype eq 'ipo') {
                        $main::p_FeedParNRT2NRT_mcp{$main::p_sig_name{$id}} = $real_dist ;
                    }
                } else {
                    if (exists $main::p_max_nonrt_nonmcp_feed_pars_num{$main::p_sig_name{$id}}) {
                        if ($main::p_feed_pars_num{$id} > $main::p_max_nonrt_nonmcp_feed_pars_num{$main::p_sig_name{$id}}) {
                            $main::p_max_nonrt_nonmcp_feed_pars_num{$main::p_sig_name{$id}}    = $main::p_feed_pars_num{$id} ;
                            $main::p_max_nonrt_nonmcp_feed_pars{$main::p_sig_name{$id}}        = $main::p_feed_pars{$id} ;
                            $main::p_max_nonrt_nonmcp_man_dist{$main::p_sig_name{$id}}         = $main::p_man_dist{$id} ;
                            $main::p_max_nonrt_nonmcp_ideal_dist{$main::p_sig_name{$id}}       = $main::p_ideal_dist{$id} ;
                            $main::p_max_nonrt_nonmcp_real_dist{$main::p_sig_name{$id}}        = $main::p_real_dist{$id} ;
                            $main::p_max_nonrt_nonmcp_source_port_dist{$main::p_sig_name{$id}} = $main::p_source_port_dist{$id} ;
                            $main::p_max_nonrt_nonmcp_dest_port_dist{$main::p_sig_name{$id}}   = $main::p_dest_port_dist{$id} ;
                            $main::p_max_nonrt_nonmcp_end_clk{$main::p_sig_name{$id}}          = $capt_clk ; 
                            $main::p_nonrt_nonmcp_sig_is_mcp{$main::p_sig_name{$id}}           = $main::p_is_mcp{$id} ;
                        }
                    } else { 
                        $main::p_max_nonrt_nonmcp_feed_pars_num{$main::p_sig_name{$id}}    = $main::p_feed_pars_num{$id} ;
                        $main::p_max_nonrt_nonmcp_feed_pars{$main::p_sig_name{$id}}        = $main::p_feed_pars{$id} ;
                        $main::p_max_nonrt_nonmcp_man_dist{$main::p_sig_name{$id}}         = $main::p_man_dist{$id} ;
                        $main::p_max_nonrt_nonmcp_ideal_dist{$main::p_sig_name{$id}}       = $main::p_ideal_dist{$id} ;
                        $main::p_max_nonrt_nonmcp_real_dist{$main::p_sig_name{$id}}        = $main::p_real_dist{$id} ;
                        $main::p_max_nonrt_nonmcp_source_port_dist{$main::p_sig_name{$id}} = $main::p_source_port_dist{$id} ;
                        $main::p_max_nonrt_nonmcp_dest_port_dist{$main::p_sig_name{$id}}   = $main::p_dest_port_dist{$id} ;
                        $main::p_max_nonrt_nonmcp_end_clk{$main::p_sig_name{$id}}          = $capt_clk ; 
                        $main::p_nonrt_nonmcp_sig_is_mcp{$main::p_sig_name{$id}}           = $main::p_is_mcp{$id} ;
                    }        
                    if ($stype eq 'noscan' || $stype eq 'feflat') {
                        $main::p_FeedParNRT2NRT_nonmcp{$main::p_sig_name{$id}} = $mann_dist ;
                    } elsif ($stype eq 'flat') {
                        $main::p_FeedParNRT2NRT_nonmcp{$main::p_sig_name{$id}} = $ideal_dist ;
                    } elsif ($stype eq 'ipo') {
                        $main::p_FeedParNRT2NRT_nonmcp{$main::p_sig_name{$id}} = $real_dist ;
                    }
                }
            } else {
                if ($main::p_is_mcp{$id}) {
                    if (exists $main::p_max_rt_mcp_feed_pars_num{$main::p_sig_name{$id}}) {
                        if ($main::p_feed_pars_num{$id} > $main::p_max_rt_mcp_feed_pars_num{$main::p_sig_name{$id}}) {
                            $main::p_max_rt_mcp_feed_pars_num{$main::p_sig_name{$id}}    = $main::p_feed_pars_num{$id} ;
                            $main::p_max_rt_mcp_feed_pars{$main::p_sig_name{$id}}        = $main::p_feed_pars{$id} ;
                            $main::p_max_rt_mcp_man_dist{$main::p_sig_name{$id}}         = $main::p_man_dist{$id} ;
                            $main::p_max_rt_mcp_ideal_dist{$main::p_sig_name{$id}}       = $main::p_ideal_dist{$id} ;
                            $main::p_max_rt_mcp_real_dist{$main::p_sig_name{$id}}        = $main::p_real_dist{$id} ;
                            $main::p_max_rt_mcp_source_port_dist{$main::p_sig_name{$id}} = $main::p_source_port_dist{$id} ;
                            $main::p_max_rt_mcp_dest_port_dist{$main::p_sig_name{$id}}   = $main::p_dest_port_dist{$id} ;
                            $main::p_max_rt_mcp_end_clk{$main::p_sig_name{$id}}          = $capt_clk ; 
                            $main::p_max_rt_mcp_s_routeRule{$main::p_sig_name{$id}}      = $main::p_start_routeRule{$id} ; 
                            $main::p_max_rt_mcp_e_routeRule{$main::p_sig_name{$id}}      = $main::p_end_routeRule{$id} ; 
                            $main::p_rt_mcp_sig_is_mcp{$main::p_sig_name{$id}}           = $main::p_is_mcp{$id} ;
                        }
                    } else { 
                        $main::p_max_rt_mcp_feed_pars_num{$main::p_sig_name{$id}}    = $main::p_feed_pars_num{$id} ;
                        $main::p_max_rt_mcp_feed_pars{$main::p_sig_name{$id}}        = $main::p_feed_pars{$id} ;
                        $main::p_max_rt_mcp_man_dist{$main::p_sig_name{$id}}         = $main::p_man_dist{$id} ;
                        $main::p_max_rt_mcp_ideal_dist{$main::p_sig_name{$id}}       = $main::p_ideal_dist{$id} ;
                        $main::p_max_rt_mcp_real_dist{$main::p_sig_name{$id}}        = $main::p_real_dist{$id} ;
                        $main::p_max_rt_mcp_source_port_dist{$main::p_sig_name{$id}} = $main::p_source_port_dist{$id} ;
                        $main::p_max_rt_mcp_dest_port_dist{$main::p_sig_name{$id}}   = $main::p_dest_port_dist{$id} ;
                        $main::p_max_rt_mcp_end_clk{$main::p_sig_name{$id}}          = $capt_clk ; 
                        $main::p_max_rt_mcp_s_routeRule{$main::p_sig_name{$id}}      = $main::p_start_routeRule{$id} ; 
                        $main::p_max_rt_mcp_e_routeRule{$main::p_sig_name{$id}}      = $main::p_end_routeRule{$id} ; 
                        $main::p_rt_mcp_sig_is_mcp{$main::p_sig_name{$id}}           = $main::p_is_mcp{$id} ;
                    }     
                    if ($stype eq 'noscan' || $stype eq 'feflat') {
                        $main::p_FeedParRT_mcp{$main::p_sig_name{$id}} = $mann_dist ;
                    } elsif ($stype eq 'flat') {
                        $main::p_FeedParRT_mcp{$main::p_sig_name{$id}} = $ideal_dist ;
                    } elsif ($stype eq 'ipo') {
                        $main::p_FeedParRT_mcp{$main::p_sig_name{$id}} = $real_dist ;
                    }
                } else {
                    if (exists $main::p_max_rt_nonmcp_feed_pars_num{$main::p_sig_name{$id}}) {
                        if ($main::p_feed_pars_num{$id} > $main::p_max_rt_nonmcp_feed_pars_num{$main::p_sig_name{$id}}) {
                            $main::p_max_rt_nonmcp_feed_pars_num{$main::p_sig_name{$id}}    = $main::p_feed_pars_num{$id} ;
                            $main::p_max_rt_nonmcp_feed_pars{$main::p_sig_name{$id}}        = $main::p_feed_pars{$id} ;
                            $main::p_max_rt_nonmcp_man_dist{$main::p_sig_name{$id}}         = $main::p_man_dist{$id} ;
                            $main::p_max_rt_nonmcp_ideal_dist{$main::p_sig_name{$id}}       = $main::p_ideal_dist{$id} ;
                            $main::p_max_rt_nonmcp_real_dist{$main::p_sig_name{$id}}        = $main::p_real_dist{$id} ;
                            $main::p_max_rt_nonmcp_source_port_dist{$main::p_sig_name{$id}} = $main::p_source_port_dist{$id} ;
                            $main::p_max_rt_nonmcp_dest_port_dist{$main::p_sig_name{$id}}   = $main::p_dest_port_dist{$id} ;
                            $main::p_max_rt_nonmcp_end_clk{$main::p_sig_name{$id}}          = $capt_clk ; 
                            $main::p_max_rt_nonmcp_s_routeRule{$main::p_sig_name{$id}}      = $main::p_start_routeRule{$id} ; 
                            $main::p_max_rt_nonmcp_e_routeRule{$main::p_sig_name{$id}}      = $main::p_end_routeRule{$id} ; 
                            $main::p_rt_nonmcp_sig_is_mcp{$main::p_sig_name{$id}}           = $main::p_is_mcp{$id} ;
                        }
                    } else { 
                        $main::p_max_rt_nonmcp_feed_pars_num{$main::p_sig_name{$id}}    = $main::p_feed_pars_num{$id} ;
                        $main::p_max_rt_nonmcp_feed_pars{$main::p_sig_name{$id}}        = $main::p_feed_pars{$id} ;
                        $main::p_max_rt_nonmcp_man_dist{$main::p_sig_name{$id}}         = $main::p_man_dist{$id} ;
                        $main::p_max_rt_nonmcp_ideal_dist{$main::p_sig_name{$id}}       = $main::p_ideal_dist{$id} ;
                        $main::p_max_rt_nonmcp_real_dist{$main::p_sig_name{$id}}        = $main::p_real_dist{$id} ;
                        $main::p_max_rt_nonmcp_source_port_dist{$main::p_sig_name{$id}} = $main::p_source_port_dist{$id} ;
                        $main::p_max_rt_nonmcp_dest_port_dist{$main::p_sig_name{$id}}   = $main::p_dest_port_dist{$id} ;
                        $main::p_max_rt_nonmcp_end_clk{$main::p_sig_name{$id}}          = $capt_clk ; 
                        $main::p_max_rt_nonmcp_s_routeRule{$main::p_sig_name{$id}}      = $main::p_start_routeRule{$id} ; 
                        $main::p_max_rt_nonmcp_e_routeRule{$main::p_sig_name{$id}}      = $main::p_end_routeRule{$id} ; 
                        $main::p_rt_nonmcp_sig_is_mcp{$main::p_sig_name{$id}}           = $main::p_is_mcp{$id} ;
                    }     
                    if ($stype eq 'noscan' || $stype eq 'feflat') {
                        $main::p_FeedParRT_nonmcp{$main::p_sig_name{$id}} = $mann_dist ;
                    } elsif ($stype eq 'flat') {
                        $main::p_FeedParRT_nonmcp{$main::p_sig_name{$id}} = $ideal_dist ;
                    } elsif ($stype eq 'ipo') {
                        $main::p_FeedParRT_nonmcp{$main::p_sig_name{$id}} = $real_dist ;
                    }
                }
            }
        } 
        # adjacent pars (ipo or flat)  ------ nonRT => nonRT # missing retiming 
        #                              |----- nonRT => RT    # start_port_dist/end_port_dist too large
        #                              |----- RT    => nonRT # start_port_dist/end_port_dist too large
        if ($main::p_feed_pars_num{$id} == 2 && $main::p_sig_name{$id} ne "" && ($stype eq 'flat' || $stype eq 'ipo')) {
            $main::p_max_feed_pars{$main::p_sig_name{$id}}        = $main::p_feed_pars{$id} ;
            $main::p_max_man_dist{$main::p_sig_name{$id}}         = $main::p_man_dist{$id} ;
            $main::p_max_ideal_dist{$main::p_sig_name{$id}}       = $main::p_ideal_dist{$id} ;
            $main::p_max_real_dist{$main::p_sig_name{$id}}        = $main::p_real_dist{$id} ;
            $main::p_max_source_port_dist{$main::p_sig_name{$id}} = $main::p_source_port_dist{$id} ;
            $main::p_max_dest_port_dist{$main::p_sig_name{$id}}   = $main::p_dest_port_dist{$id} ;
            $main::p_max_end_clk{$main::p_sig_name{$id}}          = $capt_clk ; 
            $main::p_sig_s_routeRule{$main::p_sig_name{$id}}      = $main::p_start_routeRule{$id} ; 
            $main::p_sig_e_routeRule{$main::p_sig_name{$id}}      = $main::p_end_routeRule{$id} ; 
            $main::p_sig_is_mcp{$main::p_sig_name{$id}}           = $main::p_is_mcp{$id} ;

            if ($start_unit !~ /_retime_partition_/ && $end_unit !~ /_retime_partition_/) {
                if ($main::p_is_mcp{$id}) {
                    if ($stype eq 'flat') {
                        $main::p_AdjParNRT2NRT_mcp{$main::p_sig_name{$id}} = $ideal_dist ;
                    } else {
                        $main::p_AdjParNRT2NRT_mcp{$main::p_sig_name{$id}} = $real_dist ;
                    }
                } else {
                    if ($stype eq 'flat') {
                        $main::p_AdjParNRT2NRT_nonmcp{$main::p_sig_name{$id}} = $ideal_dist ;
                    } else {
                        $main::p_AdjParNRT2NRT_nonmcp{$main::p_sig_name{$id}} = $real_dist ;
                    }
                }
            } elsif ($start_unit =~ /_retime_partition_/ && $end_unit !~ /_retime_partition_/) {
                if ($main::p_is_mcp{$id}) {
                    if ($stype eq 'flat') {
                        $main::p_AdjParRT2NRT_mcp{$main::p_sig_name{$id}} = $ideal_dist ;
                    } else {
                        $main::p_AdjParRT2NRT_mcp{$main::p_sig_name{$id}} = $real_dist ;
                    }
                } else {
                    if ($stype eq 'flat') {
                        $main::p_AdjParRT2NRT_nonmcp{$main::p_sig_name{$id}} = $ideal_dist ;
                    } else {
                        $main::p_AdjParRT2NRT_nonmcp{$main::p_sig_name{$id}} = $real_dist ;
                    }
                }
            } elsif ($start_unit !~ /_retime_partition_/ && $end_unit =~ /_retime_partition_/) {
                if ($main::p_is_mcp{$id}) {
                    if ($stype eq 'flat') {
                        $main::p_AdjParNRT2RT_mcp{$main::p_sig_name{$id}} = $ideal_dist ;
                    } else {
                        $main::p_AdjParNRT2RT_mcp{$main::p_sig_name{$id}} = $real_dist ;
                    }
                } else {
                    if ($stype eq 'flat') {
                        $main::p_AdjParNRT2RT_nonmcp{$main::p_sig_name{$id}} = $ideal_dist ;
                    } else {
                        $main::p_AdjParNRT2RT_nonmcp{$main::p_sig_name{$id}} = $real_dist ;
                    }
                }
            } else {
                if ($main::p_is_mcp{$id}) {
                    if ($stype eq 'flat') {
                        $main::p_AdjParRT2RT_mcp{$main::p_sig_name{$id}} = $ideal_dist ;
                    } else {
                        $main::p_AdjParRT2RT_mcp{$main::p_sig_name{$id}} = $real_dist ;
                    }
                } else {
                    if ($stype eq 'flat') {
                        $main::p_AdjParRT2RT_nonmcp{$main::p_sig_name{$id}} = $ideal_dist ;
                    } else {
                        $main::p_AdjParRT2RT_nonmcp{$main::p_sig_name{$id}} = $real_dist ;
                    }
                }   
            } 
        } 
    }
}

sub dump_reports {
    my ($top,$rep_name) = @_;

    my $s_type = session_type;

    open DistRep, ">${rep_name}.distance" or die $!;
    print "    Start to Dump Dist Rep @ " . `date` . "\n" ;

    print DistRep "#\n";
    print DistRep "# Manhattan: get_distance of ONLY startpoint, endpoint\n";
    print DistRep "# Ideal:     get_distance of ONLY startpoint, partition pins, endpoint\n";
    print DistRep "# Real:      get_distance of ALL (startpoint, combinational cells, partition pins, endpoint)\n";
    print DistRep "# Detour:    div(ideal / manhattan)..use this to metric identify bad partition pins\n";
    print DistRep "#\n";

    foreach my $id (sort keys %main::p_dist_rep) {
        print DistRep "$main::p_dist_rep{$id}\n" ;
    }

    close DistRep ;
    
    open IODistRep, ">${rep_name}.io.distance" or die $!;
    print "    Start to Dump IODist Rep @ " . `date` . "\n" ; 

    print IODistRep "#\n";
    print IODistRep "# Manhattan: get_distance of ONLY startpoint, endpoint\n";
    print IODistRep "# Ideal:     get_distance of ONLY startpoint, partition pins, endpoint\n";
    print IODistRep "# Real:      get_distance of ALL (startpoint, combinational cells, partition pins, endpoint)\n";
    print IODistRep "# Detour:    div(ideal / manhattan)..use this to metric identify bad partition pins\n";
    print IODistRep "#\n";

    foreach my $id (sort keys %main::p_io_dist_rep) {
        print IODistRep "$main::p_io_dist_rep{$id}\n" ;
    }
    
    close IODistRep ;
    
    open MannPlot, ">${rep_name}.manhattan_plot.medic" or die $!;
    print "    Start to Dump MannPlot Rep @ " . `date` . "\n" ; 

    foreach my $id (sort keys %main::p_mann_plot_rep) {
        print MannPlot "$main::p_mann_plot_rep{$id}\n" ;
    }

    close MannPlot ;

    open RetimeReport,  ">${rep_name}.full_retime.report" or die $!;
    print "    Start to Dump Retime Rep @ " . `date` . "\n" ;

    print RetimeReport "# Each column is: longest-net-name, end-clk, feed-pars, mann-dist, ideal-dsit\n";
    print RetimeReport "# !!! ideal_dist and feed_pars could be inaccurate without <par>_hfp.def\n";
    print RetimeReport "# !!! Please pay attention to the path if it's been commented out \n\n";

    foreach my $id (sort keys %main::p_retime_rep) {
        print RetimeReport "$main::p_retime_rep{$id}\n" ;
    }    

    close RetimeReport ;

    open McpReport, ">${rep_name}.temp_mcp_for_missing_retime.tcl" or die $!;
    print "    Start to Dump MCP tcl file @ " . `date` . "\n" ;
    
    foreach my $id (sort keys %main::p_mcp_rep) {
        print McpReport "$main::p_mcp_rep{$id}\n" ; 
    }
    close McpReport ;

    open FeedthrParRep , "> ${rep_name}.uniq_retime_feedpar.report" or die $! ;;
    print "    Start to Dump Feedthr Pars file @ " . `date` . "\n" ;
    #$main::p_AdjRep{$id} = "$capt_clk\t$feed_pars\t\t$mann_dist\t$ideal_dist\t$main::p_source_port_dist{$id}\t$main::p_dest_port_dist{$id}\tis_mcp: $main::p_is_mcp{$id}" ;
    
    print FeedthrParRep "# The signals through partitions :\n\n" ;
    print FeedthrParRep "# nonRT => nonRT && IS_MCP == 0\n" ;
    
    if ($stype eq 'ipo') {
        printf FeedthrParRep ("%-80s\t%-40s\t\t%10s\t%10s\t%10s\t%10s\t%10s\t%s\n", "#<Signal Name>", "<Feedthr Partitions>", "<End Clk>", "<Mann Dist>", "<Real Dist>", "<Source Port Dist>", "<Dest Port Dist>", "is_mcp: <\${is_mcp}>" ) ;  
    } else { 
        printf FeedthrParRep ("%-80s\t%-40s\t\t%10s\t%10s\t%10s\t%10s\t%10s\t%s\n", "#<Signal Name>", "<Feedthr Partitions>", "<End Clk>", "<Mann Dist>", "<Ideal Dist>", "<Source Port Dist>", "<Dest Port Dist>", "is_mcp: <\${is_mcp}>" ) ;  
    }

    foreach my $sig_name (sort {$main::p_FeedParNRT2NRT_nonmcp{$b} <=> $main::p_FeedParNRT2NRT_nonmcp{$a}} keys %main::p_FeedParNRT2NRT_nonmcp) {
        if ($stype eq 'ipo') {
            printf FeedthrParRep ("%-80s\t%-40s\t\t%10s\t%10s\t%10s\t%10s\t%10s\t%s # nonRT  & MCP == 0\n", $sig_name, $main::p_max_nonrt_nonmcp_feed_pars{$sig_name}, $main::p_max_nonrt_nonmcp_end_clk{$sig_name}, $main::p_max_nonrt_nonmcp_man_dist{$sig_name}, $main::p_max_nonrt_nonmcp_real_dist{$sig_name}, $main::p_max_nonrt_nonmcp_source_port_dist{$sig_name}, $main::p_max_nonrt_nonmcp_dest_port_dist{$sig_name}, "is_mcp: $main::p_nonrt_nonmcp_sig_is_mcp{$sig_name}") ;
        } else {
            printf FeedthrParRep ("%-80s\t%-40s\t\t%10s\t%10s\t%10s\t%10s\t%10s\t%s # nonRT  & MCP == 0\n", $sig_name, $main::p_max_nonrt_nonmcp_feed_pars{$sig_name}, $main::p_max_nonrt_nonmcp_end_clk{$sig_name}, $main::p_max_nonrt_nonmcp_man_dist{$sig_name}, $main::p_max_nonrt_nonmcp_ideal_dist{$sig_name}, $main::p_max_nonrt_nonmcp_source_port_dist{$sig_name}, $main::p_max_nonrt_nonmcp_dest_port_dist{$sig_name}, "is_mcp: $main::p_nonrt_nonmcp_sig_is_mcp{$sig_name}") ;
        }
    }

    print FeedthrParRep "\n# nonRT => nonRT && IS_MCP == 1\n" ;

    if ($stype eq 'ipo') {
        printf FeedthrParRep ("%-80s\t%-40s\t\t%10s\t%10s\t%10s\t%10s\t%10s\t%s\n", "#<Signal Name>", "<Feedthr Partitions>", "<End Clk>", "<Mann Dist>", "<Real Dist>", "<Source Port Dist>", "<Dest Port Dist>", "is_mcp: <\${is_mcp}>" ) ;  
    } else { 
        printf FeedthrParRep ("%-80s\t%-40s\t\t%10s\t%10s\t%10s\t%10s\t%10s\t%s\n", "#<Signal Name>", "<Feedthr Partitions>", "<End Clk>", "<Mann Dist>", "<Ideal Dist>", "<Source Port Dist>", "<Dest Port Dist>", "is_mcp: <\${is_mcp}>" ) ;  
    }

    foreach my $sig_name (sort {$main::p_FeedParNRT2NRT_mcp{$b} <=> $main::p_FeedParNRT2NRT_mcp{$a}} keys %main::p_FeedParNRT2NRT_mcp) {
        if ($stype eq 'ipo') {
            printf FeedthrParRep ("%-80s\t%-40s\t\t%10s\t%10s\t%10s\t%10s\t%10s\t%s # nonRT  & MCP == 1\n", $sig_name, $main::p_max_nonrt_mcp_feed_pars{$sig_name}, $main::p_max_nonrt_mcp_end_clk{$sig_name}, $main::p_max_nonrt_mcp_man_dist{$sig_name}, $main::p_max_nonrt_mcp_real_dist{$sig_name}, $main::p_max_nonrt_mcp_source_port_dist{$sig_name}, $main::p_max_nonrt_mcp_dest_port_dist{$sig_name}, "is_mcp: $main::p_nonrt_mcp_sig_is_mcp{$sig_name}") ;
        } else {
            printf FeedthrParRep ("%-80s\t%-40s\t\t%10s\t%10s\t%10s\t%10s\t%10s\t%s # nonRT  & MCP == 1\n", $sig_name, $main::p_max_nonrt_mcp_feed_pars{$sig_name}, $main::p_max_nonrt_mcp_end_clk{$sig_name}, $main::p_max_nonrt_mcp_man_dist{$sig_name}, $main::p_max_nonrt_mcp_ideal_dist{$sig_name}, $main::p_max_nonrt_mcp_source_port_dist{$sig_name}, $main::p_max_nonrt_mcp_dest_port_dist{$sig_name}, "is_mcp: $main::p_nonrt_mcp_sig_is_mcp{$sig_name}") ;
        }
    }

    print FeedthrParRep "\n# (nonRT => RT || RT => nonRT || RT => RT) && IS_MCP == 0\n" ;
    
    if ($stype eq 'ipo') {
        printf FeedthrParRep ("%-80s\t%-40s\t\t%10s\t%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s\n", "#<Signal Name>", "<Feedthr Partitions>", "<End Clk>", "<Mann Dist>", "<Real Dist>", "<Source Port Dist>", "<Dest Port Dist>", "<Start routeRule>", "<End routeRule>", "is_mcp: <\${is_mcp}>" ) ;  
    } else { 
        printf FeedthrParRep ("%-80s\t%-40s\t\t%10s\t%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s\n", "#<Signal Name>", "<Feedthr Partitions>", "<End Clk>", "<Mann Dist>", "<Ideal Dist>", "<Source Port Dist>", "<Dest Port Dist>", "<Start routeRule>", "<End routeRule>", "is_mcp: <\${is_mcp}>" ) ;  
    }

    foreach my $sig_name (sort {$main::p_FeedParRT_nonmcp{$b} <=> $main::p_FeedParRT_nonmcp{$a}} keys %main::p_FeedParRT_nonmcp) {
        if ($stype eq 'ipo') {
            printf FeedthrParRep ("%-80s\t%-40s\t\t%10s\t%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s # RT  & MCP == 0\n", $sig_name, $main::p_max_rt_nonmcp_feed_pars{$sig_name}, $main::p_max_rt_nonmcp_end_clk{$sig_name}, $main::p_max_rt_nonmcp_man_dist{$sig_name}, $main::p_max_rt_nonmcp_real_dist{$sig_name}, $main::p_max_rt_nonmcp_source_port_dist{$sig_name}, $main::p_max_rt_nonmcp_dest_port_dist{$sig_name}, $main::p_max_rt_nonmcp_s_routeRule{$sig_name}, $main::p_max_rt_nonmcp_e_routeRule{$sig_name}, "is_mcp: $main::p_rt_nonmcp_sig_is_mcp{$sig_name}") ;
        } else {
            printf FeedthrParRep ("%-80s\t%-40s\t\t%10s\t%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s # RT  & MCP == 0\n", $sig_name, $main::p_max_rt_nonmcp_feed_pars{$sig_name}, $main::p_max_rt_nonmcp_end_clk{$sig_name}, $main::p_max_rt_nonmcp_man_dist{$sig_name}, $main::p_max_rt_nonmcp_ideal_dist{$sig_name}, $main::p_max_rt_nonmcp_source_port_dist{$sig_name}, $main::p_max_rt_nonmcp_dest_port_dist{$sig_name}, $main::p_max_rt_nonmcp_s_routeRule{$sig_name}, $main::p_max_rt_nonmcp_e_routeRule{$sig_name}, "is_mcp: $main::p_rt_nonmcp_sig_is_mcp{$sig_name}") ;
        }
    }

    print FeedthrParRep "\n# (nonRT => RT || RT => nonRT || RT => RT) && IS_MCP == 1\n" ;

    if ($stype eq 'ipo') {
        printf FeedthrParRep ("%-80s\t%-40s\t\t%10s\t%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s\n", "#<Signal Name>", "<Feedthr Partitions>", "<End Clk>", "<Mann Dist>", "<Real Dist>", "<Source Port Dist>", "<Dest Port Dist>", "<Start routeRule>", "<End routeRule>", "is_mcp: <\${is_mcp}>" ) ;  
    } else { 
        printf FeedthrParRep ("%-80s\t%-40s\t\t%10s\t%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s\n", "#<Signal Name>", "<Feedthr Partitions>", "<End Clk>", "<Mann Dist>", "<Ideal Dist>", "<Source Port Dist>", "<Dest Port Dist>", "<Start routeRule>", "<End routeRule>", "is_mcp: <\${is_mcp}>" ) ;  
    }

    foreach my $sig_name (sort {$main::p_FeedParRT_mcp{$b} <=> $main::p_FeedParRT_mcp{$a}} keys %main::p_FeedParRT_mcp) {
        if ($stype eq 'ipo') {
            printf FeedthrParRep ("%-80s\t%-40s\t\t%10s\t%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s # RT  & MCP == 1\n", $sig_name, $main::p_max_rt_mcp_feed_pars{$sig_name}, $main::p_max_rt_mcp_end_clk{$sig_name}, $main::p_max_rt_mcp_man_dist{$sig_name}, $main::p_max_rt_mcp_real_dist{$sig_name}, $main::p_max_rt_mcp_source_port_dist{$sig_name}, $main::p_max_rt_mcp_dest_port_dist{$sig_name}, $main::p_max_rt_mcp_s_routeRule{$sig_name}, $main::p_max_rt_mcp_e_routeRule{$sig_name}, "is_mcp: $main::p_rt_mcp_sig_is_mcp{$sig_name}") ;
        } else {
            printf FeedthrParRep ("%-80s\t%-40s\t\t%10s\t%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s # RT  & MCP == 1\n", $sig_name, $main::p_max_rt_mcp_feed_pars{$sig_name}, $main::p_max_rt_mcp_end_clk{$sig_name}, $main::p_max_rt_mcp_man_dist{$sig_name}, $main::p_max_rt_mcp_ideal_dist{$sig_name}, $main::p_max_rt_mcp_source_port_dist{$sig_name}, $main::p_max_rt_mcp_dest_port_dist{$sig_name}, $main::p_max_rt_mcp_s_routeRule{$sig_name}, $main::p_max_rt_mcp_e_routeRule{$sig_name}, "is_mcp: $main::p_rt_mcp_sig_is_mcp{$sig_name}") ;
        }
    }

    print FeedthrParRep "\n# Detour caused by comb logic :\n" ;

    if ($stype eq 'ipo') {
        printf FeedthrParRep ("%-80s\t%-40s\t\t%10s\t%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s\n", "#<Signal Name>", "<Feedthr Partitions>", "<End Clk>", "<Mann Dist>", "<Real Dist>", "<Source Port Dist>", "<Dest Port Dist>", "<Start routeRule>", "<End routeRule>", "is_mcp: <\${is_mcp}>" ) ;
    } else {
        printf FeedthrParRep ("%-80s\t%-40s\t\t%10s\t%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s\n", "#<Signal Name>", "<Feedthr Partitions>", "<End Clk>", "<Mann Dist>", "<Ideal Dist>", "<Source Port Dist>", "<Dest Port Dist>", "<Start routeRule>", "<End routeRule>", "is_mcp: <\${is_mcp}>" ) ;
    }

    foreach my $sig_name (sort keys %main::p_comb_detour_start_routeRule) {
        printf FeedthrParRep ("%-80s\t%-40s\t\t%10s\t%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s\n", $sig_name, $main::p_comb_detour_feed_pars{$sig_name}, $main::p_comb_detour_end_clk{$sig_name}, $main::p_comb_detour_man_dist{$sig_name}, $main::p_comb_detour_real_dist{$sig_name}, $main::p_comb_detour_source_port_dist{$sig_name}, $main::p_comb_detour_dest_port_dist{$sig_name}, $main::p_comb_detour_start_routeRule{$sig_name}, $main::p_comb_detour_end_routeRule{$sig_name}, "is_mcp: $main::p_comb_detour_is_mcp{$sig_name}") ;
    }

    close FeedthrParRep ;


    print "    Start to Dump Neighbor Pars file @ " . `date` . "\n" ;
    open AdjacentParRep, "> ${rep_name}.uniq_retime_adjpar.report" or die $! ;;

    print AdjacentParRep "# This is for neighbor partitions reports only on flat/ipo NL. \n\n" ;

    print AdjacentParRep "# nonRT => nonRT && IS_MCP == 0\n" ;
    if ($stype eq 'ipo') {
        printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\n", "#<Signal Name>", "<Feedthr Partitions>", "<End Clk>", "<Mann Dist>", "<Real Dist>", "<Source Port Dist>", "<Dest Port Dist>", "is_mcp: <\${is_mcp}>" ) ;
    } else {
        printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\n", "#<Signal Name>", "<Feedthr Partitions>", "<End Clk>", "<Mann Dist>", "<Ideal Dist>", "<Source Port Dist>", "<Dest Port Dist>", "is_mcp: <\${is_mcp}>" ) ;
    }

    foreach my $sig_name (sort {$main::p_AdjParNRT2NRT_nonmcp{$b} <=> $main::p_AdjParNRT2NRT_nonmcp{$a}} keys %main::p_AdjParNRT2NRT_nonmcp) {
        if ($stype eq 'ipo') {
            printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s # nonRT => nonRT & MCP == 0\n", $sig_name, $main::p_max_feed_pars{$sig_name}, $main::p_max_end_clk{$sig_name}, $main::p_max_man_dist{$sig_name}, $main::p_max_real_dist{$sig_name}, $main::p_max_source_port_dist{$sig_name}, $main::p_max_dest_port_dist{$sig_name}, "is_mcp: $main::p_sig_is_mcp{$sig_name}") ;
        } else {
            printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s # nonRT => nonRT & MCP == 0\n", $sig_name, $main::p_max_feed_pars{$sig_name}, $main::p_max_end_clk{$sig_name}, $main::p_max_man_dist{$sig_name}, $main::p_max_ideal_dist{$sig_name}, $main::p_max_source_port_dist{$sig_name}, $main::p_max_dest_port_dist{$sig_name}, "is_mcp: $main::p_sig_is_mcp{$sig_name}") ;
        }
    }

    print AdjacentParRep "\n# nonRT => nonRT && IS_MCP == 1\n" ;
    if ($stype eq 'ipo') {
        printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\n", "#<Signal Name>", "<Feedthr Partitions>", "<End Clk>", "<Mann Dist>", "<Real Dist>", "<Source Port Dist>", "<Dest Port Dist>", "is_mcp: <\${is_mcp}>" ) ;
    } else {
        printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\n", "#<Signal Name>", "<Feedthr Partitions>", "<End Clk>", "<Mann Dist>", "<Ideal Dist>", "<Source Port Dist>", "<Dest Port Dist>", "is_mcp: <\${is_mcp}>" ) ;
    }

    foreach my $sig_name (sort {$main::p_AdjParNRT2NRT_mcp{$b} <=> $main::p_AdjParNRT2NRT_mcp{$a}} keys %main::p_AdjParNRT2NRT_mcp) {
        if ($stype eq 'ipo') {
            printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s # nonRT => nonRT & MCP == 1\n", $sig_name, $main::p_max_feed_pars{$sig_name}, $main::p_max_end_clk{$sig_name}, $main::p_max_man_dist{$sig_name}, $main::p_max_real_dist{$sig_name}, $main::p_max_source_port_dist{$sig_name}, $main::p_max_dest_port_dist{$sig_name}, "is_mcp: $main::p_sig_is_mcp{$sig_name}") ;
        } else {
            printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s # nonRT => nonRT & MCP == 1\n", $sig_name, $main::p_max_feed_pars{$sig_name}, $main::p_max_end_clk{$sig_name}, $main::p_max_man_dist{$sig_name}, $main::p_max_ideal_dist{$sig_name}, $main::p_max_source_port_dist{$sig_name}, $main::p_max_dest_port_dist{$sig_name}, "is_mcp: $main::p_sig_is_mcp{$sig_name}") ;
        }
    }

    print AdjacentParRep "\n# RT => nonRT && IS_MCP == 0\n" ;
    if ($stype eq 'ipo') {
        printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s\n", "#<Signal Name>", "<Feedthr Partitions>", "<End Clk>", "<Mann Dist>", "<Real Dist>", "<Source Port Dist>", "<Dest Port Dist>", "<Start routeRule>", "<End routeRule>", "is_mcp: <\${is_mcp}>" ) ;
    } else {
        printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s\n", "#<Signal Name>", "<Feedthr Partitions>", "<End Clk>", "<Mann Dist>", "<Ideal Dist>", "<Source Port Dist>", "<Dest Port Dist>", "<Start routeRule>", "<End routeRule>", "is_mcp: <\${is_mcp}>" ) ;
    }

    foreach my $sig_name (sort {$main::p_AdjParRT2NRT_nonmcp{$b} <=> $main::p_AdjParRT2NRT_nonmcp{$a}} keys %main::p_AdjParRT2NRT_nonmcp) {
        if ($stype eq 'ipo') {
            printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s # RT => nonRT & MCP == 0\n", $sig_name, $main::p_max_feed_pars{$sig_name}, $main::p_max_end_clk{$sig_name}, $main::p_max_man_dist{$sig_name}, $main::p_max_real_dist{$sig_name}, $main::p_max_source_port_dist{$sig_name}, $main::p_max_dest_port_dist{$sig_name}, $main::p_sig_s_routeRule{$sig_name}, $main::p_sig_e_routeRule{$sig_name}, "is_mcp: $main::p_sig_is_mcp{$sig_name}") ;
        } else {
            printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s # RT => nonRT & MCP == 0\n", $sig_name, $main::p_max_feed_pars{$sig_name}, $main::p_max_end_clk{$sig_name}, $main::p_max_man_dist{$sig_name}, $main::p_max_ideal_dist{$sig_name}, $main::p_max_source_port_dist{$sig_name}, $main::p_max_dest_port_dist{$sig_name}, $main::p_sig_s_routeRule{$sig_name}, $main::p_sig_e_routeRule{$sig_name}, "is_mcp: $main::p_sig_is_mcp{$sig_name}") ;
        }
    }

    print AdjacentParRep "\n# RT => nonRT && IS_MCP == 1\n" ;
    if ($stype eq 'ipo') {
        printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s\n", "#<Signal Name>", "<Feedthr Partitions>", "<End Clk>", "<Mann Dist>", "<Real Dist>", "<Source Port Dist>", "<Dest Port Dist>", "<Start routeRule>", "<End routeRule>", "is_mcp: <\${is_mcp}>" ) ;
    } else {
        printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s\n", "#<Signal Name>", "<Feedthr Partitions>", "<End Clk>", "<Mann Dist>", "<Ideal Dist>", "<Source Port Dist>", "<Dest Port Dist>", "<Start routeRule>", "<End routeRule>", "is_mcp: <\${is_mcp}>" ) ;
    }

    foreach my $sig_name (sort {$main::p_AdjParRT2NRT_mcp{$b} <=> $main::p_AdjParRT2NRT_mcp{$a}} keys %main::p_AdjParRT2NRT_mcp) {
        if ($stype eq 'ipo') {
            printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s # RT => nonRT & MCP == 1\n", $sig_name, $main::p_max_feed_pars{$sig_name}, $main::p_max_end_clk{$sig_name}, $main::p_max_man_dist{$sig_name}, $main::p_max_real_dist{$sig_name}, $main::p_max_source_port_dist{$sig_name}, $main::p_max_dest_port_dist{$sig_name}, $main::p_sig_s_routeRule{$sig_name}, $main::p_sig_e_routeRule{$sig_name}, "is_mcp: $main::p_sig_is_mcp{$sig_name}") ;
        } else {
            printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s # RT => nonRT & MCP == 1\n", $sig_name, $main::p_max_feed_pars{$sig_name}, $main::p_max_end_clk{$sig_name}, $main::p_max_man_dist{$sig_name}, $main::p_max_ideal_dist{$sig_name}, $main::p_max_source_port_dist{$sig_name}, $main::p_max_dest_port_dist{$sig_name}, $main::p_sig_s_routeRule{$sig_name}, $main::p_sig_e_routeRule{$sig_name}, "is_mcp: $main::p_sig_is_mcp{$sig_name}") ;
        }
    }

    print AdjacentParRep "\n# nonRT => RT && IS_MCP == 0\n" ;

    if ($stype eq 'ipo') {
        printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s\n", "#<Signal Name>", "<Feedthr Partitions>", "<End Clk>", "<Mann Dist>", "<Real Dist>", "<Source Port Dist>", "<Dest Port Dist>", "<Start routeRule>", "<End routeRule>", "is_mcp: <\${is_mcp}>" ) ;
    } else {
        printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s\n", "#<Signal Name>", "<Feedthr Partitions>", "<End Clk>", "<Mann Dist>", "<Ideal Dist>", "<Source Port Dist>", "<Dest Port Dist>", "<Start routeRule>", "<End routeRule>", "is_mcp: <\${is_mcp}>" ) ;
    }

    foreach my $sig_name (sort {$main::p_AdjParNRT2RT_nonmcp{$b} <=> $main::p_AdjParNRT2RT_nonmcp{$a}} keys %main::p_AdjParNRT2RT_nonmcp) {
        if ($stype eq 'ipo') {
            printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s # nonRT => RT & MCP == 0\n", $sig_name, $main::p_max_feed_pars{$sig_name}, $main::p_max_end_clk{$sig_name}, $main::p_max_man_dist{$sig_name}, $main::p_max_real_dist{$sig_name}, $main::p_max_source_port_dist{$sig_name}, $main::p_max_dest_port_dist{$sig_name}, $main::p_sig_s_routeRule{$sig_name}, $main::p_sig_e_routeRule{$sig_name}, "is_mcp: $main::p_sig_is_mcp{$sig_name}") ;
        } else {
            printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s # nonRT => RT & MCP == 0\n", $sig_name, $main::p_max_feed_pars{$sig_name}, $main::p_max_end_clk{$sig_name}, $main::p_max_man_dist{$sig_name}, $main::p_max_ideal_dist{$sig_name}, $main::p_max_source_port_dist{$sig_name}, $main::p_max_dest_port_dist{$sig_name}, $main::p_sig_s_routeRule{$sig_name}, $main::p_sig_e_routeRule{$sig_name}, "is_mcp: $main::p_sig_is_mcp{$sig_name}") ;
        }
    }

    print AdjacentParRep "\n# nonRT => RT && IS_MCP == 1\n" ;
    if ($stype eq 'ipo') {
        printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s\n", "#<Signal Name>", "<Feedthr Partitions>", "<End Clk>", "<Mann Dist>", "<Real Dist>", "<Source Port Dist>", "<Dest Port Dist>", "<Start routeRule>", "<End routeRule>", "is_mcp: <\${is_mcp}>" ) ;
    } else {
        printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s\n", "#<Signal Name>", "<Feedthr Partitions>", "<End Clk>", "<Mann Dist>", "<Ideal Dist>", "<Source Port Dist>", "<Dest Port Dist>", "<Start routeRule>", "<End routeRule>", "is_mcp: <\${is_mcp}>" ) ;
    }

    foreach my $sig_name (sort {$main::p_AdjParNRT2RT_mcp{$b} <=> $main::p_AdjParNRT2RT_mcp{$a}} keys %main::p_AdjParNRT2RT_mcp) {
        if ($stype eq 'ipo') {
            printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s # nonRT => RT & MCP == 1\n", $sig_name, $main::p_max_feed_pars{$sig_name}, $main::p_max_end_clk{$sig_name}, $main::p_max_man_dist{$sig_name}, $main::p_max_real_dist{$sig_name}, $main::p_max_source_port_dist{$sig_name}, $main::p_max_dest_port_dist{$sig_name}, $main::p_sig_s_routeRule{$sig_name}, $main::p_sig_e_routeRule{$sig_name}, "is_mcp: $main::p_sig_is_mcp{$sig_name}") ;
        } else {
            printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s # nonRT => RT & MCP == 1\n", $sig_name, $main::p_max_feed_pars{$sig_name}, $main::p_max_end_clk{$sig_name}, $main::p_max_man_dist{$sig_name}, $main::p_max_ideal_dist{$sig_name}, $main::p_max_source_port_dist{$sig_name}, $main::p_max_dest_port_dist{$sig_name}, $main::p_sig_s_routeRule{$sig_name}, $main::p_sig_e_routeRule{$sig_name}, "is_mcp: $main::p_sig_is_mcp{$sig_name}") ;
        }
    }

    print AdjacentParRep "\n# RT => RT && IS_MCP == 0\n" ;
    if ($stype eq 'ipo') {
        printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s\n", "#<Signal Name>", "<Feedthr Partitions>", "<End Clk>", "<Mann Dist>", "<Real Dist>", "<Source Port Dist>", "<Dest Port Dist>", "<Start routeRule>", "<End routeRule>", "is_mcp: <\${is_mcp}>" ) ;
    } else {
        printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s\n", "#<Signal Name>", "<Feedthr Partitions>", "<End Clk>", "<Mann Dist>", "<Ideal Dist>", "<Source Port Dist>", "<Dest Port Dist>", "<Start routeRule>", "<End routeRule>", "is_mcp: <\${is_mcp}>" ) ;
    }

    foreach my $sig_name (sort {$main::p_AdjParRT2RT_nonmcp{$b} <=> $main::p_AdjParRT2RT_nonmcp{$a}} keys %main::p_AdjParRT2RT_nonmcp) {
        if ($stype eq 'ipo') {
            printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s # RT => RT & MCP == 0\n", $sig_name, $main::p_max_feed_pars{$sig_name}, $main::p_max_end_clk{$sig_name}, $main::p_max_man_dist{$sig_name}, $main::p_max_real_dist{$sig_name}, $main::p_max_source_port_dist{$sig_name}, $main::p_max_dest_port_dist{$sig_name}, $main::p_sig_s_routeRule{$sig_name}, $main::p_sig_e_routeRule{$sig_name}, "is_mcp: $main::p_sig_is_mcp{$sig_name}") ;
        } else {
            printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s # RT => RT & MCP == 0\n", $sig_name, $main::p_max_feed_pars{$sig_name}, $main::p_max_end_clk{$sig_name}, $main::p_max_man_dist{$sig_name}, $main::p_max_ideal_dist{$sig_name}, $main::p_max_source_port_dist{$sig_name}, $main::p_max_dest_port_dist{$sig_name}, $main::p_sig_s_routeRule{$sig_name}, $main::p_sig_e_routeRule{$sig_name}, "is_mcp: $main::p_sig_is_mcp{$sig_name}") ;
        }
    }

    print AdjacentParRep "\n# RT => RT && IS_MCP == 1\n" ;
    if ($stype eq 'ipo') {
        printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s\n", "#<Signal Name>", "<Feedthr Partitions>", "<End Clk>", "<Mann Dist>", "<Real Dist>", "<Source Port Dist>", "<Dest Port Dist>", "<Start routeRule>", "<End routeRule>", "is_mcp: <\${is_mcp}>" ) ;
    } else {
        printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s\n", "#<Signal Name>", "<Feedthr Partitions>", "<End Clk>", "<Mann Dist>", "<Ideal Dist>", "<Source Port Dist>", "<Dest Port Dist>", "<Start routeRule>", "<End routeRule>", "is_mcp: <\${is_mcp}>" ) ;
    }

    foreach my $sig_name (sort {$main::p_AdjParRT2RT_mcp{$b} <=> $main::p_AdjParRT2RT_mcp{$a}} keys %main::p_AdjParRT2RT_mcp) {
        if ($stype eq 'ipo') {
            printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s # RT => RT & MCP == 1\n", $sig_name, $main::p_max_feed_pars{$sig_name}, $main::p_max_end_clk{$sig_name}, $main::p_max_man_dist{$sig_name}, $main::p_max_real_dist{$sig_name}, $main::p_max_source_port_dist{$sig_name}, $main::p_max_dest_port_dist{$sig_name}, $main::p_sig_s_routeRule{$sig_name}, $main::p_sig_e_routeRule{$sig_name}, "is_mcp: $main::p_sig_is_mcp{$sig_name}") ;
        } else {
            printf AdjacentParRep ("%-80s\t%-40s\t\t%10s%10s\t%10s\t%10s\t%10s\t%s\t%s\t%s  # RT => RT & MCP == 1\n", $sig_name, $main::p_max_feed_pars{$sig_name},$main::p_max_end_clk{$sig_name}, $main::p_max_man_dist{$sig_name}, $main::p_max_ideal_dist{$sig_name}, $main::p_max_source_port_dist{$sig_name}, $main::p_max_dest_port_dist{$sig_name}, $main::p_sig_s_routeRule{$sig_name}, $main::p_sig_e_routeRule{$sig_name}, "is_mcp: $main::p_sig_is_mcp{$sig_name}") ;
        }
    }

    close AdjacentParRep ;

    print "    Start to Dump Detour plot file @ " . `date` . "\n" ;
    open DetourPlot, ">${rep_name}.detour_plot.medic" or die $!;
        
    foreach my $id (sort keys %main::p_detour_plot_rep) {
        print DetourPlot "$main::p_detour_plot_rep{$id}\n" ;
    }

    close DetourPlot ;

    print "    Start to Dump Histogram file @ " . `date` . "\n" ;
    foreach my $vio (@main::selected_vios) {
        my $id = attr_of_vio (id => $vio) ;
        #print "$id m: $main::p_man_dist{$id} r: $main::p_real_dist{$id} i: $main::p_ideal_dist{$id} s: $main::share_variables{"DIST_HISTOGRAM_SCALE"} \n" ;
        $main::p_dist_histogram_mann{ get_histogram_idx($main::p_man_dist{$id}, $main::share_variables{"DIST_HISTOGRAM_SCALE"}, $main::share_variables{"DIST_HISTOGRAM_MIN"}, $main::share_variables{"DIST_HISTOGRAM_MAX"}) } += 1;
        $main::p_dist_histogram_real{ get_histogram_idx($main::p_real_dist{$id}, $main::share_variables{"DIST_HISTOGRAM_SCALE"}, $main::share_variables{"DIST_HISTOGRAM_MIN"}, $main::share_variables{"DIST_HISTOGRAM_MAX"}) } += 1;
        $main::p_dist_histogram_ideal{ get_histogram_idx($main::p_ideal_dist{$id}, $main::share_variables{"DIST_HISTOGRAM_SCALE"}, $main::share_variables{"DIST_HISTOGRAM_MIN"}, $main::share_variables{"DIST_HISTOGRAM_MAX"}) } += 1;
        $main::p_detour_histogram{ get_histogram_idx_decimal($main::p_detour_ratio{$id}, 0.1, 1.0, 2.0) } += 1;
        # re-annotate the vio attribute
        set_vio_attr($vio, man_distance           => $main::p_man_dist{$id}); 
        set_vio_attr($vio, detour_ratio           => $main::p_detour_ratio{$id}) ;
        set_vio_attr($vio, feed_pars              => $main::p_feed_pars{$id});
        set_vio_attr($vio, feed_pars_num          => $main::p_feed_pars_num{$id});
        set_vio_attr($vio, longest_par_net        => $main::p_longest_par_net{$id});
        set_vio_attr($vio, longest_par_net_length => $main::p_longest_par_net_length{$id});
        set_vio_attr($vio, start_unit             => $main::p_start_unit{$id});
        set_vio_attr($vio, end_unit               => $main::p_end_unit{$id});
        set_vio_attr($vio, par_num                => $main::p_par_num{$id});
        set_vio_attr($vio, module_split_by_par    => $main::p_module_split_by_par{$id});
        set_vio_attr($vio, real_distance          => $main::p_real_dist{$id});
        set_vio_attr($vio, ideal_distance         => $main::p_ideal_dist{$id});
        set_vio_attr($vio, is_mcp                 => $main::p_is_mcp{$id});
        set_vio_attr($vio, mcp_setup_num          => $main::p_mcp_setup_num{$id});
        set_vio_attr($vio, bin_man_distance       => $main::p_bin_man_distance{$id});
        set_vio_attr($vio, bin_ideal_distance     => $main::p_bin_ideal_distance{$id});
        set_vio_attr($vio, bin_real_distance      => $main::p_bin_real_distance{$id});
        set_vio_attr($vio, sig_name               => $main::p_sig_name{$id});
    }

    open Histogram,     ">${rep_name}.distance.HISTOGRAM" or die $!;

    printf Histogram ("%s\n\n", "Summary for ${top}, report=${rep_name}") ;
    printf Histogram ("%7s\t%-10s\t%-10s\t%-10s\n", " ", "Mann", "Ideal", "Real") ;
    ## syntax is Numeric sort
    foreach my $loop (sort {$a <=> $b} (keys %main::p_dist_histogram_mann)) {
        my $sign = " ";
        if ($loop eq $main::share_variables{"DIST_HISTOGRAM_MIN"}) { $sign = "<"; }
        if ($loop eq $main::share_variables{"DIST_HISTOGRAM_MAX"}) { $sign = ">"; }
        printf Histogram ("%s %5s\t%-10s\t%-10s\t%-10s\n", $sign, $loop, $main::p_dist_histogram_mann{$loop}, $main::p_dist_histogram_ideal{$loop}, $main::p_dist_histogram_real{$loop}) ;
    }

    print Histogram "\n\tMultiplier\n";
    ## syntax is Numeric sort
    foreach my $loop (sort {$a <=> $b} (keys %main::p_detour_histogram)) {
        my $sign = " ";
        if ($loop == 2.0) { $sign = ">"; }
        printf Histogram ("%s %5s\t%-10s\n", $sign, $loop, $main::p_detour_histogram{$loop}) ;
    }

    close (Histogram);

    print "    Start to Retime/Detour Summary file @ " . `date` . "\n" ;

    open RDSum,         ">${rep_name}.retime_detour.sum" or die $!;

    my $RETIME_DISTANCE                 = $main::share_variables{"RETIME_DISTANCE"};
    my $RETIME_DISTANCE_for_inter       = (int (($RETIME_DISTANCE/200) * 0.8)) * 100;
    my $DIST_HISTOGRAM_SCALE            = $main::share_variables{"DIST_HISTOGRAM_SCALE"};
    my $DIST_HISTOGRAM_MAX              = $main::share_variables{"DIST_HISTOGRAM_MAX"};
    my $MAN_DISTANCE_max_step           = (int (($DIST_HISTOGRAM_MAX - $RETIME_DISTANCE)/$DIST_HISTOGRAM_SCALE) + 1 );
    my $MAN_DISTANCE_max_step_for_inter = (int (($DIST_HISTOGRAM_MAX/2 - $RETIME_DISTANCE_for_inter)/$DIST_HISTOGRAM_SCALE) + 1);

    print RDSum "For this summary, per stage retime distance is $RETIME_DISTANCE for intra-chiplet, and it is $RETIME_DISTANCE_for_inter for inter-chiplet retime analysis.\n\n";

    print RDSum "Summary for ${top} inter-chiplet distance based on report ${rep_name}: \n";
    print RDSum (join "\n", (report_vios (-filter=>"is_io", -by=>"end_clk", -show=>"bin(man_distance,-step, ${RETIME_DISTANCE_for_inter}, ${DIST_HISTOGRAM_SCALE}, ${MAN_DISTANCE_max_step_for_inter}) worst(man_distance) count(id)"))) ;
    print RDSum "\n\n" ;
    
    print RDSum "Summary for ${top} intra-chiplet distance based on report ${rep_name}: \n";

    print RDSum (join "\n", (report_vios (-filter=>"!is_io", -by=>"end_clk", -show=>"bin(man_distance,-step, ${RETIME_DISTANCE}, ${DIST_HISTOGRAM_SCALE}, ${MAN_DISTANCE_max_step}) worst(man_distance) count(id)"))) ;
    print RDSum "\n\n" ;

    print RDSum "Summary for ${top} inter-chiplet detour based on report ${rep_name}: \n";

    print RDSum (join "\n", (report_vios (-filter=>"is_io and 'man_distance > ${RETIME_DISTANCE}' and 'detour_ratio >= 1.2'", -by=>"end_clk", -show=>"bin(detour_ratio,-step, 1.2,0.1,9) worst(detour_ratio) count(id)"))) ;
    print RDSum "\n\n" ;
    
    print RDSum "Summary for ${top} intra-chiplet detour based on report ${rep_name}: \n";

    print RDSum (join "\n", (report_vios (-filter=>"!is_io and 'man_distance > ${RETIME_DISTANCE}' and 'detour_ratio >= 1.2'", -by=>"end_clk", -show=>"bin(detour_ratio,-step, 1.2,0.1,9) worst(detour_ratio) count(id)"))) ; 

    close (RDSum);
    
    print "    Start to unified retime report file @ " . `date` . "\n" ;
    uniqReport($rep_name);
    
    print "    All done @ " . `date` ;

}


sub get_dist_pinArray {
   my @pin_list = @_;
   my $pin_list_size = scalar @pin_list;

   my $RC = 0;
   for ($idx = 0; $idx < $pin_list_size-1; $idx++) {
	$RC += get_dist (@pin_list[$idx] => @pin_list[$idx+1]);
   }

   return $RC;
}

sub get_histogram_idx {
   my ($distance , $scale, $min, $max) = @_;

   my $myIdx = int ($distance / $scale) * $scale ;
   if ( $myIdx > $max ) { $myIdx = $max; }
   if ( $myIdx < $min ) { $myIdx = $min; }

   return $myIdx;
}

sub get_histogram_idx_decimal {
   my ($distance , $scale, $min, $max) = @_;

   my $distance_mod = $distance * 10;
   my $scale_mod = $scale * 10;
   my $min_mod = $min * 10;
   my $max_mod = $max * 10;

   my $myIdx_mod = get_histogram_idx($distance_mod, $scale_mod, $min_mod, $max_mod);

   return ($myIdx_mod / 10);
}

sub get_feed_pars {
	#give net, this routine gives list of pars that net has to cross
	#make sure you run below commands before calling this function
	#set_verilog_build_from_layout
  	#set_libs_default_none
  	#load_coff_data /home/gv100_layout/tot/layout/revP3.0/blocks/gv100_top/control/hcoff.data
  	#set_chip_top NV_gva_ff0
	my $net = shift;
	my $end_par_u = shift;
	my $top = shift;
	my $end_par = lc($end_par_u);
	my @parList;
	return if(is_power_net($net)); #skip power nets
	my $driver; ($driver) = get_drivers ($net);
	my @loads = get_loads($net);
	return if(scalar(@loads) < 1);
	if(is_port($driver)) {#if port assign one loads
		($driver) = shift(@loads);
	}
	my $dpar = partition_inst_of_pin ($driver);
	my ($dx,$dy) = get_object_xy ($dpar);
	foreach $load (@loads) { #loop through each load and get farthest load
		next if(is_port($load)); #skip chiplet/nv_top ports
		my @temp; #array to check farthest load
		my $lpar = partition_inst_of_pin($load);	
		if($lpar ne $dpar) {
		   if ($end_par eq $lpar) {
			if ( (($dpar !~ /TPC/) && ($lpar !~ /TPC/)) && (($dpar !~ /GAA0SC/) && ($lpar !~ /GAA0SC/))) {
		    	if (!(tl_is_abutted ($lpar,$dpar))) {
		    	my ($lx,$ly) = get_object_xy ($lpar);
		    	my @flist = tl_get_crossed_edges(-min_cross => $dx,$dy,$lx,$ly,$dpar,$lpar);
		    	  foreach $a (@flist) {
		    	  	my $par = $a->[0];#parInst	
		    	  	push(@temp, $par) if($temp[-1] ne $par);
		    	  }
		    	} else {
		    		push(@temp,$dpar);
		    		push(@temp,$lpar);
		        } 
			} else {
		    	  push(@temp,$dpar);
		          push(@temp,$lpar);
			}
		  } else {
			  push(@temp,$dpar);
			  push(@temp,$end_par);
		  }
	} else {
		push(@temp,$lpar);
    }
   if(scalar(@temp) > scalar(@parList)) { #assing farthest load
			@parList = @temp;
		}
  }
	return @parList;
}

sub get_feed_pars_for_pars {
	my $spar_u = shift;
	my $spar = lc($spar_u);
	my $epar_u = shift;
	my $epar = lc($epar_u);
	my @parList;
	return $spar if($spar eq $epar);
    if (!(tl_is_abutted ($spar,$epar))) {
	  my ($dx,$dy) = get_object_xy ($spar);
	  my ($lx,$ly) = get_object_xy ($epar);
	  my @flist = tl_get_crossed_edges(-min_cross => $dx,$dy,$lx,$ly,$spar,$epar);
	  foreach $a (@flist) {
	  	my $par = $a->[0];#parInst	
	  	push(@parList, $par) if($parList[-1] ne $par);
	  }
	} else {
		  push(@parList,$spar);
		  push(@parList,$epar);
	}

	return @parList;
}

sub partition_inst_of_pin {
	my $pin = shift;
	#my ($up_pin_hier, $up_module, $sub_inst, $sub_ref, $sub_ref_pin) = get_pin_context_whier($pin);
	my @up_pin_hier = get_pin_context_whier($pin);
	$up_pin_hier = @up_pin_hier[0];
	#@par_hier=grep(is_partition_module($_->[1]),get_hier_list_txt (-of_pin => $pin)); 
	#@chiplet_hier=grep(is_chiplet_module($_->[1]),get_hier_list_txt (-of_pin => $pin)); 
	#$up_pin_hier = lc($par_hier[0]->[1]);
	#$up_chiplet_hier = lc($chiplet_hier[0]->[1]);
	if (!is_partition_inst($up_pin_hier)) {
		my $uphier = get_up_inst ($up_pin_hier);
		$up_pin_hier = $uphier;
	}
	return ($up_pin_hier);
}

sub session_type {
    my $block=get_root_parent();
    my $gv_file = $M_file_gv{$block};
    my ($view) = $gv_file =~ /.*\/$block\.(.*)\.gv/;
    # view = (noscan|mbist|feflat|flat|layout/ipo/anno|pretp)
    if ($view =~ /noscan/ && $view !~ /pnr/) { #noscan.flat, noscan.par
    	    $view = "noscan";
    } elsif ($view =~ /ipo\d+$/) {
    	    $view = "anno";
    } elsif ($view =~ /FE_flat$/) {
    	    $view = "feflat";
    } elsif ($view =~ /flat$/) {
    	    $view = "flat";
    } elsif ($view =~ /pretp$/) {
    	    $view = "pretp";
    } elsif ($view =~ /mbist$/) {
    	    $view = "mbist";
    } elsif ($view =~ /noscan/ && $view =~ /pnr/) {
    	    $view = "noscan_pnrprecheck";
    }else {
    	    $view = "layout";
    }
    # there's issue if the top netlist is a soft link in TOT
    # example in GA103, nv_top.flat.gv.gz -> nv_top.FE_flat.gv.gz, the flow returns feflat instead of flat
    if ($ENV{TS_VIEW} ne "") {
        $type = $ENV{TS_VIEW}; 
    } else {
        $type = $view; 
    }
    return ($type);
}

sub uniqReport {
    (my $rep_name) = @_; 
    my @lines = ();
    open R, "${rep_name}.full_retime.report";
    open UR, ">${rep_name}.uniq_retime.report";

    my $type          = $ENV{NAHIER_TYPE} ;
    # to sort by man_dist if noscan or feflat
    my %mcped_att       = () ;
    my %non_mcped_att   = () ;
    my %mcped           = () ;
    my %non_mcped       = () ;
    my %mcped_att_d     = () ;
    my %non_mcped_att_d = () ;
    my %mcped_d         = () ;
    my %non_mcped_d     = () ;

    print UR "# Each column is: signal_name, end-clk, feed-pars, mann-dist, ideal-dsit\n" ;
    print UR "# !!! ideal_dist and feed_pars could be inaccurate without <par>_hfp.def\n\n" ;

    while (<R>) {
        #$line =~ s/\[[0-9]+\]/.*/g ;
        #@line_arr = split (/\t/, $line);
        #if (! (grep (/$line_arr[0]/, @lines))) {
        #    push (@lines, $line_arr[0]); 
        #    print UR $line;
        #}
        chomp ;
        my $line = $_ ;
        if ($line =~ /^\#/) {
            next ;
        } else {
            if ($line =~ /^ATTENTION : (\S+?)\s+.*\s+(\S+?)\s+(\S+?)\s+is_mcp: (\d)/) {
                my $s_name = $1 ;
                my $m_dist = $2 ;
                my $r_dist = $3 ;
                my $is_mcp = $4 ;
                $s_name =~ s/\[[0-9]+\]/.*/g ;
                $line   =~ s/^ATTENTION : \S+?\s+(.*)/$1/ ;
                if ($is_mcp) {
                    $mcped_att{$s_name} = $line ;
                    if ($type eq "noscan" || $type eq "feflat") {
                        $mcped_att_d{$s_name} = $m_dist ;
                    } else {
                        $mcped_att_d{$s_name} = $r_dist ; 
                    }
                } else {
                    $non_mcped_att{$s_name} = $line ;
                    if ($type eq "noscan" || $type eq "feflat") {
                        $non_mcped_att_d{$s_name} = $m_dist ;
                    } else {
                        $non_mcped_att_d{$s_name} = $r_dist ; 
                    }
                }
            } elsif ($line =~ /^(\S+?)\s+.*\s+(\S+?)\s+(\S+?)\s+is_mcp: (\d)/) {
                my $s_name = $1 ;
                my $m_dist = $2 ;
                my $r_dist = $3 ;
                my $is_mcp = $4 ;
                $s_name =~ s/\[[0-9]+\]/.*/g ;
                $line   =~ s/\S+?\s+(.*)/$1/ ;
                if ($is_mcp) {
                    $mcped{$s_name} = $line ;
                    if ($type eq "noscan" || $type eq "feflat") {
                        $mcped_d{$s_name} = $m_dist ;
                    } else {
                        $mcped_d{$s_name} = $r_dist ;
                    }
                } else {
                    $non_mcped{$s_name} = $line ;
                    if ($type eq "noscan" || $type eq "feflat") {
                        $non_mcped_d{$s_name} = $m_dist ;
                    } else {
                        $non_mcped_d{$s_name} = $r_dist ;
                    }
                }

            }
        } 
    }


    # start to dump the file ;
    print UR "#################\n" ;
    print UR "### IMPORTANT ###\n" ;
    print UR "#################\n\n" ;

    print UR "IS_MCP == 0 : \n\n" ;
    foreach my $s_name (sort {$non_mcped_att_d{$b} <=> $non_mcped_att_d{$a}} keys %non_mcped_att_d) {
        printf UR ("ATTENTION : %-100s %s\n", $s_name, $non_mcped_att{$s_name}) ;
    }

    print UR "\n" ;
    print UR "IS_MCP == 1 : \n\n" ;
    foreach my $s_name (sort {$mcped_att_d{$b} <=> $mcped_att_d{$a}} keys %mcped_att_d) {
        printf UR ("ATTENTION : %-100s %s\n", $s_name, $mcped_att{$s_name}) ;
    }

    print UR "\n" ;
    print UR "####################\n" ;
    print UR "### NORMAL PATHS ###\n" ;
    print UR "####################\n\n" ;

    print UR "IS_MCP == 0 : \n\n" ;
    foreach my $s_name (sort {$non_mcped_d{$b} <=> $non_mcped_d{$a}} keys %non_mcped_d) {
        printf UR ("%-100s %s\n", $s_name, $non_mcped{$s_name}) ;
    }
    
    print UR "\n" ;
    print UR "IS_MCP == 1 : \n\n" ;
    foreach my $s_name (sort {$mcped_d{$b} <=> $mcped_d{$a}} keys %mcped_d) {
        printf UR ("%-100s %s\n", $s_name, $mcped{$s_name}) ;
    }
    
    close R;
    close UR;
}

sub genUnitNameHash {
    my $config = CadConfig::factory();
    my %unit_hier_mapping;
    my @all_units = sort(keys(%{$config->{partitioning}->{units}}));
    my %hash_units;
    @all_units = grep { ++$hash_units{$_} < 2 } @all_units;

    ### Generate unit -> hier_name hash
    foreach my $unit (@all_units) {
        if (%{$config->{partitioning}->{units}{$unit}{"partition"}}) {
            foreach my $s_par (keys(%{$config->{partitioning}->{units}{$unit}{"partition"}})) {
                my @inst_names = split(',',$config->{partitioning}->{units}{$unit}{"partition"}{$s_par});
                foreach my $inst_name (@inst_names) {
                    $unit_hier_mapping{"$s_par/$inst_name"} = $unit;
                }
            }
        }
    }
    return %unit_hier_mapping;
}

sub mapPinUnit {
    (my $pin,my %unit_hier_mapping) = @_;
    foreach my $unit_hier (keys %unit_hier_mapping) {
        if ($pin =~ /$unit_hier/) {
            return $unit_hier_mapping{$unit_hier};
        }
    }
    return "";
}

sub expand_chiplet_in_partitions {
    # expand all chiplet partition/ sub-chiplet partitions in array.
    my ($top,@par_hier) = @_;
    my @all_cells;
    if ($top eq "") {
        @all_cells = get_cells(-quiet => "*");
    } else {
        @all_cells = get_cells(-quiet => $top."/*");
    }
    if (scalar(@all_cells) > 0) {
        foreach my $s_cell (@all_cells) {
            my $s_ref_name = attr_of_cell(ref_name,name_of_cell($s_cell));
            if (attr_of_ref(is_chiplet,$s_ref_name) == 1) {
                ($top,@par_hier) = expand_chiplet_in_partitions(name_of_cell($s_cell),@par_hier);
            } elsif (attr_of_ref(is_partition,$s_ref_name) == 1) {
                push(@par_hier,$s_cell);
            }
        }
    }
    return ($top,@par_hier);
}

sub is_stub_chiplet {
    (my $top) = @_;
    if ($top eq "") {
        @all_cells = get_cells(-quiet => "*");
    } else {
        @all_cells = get_cells(-quiet => $top."/*");
    } 
    my $s_ref_name = attr_of_cell(ref_name,name_of_cell($top));
    my $scalar = @all_cells;
    if ((attr_of_ref(is_chiplet,$s_ref_name) == 1) && ($scalar == 0)) {
        return 1;
    }
    return 0;
}

sub expand_sub_chiplets {
    # expand all chiplet partition/ sub-chiplet partitions in array.
    my ($top,@sub_chiplet_hier) = @_;
    my @all_cells;
    if ($top eq "") {
        @all_cells = get_cells(-quiet => "*");
    } else {
        @all_cells = get_cells(-quiet => $top."/*");
    }
    if (scalar(@all_cells) > 0) {
        foreach my $s_cell (@all_cells) {
            my $s_ref_name = attr_of_cell(ref_name,name_of_cell($s_cell));
            if (attr_of_ref(is_chiplet,$s_ref_name) == 1) {
                push(@sub_chiplet_hier,$s_cell);
                ($top,@sub_chiplet_hier) = expand_sub_chiplets(name_of_cell($s_cell),@sub_chiplet_hier);
            }
        }
    }
    return ($top,@sub_chiplet_hier);
}

Tsub GetVioSigName => << 'END' ;
    DESC {
        to get the RTL net name of one violation.
    }
    ARGS {
        $vio
    }

    my @pins      = split (" ", (attr_of_vio ('pin_list' => $vio))) ;
    my @hier_pins = grep (attr_of_pin (is_hier => $_), @pins) ;

    my @sig_names = () ;

    foreach my $pin (@hier_pins) {
        if (is_port $pin) {
            push @sig_name, $pin ;
        } else {
            my ($par, $par_ref, $pin_name) = get_pin_context $pin ;
            if ((is_partition_module $par_ref) && (exists $M_noscan_port_mapping{$par_ref}{$pin_name})){
                $pin_name =~ s/\[\d+\]$// ;
                push @sig_names, $pin_name ;
            } else {
                next ;
            }
        }
    }

    if ($#sig_names != -1) {
        return $sig_names[0] ;
    } else {
        return "NA" ;
    }

END

Tsub GetSourcePortDist => << 'END' ;
    DESC {
        get the dist between violation start_pin and start_par_cell port.
    }
    ARGS {
        $vio
    }

    my $start_pin    = attr_of_vio (start_pin => $vio) ;
    my $start_par    = attr_of_vio (start_par => $vio) ;
    my @hier_port    = grep (attr_of_pin (is_hier, $_), split (" ", attr_of_vio (pin_list => $vio))) ;
    my @source_ports = () ;
    my $dist ;

    foreach my $port (@hier_port) {
        if (is_port $port) {
            push @source_ports, $port ;
        } else {
            my @pin_context = get_pin_context ($port) ;
            if ($pin_context[1] eq $start_par) {
                #$dist = get_dist ($port, $start_pin) ; 
                push @source_ports, $port ;
            }
        }
    }

    if ($#source_ports > 0) {
        $dist = get_dist ($start_pin, $source_ports[0]) ;
    } elsif ($#source_ports == -1) {
        $dist = 0 ;
    } else {
        $dist = get_dist ($start_pin, $source_ports[0]) ;
    }

    return $dist ;

END

Tsub GetDestPortDist => << 'END' ;
    DESC {
        get the dist between violation end_pin and end_par_cell port.
    }
    ARGS {
        $vio
    }

    my $end_pin    = attr_of_vio (end_pin => $vio) ;
    my $end_par    = attr_of_vio (end_par => $vio) ;
    my @hier_port  = grep (attr_of_pin (is_hier, $_), split (" ", attr_of_vio (pin_list => $vio))) ;
    my @dest_ports = () ;
    my $dist ;

    foreach my $port (@hier_port) {
        if (is_port $port) {
            push @dest_ports, $port ;
        } else {
            my @pin_context = get_pin_context ($port) ;
            if ($pin_context[1] eq $end_par) {
                #$dist = get_dist ($port, $end_pin) ;
                push @dest_ports, $port ;
            }
        }
    }

    if ($#dest_ports > 0) {
        $dist = get_dist ($end_pin, $dest_ports[-1]) ;
    } elsif ($#dest_ports == -1) {
        $dist = 0 ;
    } else {
        $dist = get_dist ($end_pin, $dest_ports[0]) ;
    }

    return $dist ;

END

Tsub GetSourceCoor => << 'END' ;
    DESC {
        get the violation start pin coordinate.
    }
    ARGS {
        $vio
    }

    my $start_pin = attr_of_vio (start_pin => $vio) ;
    my @coor      = get_pin_xy $start_pin ;

    return "$coor[0],$coor[1]" ;

END

Tsub GetDestCoor => << 'END' ;
    DESC {
        get the violation end pin coordinate.
    }
    ARGS {
        $vio
    }

    my $end_pin = attr_of_vio (end_pin => $vio) ;
    my @coor    = get_pin_xy $end_pin ;

    return "$coor[0],$coor[1]" ;

END

Tsub GetStartRouteRule => << 'END' ;
    DESC {
        get the violation start pin routeRules.
    }
    ARGS {
        $vio
    }

    #my $start_pin = attr_of_vio (start_pin => $vio) ;
    my @pin_list  = split (" ", attr_of_vio (pin_list => $vio)) ;;
    my $start_pin = $pin_list[1] ;
    my $routeRule = get_rule_of_pin ($start_pin) ;

    return $routeRule ;

END

Tsub GetEndRouteRule => << 'END' ;
    DESC {
        get the violation end pin routeRules.
    }
    ARGS {
        $vio
    }

    my $end_pin = attr_of_vio (end_pin => $vio) ;
    my $routeRule = get_rule_of_pin ($end_pin) ;

    return $routeRule ;

END

Tsub get_rule_of_pin => << 'END';
    DESC {
        To get the routeRule of retime flop pin
    }
    ARGS {
        $pin   ,
    }

    if (!$pin) {
        error "No pin listed.\n" ;
        return () ;
    }

    if (get_port (-quiet, $pin)) {
        return "NA" ;
    }

    if (!(get_pins (-quiet, $pin))) {
        error "$pin not found.\n" ;
        return () ;
    }

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
            foreach my $chiplet (sort keys %M_routeRules_pipe) {
                foreach my $rule (sort keys %{$M_routeRules_pipe{$chiplet}}) {
                    if (exists $M_routeRules_pipe{$chiplet}{$rule}{$pipe}) {
                        return "$chiplet $rule $pipe" ;
                    }
                }
            }
            return "NA" ;
    } else {
        return "NA" ;
    }

END

Tsub load_port_map_file => << 'END' ;
    DESC {
        to load the port mapping file.
    }
    ARGS {
    }

    %M_noscan_port_mapping = () ;

    my $proj = $ENV{NV_PROJECT} ;
    my $rev  = $ENV{USE_LAYOUT_REV} ;
    my %all_mods = map  ({$_ => 1} (get_modules "*")) ;
    my @chiplets = grep ((exists $all_mods{$_}), (all_chiplets)) ;

    foreach my $top (@chiplets) {
        my $portmap_file = "/home/${proj}_layout/tot/layout/${rev}/blocks/${top}/noscan_cfg/${top}.noscan.portmap" ;

        if (-e $portmap_file) {
            print "Loading $portmap_file ...\n" ;
            open IN, "$portmap_file" ;
            while (<IN>) {
                chomp ;
                my $line = $_ ;
                if ($line =~ /^\w+/) {
                    # partition_module partition_port  cell cell_inst cell_pin
                    my ($par_ref, $par_port, $unit_name, $unit_inst, $unit_port) = split (" ", $line) ;
                    $par_port =~ s/^\\// ;
                    $M_noscan_port_mapping{$par_ref}{$par_port} = 1 ;
                }
            }
            close IN ;
        } else {
            error "Can't find portmap file : $portmap_file\n" ;
        }
    }

    return 1 ;

END

Tsub load_routeRules_files => << 'END' ;
    DESC  {
        to parse the route Rule files in mender session
    }
    ARGS {
    }

    %M_routeRules      = () ;
    %M_routeRules_pipe = () ;
    $chiplet_uc        = "" ;

    my %all_mods = map  ({$_ => 1} (get_modules "*")) ;
    my @chiplets = grep ((exists $all_mods{$_}), (all_chiplets)) ;

    my $litter = $CONFIG->{LITTER_NAME} ;
    my $chip_root = `depth` ;
    chomp $chip_root ;

    my $routeRulesdir = "$chip_root/ip/retime/retime/1.0/vmod/include/interface_retime" ;
    foreach my $block (@chiplets) {
        my $chiplet        = $block ;
        $chiplet           =~ s/NV_(.*)/$1/ ;
        $chiplet_uc     = uc $chiplet ;
        my $routeRulesFile = "$routeRulesdir/interface_retime_${litter}_${chiplet_uc}_routeRules.pm" ;
        if (-e $routeRulesFile) {
            `p4 sync $routeRulesFile` ;
            #print "Loading routeRules file : $routeRulesFile\n" ;
            load "$routeRulesFile" ;
        } else {
            next ;
        }
    }

    foreach my $chiplet (sort keys %M_routeRules) {
        foreach my $rule_name (sort keys %{$M_routeRules{$chiplet}}) {
            if (exists $M_routeRules{$chiplet}{$rule_name}{pipeline_steps}) {
                foreach my $pipe (split (",", $M_routeRules{$chiplet}{$rule_name}{pipeline_steps})) {
                    $M_routeRules_pipe{$chiplet}{$rule_name}{$pipe} = 1 ;
                }
            }
            if (exists $M_routeRules{$chiplet}{$rule_name}{tap}) {
                foreach my $tap_num (sort keys %{$M_routeRules{$chiplet}{$rule_name}{tap}}) {
                    if (exists $M_routeRules{$chiplet}{$rule_name}{tap}{$tap_num}{pipeline_steps}) {
                        foreach my $pipe (split (",", $M_routeRules{$chiplet}{$rule_name}{tap}{$tap_num}{pipeline_steps})) {
                            $M_routeRules_pipe{$chiplet}{$rule_name}{$pipe} = 1 ;
                        }
                    }
                }
            }
        }
    }

    return 1 ;

END

Tsub AddRouteRule => << 'END' ;
    DESC {
        a dummy function for parsing the interface_retime_*.pm files
    }
    ARGS {
        @args
    }

    my %in = @args ;

    my $rule_name = $in{name} ;
    foreach my $key (sort keys %in) {
        $M_routeRules{$chiplet_uc}{$rule_name}{$key} = $in{$key} ;
    }

    return 1 ;

END

