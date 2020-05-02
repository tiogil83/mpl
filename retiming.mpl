use strict ;

# global vars 
our $chiplet_uc ;
our %M_routeRules ;
our %M_routeRules_pipe ;
our %M_noscan_port_mapping ;
our %M_retime_interf ;

Tsub get_net_fi_fo_clks => << 'END' ;
    DESC {
        To get the fanin and fanout clocks in mender session
    }
    ARGS {
        $net_name  # net name or pin name
    }

    my %path  = () ;
    my @fis = get_fan2 (-end, -fanin => (get_nets $net_name)) ;
    my @fos = get_fan2 (-end, -fanout => (get_nets $net_name)) ;


    foreach my $fi (@fis) {
        $fi =~ s/(\S+)\s+.*/$1/ ;
        unless (is_port $fi) {
            foreach my $fo (@fos) {
                $fo =~ s/(\S+)\s+.*/$1/ ;
                unless (is_port $fo) {
                    my $rtn_d = get_path_delay (-from => $fi, -to => $fo, -rtn_delay, -quiet, -wire_model => 'none') ;
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
    } else {
        $clk_name = "" ;
        #print "Double check $cg_pin\n" ;
    }

    if ($clk_name eq "xtal_clk") {
        $clk_name = "xtal_in" ;
    }

    return $clk_name ;

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
        return "$cp_pin_name[0]" ;
    } else {
        print "ERROR: $pin_name had multi-cp\n";
        return () ;
    }

END


Tsub load_routeRules_files => << 'END' ;
    DESC  {
        to parse the route Rule files in mender session 
    }
    ARGS {
    }

    %M_routeRules       = () ;
    %M_routeRules_pipe  = () ;
    $chiplet_uc       = "" ;

    my @chiplets = all_chiplets ;

    my $litter = $CONFIG->{LITTER_NAME} ; 
    my $chip_root = `depth` ;
    chomp $chip_root ;

    my $routeRulesdir = "$chip_root/ip/retime/retime/1.0/vmod/include/interface_retime" ;
    foreach my $block (@chiplets) {
        my $chiplet        = $block ;
        $chiplet           =~ s/NV_(.*)/$1/ ;
        $chiplet_uc     = uc $chiplet ; 
        my @routeRulesFiles = glob "$routeRulesdir/interface_retime_${litter}_${chiplet_uc}*.pm" ; 
        foreach my $routeRulesFile (@routeRulesFiles) { 
            if (-e $routeRulesFile) {
                `p4 sync $routeRulesFile` ; 
                #print "Loading routeRules file : $routeRulesFile\n" ;
                load "$routeRulesFile" ;
            } else {
                next ;
            }
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

Tsub get_rule_of_step => << 'END' ;
    DESC {
        To get the routeRule of the pipeline step 
    }
    ARGS {
        $pipe_step
    }

    my @rules = sort keys %M_routeRules_pipe ;
    if ($#rules == -1) {
        load_routeRules_files ;
    } 

    foreach my $chiplet (sort keys %M_routeRules_pipe) {
        foreach my $rule (sort keys %{$M_routeRules_pipe{$chiplet}}) {
            if (exists $M_routeRules_pipe{$chiplet}{$rule}{$pipe_step}) {
                return "$chiplet $rule" ;
            }
        }
    }

    return 0 ;

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

    my @rules = sort keys %M_routeRules_pipe ;
    if ($#rules == -1) {
        load_routeRules_files ;
    } 
    
    if (defined $d) {
        foreach my $key (sort keys %M_routeRules_pipe) {
            print "Rule : $key\n" ;
        }
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
                        return "$chiplet $rule" ;
                    } 
                }
            }
            return "NA" ;
    } else {
        return "NA" ;
    }


END

Tsub set_retiming_violation_attr => << 'END' ;
    DESC {
        to set the retiming related violation attributions.
    }
    ARGS {
    }

    define_vio_attr (-class => "path", -is_num => 0, -code_ptr => \&GetStartRouteRule, -attr => 'start_routeRule');
    define_vio_attr (-class => "path", -is_num => 0, -code_ptr => \&GetEndRouteRule, -attr => 'end_routeRule');
    define_vio_attr (-class => "path", -is_num => 0, -code_ptr => \&GetSourceCoor, -attr => 'source_coor');
    define_vio_attr (-class => "path", -is_num => 0, -code_ptr => \&GetDestCoor, -attr => 'dest_coor');
    define_vio_attr (-class => "path", -is_num => 1, -code_ptr => \&GetSourcePortDist, -attr => 'source_port_dist') ;
    define_vio_attr (-class => "path", -is_num => 1, -code_ptr => \&GetDestPortDist, -attr => 'dest_port_dist') ;
    define_vio_attr (-class => "path", -is_num => 1, -code_ptr => \&GetManDist, -attr => 'man_dist') ;
    define_vio_attr (-class => "path", -is_num => 1, -code_ptr => \&GetRealDist, -attr => 'real_dist') ;
    define_vio_attr (-class => "path", -is_num => 0, -code_ptr => \&GetVioSigName, -attr => 'sig_name') ;

END

Tsub get_vio_by_id => << 'END' ;
    DESC {
        to get the violation through id number
    }
    ARGS {
        $id
    }

    my @vios = all_vios (-filter => "id eq \'$id\' and (type eq \"max\" or type eq \"min\")") ;
    return $vios[0] ;

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

Tsub get_start_routeRule => << 'END' ;
    DESC {
        get the violation start_pin routeRules.
    }
    ARGS {
        $id
    }

    my $vio       = get_vio_by_id ($id) ;
    my $routeRule = attr_of_vio ('start_routeRule' => $vio) ;
    
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

Tsub get_end_routeRule => << 'END' ;
    DESC {
        get the violation end_pin routeRules.
    }
    ARGS {
        $id
    }

    my $vio       = get_vio_by_id ($id) ;
    my $routeRule = attr_of_vio ('end_routeRule' => $vio) ;
    
    return $routeRule ;

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

Tsub get_source_coor => << 'END' ;
    DESC {
        get the violation start_pin coordinates.
    }
    ARGS {
        $id
    }

    my $vio  = get_vio_by_id ($id) ;
    my $coor = attr_of_vio ('source_coor' => $vio) ;
    
    return $coor ;

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

Tsub get_dest_coor => << 'END' ;
    DESC {
        get the violation end_pin coordinates.
    }
    ARGS {
        $id
    }

    my $vio  = get_vio_by_id ($id) ;
    my $coor = attr_of_vio ('dest_coor' => $vio) ;

    return $coor ;

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
        my @pin_context = get_pin_context ($port) ;
        if ($pin_context[1] eq $start_par) {
            #$dist = get_dist ($port, $start_pin) ; 
            push @source_ports, $port ;
        }
    } 

    if ($#source_ports > 0) {
        error ("check the detour for the path\n") ;
        return () ;
    } elsif ($#source_ports == -1) {
        $dist = 0 ;
    } else {
        $dist = get_dist ($start_pin, $source_ports[0]) ;
    }

    return $dist ;

END

Tsub get_source_port_dist => << 'END' ;
    DESC {
        get the dist between violation start_pin and start_par_cell port.
    }
    ARGS {
        $id
    }

    my $vio  = get_vio_by_id ($id) ;
    my $dist = attr_of_vio ('source_port_dist' => $vio) ;

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
        my @pin_context = get_pin_context ($port) ;
        if ($pin_context[1] eq $end_par) {
            #$dist = get_dist ($port, $end_pin) ;
            push @dest_ports, $port ;
        }
    } 

    if ($#dest_ports > 0) {
        error ("check the detour for the path\n") ;
        return () ;
    } elsif ($#dest_ports == -1) {
        $dist = 0 ;
    } else {
        $dist = get_dist ($end_pin, $dest_ports[0]) ;
    }

    return $dist ;

END

Tsub get_dest_port_dist => << 'END' ;
    DESC {
        get the dist between violation end_pin and end_par_cell port.
    }
    ARGS {
        $id
    }

    my $vio  = get_vio_by_id ($id) ;
    my $dist = attr_of_vio ('dest_port_dist' => $vio) ;

    return $dist ;

END

Tsub GetManDist => << 'END' ;
    DESC {
        get the manhattan distance between violation start_pin and end_pin. 
    }
    ARGS {
        $vio
    }

    my $dist      = 0 ;
    my $start_pin = attr_of_vio (start_pin => $vio) ;
    my $end_pin   = attr_of_vio (end_pin => $vio) ;
    $dist = get_dist ($start_pin, $end_pin) ;
    
    return $dist ;

END

Tsub get_man_dist => << 'END' ;
    DESC {
        get the manhattan distance between violation start_pin and end_pin.
    }
    ARGS {
        $id
    }

    my $vio  = get_vio_by_id ($id) ;
    my $dist = attr_of_vio ('man_dist' => $vio) ;

    return $dist ;

END

Tsub GetRealDist => << 'END' ;
    DESC {
        get the real distance between violation start_pin and end_pin.
    }
    ARGS {
        $vio
    }

    my $sum_dist = 0 ;
    my @pin_list = split (" ", attr_of_vio (pin_list => $vio)) ;

    foreach my $i (1..$#pin_list) {
        my $dist  = get_dist ($pin_list[$i], $pin_list[$i-1]) ;
        $sum_dist = $sum_dist + $dist ; 
    }

    return $sum_dist ;

END

Tsub get_real_dist => << 'END' ;
    DESC {
        get the real distance through all the path pins.
    }
    ARGS {
        $id
    }

    my $vio  = get_vio_by_id ($id) ;
    my $dist = attr_of_vio ('real_dist' => $vio) ;

    return $dist ;

END

Tsub dump_retime_vios => << 'END' ;
    DESC {
        to dump out the retime related violations.
        -m_dist : Manhattan Dist threshold. 1000um by default.
        -r_dist : Real Dist threshold. 1100um by default.
        -slack  : Slack threshold. 0 by default.  
    }
    ARGS {
        -m_dist:$man_dist_threshold,
        -r_dist:$real_dist_threshold,
        -slack:$slack_threshold
    }

    if (!defined $man_dist_threshold) {
        $man_dist_threshold = 1000 ;
    }

    if (!defined $real_dist_threshold) {
        $real_dist_threshold = 1100 ;
    }

    if (!defined $slack_threshold) {
        $slack_threshold = 0 ;
    }

    print "Loading retime related files ...\n" ; 
    load_routeRules_files () ;
    load_port_map_file () ;
    set_retiming_violation_attr ;
    print "Done for loading files ...\n\n" ; 

    my $proj     = $ENV{NV_PROJECT} ;
    my $pwd      = $ENV{PWD} ;
    my $rep_dir  = "${pwd}/${proj}/rep" ;

    # /home/scratch.ga103_NV_gac_g0/ga103/ga103/timing/ga103/rep/NV_gac_g0..anno30000.pt.ffg_105c_0p67v_min_si.std_min.fhs_noctx.TOP_G_Gp__105.2019Sep24_00_58_PTECO.unified.pba.viol.gz

    my @vio_files  = get_files (-type => vios) ;
    my @ipo_vios   = () ;
    my @skip_files = () ;
    my @out_files  = () ;

    foreach my $vio_file (@vio_files) {
        if ($vio_file !~ /\.\.anno\d+\.pt/ || $vio_file =~ /\.\.anno\d+\.pt\.\S+?_min\S*\.\S+?_min\./) {
            #print "Skip violation file : $vio_file\n" ;
            push @skip_files, $vio_file ;
        } else {
            push @ipo_vios, $vio_file ;
        }
    }

    if ($#skip_files != -1) {
        print "Skipping Non-ipo or hold violation files :\n" ;
        foreach my $file (@skip_files) {
            print "\t$file\n" ;
        }
    }

    if ($#ipo_vios != -1) {
        print "\n\n" ;
        print "Manhattan Dist > ${man_dist_threshold}um\n" ;
        print "Real Dist      > ${real_dist_threshold}um\n" ;
        print "Slack          < $slack_threshold\n\n" ;
        
        my $output_file = "" ;
        my $out         = "" ;
        
        foreach my $vio_file (@ipo_vios) {
            $output_file = $vio_file ;
            $output_file =~ s/.*\/// ;
            $output_file = "${rep_dir}/$output_file" ;
            if ($output_file =~ /\.gz$/) {
                $output_file =~ s/(.*)\.unified..*viol.gz/$1.retime.viol.gz/ ; 
                $out = $output_file ;
                $out =~ s/\.gz$// ;
            } else {
                $output_file =~ s/(.*)\.unified.pba.viol/$1.retime.viol.gz/ ;
                $out = $output_file ;
            }

            my @vios = all_vios (-filter => "type eq \"max\" and man_dist > $man_dist_threshold and real_dist > $real_dist_threshold and slack < $slack_threshold and file eq \'$vio_file\'") ;

            open OUT, "> $out" ;
 
            print OUT "#Original violation file : \n#\t$vio_file\n\n" ;

            foreach my $i (0..$#vios) {
                my $vio         = $vios[$i] ;
                my $vio_id      = attr_of_vio ('id' => $vio) ;
                my $start_rule  = attr_of_vio ('start_routeRule' => $vio) ; 
                my $end_rule    = attr_of_vio ('end_routeRule' => $vio) ;  
                my $source_coor = attr_of_vio ('source_coor' => $vio) ;
                my $dest_coor   = attr_of_vio ('dest_coor' => $vio) ;
                my $man_dist    = attr_of_vio ('man_dist' => $vio) ;
                my $real_dist   = attr_of_vio ('real_dist' => $vio) ;
                my $sig_name    = attr_of_vio ('sig_name' => $vio) ;
                my $corner      = attr_of_vio ('project_corner' => $vio) ;
                my $slack       = attr_of_vio ('slack' => $vio) ;
                
                $i = $i + 1 ;
                
                print OUT "# Path $i\n" ;
                print OUT "# Corner         : $corner\n" ;
                print OUT "# Slack          : $slack\n" ;
                print OUT "# Start Pin Rule : $start_rule\n" ;
                print OUT "# End Pin Rule   : $end_rule\n" ;
                print OUT "# Manhattan Dist : ${man_dist}um\n" ;
                print OUT "# Real Dist      : ${real_dist}um\n" ;
                print OUT "# Signal Name    : $sig_name\n\n" ;
                
                print OUT (show_path $vio_id) ; 

            }
            
            close OUT ;

            push @out_files, $out ;

        }
    } else {
        return "No ipo violation files found. Please double check.\n" ;
    }

    print "\n\n" ;

    if ($#out_files != -1) {
        print "Dumping files : \n" ;
        foreach my $file (@out_files) {
            if (-e "$file.gz") {
                unlink "$file.gz" ;
            } 
            system "gzip $file" ;
            print "\t${file}.gz\n" ;
        }
    }

    return 1 ;

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
    #my $top  = get_top ;
    my %all_mods = map  ({$_ => 1} (get_modules "*")) ;
    my @chiplets = grep ((exists $all_mods{$_}), (all_chiplets)) ;

    foreach my $top (@chiplets) {
        my $portmap_file = "/home/${proj}_layout/tot/layout/${rev}/blocks/${top}/noscan_cfg/${top}.noscan.portmap" ; 

        if (-e $portmap_file) {
            open IN, "$portmap_file" ;
            while (<IN>) {
                chomp ;
                my $line = $_ ;
                #if ($line !~ /^#/ && $line !~ /^\s+/) {
                if ($line =~ /^\w+/) {
                    # partition_module partition_port  cell cell_inst cell_pin
                    my ($par_ref, $par_port, $unit_name, $unit_inst, $unit_port) = split (" ", $line) ; 
                    $par_port =~ s/^\\// ;
                    $M_noscan_port_mapping{$par_ref}{$par_port} = 1 ;
                }
            }
            close IN ;
            print "Loaded Port Mapping file: $portmap_file ...\n" ;
        } else {
            error "Can't find portmap file : $portmap_file\n" ;
        }
    }

    #return %port_mapping ;

END

Tsub GetVioSigName => << 'END' ;
    DESC {
        to get the RTL net name of one violation.
    }
    ARGS {
        $vio
    }

    my @port_maps = sort keys %M_noscan_port_mapping ;

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


Tsub get_sig_name => << 'END' ;
    DESC {
        to get the RTL net name of one violation.
    }
    ARGS {
        $id
    }

    my $vio  = get_vio_by_id ($id) ;
    my $sig = attr_of_vio ('sig_name' => $vio) ;

    return $sig ;

END

Tsub get_neighbor_partitions => << 'END' ;
    DESC {
        to get all the neighbor partitions in chiplet
    }
    ARGS {
    }

    my $top = get_top ;
    if ($top !~ /nv.*_top/) {
        set_chip_top $top ;
    } 
    
    my @pars = grep (attr_of_ref (is_partition => (get_ref $_)), (get_cells "*")) ;

    my %neighbor_pars = () ;
    
    foreach my $par (@pars) {
        my @n_pars = tl_get_abutments $par ;
        foreach my $i (0..$#n_pars) {
            my $n_par = $n_pars[$i][0] ;
            if ((grep ($_ eq $n_par, @pars)) && !(exists $neighbor_pars{$par}{$n_par}) && !(exists $neighbor_pars{$n_par}{$par})) {
                $neighbor_pars{$par}{$n_par} = 1 ;
            }
        }
    }
    
    foreach my $key1 (sort keys %neighbor_pars) {
        foreach my $key2 (sort keys %{$neighbor_pars{$key1}}) {
            print "-ignoreInstanceConnections $key1:$key2\n" ;
        }
    }

END



Tsub load_retime_interface_files => << 'END' ;
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

Tsub Include  => << 'END' ;
    DESC {
        a dummy function for parsing the interface_retime_*.pm files
    }
    ARGS {
        @args
    }

END

Tsub AddRTLCode => << 'END' ;
    DESC {
        a dummy function for parsing the interface_retime_*.pm files
    }
    ARGS {
        @args
    }

END

Tsub SetRetimeBufferCell => << 'END' ;
    DESC {
        a dummy function for parsing the interface_retime_*.pm files
    }
    ARGS {
        @args
    }

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
    my @fuse_ram_lef = glob "${layout_dir}/libs/lef/fuse_rams_*.lef" ;
    my $dummy_macros = "${layout_dir}/libs/lef/macros_dummy.lef" ;
    my $coff_data    = "${layout_dir}/blocks/${proj}_top/control/coff.xml" ;

    if ($type ne 'anno') {
        load_once @ramlib_lef ;
        load_once @fuse_ram_lef ;
        load_once $dummy_macros ;
        load_once $coff_data ;
    }

    my %allModules = map  ({$_ => 1} (get_modules ("*"))) ;
    my @moduleRefs = grep (exists $allModules{$_}, (all_macros)) ;
    push @moduleRefs, (grep (attr_of_ref (is_ram => $_), (sort keys %allModules))) ;
    push @moduleRefs, (grep (attr_of_ref (is_analog => $_), (sort keys %allModules))) ;
    push @moduleRefs, (grep (attr_of_ref (Prop_IsPad => $_), (sort keys %allModules))) ;
    push @moduleRefs, (grep (attr_of_ref (Prop_IsFuse => $_), (sort keys %allModules))) ;

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
    # 4. retime regions with long distance ;

    my @hilite_regions = () ;

    # 1. overbound of the partitions
    print "\nCheck 1 : region overbound the partitions : \n\n" ;
    foreach my $par_inst (sort keys %region_coor) {
        foreach my $region_name (sort keys %{$region_coor{$par_inst}}) {
            my ($x1, $y1, $x2, $y2) =  @{$region_coor{$par_inst}{$region_name}} ;
            #print ("$x1, $y1, $x2, $y2\n") ;
            if (is_point_in_par ($x1, $y1, $par_inst) && is_point_in_par ($x2, $y1, $par_inst) && is_point_in_par ($x1, $y2, $par_inst) && is_point_in_par ($x2, $y2, $par_inst)) {
            } else {
                print "WARNING : $region_name is over the bounds of $par_inst\n" ;
                push @hilite_regions, $region_name ;
                #hilite (-fill => red, $region_name) ;
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
            print "WARNING : $region_name overlaps $overlap_multi_rams{$par_inst}{$region_name} rams/macros/analog/pads\n" ;
            push @hilite_regions, $region_name ;
            #hilite ($region_name, -fill => red) ;
        }
    }

    # 3. overlap with blockage ;
    print "\nCheck 3 : region overlaps blockages : \n\n" ;

    foreach my $par_inst (sort keys %blockage_coor) {
        foreach my $blkg_name (sort keys %{$blockage_coor{$par_inst}}) {
            foreach my $region_name (sort keys %{$region_coor{$par_inst}}) {
                my @overlap_rect = rects_of_overlap_rects ($region_coor{$par_inst}{$region_name}, $blockage_coor{$par_inst}{$blkg_name}) ;
                if (@overlap_rect) {
                    print "WARNING : $region_name overlaps blockage\n" ;
                    push @hilite_regions, $region_name ;
                    #hilite ($region_name, -fill => red) ;
                    next ;
                }
            }
        }
    }

    # 4. retime regions with long distance ;

    #print "\nCheck 4 : distance over 1000um between regions : \n\n" ;

    ## parsing the retime regions ;
    #my %region_pipe_relation = () ;
    #my @region_files = grep ($_ =~ /_RETIME\.tcl/, (get_files (-type => tcl))) ;
    #foreach my $file (@region_files) {
    #    my $par_ref = $file ;
    #    $file =~ s/(.*\.tcl).*/$1/ ;
    #    $par_ref =~ s/.*control\/(\S+)_RETIME\.tcl.*/$1/ ;
    #    open IN, "$file" ;
    #    while (<IN>) {
    #        chomp ;
    #        my $line = $_ ;
    #        if ($line =~ /nvb_add_to_region\s+(\S+)\s+\*_(\S+)\/\*/) {
    #            my $region_name = $1 ;
    #            my $pipe_step   = $2 ;
    #            my @par_insts   = get_cells_of $par_ref ;
    #            foreach my $par_inst (@par_insts) {
    #                $region_pipe_relation{$par_inst}{$pipe_step} = $region_name ; 
    #            }
    #        } else {
    #            next ;
    #        }
    #    }
    #    close IN ;
    #} 

    #foreach my $par_inst (sort keys %region_pipe_relation) {
    #    foreach my $pipe_step (sort keys %{$region_pipe_relation{$par_inst}}) {
    #        my $rule_name = get_rule_of_step $pipe_step ;
    #        if ($rule_name) {
    #            my ($chiplet, $rule) = split (" ", $rule_name) ;
    #            my @pipes = () ;
    #            if ($M_routeRules{$chiplet}{$rule_name}{pipeline_steps} =~ /$pipe_step/) {
    #                my $curr_region = $region_pipe_relation{$par_inst}{$pipe_step} ;
    #                @pipes          = split (",", $$M_routeRules{$chiplet}{$rule_name}{pipeline_steps}) ;
    #            }
    #        } else {
    #            next ;
    #        }
    #    } 
    #}
     

    # plot all the macros/rams again for not masked by region rects.
    print "\n" ;
    hilite (@hilite_regions, -fill => red) ;
    plot_all_modules ;

    return 1 ;

END

Tsub get_region_step => << 'END' ;
    DESC {
        parsing the retime region tcl files.
    }
    ARGS {
        -region:$opt_r ,
        -step:$opt_s
    }

    if ((defined $opt_r) && (defined $opt_s)) {
        die "either -region or -step\n" ;
    }

    my %region_coor = () ;
    my %region_step = () ;
    
    my @retime_tcl_files = grep ($_ =~ /_RETIME\.tcl/, (get_files (-type => tcl))) ;
    foreach my $file (@retime_tcl_files) {
        $file =~ s/(.*_RETIME\.tcl).*/$1/ ;
        my $par = $file ;
        $par =~ s/.*\/(\S+)_RETIME\.tcl.*/$1/ ;
        open IN, "$file" or die "Can't open file $file\n" ;
        while (<IN>) {
            chomp ;
            my $line = $_ ;
            if ($line =~ /nvb_add_to_region (\S+) \*_(\S+)\/\*/) {
                my $region_name = $1 ;
                my $step        = $2 ;
                foreach my $par_inst (get_cells_of $par) {
                    $region_step{$par_inst}{$region_name}{$step} = 1 ;
                }
            } 
        }
        close IN ;
    }

    foreach my $par (sort keys %M_nvb_region) {
        foreach my $region_name (sort keys %{$M_nvb_region{$par}}) {
            my @coor = @{$M_nvb_region{$par}{$region_name}} ;
            foreach my $par_inst (get_cells_of $par) {
                my @top_coor = top_rects_of_base_rects (cell_of_name ($par_inst), @coor) ;
                my @ne_coor  = ($top_coor[0][0], $top_coor[0][1]) ;
                @{$region_coor{$par_inst}{$region_name}} = @ne_coor ;
            }
        }
    }

    my $region_info = "" ;

    if (defined $opt_r) {
        foreach my $par (sort keys %region_coor) {
            foreach my $region_name (sort keys %{$region_coor{$par}}) {
                if ($region_name eq $opt_r) {
                    my $coor  = (join (",", @{$region_coor{$par}{$region_name}})) ;
                    my @steps = sort keys %{$region_step{$par}{$region_name}} ;
                    my $step  = (join (",", @steps)) ;
                    $region_info = "$region_name : $coor : $step" ;
                    print "$region_info\n" ;
                }
            }        
        } 
    }

    #my ($curr_region, $curr_coor, $curr_step) = split (":", $region_info) ; 
    #foreach my $step (split ",", $curr_step) {
    #    my @insts = get_cells (-hier => "*_${step}/*") ;
    #    if ($#insts != -1) {
    #        my $inst  = $insts[0] ;
    #        my @fis   = get_fan2 (-fanin, -end, -pins, $inst) ;
    #        my $fi    = $fi[0] ;
    #    }
    #} 

    if (defined $opt_s) {
        foreach my $par (sort keys %region_step) {
            foreach my $region_name (sort keys %{$region_step{$par}}) {
                foreach my $step (sort keys %{$region_step{$par}{$region_name}}) {
                    if ($step eq $opt_s) {
                        my $coor        = (join (",", @{$region_coor{$par}{$region_name}})) ;
                        my @steps       = sort keys %{$region_step{$par}{$region_name}} ;
                        my $all_steps   = (join (",", @steps)) ;
                        print "$region_name : $coor : $step\n" ;
                    }
                }
            }
        }
    }

    return 1 ;

END

Tsub plot_retiming => << 'END' ;
    DESC {
        to plot the retiming 
    }
    ARGS {
        $rule ,
    }

    my $top        = get_top ;
    my $chiplet    = $top ;
    $chiplet       =~ s/^NV_// ;
    my $chiplet_uc = uc $chiplet ;
    my $rule_name  = $rule ; 
    my $tap_num    = $rule ;

    if ($rule !~ /_tap/) {
        $rule_name = $rule ;
        $tap_num   = "" ;
    } else {
        $rule_name     =~ s/_tap.*// ;
        $tap_num       =~ s/.*_(tap.*)/$1/ ;
    }
    
    my %par_steps  = () ;
    my %par_refs   = () ;

    if ($rule !~ /tap/ && (! exists $M_routeRules{$chiplet_uc}{$rule_name})){
        return "No rule $rule in $chiplet_uc\n" ;
    } elsif ($rule =~ /tap/ && (! exists $M_routeRules{$chiplet_uc}{$rule_name}{tap}{$tap_num})) {
        return "No rule $rule in $chiplet_uc\n" ;
    }

    my $main_src_loc    = $M_routeRules{$chiplet_uc}{$rule_name}{source_location} ;
    my $main_dest_loc   = $M_routeRules{$chiplet_uc}{$rule_name}{destination_location} ;
    if ($M_routeRules{$chiplet_uc}{$rule_name}{pipeline_steps} ne "") { 
        my @main_par_steps  = split (",", $M_routeRules{$chiplet_uc}{$rule_name}{pipeline_steps})  ; 
        my @main_par_refs   = split (",", $M_routeRules{$chiplet_uc}{$rule_name}{partition_ref})  ; 
        foreach my $i (0..$#main_par_steps) {
            my $par_ref     = $main_par_refs[$i] ; 
            my $par_step    = $main_par_steps[$i] ;
            $par_ref        =~ s/(\d+)__(\d+)__\w+/$1:$2/ ;
            my ($x, $y)     = split (":", $par_ref) ; 
            my $coor_x      = $x * 50 ;
            my $coor_y      = $y * 50 ;
            if ($i == 0) {
                ${$par_refs{MAIN}}[$i] = $main_src_loc ;
            }
            $i              = $i + 1 ;
            ${$par_refs{MAIN}}[$i] = "$coor_x, $coor_y" ;  
        }
        push $par_refs{MAIN}, $main_dest_loc ;
    } else {
        $par_refs{MAIN}[0] = $main_src_loc ;
        $par_refs{MAIN}[1] = $main_dest_loc ;
    }

    if ($rule !~ /_tap/) {
        my @main_par_refs = @{$par_refs{MAIN}} ;
        foreach my $i (0..$#main_par_refs) {
            usr_plot_rect (-name => "${rule}_$i", -coor => "$main_par_refs[$i]") ;
            if ($i > 0) {
                my ($sx, $sy) = split (",", $main_par_refs[$i-1]) ;
                my ($ex, $ey) = split (",", $main_par_refs[$i]) ;
                plot_line (-arrow => "last", $sx, $sy, $ex, $ey, -color => "red") ;
            }
        }
    } 

    if ($rule =~ /_tap/) {
        foreach my $tap (sort keys $M_routeRules{$chiplet_uc}{$rule_name}{tap}) {
            my $tap_src        = $M_routeRules{$chiplet_uc}{$rule_name}{tap}{$tap}{tap_chain} ;
            my $tap_src_num    = $M_routeRules{$chiplet_uc}{$rule_name}{tap}{$tap}{tap_number} ;
            my $tap_src_coor   = ${$par_refs{$tap_src}}[$tap_src_num] ;
            my $tap_dest_coor  = $M_routeRules{$chiplet_uc}{$rule_name}{tap}{$tap}{destination_location} ;
            if ($M_routeRules{$chiplet_uc}{$rule_name}{tap}{$tap}{pipeline_steps} eq "") {
                $par_refs{$tap}[0] = $tap_src_coor ;
                $par_refs{$tap}[1] = $tap_dest_coor ;  
            } else {
                my @tap_par_steps = split (",", $M_routeRules{$chiplet_uc}{$rule_name}{tap}{$tap}{pipeline_steps})  ; 
                my @tap_par_refs  = split (",", $M_routeRules{$chiplet_uc}{$rule_name}{tap}{$tap}{partition_ref})  ; 
                foreach my $i (0..$#tap_par_steps) {
                    my $par_ref  = $tap_par_refs[$i] ;
                    my $par_step = $tap_par_steps[$i] ;
                    $par_ref     =~ s/(\d+)__(\d+)__\w+/$1:$2/ ;
                    my ($x, $y)  = split (":", $par_ref) ;
                    my $coor_x   = $x * 50 ;
                    my $coor_y   = $y * 50 ;

                    if ($i == 0) {
                        ${$par_refs{$tap}}[$i] = $tap_src_coor ;
                    }
                    $i = $i + 1 ;
                    ${$par_refs{$tap}}[$i] = "$coor_x, $coor_y" ;
                }
                push @{$par_refs{$tap}} , $tap_dest_coor ;
            }
        }
        while (1) {
            my $tap_src_loc_done = 1 ;
            foreach my $tap (sort keys %par_refs) {
                if (!defined ${$par_refs{$tap}}[0]) {
                    $tap_src_loc_done = 0 ;
                    my $src_chain = $M_routeRules{$chiplet_uc}{$rule_name}{tap}{$tap}{tap_chain} ;
                    my $src_num   = $M_routeRules{$chiplet_uc}{$rule_name}{tap}{$tap}{tap_number} ;
                    if (defined ${par_refs{$src_chain}}[$src_num]) {
                        ${$par_refs{$tap}}[0] = ${par_refs{$src_chain}}[$src_num] ;
                    } else {
                        next ;
                    }
                }
            }
            if ($tap_src_loc_done == 1) {
                last ;
            }
        }
        my @tap_par_refs = @{$par_refs{$tap_num}} ; 
        foreach my $i (0..$#tap_par_refs) {
            usr_plot_rect (-name => "${rule}_${i}", -coor => "$tap_par_refs[$i]") ;
            if ($i > 0) {
                my ($sx, $sy) = split (",", ${$par_refs{$tap_num}}[$i-1]) ;
                my ($ex, $ey) = split (",", ${$par_refs{$tap_num}}[$i]) ;
                plot_line (-arrow => "last", $sx, $sy, $ex, $ey, -color => "red") ;
            }
        }
    }

    #print (Dumper %par_refs) ;

END

Tsub usr_plot_rect => << 'END' ;
    DESC {
        plot rect on the coordinates
    }
    ARGS{    
        -name:$name ,
        -coor:$coor ,
    }

    my ($sx, $sy) = split (",", $coor) ;
    my $ex = $sx + 50 ;
    my $ey = $sy + 50 ;

    plot_rect ($name, $sx, $sy, $ex, $ey, -fill => "blue", -outline => "blue") ;

END

Tsub dump_rtl_net_names => << 'END' ;
    DESC {
        to dump the full retiming rtl names 
    }
    ARGS {
        $chiplet ,
        -o:$outfile ,
        -mail,
    }
    
    my %rtl_nets_name = () ;
    
    if (! defined $outfile) {
        $outfile = "$ENV{PWD}/${chiplet}_all.csv" ;
    }
    
    print "OUTPUT FILE : $outfile\n" ;
    
    foreach my $rule (sort keys %{$M_routeRules{$chiplet}}) {
        my @rtl_nets = split (",", $M_retime_interf{$chiplet}{$rule}{rtl_net_name}) ;    
        foreach my $rtl_net (@rtl_nets) {
            my $src_unit  = $M_retime_interf{$chiplet}{$rule}{src_inst} ;
            my $dest_unit = $M_retime_interf{$chiplet}{$rule}{dest_inst} ;
            my $end_clk   = $M_routeRules{$chiplet}{$rule}{clock_name} ;
            my $src_par   = $M_routeRules{$chiplet}{$rule}{source_partition} ;
            my $dest_par  = $M_routeRules{$chiplet}{$rule}{destination_partition} ;
            my $steps_num = scalar (split (",", $M_routeRules{$chiplet}{$rule}{pipeline_steps})) ; 
            my @src_loc   = split (",", $M_routeRules{$chiplet}{$rule}{source_location}) ; 
            my @dest_loc  = split (",", $M_routeRules{$chiplet}{$rule}{destination_location}) ; 
            my $dist      = "" ;
            if (@src_loc && @dest_loc) { 
                $dist = get_dist (@src_loc, @dest_loc) ;
                $dist = "${dist}um" ;
            } 
            $rtl_nets_name{$dest_unit}{$rtl_net} = "$rtl_net,$rule,$end_clk,$src_unit,$dest_unit,$src_par, $dest_par, $steps_num, ${dist}" ; 
        }
    }

    open OUT, "> $outfile" ;

    print OUT "RTL_net,Rule,Clock,Src_unit,Dest_unit,Src_par,Dest_par,Steps,Dist\n" ;
    foreach my $dest_unit (sort keys %rtl_nets_name) {
        foreach my $rtl_net (sort keys %{$rtl_nets_name{$dest_unit}}) {
            print OUT "$rtl_nets_name{$dest_unit}{$rtl_net}\n" ;
        }
    }

    if (defined $opt_mail) {
        my $id   = `whoami` ;
        chomp $id ;
        my $subj = "$chiplet retiming signals csv" ; 
        my $atch = "$outfile" ;
        my $body = "$outfile" ;
        my $cmd  = "echo \"$body\" | mutt $id -s \"$subj\" -a \"$atch\"" ;
        print "Mail to $id : $outfile\n" ;
        system "$cmd" ;
    }

    close OUT ;

END

return 1 ;
