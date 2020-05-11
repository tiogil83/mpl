#######################################################################
# Powerful scripts for GPU Shanghai ASIC Physical Design Team.
# Works in Mender shell
# Use "shpd_" as the prefix for sub defination, to avoid override.
# Author: Spirit Zhang  (spzhang@nvidia.com)
# Date: Since 2008.10
#########################################################################

sub ECO_ROUTE_DELTA () { 25 } #Set to 25 um in 40nm process
sub ECO_ROUTE_SLIDE () { 30 } #Set to 50 um in 40nm process
sub MAX_TRANS_REQ () { 400 }
sub AUTHOR () { Spirit }

#Subroutines:
#sub shpd_parse_parameter 
#sub is_para_ok 
#sub shpd_get_partition_dir 
#sub shpd_check_hold_margin 
#sub shpd_get_early_buffer 
#sub shpd_get_proj_name 
#sub shpd_check_donors 
#sub sp_get_viol_files 
#sub sp_get_mins  
#sub sp_get_trans  
#sub sp_get_cap 
#sub is_from_top 
#sub sp_get_pin_context 
#sub sp_get_glitch  
#sub m_report_cap 
#sub m_report_trans 
#sub m_report_mins 
#sub m_report_glitch 
#sub shpd_get_units_of 
#sub shpd_get_pars_of 
#sub shpd_get_units_inst_cnt 
#sub shpd_check_trans_for_hold 
#sub shpd_move_buffer_at 
#sub shpd_get_node_dir 
#sub shpd_get_locus_length 
#sub shpd_is_detour_locus  
#sub shpd_add_buffer_chain  
#sub shpd_get_cts_nodes 
#sub shpd_get_equiv_cg_nodes 
#sub shpd_scan_reorder 
#sub a03_group 
#sub a03_scan_reorder 
#sub a03_stich_buffers 
#sub set_eco_equiv_check 
#sub compare_try 
#sub compare_formal 
#sub menderFV_turnoff_test 
#sub test_bdd_run_auto 

sub shpd_parse_parameter {
    my @parameter = @_;
    my $key_n = undef;
    my $para = ();
    my %para_hash = ();
    foreach $para (@parameter) {
        if ($para =~ /\B\-\D\S+\b/) {
            $key_n = $para;
        } elsif ($key_n) {
            push @{$para_hash{$key_n}}, $para;
        }
    }
    return (%para_hash);
}

sub is_para_ok {
    my $paras = shift @_;
    my @args = @_;
    my $return = 1;
    my %arg_hash = ();
    foreach (@args) {
        $arg_hash{$_} = 1;
    }
    foreach my $para (keys %{$paras}) {
        if (! (defined $arg_hash{$para})) {
            return (0);
        }
    }
    return ($return);
}
#sub check_viol () {
#    #should get the violfiles now
#    my $par = get_top;
#    my $ipo_num = get_ipo_num $par;
#    my @viol_files = load_array ("gt216/mender/FP1/df");#("gt216\/mender\/$par\/$par\.ipo${ipo_num}\.violfiles");
#    while (@viol_files) {
#
#        my $viol_file = shift @viol_files;
#        if ($viol_file =~ /\.gz/) {
#            open (VIOL, "gunzip -c  $viol_file | ") or error "input gzip $viol_file not found";
#        }
#        else {
#            open (VIOL, $viol_file) or error "input $viol_file not found";
#        }
#        lprint "the file is $viol_file \n";
#       # open (VIOL,"$viol_file") or die;
#            if ($viol_file=~/\_master/) {
#                if ($viol_file=~/transition/) {
#                   # open (VIOL,"$viol_file") or die;
#                    while (<VIOL>) {
#                       if (/^\s+(\S+)\s+(\S+)\s+(\S+)\s+i(\S+)\s+\(VIOLATED/) {
#                            ${top}{trans}{$1}{required} = $2;
#                            ${top}{trans}{$1}{actural} = $3;
#                            ${top}{trans}{$1}{violation} = $4;
#                            ${top}{trans}{$1}{source} = $viol_file;
#                        } 
#                    }
#                }
#                elsif ($viol_file=~ /hold[w|b]c/) {
#                    while (<VIOL>) {
#                        if (/^\s+(\S+)\s+(\S+)\s+\(VIOLATED\)\s+\S+\s+start\=(\S+)$/) {
#                            ${top}{hold}{$1}{violation} = $2;
#                            ${top}{hold}{$1}{start} = $3;
#                            ${top}{hold}{$1}{source} = $viol_file;
#                        }    
#                    }    
#                }
#                else {
#                    lprint "A don't know viol file from Master area: $viol_file";
#                } # add rc011 add max_cap &max_trans in all corners
#            }
#            else {
#                if ($viol_file =~ /ocv/) {
#                    while (<VIOL>) {
#                        if (/^\s+(\S+)\s+(\S+)\s+\(VIOLATED\)\s+\S+\s+start\=(\S+)$/) {
#                            ${par}{hold}{$1}{violation} = $2;
#                            ${par}{hold}{$1}{start} = $3;
#                            ${par}{hold}{$1}{source} = $viol_file;
#                        }
#                    }
#                } 
#                elsif ($viol_file = ~/wc/){
#                    lprint "here ,par\n";
#                    while (<VIOL>) {
#                        if (/^\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+\(VIOLATED/) {
#                             lprint "here ,good\n";
#                            ${par}{trans}{$1}{require} = $2;
#                            ${par}{trans}{$1}{actural} =$3;
#                            ${par}{trans}{$1}{violation} = $4;
#                            ${par}{trans}{$1}{source} = $viol_file;
#                        }
#                    }
#                }
#            }      
#        }
#return (%par);
#close(REP);
# } 
#
#
sub shpd_get_partition_dir {
    # HARDCODE hard coded the dirs
    my $proj = shift;
    my %rep_dir = (gt215 => "/home/scratch.gt215_partition/gt215/gt215/timing/gt215/rep",
                   rsx40 => "/home/scratch.rsx40_partition/rsx40/rsx40/timing/rs/rep"   ,
                   gf100 => "/home/scratch.gf100_partition/gf100/gf100/timing/gf100/rep",
                  );
    return ($rep_dir{$proj});
}


sub shpd_check_hold_margin {	
	my $block = get_top;
	my $ipo_sp = get_ipo_num $block;
	my $curr_dir_sp = pwd;
    my $partition_rep_dir;
    my %opts = shpd_parse_parameter @_;
    my @files = @{$opts{-file}};	
    my $slack = (defined @{$opts{-slack_min}}) ? (shift @{$opts{-slack_min}}) : 0.03;
    
    if (!(@files) or (!(%opts) or !(is_para_ok (\%opts,-file,-slack_min)))) {
        print "Error: wrong parameter speficified\n";    
        print "-file      \$file1 \$file2 \.\.\. : the dcsh files\n";
        print "-slack_min \$slack_margin : print the cells through which the hold margin is worst than \$slack_margin\n";
        return ();

    }
	if ($curr_dir_sp =~ /\/scratch\.\S+?\/(\S+?)\/\S+?\/timing$/) {
	    $proj_sp = $1;
	} 
	else {
	    lprint "ERROR! you are not in timing dir\n";
        return ();
	}
    $partition_rep_dir = shpd_get_partition_dir $proj_sp;	
	load_once "$partition_rep_dir/$block\.anno$ipo_sp\.ocvbc\.vhv\.cellpin\.attr\.rep\.\gz";
    undo_eco;
    print "Warning: undo_eco asserted\n";
    foreach my  $scripts_dcsh (@files) {	
        if (!(-e $scripts_dcsh)) {print "Error: The dcsh is not exist\n";return ();}
        print "Current ECO file: $scripts_dcsh\n\n";
        open (DCSH,"$scripts_dcsh") or die "$!";
        open (FILE,">${scripts_dcsh}\.verify");
        while (<DCSH>) {
            if (/^remove_cell\s(\S+)\s+/) {
               my  $cell = $1;
               if (is_cell $cell) {
                    my  $out_pin =  get_pins ( -dir =>out,  -of =>$cell);
                    my  $hold_slack = wh_get_slack_min $out_pin;
                    my  $ref = get_ref $1;
                    if ($hold_slack < $slack) {
                      lprint "removed\: $cell $ref  hold slack\: $hold_slack \n";
                      print  FILE "removed\: $cell $ref  hold slack\: $hold_slack \n";
                    }
                }
            } 
            elsif (/^change_link\s(\S+)\s(\S+)\/(\S+)/) {
                my  $inst_sp = $1; 
                if (is_cell $inst_sp) {
                    my  $ref_pre = get_ref $inst_sp;
                    my  $ref_pos = $3;
                    my  @out_pin =  get_pins( -dir =>out => -of => $inst_sp);
                    my  $setup_slack = wh_get_slack_max $out_pin[0];
                    my  $hold_slack = wh_get_slack_min $out_pin[0];
                    if ($hold_slack < $slack) {
                      lprint "changed: $1 $ref_pre \-\> $ref_pos   setup slack: $setup_slack   hold slack:  $hold_slack \n";
                      print FILE "changed: $1 $ref_pre \-\> $ref_pos   setup slack: $setup_slack   hold slack:  $hold_slack \n";
                    }
                }
            }
        }
        close (FILE);
    }
}

Tsub shdp_foo  => << 'END';
    DESC {
        foo for mender Tsub
    }

    ARGS {
        -arg1: $arg1
        -arg2: @arg1
    }

END


sub shpd_get_early_buffer {
#shpd_get_early_buffer -pins startpin1 startpin2 ... -slack_max $max_threshold -slack_min $min_threshold
    my %opts = shpd_parse_parameter @_;
    my @loads = @{$opts{-pins}};
    my @return = ();

    my $thr_min  = (defined @{$opts{-slack_min}}) ? (shift @{$opts{-slack_min}}) : 0.0;
    my $thr_max  = (defined @{$opts{-slack_max}}) ? (shift @{$opts{-slack_max}}) : 0.2;

    if (!(@loads) or !(%opts) or !(is_para_ok (\%opts,-pins,-slack_min,-slack_max))) {
        print "Error: wrong parameter speficified\n";
        print "-pins      \$pin1 \$pin2 \.\.\. : the input pins from which searching started\n";
        print "-slack_min \$slack_margin : the hold slack  \$slack_margin\n";
        print "-slack_max \$slack_margin : the setup margin  \$slack_margin\n";
        return ();
    }
    foreach my $load_pin (@loads) {
        if (is_port $load_pin) {
            next;
        }        
        my @inst_context = get_pin_context $load_pin;
        my $s_min = wh_get_slack_min $load_pin;
        my $s_max = wh_get_slack_max $load_pin;
        if (($s_max > $thr_max and $s_min < $thr_min) 
            or (is_latch_ref $inst_context[1]) 
            or (is_flop_ref $inst_context[1]) 
            or (is_ram_ref $inst_context[1])
        ) {
            if (($s_max > $thr_max and $s_min < $thr_min) 
                and (!((is_latch_ref $inst_context[1]) 
                or (is_flop_ref $inst_context[1]) 
                or (is_ram_ref $inst_context[1])))
            ) {
                my $load_num = all_fanout (-end ,"$inst_context[0]");
                push (@return, "$load_pin $s_min $s_max");
                next;
            } else {
                next;
            }
            
        } elsif ($s_min < $thr_min){
            my @reurn_t = ();
            my @recur_loads = ();
            my @inst_loads = get_loads ($inst_context[0]);
            foreach my $inst_load (@inst_loads) {
                my @loads_context = get_pin_context $inst_load;
                if (is_flop_ref $loads_context[1]
                    or is_latch_ref $loads_context[1] 
                    or is_ram_ref $loads_context[1]) {
                      my $s_slack_t = wh_get_slack_min $inst_load;
                      my $s_max_t   = wh_get_slack_max $inst_load;
                        if ($s_slack_t < $thr_min) {
                            lprint "find non-common endpoint for $inst_context[0]\n";
                            push (@return,{$inst_context[0] => "$inst_load $s_slack_t $s_max_t"}); #without enough max margin, but min violated
                        }
                } else {
                    push (@recur_loads, $inst_load); 
                }
            }
            @reurn_t = shpd_get_early_buffer (@recur_loads);
            push (@return,@reurn_t);
        }
    }
    return (@return);
}

sub shpd_get_proj_name {
    my $proj = ();
    my $tot = get_project_home ();
    open (TREE,"$tot/tree.make") or die "Can't open tree.make in shpd_get_proj_name";
    while (<TREE>) {
        my $line = $_;
        if ($line =~ s/export\s+PROJECTS\s+\S+\s+(\S+)\s*$/$1/) {
            $proj = $line;
            last;
        }
    }
    close (TREE);
    return ($proj);
}

sub shpd_check_donors {
    my %dc_tg = ();
    my @dc_tg = ();
    my $tot = `depth`;
    my @dc_files = ();
    my $par = get_top();
    my $proj = shpd_get_proj_name;
    (keys (%{$Eco_pending_donor{$par}})) or \
    lprint "Error: use this sub before write_eco or non donor cell used\n" and return 0;
    my @donor_cells_used =  keys (%{$Eco_pending_donor{$par}});
    my $eco_dir = "$tot/timing/$proj/eco/$par";
    my @mpl_files = glob ("$eco_dir/*.mpl");
    (@mpl_files) or lprint "Wrong eco dir? $eco_dir\n" and return 0;
    foreach my $mpl_file (@mpl_files) {
        #my $p4_echo = `p4 have $mpl_file`; 
        #next unless (!$p4_echo); 
        open (IN,$mpl_file) or die "$!";
        my $is_mental = 0;
        while (<IN>) {
            my $line = $_;
            if ($line =~ /set_eco_metal_only/) {
                $is_mental = 1;
                next;
            }
            if (($is_mental == 1) && ($line =~ /Generic\s+scripts\s+to\s+include/)) {
                while (<IN>) {
                    my $line = $_;
                    last unless ($line !~ /Write\s+out\s+new\s+gv/);
                    if ($line =~ /load\s+\"(\S+)\"/) {
                        push (@dc_files,$1);
                    }
                }
            }
        }
        close (IN);
    }
    return 0 unless (@dc_files);
    @dc_files = remove_duplicates @dc_files;
    foreach my $dc_file (@dc_files) {
        chomp $dc_file;
        open (DCSH,$dc_file) or die "$!";
        my @dc_content = <DCSH>;
        foreach my $donor_cell (@donor_cells_used) {
            set_perl_only on;
            if (grep ($_ =~ qr/$donor_cell/,@dc_content)) {
                #print "\n$donor_cell has been used already in $dc_file but may not be claimed";
                push (@{$dc_tg{$dc_file}},"\t $donor_cell\n");
            } 
            set_perl_only off;
        }
    } 
    close (DCSH);
    return 0 unless (%dc_tg);
    return (%dc_tg);
}

############################################################################################
#DESC: This scripts provides subs to analyse violators in mender session.
#Date: Nov,15,2008
#Author: spzhang@nvidia.com
############################################################################################
#package used
#load_mpl  "/home/scratch.spzhang_gf100/tool_central/shpd_scripts/CheckViol.pm";

#subs:
#sp_get_viol_files: Get viol files ECO tracker found in netfix mode, or get viol files in master partition area in non netfix mode.
#sp_get_mins: Get an object of hold violators.
#sp_get_trans: Get an object of transitions.
#sp_get_cap: Get an object of max_cap violations.
#is_from_top: Rurn 1 if the given input pin has  top fanins. usage: is_from_top ($input_pin);
#sp_get_pin_context: Rurn the context of a given pin or net.
#m_report_cap: Report max_cap.
#m_report_trans: Report transitions. 
#m_report_mins: Report hold.

#In netfix mode, all viol files included, otherwise, only partition level viol files.
sub sp_get_viol_files {
  my (%proj_par_dir,$pwd,$proj);
  %proj_par_dir = ( #hard coded 
     gt218 => "/home/scratch.gt218_partition/gt218/gt218/timing/gt218",
     gt216 => "/home/scratch.gt216_partition/gt216/gt216/timing/gt216",
     gt215 => "/home/scratch.gt215_partition/gt215/gt215/timing/gt215",
     rsx40 => "/home/scratch.rsx40_partition/rsx40/rsx40/timing/rs",
     gf100 => "/home/scratch.gf100_partition/gf100/gf100/timing/gf100"
#    gf100 => "/home/scratch.spzhang_gf100/fermi1_gf100/fermi1_gf100/timing/gf100"
  );
  $proj = shpd_get_proj_name ();
  if ($netfix_mode and $VIOL_FILES) {
    my @result_netfix = split /\s+/, $VIOL_FILES;
    return (@result_netfix);
  }
  else {
    print "WARNING: Non netfix mod, only partition level violfiles considered\n";
    my ($block,$ipo,@ls_result,@result_par);
    $block = get_top;
    $ipo = get_ipo_num $block;
    cd "$proj_par_dir{$proj}/rep";
    @ls_result = glob ("$block.anno$ipo*.viol.gz");
    @result_par = map ("$proj_par_dir{$proj}/rep/".$_, @ls_result);
    cd $pwd;
    @result_par or return ();
    return (@result_par);
  }
#  You can feed the violfiles whatever you want:
#  my @result_dd = load_array ("/home/spzhang/viol_list");
#  return (@result_dd);
}


sub sp_get_mins  {
  set_perl_only on; 
  my @viol_files =  sp_get_viol_files;# @_;
  @viol_files or print "ERROR: No Viol Files input\n";
  undef $M_check_viol;
  $M_check_viol = CheckViol->new();
  $M_check_viol->get_min(@viol_files);
#  my @viol_files = @_;
#  @viol_files or print "ERROR: No Viol Files input\n";
#  my %mins = ();
#  while (@viol_files) {
#    my $viol_file = shift @viol_files;
#    my %min_ts = ();
#    undef $M_check_viol;
#    $M_check_viol = CheckViol->new();
#    %min_ts = $M_check_viol->get_min("$viol_file");
#    foreach $min_t (@min_ts) {
#      if (grep ${$min_t}[0] eq $_, keys %mins) {
#        if ($mins{${$min_t}[0]}{violation} !=  ${$min_t}[1]) {
#          push (@{$mins{${$min_t}[0]}{violation}},${$min_t}[1]);
#        } 
#        if ($mins{${$min_t}[0]}{startpoint} ne ${$min_t}[2]) {
#          push (@{$mins{${$min_t}[0]}{startpoint}},${$min_t}[2]);
#        }
#        if ($mins{${$min_t}[0]}{violfile} ne ${$min_t}[3]) {
#          push (@{$mins{${$min_t}[0]}{violfile}},${$min_t}[3]);
#        }
#      }
#      else {
#        $mins{${$min_t}[0]}{violation} = ${$min_t}[1];
#        $mins{${$min_t}[0]}{startpoint} = ${$min_t}[2];
#        $mins{${$min_t}[0]}{violfile} = ${$min_t}[3];  #encoding is needed
#      }
#    }     
#  }
  set_perl_only off;
  return ($M_check_viol);
}

sub sp_get_trans  {
  set_perl_only on;
  my @viol_files =  sp_get_viol_files;# @_;
  @viol_files or print "ERROR: No Viol Files input\n";
  undef $M_check_viol;
  $M_check_viol = CheckViol->new();
  $M_check_viol->get_trans(@viol_files);
 # while (@viol_files) {
 #   my $viol_file = shift @viol_files;
 #   my @trans_ts = ();
 #   undef $M_check_viol;
 #   $M_check_viol = CheckViol->new();
 #   @trans_ts = $M_check_viol->get_trans ("$viol_file");
 #   foreach $trans_t (@trans_ts) {
 #     if (grep ${$trans_t}[0] eq $_, keys %trans) {
 #       my $viol_t = ${$trans_t}[1] - ${$trans_t}[2];
 #       if ($viol_t > $trans{${$trans_t}[0]}{violation}) {
 #         $trans{${$trans_t}[0]}{reqd} = ${$trans_t}[1];
 #         $trans{${$trans_t}[0]}{tran} = ${$trans_t}[2];
 #         $trans{${$trans_t}[0]}{violation} = $viol_t;
 #         $trans{${$trans_t}[0]}{violfile} = ${$trans_t}[3];
 #       } 
 #     }
 #     else {
 #       $trans{${$trans_t}[0]}{reqd} = ${$trans_t}[1];
 #       $trans{${$trans_t}[0]}{tran} = ${$trans_t}[2];
 #       $trans{${$trans_t}[0]}{violation} = ${$trans_t}[1] - ${$trans_t}[2];
 #       $trans{${$trans_t}[0]}{violfile} = ${$trans_t}[3];
 #     }
 #   }
 # }
  set_perl_only off;
#adding more info: is_detour net? is_inter? driver strength? loads_num? route_length_net?
  return ($M_check_viol);
}

sub sp_get_cap { 
  set_perl_only on;
  my @viol_files = sp_get_viol_files;
  @viol_files or print "ERROR: No Viol Files input\n";
  undef $M_check_viol;
  $M_check_viol = CheckViol->new();
  $cap = $M_check_viol->get_cap(@viol_files); 
#  while (@viol_files) {
#    my $viol_file = shift @viol_files;
#    my @cap_ts = ();
#    undef $M_check_viol;
#    $M_check_viol = CheckViol->new();
#    @cap_ts = $M_check_viol->get_cap ("$viol_file");
#    foreach $cap_t (@cap_ts) {
#      if (grep ${$cap_t}[0] eq $_, keys %cap) {
#        my $viol_t = ${$cap_t}[1] - ${$cap_t}[2];
#        if ($viol_t > $cap{${$cap_t}[0]}{violation}) {
#          $cap{${$cap_t}[0]}{reqd} = ${$cap_t}[1];
#          $cap{${$cap_t}[0]}{cap} = ${cap_t}[2];
#          $cap{${$cap_t}[0]}{violation} = $viol_t;
#          $cap{${$cap_t}[0]}{violfile} = ${$cap_t}[3];
#        }
#      }
#      else {
#        $cap{${$cap_t}[0]}{reqd} = ${$cap_t}[1];
#        $cap{${$cap_t}[0]}{cap} = ${$cap_t}[2];
#        $cap{${$cap_t}[0]}{violation} = ${$cap_t}[1] - ${$cap_t}[2];
#        $cap{${$cap_t}[0]}{violfile} = ${$cap_t}[3];
#      }
#    }
#  }
  set_perl_only off;
  return ($M_check_viol);
}

sub is_from_top {
  my $nod = shift;
  my $block = get_top;
  my @fan_in = get_fanin (-end, $nod);
  my $return = 0;
  foreach  (@fan_in) {
      my $ref = ${$_}[2];
      if ($ref  eq  $block) {
        $return = 1;
        last;
      }
  }
  return ($return);
}

sub sp_get_pin_context {
  my $viol_pin = shift;
  my ($l_pin,$net,$driver_ref,$net_length,$loads); #$driver_ref is driver ref or port name; $loads are number of loads or port name
  my ($top_inst, $module);
  set_perl_only on;
  $l_pin = rindex $viol_pin."\$", "\$";
  set_perl_only off;
  if (is_pin $viol_pin) {
    $net_local = get_net (-local => -of => $viol_pin);
    ($top_inst, $module, $net) = get_net_context ($net_local);
    push_top ($module);

    my $route_length = get_route_length $net;
    my $stiner_length= get_net_length $net;
    $net_length = (get_route_length $net) ? ($route_length) : "$stiner_length".'*';
    pop_top ();
    $net = $net_local;
    if (is_driver $viol_pin) {
      my @viol_pin_context = get_pin_context ($viol_pin); #$viol_pin_context[1] is ref of the given pin;
      $driver_ref = $viol_pin_context[1];
      $loads = (is_port $net)?("port"):(get_loads $viol_pin);
    }
    elsif (is_load $viol_pin) {
      my @viol_pin_context = (is_port $net) ? ():((is_pin get_drivers $viol_pin) ? get_pin_context (get_drivers $viol_pin) : ());
      $driver_ref = (is_port $net)?("port"):((scalar @viol_pin_context) ? $viol_pin_context[1]: NA);
      my $load_num = get_loads $net;
      $loads = "self\/$load_num";
    }
  } elsif (is_net $viol_pin) {
     # print "Get a net with violation net: $viol_pin\n";
      $net = $viol_pin;
  #    my ($top_inst, $module, $net) = get_net_context ($net_name);
  #    push_top ($module);

      if (is_port $viol_pin) {
        $driver_ref = (is_input $viol_pin) ? ("port") : (get_ref (get_drivers (-inst => $viol_pin)));
        my $load_num = get_loads $viol_pin;
        $loads = (is_output $viol_pin) ? ("port") : "self\/$load_num" ; 
        my $route_length = get_route_length $viol_pin;
        my $stiner_length= get_net_length $viol_pin;
        $net_length = (get_route_length $viol_pin) ? ($route_length) : "$stiner_length".'*';
      } 
      else {
        my @viol_pin_context = (is_port $net) ? ():(get_pin_context (get_drivers $viol_pin));
        $driver_ref = (is_port $net)?("port"):($viol_pin_context[1]);
        my $load_num = get_loads $viol_pin;
        $loads = "self\/$load_num";
        my $route_length = get_route_length $viol_pin;
        my $stiner_length= get_net_length $viol_pin;
        $net_length = (get_route_length $viol_pin) ? ($route_length) : "$stiner_length".'*';
#        $net_length = (get_route_length $viol_pin) ? (get_route_length $viol_pin) : -1;
      }
  } else {
     $driver_ref = "NA";
     $net_length = "NA";
     $loads      = "NA";
     $net        = "NA";
  }
  return ($l_pin,$driver_ref,$net_length,$loads,$net);
}



sub sp_get_glitch  {
  set_perl_only on;
  my @viol_files =  sp_get_viol_files;# @_;
  @viol_files = grep (/glitch/, @viol_files);
  @viol_files or print "ERROR: No glitch Viol Files input\n";
  undef $M_check_viol;
  $M_check_viol = CheckViol->new();
  $M_check_viol->get_glitch(@viol_files);
  set_perl_only off;
#adding more info: is_detour net? is_inter? driver strength? loads_num? route_length_net?
  return ($M_check_viol);
}

sub m_report_cap {
  my $header = "-" x195;
  my %opts = @_;
  my @return;
  if (%opts and (grep ($_ !~ /-pin|-slack|-intra|-record|-top/,(keys %opts)))) {
    print "Error: undefined parameters found in your constraint\n";
    print "  -pin \<pin_name\> : print the detail information of the speficied pin\n"; 
    print "  -record \<1 | 0\> : print the eco_tracker information\n";
    print "  -slack \<slack\>  : print the viols whose slack is worse than specified\n";  
    print "  -top    \<1 | 0\> : print or not print the viols from or to port\n";
    print "  -intra  \<1 | 0\> : print intra viols only\n";
    return(0);
  }

  if (defined $opts{-pin} and (defined $opts{-slack} or defined $opts{-top})) {
    print "Error: the constraint -pin can't be combined with any other ones\n";
    return (0);
  }
  if (defined $opts{-pin} and (!(is_pin $opts{-pin}) and !(is_net $opts{-pin}))) {return("Pin not found or was modified in the eco,undo_eco and try")};
  if ((defined $opts{-slack}) and ($opts{-slack} !~ /\b\-|\d\b/)) {return ("Please give the value of max_cap threshold")};
  if ((defined $opts{-record}) and ($opts{-record} !~ /1|0/)) {return ("Please give 1 or 0 as indication")};

  my $format_header1 = "%-110s%12s%12s%8s%19s%13s%15s%10s";
  my $format_header2 = "%-110s%12.3f%12.3f%8.3f%19s%13.2f%15s%10s";
  if (defined $opts{-intra}) {
    $SHPD_save_netfix_mode = $netfix_mode;
    $netfix_mode = 0;
    $M_sp_max_cap = ();
    $SHPD_m_report_data_reload = 1;
  }

  #handle the detail infor for one endpoint:
  if (defined $M_sp_max_cap && $SHPD_m_report_data_reload) {
    $netfix_mode = $SHPD_save_netfix_mode;
    $M_sp_max_cap = sp_get_cap();
    $SHPD_m_report_data_reload = 0;
    #$netfix_mode = $SHPD_save_netfix_mode;
  }
  unless (defined $M_sp_max_cap) {
    $M_sp_max_cap = sp_get_cap();
  }
  my $block = get_top ();
  my $ipo = get_ipo_num $block;
  my $wns = 10000;
  #$M_sp_max_cap = sp_get_cap;
  my $max_cap = $M_sp_max_cap;
  if (defined $opts{-pin}) {
    my @rtn_table;
    my ($l_pin,$driver_ref,$net_length,$loads,$net) = sp_get_pin_context ($opts{-pin});
    $net_length = sprintf ("%.1f", $net_length);
    my $cap_bak = shift @{$max_cap->{cap}{$opts{-pin}}};
    
    my $record;
#    print "$header\n";
#    printf "\n$format_header1\n",VIOL_FILES,REQUD,ACTUAL,SLACK,DRIVER_REF,NET_LENGTH,LOADS,FIXED;
    foreach my $pin_arr (@{$max_cap->{cap}{$opts{-pin}}}) {
    #printf  "$format_header2\n",${$pin_arr}{file},${$pin_arr}{reqd},${$pin_arr}{cap},${$pin_arr}{violation},$driver_ref,$net_length,$loads,$record;
    my ($ipo_num) = ${$pin_arr}{file} =~ /anno(\w+)[^\/]*$/;
    if ($netfix_mode) {
        $record = (get_eco_tracker (-ipo_num => $ipo_num,$opts{-pin})) ? 1 :0;
    } else {
        $record = "unkown";
    }
        ${$pin_arr}{reqd} = sprintf ("%.3f", ${$pin_arr}{reqd});
        ${$pin_arr}{cap} = sprintf ("%.3f", ${$pin_arr}{cap});
        ${$pin_arr}{violation} = sprintf ("%.3f", ${$pin_arr}{violation});
        push (@rtn_table, [${$pin_arr}{file},${$pin_arr}{reqd},${$pin_arr}{cap},${$pin_arr}{violation},$driver_ref,$net_length,$loads,$record]);
    }
    unshift (@{$max_cap->{cap}{$opts{-pin}}},$cap_bak);
    @rtn_table = map (join ("\t", @$_), @rtn_table);
    unshift (@rtn_table,"VIOL_FILES\tREQUD\tACTUAL\tSLACK\tDRIVER_REF\tNET_LENGTH\tLOADS\tFIXED");
    @rtn_table = table_tab (@rtn_table);
    splice (@rtn_table, 1,0, "-" x length ($rtn_table[0]));
    @rtn_table;
  }
  else {
#  shift @{$max_cap->{cap}{$opts{-pin}}};  
    my @rtn_table;
    foreach my $viol_pin (keys %{$max_cap->{cap}}) {
      my ($l_pin,$driver_ref,$net_length,$loads,$net) = sp_get_pin_context ($viol_pin);
      $net_length = sprintf ("%.1f",$net_length);
      $max_cap->{cap}{$viol_pin}[0]{is_top} = (is_port($net)) ? 1 : 0;
      my $record;
    my ($ipo_num) = $max_cap->{cap}{$viol_pin}[0]{file} =~ /anno(\w+)[^\/]*$/;
    if ($netfix_mode) {
        $record = (get_eco_tracker (-ipo_num => $ipo_num,$viol_pin)) ? 1 :0;
    } else {
        $record = "unkown";
    }

      my ($c_top,$c_slack,$c_record);
      $c_top    = (defined $opts{-top}) ? $opts{-top} : ($max_cap->{cap}{$viol_pin}[0]{is_top});
      $c_slack  = (defined $opts{-slack}) ? $opts{-slack} : 0.1;#$max_cap->{cap}{$viol_pin}[0]{violation};
      $c_record = (defined $opts{-record}) ? $opts{-record} : $record; 
      if ((($max_cap->{cap}{$viol_pin}[0]{violation}) <= $c_slack) and (($max_cap->{cap}{$viol_pin}[0]{is_top}) == $c_top) and ($c_record == $record)) {      
        push @return, sprintf  "$format_header2\n",$viol_pin,$max_cap->{cap}{$viol_pin}[0]{reqd},$max_cap->{cap}{$viol_pin}[0]{cap},$max_cap->{cap}{$viol_pin}[0]{violation},$driver_ref,$net_length,$loads,$record;
        $max_cap->{cap}{$viol_pin}[0]{reqd} = sprintf ("%.3f", $max_cap->{cap}{$viol_pin}[0]{reqd});
        $max_cap->{cap}{$viol_pin}[0]{cap} = sprintf ("%.3f", $max_cap->{cap}{$viol_pin}[0]{cap});
        $max_cap->{cap}{$viol_pin}[0]{violation} = sprintf ("%.3f",$max_cap->{cap}{$viol_pin}[0]{violation});
        push (@rtn_table,[$viol_pin,$max_cap->{cap}{$viol_pin}[0]{reqd},$max_cap->{cap}{$viol_pin}[0]{cap},$max_cap->{cap}{$viol_pin}[0]{violation},$driver_ref,$net_length,$loads,$record]);
#        if ($record == 0 or $record eq "unkown") {
          $wns = ($max_cap->{cap}{$viol_pin}[0]{violation} < $wns ) ? $max_cap->{cap}{$viol_pin}[0]{violation} : $wns;
#        }
      }
    }
    #printf "\n$format_header1\n",VIOLATORS,REQUD,ACTUAL,SLACK,DRIVER_REF,NET_LENGTH,LOADS,FIXED;
    #print "$header\n";
    #return (@return);
    my $viol_num = scalar (@rtn_table); 
    unless ($viol_num) {$wns = "NA";};
    @rtn_table = map (join ("\t", @$_), @rtn_table);
#    unshift (@rtn_table,"$header");
    unshift (@rtn_table,"VIOLATORS\tREQUD\tACTUAL\tSLACK\tDRIVER_REF\tNET_LENGTH\tLOADS\tFIXED");
    @rtn_table = table_tab (@rtn_table);
    splice (@rtn_table, 1,0, "-" x length ($rtn_table[0]));
    push (@rtn_table,"\nTotal max_cap viols need to fix: $wns ($viol_num)");
  if (defined $opts{-intra}) {
    $netfix_mode = $SHPD_save_netfix_mode;
  }
    @rtn_table;
      
  }
}


sub m_report_trans {
  my $header = "-" x195;
  my %opts = @_;
  my @return;
  if (%opts and (grep ($_ !~ /-pin|-slack|-intra|-record|-top/,(keys %opts)))) {
    print "Error: undefined parameters found in your constraint\n";
    print "  -pin \<pin_name\> : print the detail information of the speficied pin\n"; 
    print "  -record \<1 | 0\> : print the eco_tracker information\n";
    print "  -slack \<slack\>  : print the viols whose slack is worse than specified\n";  
    print "  -top    \<1 | 0\> : print or not print the viols from or to port\n";
    print "  -intra  \<1 | 0\> : print intra viols only\n";
    return(0);
  }

  if (defined $opts{-pin} and (defined $opts{-slack} or defined $opts{-top})) {
    print "Error: the constraint -pin can't be combined with any other ones\n";
    return (0);
  }
  if (defined $opts{-pin} and (!(is_pin $opts{-pin}) and !(is_net $opts{-pin}))) {return("Pin not found or was modified in the eco,undo_eco and try")};
  if ((defined $opts{-slack}) and ($opts{-slack} !~ /\b\-|\d\b/)) {return ("Please give the value of max_trans threshold")};
  if ((defined $opts{-record}) and ($opts{-record} !~ /1|0/)) {return ("Please give 1 or 0 as indication")};

  my $format_header1 = "%-110s%12s%12s%8s%19s%13s%15s%10s";
  my $format_header2 = "%-110s%12.3f%12.3f%8.3f%19s%13.2f%15s%10s";
  
  if (defined $opts{-intra}) {
    $SHPD_save_netfix_mode = $netfix_mode;
    $netfix_mode = 0;
    $M_sp_max_trans = ();
    $SHPD_m_report_data_reload = 1;
  }

  #handle the detail infor for one endpoint:
  if (defined $M_sp_max_trans && $SHPD_m_report_data_reload) {
    $netfix_mode = $SHPD_save_netfix_mode;
    $M_sp_max_trans = sp_get_trans();
    $SHPD_m_report_data_reload = 0;
  }
  unless (defined $M_sp_max_trans) {
    $M_sp_max_trans = sp_get_trans();
  }
  if ($netfix_mode) {
#    set_use_eco_tracker on;
#    init_tracker -all;
   }
  my $block = get_top;
  my $ipo   = get_ipo_num $block;
  my $wns = 1;
  #$M_sp_max_trans = sp_get_trans;
  my $max_trans = $M_sp_max_trans;
  if (defined $opts{-pin}) {
    my @rtn_table;
    my ($l_pin,$driver_ref,$net_length,$loads,$net) = sp_get_pin_context ($opts{-pin});
    $net_length = sprintf ("%.1f", $net_length);
    my $trans_bak = shift @{$max_trans->{trans}{$opts{-pin}}};
    
    my $record;
#    print "$header\n";
#    printf "\n$format_header1\n",VIOL_FILES,REQUD,ACTUAL,SLACK,DRIVER_REF,NET_LENGTH,LOADS,FIXED;
    foreach my $pin_arr (@{$max_trans->{trans}{$opts{-pin}}}) {
    #printf  "$format_header2\n",${$pin_arr}{file},${$pin_arr}{reqd},${$pin_arr}{trans},${$pin_arr}{violation},$driver_ref,$net_length,$loads,$record;
    my ($ipo_num) = ${$pin_arr}{file} =~ /anno(\w+)[^\/]*$/;
    if ($netfix_mode) {
        $record = (get_eco_tracker (-ipo_num => $ipo_num,$opts{-pin})) ? 1 :0;
    } else {
        $record = "unkown";
    }

        lprint "actual trans1 ${$pin_arr}{trans}\n";
        ${$pin_arr}{reqd} = sprintf ("%.3f", ${$pin_arr}{reqd});
        ${$pin_arr}{trans} = sprintf ("%.3f", ${$pin_arr}{trans});
        ${$pin_arr}{violation} = sprintf ("%.3f", ${$pin_arr}{violation});
        push (@rtn_table, [${$pin_arr}{file},${$pin_arr}{reqd},${$pin_arr}{trans},${$pin_arr}{violation},$driver_ref,$net_length,$loads,$record]);
    }
    unshift (@{$max_trans->{trans}{$opts{-pin}}},$trans_bak);
    @rtn_table = map (join ("\t", @$_), @rtn_table);
    unshift (@rtn_table,"VIOL_FILES\tREQUD\tACTUAL\tSLACK\tDRIVER_REF\tNET_LENGTH\tLOADS\tFIXED");
    @rtn_table = table_tab (@rtn_table);
    splice (@rtn_table, 1,0, "-" x length ($rtn_table[0]));
    @rtn_table;
  }
  else {
#  shift @{$max_trans->{trans}{$opts{-pin}}};  
    my @rtn_table;
    foreach my $viol_pin (keys %{$max_trans->{trans}}) {
      my ($l_pin,$driver_ref,$net_length,$loads,$net) = sp_get_pin_context ($viol_pin);
      $net_length = sprintf ("%.1f",$net_length);
      $max_trans->{trans}{$viol_pin}[0]{is_top} = (is_port($net)) ? 1 : 0;
      my $record;
      my ($ipo_num) = $max_trans->{trans}{$viol_pin}[0]{file} =~ /anno(\w+)[^\/]*$/;
      if ($netfix_mode) {
          $record = (get_eco_tracker (-ipo_num => $ipo_num, $viol_pin)) ? 1 :0;
      } else {
          $record = "unkown";
      }
      my $corner;
      my $base = $max_trans->{trans}{$viol_pin}[0]{file};
      $base =~ s/^.*\///;
      if ($base =~ /\.(ccs|nldm)/) { #New naming convention
          $base =~ /\.\w*anno/ or $base =~ s/^(\w+)/\.annoX/;
          my ($module, $ipo_num, $tool, $lib_type, $lib_cond, $voltage, $rc, $ocv, $si, $flat, $mode) = split (/\./, $base);
          $corner = "${voltage}_${lib_cond}_${si}";
      }
      my ($c_top,$c_slack,$c_record);
      $c_top    = (defined $opts{-top}) ? $opts{-top} : ($max_trans->{trans}{$viol_pin}[0]{is_top});
      $c_slack  = (defined $opts{-slack}) ? $opts{-slack} : 0.1;#$max_trans->{trans}{$viol_pin}[0]{violation};
      $c_record = (defined $opts{-record}) ? $opts{-record} : $record; 
      if ((($max_trans->{trans}{$viol_pin}[0]{violation}) <= $c_slack) and (($max_trans->{trans}{$viol_pin}[0]{is_top}) == $c_top) and ($c_record == $record)) {      
        push @return, sprintf  "$format_header2\n",$viol_pin,$max_trans->{trans}{$viol_pin}[0]{reqd},$max_trans->{trans}{$viol_pin}[0]{trans},$max_trans->{trans}{$viol_pin}[0]{violation},$driver_ref,$net_length,$loads,$record,$corner;
        $max_trans->{trans}{$viol_pin}[0]{reqd} = sprintf ("%.3f", $max_trans->{trans}{$viol_pin}[0]{reqd});
        $max_trans->{trans}{$viol_pin}[0]{trans} = sprintf ("%.3f", $max_trans->{trans}{$viol_pin}[0]{trans});
        $max_trans->{trans}{$viol_pin}[0]{violation} = sprintf ("%.3f",$max_trans->{trans}{$viol_pin}[0]{violation});
        push (@rtn_table,[$viol_pin,$max_trans->{trans}{$viol_pin}[0]{reqd},$max_trans->{trans}{$viol_pin}[0]{trans},$max_trans->{trans}{$viol_pin}[0]{violation},$driver_ref,$net_length,$loads,$record,$corner]);
#        if ($record == 0 or $record eq "unkown") {
          $wns = ($max_trans->{trans}{$viol_pin}[0]{violation} < $wns) ? $max_trans->{trans}{$viol_pin}[0]{violation} : $wns;
#        }
      }
    }
    #printf "\n$format_header1\n",VIOLATORS,REQUD,ACTUAL,SLACK,DRIVER_REF,NET_LENGTH,LOADS,FIXED;
    #print "$header\n";
    #return (@return);
    my $viol_num = scalar (@rtn_table);
    unless ($viol_num) {$wns = "NA";};
    @rtn_table = map (join ("\t", @$_), @rtn_table);
#    unshift (@rtn_table,"$header");
    unshift (@rtn_table,"VIOLATORS\tREQUD\tACTUAL\tSLACK\tDRIVER_REF\tNET_LENGTH\tLOADS\tFIXED\tCORNER");
    @rtn_table = table_tab (@rtn_table);
    splice (@rtn_table, 1,0, "-" x length ($rtn_table[0]));
    push (@rtn_table,"\nTotal transition viols need to fix: $wns ($viol_num)");
    #push (@rtn_table,"$wns ($viol_num)");
  if (defined $opts{-intra}) {
    $netfix_mode = $SHPD_save_netfix_mode;
  }

    @rtn_table;
      
  }
}

#sub m_report_trans {


sub m_report_mins {
#  my $mins = sp_get_mins;
  my $header = "-" x195;
  my %opts = @_;
  if (%opts and (grep($_ !~ /\-slack_max\b|\-slack_min\b|\-clock\b|\-pin\b|\-skew\b|\-top\b|\-intra\b|\-corner\b|\-record\b/, (keys %opts)))) {
    print "  \nError: undefined parameters found\n";
    print "  The constaint can be combined in the command: m_report_mins \<constraint\>\n";
    print "  -record \<1 | 0\>                 : print the eco_tracker status, 1 means has been fixed\n";
    print "  -intra \<1 | 0\>                  : print only intra partition violations\n";
    print "  -pin    \<pin_name\>              : print hold detail information of the given pin\n";
    print "  -slack_max    \<setup_margin\>    : print hold viols to which the setup slack is worse than the setup_margin given\n";
    print "  -slack_min    \<hold_threshold\>  : print hold viols to which the hold slack is worse than the hold_threshold given\n";
    print "  -clock  \<clock_domain\>          : print hold viols from the spefified domain. only works in netfix mode\n";
    print "  -skew   \<skew_threshold\>        : print hold viols with the skew larger than skew_threshold\n";
    print "  -top    \<1 | 0\>                 : print or not print hold  viols that have  fanins from port\n";
    print "  -corner \<sf|hf|ss\>                : print hold  viols of the specified corner,which should be one of (sf,hf,ss),\n";
    print "                                    which means sv fast,hv fast,sv slow respectively\n";
    return ();
   }; 
  if (defined $opts{-pin} and (defined $opts{-slack_max} or defined $opts{-slack_min} or defined $opts{-clock} or defined $opts{-skew} or defined $opts{-top} or defined $opts{-corner})) {
    return (" Error: the constraint -pin can't be combined with any other ones");    
  }
  if ((defined $opts{-clock}) and (!(glob_from_array($opts{-clock}, keys %Timing_group)))) {
     print "Error: No group that has violation  matched $opts{-clock} in:\n";
     foreach (keys %Timing_group) {
      print "  $_\n";
    }
  return ();
  }
  if (defined $opts{-pin} and (!(is_pin $opts{-pin}) and !(is_net $opts{-pin}))) {return("Please give the correct pin name")};
  if ((defined $opts{-slack_min}) and (!(is_number ($opts{-slack_min})))) {return ("Please give the value of  hold threshold")};
  if ((defined $opts{-slack_max}) and (!(is_number ($opts{-slack_max})))) {return ("Please give the value of setup margin")};
  if ((defined $opts{-skew}) and (!(is_number ($opts{-skew})))) {return ("Please give the value of skew")};
  if ((defined $opts{-top}) and ($opts{-top} !~ /1|0/)) {return ("Please give 1 or 0 as indication")};
  if ((defined $opts{-corner}) and ($opts{-corner} !~ /sf|hf|ss/)) {return ("Please give sf,hf,ss")};
  if ((defined $opts{-record}) and ($opts{-record} !~ /1|0/)) {return ("Please give 1 or 0 as indication")};
#  (defined $opts{-intra}) and ($netfix_mode = 0);
  if (defined $opts{-intra}) {
    $SHPD_save_netfix_mode = $netfix_mode;
    $netfix_mode = 0;
    $SHPD_m_report_data_reload = 1;
    $M_sp_max_mins = ();
  }

  #handle the detail infor for one endpoint:
  if (defined $M_sp_max_mins && $SHPD_m_report_data_reload) {
    $netfix_mode = $SHPD_save_netfix_mode;
    $M_sp_max_mins = sp_get_mins();
    $SHPD_m_report_data_reload = 0;
    #$netfix_mode = $SHPD_save_netfix_mode;
  }

  unless (defined $M_sp_max_mins) {
    $M_sp_max_mins = sp_get_mins();
  }
  if ($netfix_mode) {
   }
  my $block = get_top ;
  my $ipo   = get_ipo_num $block;
  my $mins = $M_sp_max_mins;
  my $wns = 10000;
 
  my $format_1 = "%-110s%15s%10s%10s%10s%10s%10s%20s";
  my $format_2 = "%-110s%15s%10s%10s%10s%10s%10s%20s";
  my (@out,@return);
  if (defined $opts{-pin}) {
    my @rtn_table;
    my $end_bak = shift @{$mins->{min}{$opts{-pin}}};
#    print "\n$header\n";
#    printf "$format_2\n",VIOL_FILE,GROUP,SKEW,MIN,MAX,IS_TOP,FIXED,CORNER;
    foreach (@{$mins->{min}{$opts{-pin}}}) {
      $_->{max} = sprintf "%.3f",(wh_get_slack_max ($opts{-pin}));
      $_->{is_from_top} = is_from_top ($opts{-pin});

      my ($ipo_num) = $_->{file} =~ /anno(\w+)[^\/]*$/;
      if ($netfix_mode) {
        $_->{record} = (get_eco_tracker (-ipo_num => $ipo_num, -type => "hold", $opts{-pin})) ? 1 :0;
        lprint "tracker for hold: track: $_->{record},ipo_num $ipo_num,pin:$end\n";
      } else {
        $_->{record}  = "unkown";
      }
      #my $format = sprintf "$format_2\n",$_->{file},$_->{group},$_->{skew},$_->{slack},$_->{max},$_->{is_from_top},$_->{record},$_->{corner};
      #push (@return,$format);
      push (@rtn_table,[$_->{file},$_->{group},$_->{skew},$_->{slack},$_->{max},$_->{is_from_top},$_->{record},$_->{corner}]);
    }
    unshift (@{$mins->{min}{$opts{-pin}}},$end_bak); 
    #return (@return);
    @rtn_table = map ((join "\t",@$_),@rtn_table);
    unshift (@rtn_table, "VIOL_FILE\tGROUP\tSKEW\tMIN\tMAX\tIS_TOP\tFIXED\tCORNER");
    @rtn_table = table_tab (@rtn_table);
    splice (@rtn_table, 1,0, "-" x length ($rtn_table[0]));
    @rtn_table;
  }
  else {
    my %viols_ends = ();
    my @rtn_table;
    foreach my $end (keys %{$mins->{min}}) {
    #  $viols_ends{$end} = 1;
      my $end_bak = shift @{$mins->{min}{$end}};
      foreach (@{$mins->{min}{$end}}) {
        my ($c_min,$c_max,$c_group,$c_skew,$c_istop,$c_corner);
        $_->{max} = sprintf "%.3f" ,(wh_get_slack_max ($end)); 
        $_->{is_from_top} = is_from_top ($end); 

    my ($ipo_num) = $_->{file} =~ /anno(\w+)[^\/]*$/;
    if ($netfix_mode) {
        $_->{record} = (get_eco_tracker (-ipo_num => $ipo_num, -type => "hold", $end)) ? 1 :0;
    #    lprint "tracker for hold: track: $_->{record},ipo_num $ipo_num,pin:$end\n";
    } else {
        $_->{record}  = "unkown";
    }
  
        $c_min     = (defined $opts{-slack_min}) ? $opts{-slack_min} : 999999; 
        $c_max     = (defined $opts{-slack_max}) ? $opts{-slack_max} : 999999; 
        $c_group   = (defined $opts{-clock})     ? $opts{-clock}     : $_->{group};
        $c_skew    = (defined $opts{-skew})      ? $opts{-skew}      : $_->{skew}; #UNKN
        $c_istop   = (defined $opts{-top})       ? $opts{-top}       : $_->{is_from_top}; #need to speaded;
        $c_record  = (defined $opts{-record})    ? $opts{-record}    : $_->{record};
        $c_corner  = (defined $opts{-corner})    ? $opts{-corner}    : $_->{corner}; 
        if (($_->{slack} <= $c_min) and ($_->{max} <= $c_max) and ($_->{group} eq $c_group or ((!(defined $opts{-clock})) and $_->{group} eq "UNKNOWN")) and ($_->{skew} >= $c_skew or (!(defined $opts{-skew}) and $_->{skew} eq "UNKNOWN")) and ($c_record == $_->{record}) and ($_->{is_from_top} == $c_istop) and ($_->{corner} eq $c_corner)) {
        push (@out, [$_,$end]);
        $viols_ends{$end} = 1;
        }
      }
      unshift (@{$mins->{min}{$end}},$end_bak);
    }
    @out or print "No violations found under your constraint, or some of your parameters may not correct\n" and return ();
#    print "\n$header\n";
#    printf "$format_1\n",END_POINT,GROUP,SKEW,MIN,MAX,IS_TOP,FIXED,CORNER;
    foreach (@out) {
      push @return, sprintf  "$format_1\n",${$_}[1],${$_}[0]->{group},${$_}[0]->{skew},${$_}[0]->{slack},${$_}[0]->{max},${$_}[0]->{is_from_top},${$_}[0]->{record},${$_}[0]->{corner};
      push (@rtn_table,[${$_}[1],${$_}[0]->{group},${$_}[0]->{skew},${$_}[0]->{slack},${$_}[0]->{max},${$_}[0]->{is_from_top},${$_}[0]->{record},${$_}[0]->{corner}]);
#      if (${$_}[0]->{record} == 0 or ${$_}[0]->{record} eq "unkown") {
        $wns = (${$_}[0]->{slack} < $wns) ? ${$_}[0]->{slack} : $wns;
#      }
    }
    my $viol_num = scalar (keys %viols_ends);
    unless ($viol_num) {$wns = "NA";};
#    return (@return,scalar (@return));
    @rtn_table = map ((join "\t",@$_), @rtn_table); 
    unshift (@rtn_table,"END_POINT\tGROUP\tSKEW\tMIN\tMAX\tIS_TOP\tFIXED\tCORNER");
    @rtn_table = table_tab (@rtn_table);
    splice (@rtn_table, 1,0, "-" x length ($rtn_table[2]));
    push (@rtn_table,"\nTotal hold viols need to fix: $wns ($viol_num)");
    #push (@rtn_table,"$wns ($viol_num)");
  if (defined $opts{-intra}) {
    $netfix_mode = $SHPD_save_netfix_mode;
  }

    @rtn_table;

  }
}


Tsub m_report_glitch => << 'END';
    ARGS {
        -pin:$c_pin #print the detail information of the pin
        -record:$c_record #filter by eco_tracker status
        -slack:$slack_threshold #filter by slack
        -top:$c_top #print the viols that are from or to port
        -intra:$c_intra #print viols from intra partition viol files
        -slacktype: $c_slacktype #filter by slack type, can be area or height
    }

  (defined $c_slacktype && (!($c_slacktype eq "area" or $c_slacktype eq "height"))) and error "Wrong slacktype: $c_slacktype, should be area, or height"; 
  if ($c_intra) {
    $SHPD_save_netfix_mode = $netfix_mode;
    $netfix_mode = 0;
    $M_sp_max_glitch = ();
    $SHPD_m_report_data_reload = 1;
  }

  #handle the detail infor for one endpoint:
  if (defined $M_sp_max_glitch && $SHPD_m_report_data_reload) {
    $netfix_mode = $SHPD_save_netfix_mode;
    $M_sp_max_glitch = sp_get_glitch();
    $SHPD_m_report_data_reload = 0;
  }
  unless (defined $M_sp_max_glitch) {
    $M_sp_max_glitch = sp_get_glitch();
  }

  my $block = get_top;
  my $ipo   = get_ipo_num $block;
  my $wns = 10000;
  #$M_sp_max_glitch = sp_get_glitch;
  my $max_glitch = $M_sp_max_glitch;
  if (defined $c_pin) {
    my @rtn_table;
    my ($l_pin,$driver_ref,$net_length,$loads,$net) = sp_get_pin_context ($c_pin);
    $net_length = sprintf ("%.1f", $net_length);
    foreach my $slacktype (keys %{$max_glitch->{glitch}{$c_pin}}) {
    my $glitch_bak = shift @{$max_glitch->{glitch}{$c_pin}{$slacktype}};
    
    my $record;
    foreach my $pin_arr (@{$max_glitch->{glitch}{$c_pin}{$slacktype}}) {
    my ($ipo_num) = ${$pin_arr}{file} =~ /anno(\w+)[^\/]*$/;
    if ($netfix_mode) {
        $record = (get_eco_tracker (-ipo_num => $ipo_num,$c_pin)) ? 1 :0;
    } else {
        $record = "unkown";
    }

        ${$pin_arr}{width} = sprintf ("%.3f", ${$pin_arr}{width});
        ${$pin_arr}{height} = sprintf ("%.3f", ${$pin_arr}{height});
        ${$pin_arr}{violation} = sprintf ("%.3f", ${$pin_arr}{violation});
        push (@rtn_table, [${$pin_arr}{file},${$pin_arr}{width},${$pin_arr}{height},${$pin_arr}{violation},$driver_ref,$net_length,$loads,$slacktype,$record]);
    }
    unshift (@{$max_glitch->{glitch}{$c_pin}{$slacktype}},$glitch_bak);
    }
    #unshift (@{$max_glitch->{glitch}{$c_pin}{$slacktype}},$glitch_bak);
    @rtn_table = map (join ("\t", @$_), @rtn_table);
    unshift (@rtn_table,"VIOL_FILES\tWIDTH\tHEIGHT\tSLACK\tDRIVER_REF\tNET_LENGTH\tLOADS\tSLACKTYPE\tFIXED");
    @rtn_table = table_tab (@rtn_table);
    splice (@rtn_table, 1,0, "-" x length ($rtn_table[0]));
    @rtn_table;
  }
  else {
    my @rtn_table;
    foreach my $viol_pin (keys %{$max_glitch->{glitch}}) {
      my ($l_pin,$driver_ref,$net_length,$loads,$net) = sp_get_pin_context ($viol_pin);
      $net_length = sprintf ("%.1f",$net_length);
      foreach my $slacktype (keys %{$max_glitch->{glitch}{$viol_pin}}) {
      if (defined $c_slacktype)  {($slacktype eq $c_slacktype) or next;}
      $max_glitch->{glitch}{$viol_pin}{$slacktype}[0]{is_top} = (is_port($net)) ? 1 : 0;
      my $record;
      my ($ipo_num) = $max_glitch->{glitch}{$viol_pin}{$slacktype}[0]{file} =~ /anno(\w+)[^\/]*$/;
      if ($netfix_mode) {
          $record = (get_eco_tracker (-ipo_num => $ipo_num, $viol_pin)) ? 1 :0;
      } else {
          $record = "unkown";
      }
      my $corner;
      my $base = $max_glitch->{glitch}{$viol_pin}{$slacktype}[0]{file};
      $base =~ s/^.*\///;
      if ($base =~ /\.(ccs|nldm)/) { #New naming convention
          $base =~ /\.\w*anno/ or $base =~ s/^(\w+)/\.annoX/;
          my ($module, $ipo_num, $tool, $lib_type, $lib_cond, $voltage, $rc, $ocv, $si, $flat, $mode) = split (/\./, $base);
          $corner = "${voltage}_${lib_cond}_${si}";
      }
      $c_top    = (defined $c_top) ? $c_top : ($max_glitch->{glitch}{$viol_pin}{$slacktype}[0]{is_top});
      $c_slack  = (defined $slack_threshold) ? $slack_threshold : 0.1;#$max_glitch->{glitch}{$viol_pin}{$slacktype}[0]{violation};
      $c_record = (defined $c_record) ? $c_record : $record; 
      if ((($max_glitch->{glitch}{$viol_pin}{$slacktype}[0]{violation}) <= $c_slack) and (($max_glitch->{glitch}{$viol_pin}{$slacktype}[0]{is_top}) == $c_top) and ($c_record == $record)) {      
        $max_glitch->{glitch}{$viol_pin}{$slacktype}[0]{width} = sprintf ("%.3f", $max_glitch->{glitch}{$viol_pin}{$slacktype}[0]{width});
        $max_glitch->{glitch}{$viol_pin}{$slacktype}[0]{height} = sprintf ("%.3f", $max_glitch->{glitch}{$viol_pin}{$slacktype}[0]{height});
        $max_glitch->{glitch}{$viol_pin}{$slacktype}[0]{violation} = sprintf ("%.3f",$max_glitch->{glitch}{$viol_pin}{$slacktype}[0]{violation});
        push (@rtn_table,[$viol_pin,$max_glitch->{glitch}{$viol_pin}{$slacktype}[0]{width},$max_glitch->{glitch}{$viol_pin}{$slacktype}[0]{height},$max_glitch->{glitch}{$viol_pin}{$slacktype}[0]{violation},$driver_ref,$net_length,$loads,$record,$slacktype,$corner]);
          $wns = ($max_glitch->{glitch}{$viol_pin}{$slacktype}[0]{violation} < $wns) ? $max_glitch->{glitch}{$viol_pin}{$slacktype}[0]{violation} : $wns;
      }
      }
    }
    my $viol_num = scalar (@rtn_table);
    unless ($viol_num) {$wns = "NA";};
    @rtn_table = map (join ("\t", @$_), @rtn_table);
    unshift (@rtn_table,"VIOLATORS\tWIDTH\tHEIGHT\tSLACK\tDRIVER_REF\tNET_LENGTH\tLOADS\tFIXED\tSLACKTYPE\tCORNER");
    @rtn_table = table_tab (@rtn_table);
    splice (@rtn_table, 1,0, "-" x length ($rtn_table[0]));
    push (@rtn_table,"\nTotal glitch viols need to fix: $wns ($viol_num)");
  if ($c_intra) {
    $netfix_mode = $SHPD_save_netfix_mode;
  }
    @rtn_table;
  }

END

Tsub all_units => << 'END';
    DESC {
        Return the unit names of the current proj in array.
    }
    ARGS {

    }
    
    my @units = ();
    foreach my $unit ( keys %{${$CONFIG->partitioning}{"units"}}) {
        (is_macro_module $unit) and next; #Skip top level macro;
        (keys %{${$CONFIG->partitioning}{"units"}{$unit}{partition}}) or next;
        push (@units, $unit);
    }
    sort (@units);

END

Tsub shpd_get_unit_of  => << 'END';
    DESC {
        Return the unit of giving pin/instances in array.
        Write for Snow's MSO1 CDC check request.
    }

    ARGS {
        @objs
    }
    #(is_cell $obj or is_pin $obj) or error "Cell/pin $obj not found in the design.";
    my %prefix_unit = ();
    my @prefixes = ();
    my %rtn = ();
    my %return = ();
    foreach my $unit ( keys %{${$CONFIG->partitioning}{"units"}}) {
        (is_macro_module $unit) and next; #Skip top level macro;
     #   ($unit =~/clk/i) and next;
     #   ($unit =~/FBIO/i) and next;
        (keys %{${$CONFIG->partitioning}{"units"}{$unit}{partition}}) or next;
        my @map = translate_module ($unit);
#        push (@{$unit_par{$unit}},@map);
        (@map) or error "Can't map the unit $unit to partition";
        foreach my $prefix (@map) {
#            DI2:fgsx_0/SYS/sys_logic/disp/ihub/ 
            $prefix =~ s/\S+\:(\S+)/$1/;
            $prefix_unit{$prefix} = $unit;
            push (@prefixes,$prefix);
        }
        #push (@units, $unit);
     }
     foreach my $obj (@objs) {
        (is_cell $obj or is_pin $obj) or error "Cell/pin $obj not found in the design.";
        my @have = grep ($obj =~ /$_/, @prefixes);
        (@have == 1) or next;
        $rtn{"$obj"} = $prefix_unit{"$have[0]"};
     }

     foreach my $obj (@objs) {
        my $unit = ($rtn{$obj}) ? $rtn{$obj} : UNKOWN;
        if ($unit eq "UNKOWN") {
            my $unit_hier = shpd_get_uper_module $obj;
            $unit = ($unit_hier) ? $unit_hier : UNKOWN;
        }
        #lprint "$obj \<\-\> $unit\n";
        $return{$obj} = $unit;
     }
     %return;
END

Tsub shpd_get_units_of  => << 'END';
    ARGS {
        -top: $top
    }
    
    (defined $top) or $top = get_top ();
    $top = lc($top);
    ($top) or error "Top $top not defined";
    my %par_unit_hash = ();
    set_perl_only on;
    foreach my $unit ( keys %{${$CONFIG->partitioning}{"units"}}) {
        my @pars = keys %{${$CONFIG->partitioning}{"units"}{$unit}{partition}};
        foreach my $par (@pars) {
            #lprint "par unit $par $unit\n";
            push (@{$par_unit_hash{"$par"}}, "$unit");
        }
    }
    set_perl_only off;
    @{$par_unit_hash{"$top"}};
END

Tsub shpd_get_pars_of => << 'END';
    ARGS {
        -units: @units
    }
    (defined @units) or error "Must specify units";
    my %unit_par_hash = ();
    set_perl_only on;
        foreach my $unit  (@units)  {
             my @pars = keys %{${$CONFIG->partitioning}{"units"}{$unit}{partition}};
            #push (@{$unit_par_hash{"$unit=>"}}, @pars);
            push (@{$unit_par_hash{"$unit"}}, @pars);
        }
    set_perl_only off;
    %unit_par_hash;
END

Tsub shpd_get_units_inst_cnt => << 'END';
     my %par_unit_hash = ();
     set_perl_only on;
     foreach my $unit ( keys %{${$CONFIG->partitioning}{"units"}}) {
        my ($cnt,@pars);
        $cnt = @pars = keys %{${$CONFIG->partitioning}{"units"}{$unit}{partition}};
        ($cnt > 1) and ($par_unit_hash{"$unit=>"} = $cnt);
    }
     set_perl_only off;
    %par_unit_hash;
END
#Check the transition of the net driving new hold buffer.
Tsub shpd_check_trans_for_hold => << 'END';
    DESC {
        Check the transition of the net driving new hold buffers in the inited eco.
        A eco name must specified. or nothing returned.
    }
    ARGS {
        -trans_thr:$trans_threshold
  #      -max_thr:$max_threshold
    }
    my @rtn;
    (defined $trans_threshold) or $trans_threshold = 0.2;
    (defined $max_threshold) or $max_threshold = 0.05;
    my $save_timing_corner = get_timing_corner ();
    set_timing_corner ("slow");
    my $eco_prefix = get_eco ();
    ($eco_prefix) or return;
    my @hold_buffers = get_cells "${eco_prefix}*_HOLD_BUF*";
    foreach my $hold_buf (@hold_buffers)  {
        my ($inputs_cnt,@inputs);
        $inputs_cnt = @inputs = get_input_pins ($hold_buf);
        ($inputs_cnt > 1) and next;
        my $net_check = get_net (-of => $inputs[0]);
        my $trans = get_worst_tran ($net_check);
        my $max_slack = wh_get_slack_max ($inputs[0]);
        if ($trans > $trans_threshold) {
            push (@rtn, $inputs[0]);
            #lprint "bad transition on pin $inputs[0]\n";
        }
        
    }
    set_timing_corner ("$save_timing_corner");
    @rtn;
END

Tsub shpd_move_buffer_at => << 'END';
    DESC {
        #move the specified buffer to another pin and placed at it.
    }
    ARGS {
        -buf:$buffer
        -to:$pin
        -on_route
    }
    (get_cell (-quiet => $buffer)) or error "Cell $buffer not found";
    (is_buf_ref (get_ref $buffer)) or error "$buffer is not a buffer";
    (is_pin $pin) or error "The destiny pin $pin not found";
    my $ref_buf = get_ref ($buffer);
    remove_buffer ($buffer);
#    eco_elem (mod,pin, $pin,-xy, (get_object_xy $pin), '=','_CELL_NAME', $ref_buf, "$buffer", ["*"]);
    if ($opt_on_route) {
        create_buffer ($pin, $ref_buf, -on_route =>, -name_cell => $buffer, -xy => (get_object_xy $pin));
    } else {
        create_buffer ($pin, $ref_buf, -name_cell => $buffer, -xy => (get_object_xy $pin));
    }
END

Tsub shpd_get_node_dir => << 'END'; 
    ARGS {
        -node:$node
        -noinout
    }
    my $rtn = "unknown";
    my $dir;
    (is_pin $node or is_port $node) or error "$node is not a pin or port";
    if (is_pin $node) {
        $dir = get_pin_dir ($node);
        ($dir eq "inout" and $opt_noinout) and error "node $node is inout";
        $rtn = ($dir eq "input") ? 1 :0 ;
    } else {
        $dir = get_port_dir ($node);
        ($dir eq "inout" and $opt_noinout) and error "node $node is inout";
        $rtn = ($dir eq "input") ? 0 : 1;
    }
END
Tsub shpd_get_locus_length => << 'END';
    DESC {

    }
    ARGS {
        -locus:@locus
        -stiner
    }
    my $cnt_pt = @locus;
    ($cnt_pt < 2) and error "two points needed at least";
    my $dist_path = 0;
    my $x0 = shift (@locus);
    my $y0 = shift (@locus);
    while (@locus) {
        my $x1 = shift (@locus);
        my $y1 = shift (@locus);
        if ($opt_stiner) {
            $dist_path += get_dist ($x0,$y0,$x1,$y1);
        } else {
            $dist_path += get_dist ( -diag => $x0,$y0,$x1,$y1);
        }
        $x0 = $x1;
        $y0 = $y1;
    }
    $dist_path;
END

Tsub shpd_is_detour_locus  => << 'END';
    DESC {
        to decide if the locus detour. Mainly used for buffer chain. Retrun 1 if detour
    }
    ARGS {
        -locus:@locus
        -detour_factor:$derate_factor
    }
    my $cnt_pt = @locus;
    (defined $derate_factor) or $derate_factor = 1;
    ($cnt_pt < 2) and error "two points needed at least";
    ($cnt_pt == 2) and return (0);
    my $dist_total = get_dist ($locus[0],$locus[1],$locus[-2],$locus[-1]);
    my $dist_path = 0;
    my $x0 = shift (@locus);
    my $y0 = shift (@locus);
    while (@locus) {
        my $x1 = shift (@locus);
        my $y1 = shift (@locus);
        $dist_path += get_dist ($x0,$y0,$x1,$y1);
        $x0 = $x1;
        $y0 = $y1;
    }
    return (($dist_path > $derate_factor * $dist_total) ? 1: 0);
    
END

Tsub shpd_add_buffer_chain  => << 'END';
    DESC {
        Add buffer chain at a pin/port, on a net
    }
    ARGS {
        -at:$at_node #Add buffers from the $at_node. A node must be a pin, input or output port.Inout port isn't supported.
        -on:$on_net #Add buffers on the giving net
        -between:@between #Add buffers between the two ports, any buffers or invs would be deleted if they existed already. almostly used for feedthrough insertion.
        -through:@through #Add buffers through the giving coordinates. Can be used with one of the first 3 options. For ex: -through 30,40,20,10 (two points)

        -auto:@ref_and_dist #Add buffers with the references and distance specified. For ex: -auto BUFFD12 500. insert a BUF12 every 500um. warnings if legalized over 10%*500
        -obo:@chains#Add buffers one by one. For ex: -obo "BUFFD8 100 150" "BUFFD12 350 150"
        
        -name_cell_base:$name_cell_base #The base name of the new buffers which are named in the fule\: base_name + suffix_name
        -suffix_base:$suffix_base #The base number. suffix_name is a increaseing number.
        -on_route #On route place during buffer insertion.
        -plot #plot the connections of the new buffers to ensure your eco
    }
    (defined $suffix_base) or $suffix_base = 0;
    (defined $name_cell_base) or error "Buffer base name not specified";
    lprint "name base: $name_cell_base\n";
    (1 == ((defined $at_node) + (defined $on_net) + (defined @between))) or error "one of at, on, between must and should be specified"; 
#    (1 == (scalar @ref_and_dist) + (scalar @chains)) or error "Please exclusively specify -obo and -auto";
    (defined @through and defined @chains) and  warn_once "-through ignored since -chain defined";
    (defined @through and (!@through % 2)) or "wrong -through type";

    my @locus = ();
    my @pre_chains = ();#To keep the buffer_name=>place
    if (defined $at_node and (defined @ref_and_dist)) {
        COPY (at_node_check) {   
            (is_pin $at_node or is_port $at_node) or error "Pin $at_node not found in the current design";
            my $dir = shpd_get_node_dir (-node => $at_node, -noinout =>); #1: source is input pin or output port; 0: source is output pin or input port. Source is the place buffer insertion starts.
            my ($x,$y) = get_object_xy ($at_node);
            my ($dst_x,$dst_y,$src_x,$src_y);
            ($src_x,$src_y) = ($x,$y);
            if (1 == $dir) {
                #source is input pin or output port.
                #destination is output pin or input port.
                my $driver = get_driver (-local => $at_node);
                ($dst_x,$dst_y) = get_pin_xy ($driver);  
            } elsif (0 == $dir) {
                #source is ourput pin or input port.
                #destination is input pin or output port.
                ($dst_x,$dst_y) = get_center_of_pins (get_loads (-local => $at_node));
            }
        }
        #the locus -> holes
        COPY (get_pre_chains_auto) {
            @locus = ();
            my @locus_reverse = ();
            my @through_reverse = ();
            my $cnt_through = @through/2;
            my $index_thr = $cnt_through - 1;
            while ($index_thr >= 0) {
                my ($x_r,$y_r) = ($index_thr * 2, $index_thr * 2 + 1);
                push (@through_reverse, "$through[$x_r]","$through[$y_r]");
                $index_thr--;
            } 
            push (@locus,($src_x,$src_y,@through,$dst_x,$dst_y));
            push (@locus_reverse,($src_x,$src_y,@through_reverse,$dst_x,$dst_y));
            my $locus_length = shpd_get_locus_length (-locus => @locus);
            my $locus_length_rev = shpd_get_locus_length (-locus => @locus_reverse);
            @locus = ($locus_length < $locus_length_rev) ? @locus : @locus_reverse;
            (@locus % 2) and error "Coordates must be in pair: $at_node";
            (shpd_is_detour_locus ( -locus => @locus)) and warning "The buffer path seems to be placed unproperly, are you sure? $at_node";

            @pre_chains = ();#To keep the buffer_name=>place
            my $cnt_pts = @locus/2;
            my $index = 1;
            my ($buf_type,$span) = @ref_and_dist;
            ((is_unate_ref $buf_type) and ($span > 0)) or error "Wrong buffer type or distance";
            my $x0 = $locus[0];
            my $y0 = $locus[1];

            my ($buffer_pin_pre) = $at_node;
            my $buffer_name_post = "$name_cell_base" . "_$suffix_base";
            my @inputs = get_inputs_of ($buf_type);
            my @outputs = get_outputs_of ($buf_type);
            my $buffer_pin = ($dir) ?($inputs[0]) : $outputs[0];

            while ($index < $cnt_pts) {
                my $pts_x = 2 * $index;
                my $pts_y = $pts_x + 1;
                my $x1 = $locus[$pts_x];
                my $y1 = $locus[$pts_y];
                my $dist_seg = get_dist ($x0,$y0,$x1,$y1);
                #my $buf_cnt = floor ($dist_seg/$span); 
                my $segment = ceiling ($dist_seg/$span);
                my $buf_cnt = $segment;
                my $span_adjust = ($dist_seg/$segment); 
                my $delta_x = $x1 - $x0;
                my $delta_y = $y1 - $y0;
                my $buf_number = 0;
#                my $buf_suffix_num = $suffix_base + ($index - 1;#since $index begin with 1 
                while ($buf_number < $buf_cnt) {
                    (($index == ($cnt_pts - 1)) and ($buf_number == ($buf_cnt - 1))) and last; #don't add buffer at the destination node.
                    my $x_buf_new = $delta_x * (($span_adjust * ($buf_number + 1))/$dist_seg) + $x0; 
                    my $y_buf_new = $delta_y * (($span_adjust * ($buf_number + 1))/$dist_seg) + $y0;
                    push (@pre_chains,[$buffer_pin_pre,$buf_type,$buffer_name_post,$x_buf_new,$y_buf_new,$span_adjust]);#keep span_adjust for detour detection. 
                    $DEBUG and lprint "$buffer_pin_pre, $buf_type, $buffer_name_post, $x_buf_new,  $y_buf_new\n";
                    #(($index == ($cnt_pts - 1)) and ($buf_number == ($buf_cnt - 1))) and last; #don't add buffer at the destination node.
                    $buf_number ++;
                    $buffer_pin_pre = "$buffer_name_post/$buffer_pin";
                    $suffix_base ++;
                    $buffer_name_post = "$name_cell_base" . "_$suffix_base";
                } 
                $x0 = $x1;
                $y0 = $y1;
                $index++;
            }
        }#COPY get_pre_chain_auto
    #return;
    } elsif (defined $at_node and (defined @chains)) {
        #PASTE (at_node_check);
        COPY (get_pre_chains_user) {
            (is_pin $at_node or is_port $at_node) or error "Pin $at_node not found in the current design";
            my $dir = shpd_get_node_dir (-node => $at_node, -noinout);
            my ($buffer_pin_pre) = $at_node;
            my $buffer_name_post = "$name_cell_base" . "_$suffix_base";
            my $buffer_pin;
            foreach my $chain (@chains) {
                my @chain_single = split (/\s+/,$chain);
                my $buf_type = shift (@chain_single);
                (is_unate_ref $buf_type) or error "$buf_type is not a unate cell";
                my @inputs = get_inputs_of ($buf_type);
                my @outputs = get_outputs_of ($buf_type);
                $buffer_pin = ($dir) ?($inputs[0]) : $outputs[0];
                my $pos_cnt = @chain_single;
                my ($x_buf_new,$y_buf_new);
                if (2 == $pos_cnt) {
                    ($x_buf_new,$y_buf_new) = (@chain_single);
                } elsif (0 == $pos_cnt) {
                    ($x_buf_new,$y_buf_new) = ("at","at");
                } else {
                    error "Wrong coordinates specified for $buf_type";
                }
                $sp_debug and lprint " in obo mode at_node $at_node, $buffer_pin_pre,$buf_type,$buffer_name_post,$x_buf_new,$y_buf_new\n";
                push (@pre_chains,[$buffer_pin_pre,$buf_type,$buffer_name_post,$x_buf_new,$y_buf_new,500]); #use 50um legal distance
                $buffer_pin_pre = "$buffer_name_post/$buffer_pin";
                $suffix_base ++;
                $buffer_name_post = "$name_cell_base" . "_$suffix_base";
            }
        }
    } elsif ((defined $on_net) and (defined @ref_and_dist)) {
        (is_net $on_net) or error "net $on_net not found, check -on option";
        my $at_node = get_driver (-local => $on_net);
        PASTE (at_node_check);
        PASTE (get_pre_chains_auto);
    } elsif ((defined $on_net) and (defined @chains)) {
        (is_net $on_net) or error "net $on_net not found, check -on option";
        my $at_node = get_driver (-local => $on_net);
        PASTE (get_pre_chains_user);
    } elsif (defined @between) {
        ((is_port $between[0]) and (is_port $between[1])) or error "-between is a port only option";
        ((is_input $between[0]) ^ (is_input $between[1])) or error "between ports shouldn't be all inputs or all outputs";
        my $at_node = (is_input $between[0]) ? $between[1] : $between[0] ; #I need a output port to start.
        my $root = get_root (-sense => $at_node, -top =>);
        my $phase = ($root =~ s/^!//) ? "1" : "0";
        my $pre_buffer_type = ($phase) ? "$WH_invx20" : "$WH_clkbufx20"; #INVD12 CKBD12
        my @pre_buffer_pin = get_inputs_of ($pre_buffer_type);
        my $pre_buffer_suffix = ($phase) ? "inv" : "buf";
        my $pre_buffer_name = "$name_cell_base" . "_feedthr_" . "$pre_buffer_suffix" ;
        $DEBUG and lprint "bwtween $pre_buffer_name $name_cell_base $pre_buffer_suffix\n";
# eco_elem "mod" , "port" , "FE_FEEDX_NET_C__PD0__CE__0_gsys_clks_sys_clks_sys_core_clks_Ctrim_hubclk_phase_ne_0_" ,"="   , "_CELL_NAME",  "CKBD12" , "xxxx", ["FE_FEEDX_P_gsys_clks_sys_clks_sys_core_clks_Ctrim_hubclk_phase_ne_0_"] 
#        eco_elem (mod ,net, "$at_node", "=", "$pre_buffer_type", "$pre_buffer_name" , "(*)");
        create_buffer (-at_pin => "$at_node", "$pre_buffer_type", -name_cell => "$pre_buffer_name");
        eco_elem (mod ,pin, "$pre_buffer_name/$pre_buffer_pin[0]", "=", "$root"); #to bypass other buffers.
#        eco_elem ('mod' , 'port', "$at_node", "=", "$pre_buffer_type", "\($root\)" );
        $at_node = "$pre_buffer_name/$pre_buffer_pin[0]";
        if (defined @ref_and_dist) {
            PASTE (at_node_check);
            PASTE (get_pre_chains_auto);
        } else {
            PASTE (get_pre_chains_user);
        }
    }
    
    #push (@pre_chains,[$buffer_pin_pre,$buf_type,$buffer_name_post,$x_buf_new,$y_buf_new,$span_adjust])
    #Add buffers.
    my @invalid_chains = ();
    my @new_buffers;
    foreach my $pre_chain (@pre_chains) {
        my $span = ${$pre_chain}[5];
        my $insert_legal;
        if ($span > 300) {
            $insert_legal = 0.2 * $span; #at?
        } else {
             $insert_legal = 30;
        }
        my ($at_point_x, $at_point_y) = get_pin_xy ("${$pre_chains[0]}[0]");
        my ($insert_x,$insert_y) = ("${$pre_chain}[3]" eq "at") ? ("at", "at") :(${$pre_chain}[3],${$pre_chain}[4]) ;
        $DEBUG and info "buffer_name ${$pre_chain}[2] $insert_x,$insert_y";
        my ($legal_dist,$hole_x,$hole_y); 
        if ("${$pre_chain}[3]" eq "at") {
            ($legal_dist,$hole_x,$hole_y) = get_legal_dist_for_insert_xy ($at_point_x, $at_point_y,"${$pre_chain}[1]");
        } else {
            ($legal_dist,$hole_x,$hole_y) = get_legal_dist_for_insert_xy ($insert_x,$insert_y,${$pre_chain}[1]); 
        }
        if ($legal_dist > $insert_legal) {
            warning "${$pre_chain}[2] removed, it can't be legalized at $insert_x,$insert_y(legalized distance: $legal_dist;constraint distance:$insert_legal). It may be crossing blockages. Please use -through x y";
            push (@invalid_chains,\@{$pre_chain});
            next;
        }
        push (@new_buffers,${$pre_chain}[2]);
    }
    
    foreach my $pre_chain (@pre_chains) {
        if ($opt_on_route) {
            if ("${$pre_chain}[3]" eq "at") {
                 create_buffer (-at_pin => "${$pre_chain}[0]", ${$pre_chain}[1] , -on_route =>, -name_cell => "${$pre_chain}[2]");
            } else {
                create_buffer ("${$pre_chain}[0]", ${$pre_chain}[1], -on_route =>, -name_cell => "${$pre_chain}[2]", -xy => (${$pre_chain}[3],${$pre_chain}[4]));
            }
        } else {
            if ("${$pre_chain}[3]" eq "at") {
                create_buffer (-at_pin => "${$pre_chain}[0]", ${$pre_chain}[1] ,-name_cell => "${$pre_chain}[2]");
            } else {
                create_buffer ("${$pre_chain}[0]", ${$pre_chain}[1], -name_cell => "${$pre_chain}[2]", -xy => (${$pre_chain}[3],${$pre_chain}[4]));
            }
        }
    }
    foreach (@invalid_chains) {
        remove_unate (${$_}[2]);
    }
    if ($opt_plot) {
        foreach my $new_buffer (@new_buffers) {
            plot_conns_of ($new_buffer);
        }
    }
END

Tsub shpd_get_cts_nodes => << 'END'; 
    my ($x,$y);
    DESC {
        This sub is mainly targets on finding out equivalent nodes in a tree specified by one of the pin(-pin) on the tree, 
        or the root(-from).Mainly has 2 usages: 
        1st: get the nodes from a root pin with the specified level; 
            shpd_get_cts_nodes -from clock_root/Z -level 6 -delta 200 -near 200,500 (-near can be also an instance)
        2nd: get the nodes equivalent to the specified pin, in the range of $delta. 
            shpd_get_cts_nodes -pin latch_15/CP -delta 200 -near 200,500 (-near default to be x,y of that pin.)
            (near is the ref pin given by default)
        All of the cells return can be plotted.
    }
    ARGS {
        -from:$root
        -pin:$pin_equiv #The specified pin for reference

        -level:$level 
        -near:@cells  #Can be an instance or coordinates: $x,$y
        -delta:$delta #The range

        -plot
    }
    ALIAS: shdp_find_equiv_nodes_near

    if ($root) {
        (is_pin $root or is_net $root or is_port $root) or error "Pin/net/port $root not found";
        ($pin_equiv) and error "Should exclusively specify -from and -pin"; 
    }

    
    my $root_sense = 0;
    #my $root = "";

    if ($pin_equiv) {
        ( $root) and error "Should exclusively specify -from and -pin";
        ( $delta) or error "No -delta specified for founding equivalent pin with $pin_equiv";
        ( @cells) or @cells = ("$pin_equiv");
        (is_pin $pin_equiv) or error "Pin $pin_equiv not found";
        my $root_and_sense = get_root_fast (-sense => $pin_equiv, -local =>); 
        my ($sense, $root_t)= split (/\s+/,$root_and_sense);
        $root_sense = ($sense =~/1/) ? 1 : 0;
        $root = $root_t;
    }
    #(defined $level) and (is_number $level) or error "$level should be a number";
    my %bagua;
    my @rtn;
    if ($level) {
        my @fanouts = get_fan (-fanout =>, -out =>, -unate =>, -level => $level, -no_end => $root); 
        foreach my $fanout (@fanouts) {
            my $output = "${$fanout}[0]" . "${$fanout}[1]";
            my $round = "${$fanout}[3][2]";
            my $inst = get_inst_of_pin ("$output");
            my $inst_out = (get_output_pins ($inst))[0];
#            next if ("${$fanout}[3][3]" == -1);
            my $func_judge = ${$fanout}[3][3] + $root_sense;
            ($func_judge == 1 or $func_judge == 0) or next;
            if ( @cells) {
                ($delta) or error "-delta undefined\n";
                my ($x,$y) = parse_cell_or_xy (1,@cells);
                my $dist = get_dist ($x,$y,(get_pin_xy $output));
                next if (( $delta) and ($dist > $delta));
                push (@{$bagua{$round}}, "$inst   $dist");
            } else {
                push (@{$bagua{$round}}, $inst);
            }
        }
        my @points_on = @{$bagua{$level}};
        foreach (@points_on) {
            ($opt_plot) and plot_conns_of ((split (/\s+/,$_))[0]);
        }
        return (@points_on);
    } else {
        my @cts_bufs_bfs = get_fan (-fanout =>, -out =>, -unate =>,-no_end => $root); 
        #get_fan2 (-pins => -fanout => -unate =>  -bfs => -insts => -no_end => $root);
        foreach my $fanout (@cts_bufs_bfs) {
            my $output = "${$fanout}[0]" . "${$fanout}[1]";
            my $inst = get_inst_of_pin ("$output");
            my $inst_out = (get_output_pins ($inst))[0];

            #next if ("${$fanout}[3][3]" == -1); Some times user specify a inverted point. 
            my $func_judge = ${$fanout}[3][3] + $root_sense; #root_sense: 0,1; fan32: 1,-1; so the correct result of the sum is 1,0;
            ($func_judge == 1 or $func_judge == 0) or next;
            my $round = "${$fanout}[3][2]";
            if (@cells) {
                my ($x,$y) = parse_cell_or_xy (1,@cells);
                my $dist = get_dist ($x,$y,(get_pin_xy $output));
                next if (( $delta) and ($dist > $delta));
                $bagua{$inst_out} = $dist;
            } else {
                $bagua{$inst_out} = $round;
            }
            ($opt_plot) and plot_conns_of ($inst);
       }
       return (map("$_    $bagua{$_}" ,(sort {$bagua{$a} <=> $bagua{$b}} (keys %bagua))));
    }
END

Tsub shpd_get_equiv_cg_nodes => << 'END'; 
    DESC {
        Get another equivalent clock-gating latch on cts for a giving latch
        Two clock-gating latchs are functionally equivalent if the CP, E, TE pins have the same root.
    }
    ARGS {
        -from:$root
        -level:$level 
        -latch:$latch
    }
    (defined $root) and (is_pin $root) or error "Output pin $root not found";
    my @rtn;
    my %bagua;
    #(defined $level) and (is_number $level) or error "$level should be a number";
    if ($level) {
        my @fanouts = get_fan (-fanout =>, -in =>, -unate =>, -level => $level, -end =>,  $root); 
        foreach my $fanout (@fanouts) {
            my $input = "${$fanout}[0]" . "${$fanout}[1]";
            my $round = "${$fanout}[3][2]";
            next if ("${$fanout}[3][2]" == -1);
            my $inst = get_inst_of_pin ("$input");
            push (@{$bagua{$round}}, $inst);
        }
        @rtn = @{$bagua{$level}};
        
    } else {
        @rtn = get_fan2 (-pins =>, -fanout =>, -unate =>,  -bfs =>, -insts =>,  -end =>, $root);
    }
    @rtn = grep ((is_cg_latch_ref_name (get_ref $_)),@rtn);;
    if (defined $latch) {
        (is_cg_latch_ref_name (get_ref $latch)) or error "Clock gating latch $latch not found";
        my $e_root = get_root_fast (-sense => "$latch/E");
        my $te_root_str = get_root_fast (-sense => "$latch/TE");
        my ($sense, $te_root) = split (/\s+/,$te_root_str);
        my @got;
        my @return;
        foreach my $rtn (@rtn) {
            my $e_root_rtn = get_root_fast (-sense => "$rtn/E");
            my $te_root_str_rtn = get_root_fast (-sense => "$rtn/TE");
            my ($sense_rtn, $te_root_rtn) = split (/\s+/,$te_root_str_rtn);
            if (($e_root_rtn eq $e_root) && ($te_root_rtn eq $te_root)) {
                my $dist = get_dist ($rtn, $latch);
                (push @return, "$rtn        $dist");
                ($sense != $sense_rtn) and lprint "sense revert: $rtn!\n";
            }
        }
        @return;
    } else  {
        @rtn;
    }

END


Tsub shpd_scan_reorder => << 'END';
    DESC {
        #scan reorder the flops by the giving sequence
    }
    ARGS {
        -flops:@flops #instance name
    }
    my %flops_hash = array2hash (@flops);
    my $top = get_top ();
    my @connection_list = ();
    my $flops_cnt = @flops;
    my $index = 0;
    foreach my $flop (@flops) {
        my $ref = get_ref ($flop);
        my @inputs = get_inputs_of $ref;
        my @outputs = get_outputs_of $ref;
        my @scan_in = grep (((is_scan_ref_pin ($ref,$_)) && (!is_scan_en_ref_pin ($ref,$_))),@inputs);
        
        my @scan_out_pin = grep ((is_scan_driver("$flop/$_")),@outputs); 
        my $driver_si = get_driver ("$flop/$scan_in[0]");
        my @loads_scan = get_scan_loads ($top, "$flop/$scan_out_pin[0]");
        my $scan_float = get_net (-of => $loads_scan[0]);
        $DEBUG and lprint "load_scan $loads_scan[0] driver_si $driver_si\n";
        if ($index < ($flops_cnt -1)) {
            disconnect_net (-to => "$loads_scan[0]"); 
            disconnect_net (-to => "$flop/$scan_in[0]");
            eco_elem (mod, pin, "$loads_scan[0]", "=", "$driver_si", ); #by pass it.
            push (@connection_list,"$flop/$scan_in[0]",$scan_float);
        } else {
            disconnect_net (-to => "$flop/$scan_in[0]");
            push (@connection_list,"$flop/$scan_in[0]");
            unshift (@connection_list,$driver_si);
        }
        $index++;
    }
    while (@connection_list) {
        $DEBUG and lprint "connect $driver_pin $load_pin\n";
        my $driver_pin = shift @connection_list; #["$index"];
        my $load_pin = shift @connection_list; #["$index + 1"];        
        eco_elem (mod, pin, "$load_pin", "=", "$driver_pin");
    }
END

Tsub  shpd_plot_blockages  => << 'END';
    DESC {

    }
    ARGS {
        #-fill
    }
    my $module = $TOP_MODULE;
    apply_ilm_blockages ();
    get_phys_gui ();
    init_plot_area ();
    mg_push_undo ([mg_delete_rest ()]);
    foreach $block (@{$M_blockage{$module}}) {
        @MG_xextent = m_get_xy_p2f ($block);
        phys2view_loc (\@MG_xextent);
        draw_rect ("Blockage", @MG_xextent);
    }

END

Tsub a03_group => << 'END';
    DESC {
        Exclusively for 215 A03
    }
    ARGS {
        -span:$span #The diag distance of a cluster
        -target_line:$target_line #The line to parse the file,depends on the fixing target
        -viol_rep:$viol_rep
        -color:$color_u
        -noplot
    }
    (defined $span) or $span = 100;
    (defined  $target_line) or $target_line = 402;
    (defined $viol_rep) or $viol_rep = "/home/scratch.gt215_master/gt215/gt215/timing/gt215/eco/A03nvclk/nvclk.bcsvslowspef.a02.500k.full.rep.filtered";
    my $block = lc (get_top ());
    my @ends_parse = load_array ("$viol_rep");
    my @ends = ();
    my %root_sons = ();
    my %cluster = ();
    my %endpt_slack = ();
    my $line_num = 0 ; 
    foreach my $end_parse (@ends_parse) {
        last if ($line_num++ > $target_line);
        chomp ($end_parse);
        my @ends_all = split (/\s+/,$end_parse);
        my $end_tmp = "$ends_all[2]";
        my $viol_pin = $end_tmp;
        next unless ($viol_pin =~ s/^$block\/(.*)\/(\w+)/$2/);  
        $end_tmp =~ s/^$block\/(.*)\/.*?$/$1/;
        my $max_slack = "$ends_all[4]";
        my $ref_endpt = get_ref ($end_tmp);
        my $ck_pin = get_clock_ref_pins (get_ref $end_tmp);
        $endpt_slack{"$end_tmp"} = "$viol_pin $max_slack $ref_endpt";
        push (@ends,"$end_tmp" . "/$ck_pin");
    }
    
    foreach my $end (@ends) {
        my $root_in = get_root_fast ($end);
        push (@{$root_sons{$root_in}},$end);
    }

    foreach my $key_root_sons (keys %root_sons) {
        $DEBUG and lprint "Share point $key_root_sons:\n";
        my $cluster_num = 0;
        my @sons = @{$root_sons{$key_root_sons}};
        @sons = sort {(get_pin_xy($a))[0] <=> (get_pin_xy($b))[0]} (@sons);
        while (@sons) {
            my $son = shift (@sons);
            my ($x0,$y0) = get_pin_xy ($son);
            my @brothers = ();
            my $inst = get_inst_of_pin ($son);
            my ($viol_pin,$max_slack) = split (/\s+/,"$endpt_slack{$inst}");
            push (@{$cluster{$key_root_sons}{$cluster_num}},[$son,$viol_pin,$max_slack]);
            foreach my $brother  (@sons) {
                my ($x1,$y1) = get_pin_xy ($brother);
                my $distance = get_dist (-diag => $x0,$y0,$x1,$y1);
                if ($distance > $span) {
                    push (@brothers ,$brother);
                } else {
                     my $inst = get_inst_of_pin ($brother);
                     my ($viol_pin,$max_slack) = split (/\s+/,"$endpt_slack{$inst}");
                    push (@{$cluster{$key_root_sons}{$cluster_num}},[$brother,$viol_pin,$max_slack]);
                }
            }
            @sons = @brothers;
            $cluster_num++;
        }
    }
    
    my %color = ( "1" => "red",
                  "2" => "green",
                  "3" => "black",
                  "4" => "brown",
                  "5" => "yellow",
                  "0" => "orange"
                );
    if (defined $color_u) {
        foreach (keys %color) {
            $color{$_} = $color_u;
        }
    }
    my @rtn;
    foreach my $root_pt (keys %cluster) {
        $DEBUG and lprint "ROOT: $root_pt\n";
        my $cluster_num = 0;
        push (@rtn,"ROOT POINT: $root_pt");
        while ( $cluster{$root_pt}{$cluster_num}) {
            push (@rtn,"Group $cluster_num:");
            my @groups = sort {${$a}[2] <=> ${$b}[2]} (@{$cluster{$root_pt}{$cluster_num}});
            foreach my $clus_pin (@groups) {
                my $inst = get_inst_of_pin (${$clus_pin}[0]);
                my ($viol_pin,$max_slack,$ref_endpt) = split (/\s+/,"$endpt_slack{$inst}");
                push (@rtn,"    $inst/$viol_pin     $ref_endpt    $max_slack");
                #mrt (-from => $root_pt, -to => ${$clus_pin}[0],-plot =>);
                if (!$opt_noplot) {
                    mrt (-to => ${$clus_pin}[0],-plot =>);
                    my $index_color_plot = ($cluster_num % 6);
                    hilite ($inst, -fill => $color{$index_color_plot}, -outline => $color{$index_color_plot})
                };
            }
            $cluster_num ++;
        }
    }
    @rtn;
END


Tsub a03_scan_reorder => << 'END';
    DESC {
        #scan reorder the flops by the giving sequence
        #use scan_plot <a Scan in pin> to check if you get it.
    }
    ARGS {
        -flops:@flops #instance name
    }
    my %flops_hash = array2hash (@flops);
    my $top = get_top ();
    my @connection_list = ();
    my $flops_cnt = @flops;
    my $index = 0;
    foreach my $flop (@flops) {
        my $ref = get_ref ($flop);
        my @inputs = get_inputs_of $ref;
        my @outputs = get_outputs_of $ref;
        my @scan_in = grep (((is_scan_ref_pin ($ref,$_)) && (!is_scan_en_ref_pin ($ref,$_))),@inputs);
        
        my @scan_out_pin = grep ((is_scan_driver("$flop/$_")),@outputs); 
        my $driver_si = get_driver ("$flop/$scan_in[0]");
        my @loads_scan = get_scan_loads ($top, "$flop/$scan_out_pin[0]");
        my $scan_float = get_net (-of => $loads_scan[0]);
        $DEBUG and lprint "load_scan $loads_scan[0] driver_si $driver_si\n";
        if ($index < ($flops_cnt -1)) {
            disconnect_net (-to => "$loads_scan[0]"); 
            disconnect_net (-to => "$flop/$scan_in[0]");
            eco_elem (mod, pin, "$loads_scan[0]", "=", "$driver_si", ); #by pass it.
            push (@connection_list,"$flop/$scan_in[0]",$scan_float);
        } else {
            disconnect_net (-to => "$flop/$scan_in[0]");
            push (@connection_list,"$flop/$scan_in[0]");
            unshift (@connection_list,$driver_si);
        }
        $index++;
    }
    while (@connection_list) {
        $DEBUG and lprint "connect $driver_pin $load_pin\n";
        my $driver_pin = shift @connection_list; #["$index"];
        my $load_pin = shift @connection_list; #["$index + 1"];        
        eco_elem (mod, pin, "$load_pin", "=", "$driver_pin");
    }
END

Tsub a03_stich_buffers => << 'END';
    DESC {

    }
    ARGS {
        -donors:@dornors #from start to end. Only works for PGAO metal eco
        -plot
        -eco:$eco_name
    }
    (is_output_pin (cell_pin_of_name $dornors[0])) or error "The first parameter must be the driver pin of the chain";
    (is_input_pin (cell_pin_of_name $dornors[-1])) or error "The last parameter must be the load pin of the chain";
    my $start = shift @dornors;
    my $end = $dornors[-1];
    my $driver_of_next;
    my @cells_on_chain;
    my $start_net = get_net (-of => $start);
    my $inst_start = get_inst_of_pin ($start);
    my $net_index = 0;
    my $new_net_name = "$eco_name" . "_$inst_start" . "_$net_index";
    push (@cells_on_chain,get_inst_of_pin ($start));
    delete $dornors[-1];
    while (@dornors)  {
        my $donor = shift @dornors;
        my $ref = get_ref ($donor);
#        ($donor =~ /^ecodonor/ or (is_buf_ref $ref)) or error "Invalid donor cell $donor";
        (is_free_cell $donor) or error "This cell used was claimed! $donor";
        my $ref_bak = $ref;
        $ref =~ s/(.*?)\_S/$1/;
        my $load_pin;
        my $name_for_donor = '*' . "$donor";
        if ($ref =~ /PGAO_CKBD12/) {
            $load_pin = "$donor/I";
            $driver_of_next = "$donor/Z";
            eco_elem ("new", "net", "$new_net_name" ,"="  , "_CELL_NAME", "$ref" , "$name_for_donor", [".I ($start_net)"]);
            
        } elsif ($ref =~ /PGAO_INR2D/) {
            $load_pin = "$donor/A1";
            $driver_of_next = "$donor/ZN";
            eco_elem ("new", "net", "$new_net_name" ,"="  , "_CELL_NAME", "$ref" , "$name_for_donor", [".A1 ($start_net)", ".B1 (1'b0)"]);
        } elsif ($ref =~ /PGAO_OR2D2/) {
            $load_pin = "$donor/A2";
            $driver_of_next = "$donor/Z";
            eco_elem ("new", "net", "$new_net_name" ,"="  , "_CELL_NAME", "$ref" , "$name_for_donor", [".A2 ($start_net)", ".A1 (1'b0)"]);
        } elsif ($ref =~ /PGAO_MUX2D2/) {
            $load_pin = "$donor/I0";
            eco_elem ("new", "net", "$new_net_name" ,"="  , "_CELL_NAME", "$ref" , "$name_for_donor", [".I0 ($start_net)", ".I1 (1'b0)" , ".S(1'b0)"]);
            $driver_of_next = "$donor/Z";
        } elsif ($ref =~ /^ND2/) {
            eco_elem ("new", "net", "$new_net_name" ,"="  , "_CELL_NAME", "$ref" , "$name_for_donor", [".A2 ($start_net)", ".A1 (1'b1)"]);
        } elsif ($ref =~ /^NR2/) {
            eco_elem ("new", "net", "$new_net_name" ,"="  , "_CELL_NAME", "$ref" , "$name_for_donor", [".A2 ($start_net)", ".A1 (1'b0)"]);
        } elsif ($ref =~ /^MUX2D/) {
            eco_elem ("new", "net", "$new_net_name" ,"="  , "_CELL_NAME", "$ref" , "$name_for_donor", [".I0 ($start_net)", ".I1 (1'b0)" , ".S(1'b0)"]);
        } elsif ($ref =~ /^MUX2ND/) {
            eco_elem ("new", "net", "$new_net_name" ,"="  , "_CELL_NAME", "$ref" , "$name_for_donor", [".I0 ($start_net)", ".I1 (1'b0)" , ".S(1'b0)"]);
        } elsif ($ref =~ /^ND4/) {
            eco_elem ("new", "net", "$new_net_name" ,"="  , "_CELL_NAME", "$ref" , "$name_for_donor", [".A2 ($start_net)", ".A1 (1'b1)", ".A4 (1'b1)", ".A3 (1'b1)"]);
        } elsif ($ref =~ /^NR3/) {
            eco_elem ("new", "net", "$new_net_name" ,"="  , "_CELL_NAME", "$ref" , "$name_for_donor", [".A2 ($start_net)", ".A1 (1'b0)", ".A3 (1'b0)"]);
        } elsif ($ref =~ /^IOA21D/) {
            eco_elem ("new", "net", "$new_net_name" ,"="  , "_CELL_NAME", "$ref" , "$name_for_donor", [".A1 ($start_net)", ".A2 (1'b1)", ".B (1'b1)"]);
        } elsif ($ref =~ /^XOR2D/) {
            eco_elem ("new", "net", "$new_net_name" ,"="  , "_CELL_NAME", "$ref" , "$name_for_donor", [".A2 ($start_net)", ".A1 (1'b0)"]);
        } elsif (is_unate_ref $ref) {
            eco_elem ("new", "net", "$new_net_name" ,"="  , "_CELL_NAME", "$ref" , "$name_for_donor", [".I ($start_net)"]);
        } else {
            error "The cell types should be PGAO_CKBD12, PGAO_INR2D, PGAO_OR2D2, PGAO_MUX2D2";
        }
        push (@cells_on_chain,$donor);
        $net_index++;
        $start_net = "$new_net_name";
        $new_net_name = "$eco_name" . "_$inst_start" . "_$net_index";
    }
    eco_elem (mod, pin, "$end", "=", "$start_net");
    push (@cells_on_chain,get_inst_of_pin ($end));
    if ($opt_plot) {
        select_placement;
        foreach (@cells_on_chain) {plot_conns_of $_;}
    }
    @cells_on_chain;
END



Tsub set_eco_equiv_check => << 'END';
    ARGS {
        -src1:$src1 #Specify reference source.  Default is gv 
        -src2:$src2 #Specify target souce.  Default is gv
        -one        #Run only one pattern to establish invert/non-invert relationship for a known match
        -full       #Force exhaustive comparison.  Default is to switch to random for high input counts
        -max:1+$max_inputs  #Max number of inputs before random sim is invoked.  Default is 100.
        -random:1+$random_cnt   #Number of patterns to run for random sims.  Default is 1000.
        -quiet      #Suppress informational messages
        -map_file:$mf #matching points file. like what we do for formal check:"add_mapped_points $reference_pin/port $target_pin/port"
        -skip:@skip_pins
    }
   
    my %eqc_map_result = ();
    my @target_compare = ();
    my ($eqc_unit,$eqc_unitpin,$eqc_prefix);
    #get the eco touched pins by %Eco_translate_conn_pin:
    unless (keys %Eco_translate_conn_pin) {
        warn_once "Not auto eco translate mode, set_eco_equiv_check returned with nothing done\n";
        return (0);
    }
    lprint "Starting mender formal Check for ECO pins...\n";
    foreach $eqc_unit (keys %Eco_translate_conn_pin) {
        foreach $eqc_unitpin (keys %{$Eco_translate_conn_pin{"$eqc_unit"}})  {
            foreach $eqc_prefix (keys %{$Eco_translate_conn_pin{"$eqc_unit"}{"$eqc_unitpin"}})  {
                 my ($inst,$pin) = split (/ /, $eqc_unitpin);
                 next unless ($inst);
                 $inst =~ s/\/$//;
                 $DEBUG and lprint "$eqc_unit $inst $pin \=\> $eqc_prefix\n";
                 $eqc_map_result{"$eqc_unit $inst $pin"} = "$eqc_prefix"; #:$Eco_translate_conn_pin{"$eqc_unit"}{"$eqc_unitpin"}";
            }
        }
    }
    my $width_max = 0;
    my %flat_drivers;
    #print_hash (%eqc_map_result) if ($opt_quiet);
    foreach (keys %eqc_map_result) {
        my ($unit_module, $unit_inst, $unit_pin) = split (/\s+/, $_);
        $unit_inst =~ s/\/$//;
        my ($flat_module, $prefix) = split (/\:/,$eqc_map_result{$_});
        my $save_module = get_top ();
        my $unit_inst_pin = "$unit_inst/$unit_pin";
        my $flat_inst_pin = "$prefix$unit_inst_pin";
        my $flat_inst = "$prefix$unit_inst";
        $DEBUG and lprint "flat_pin $flat_inst_pin\n";
        #the unate cells may be deleted, trace upstream.
        set_top ($unit_module);
        next unless (is_cell $unit_inst);
        my $ref = get_ref ($unit_inst);
        next if (is_end_ref ($ref) or is_port $unit_inst);
        if (is_unate_ref ($ref)) {
            my $root_parent = get_root_parent ($unit_module);
            my @maps = translate_module ($root_parent);
            my $unit_inst_root  = "$prefix$unit_inst";
            @maps = grep (s/\S+\://, @maps); 
            foreach (@maps) { 
                $unit_inst_root =~ s/(^$_)// ;
                $root_prefix = $1; #the prefix relative to the $unit_module
            }
            ($unit_inst_root eq "$prefix$unit_inst") and error "Failed to get the pin from top view in THIS_SUB";
            set_top ($root_parent);
            my $unit_root = get_root_fast (-sense => -hier_pin => "$unit_inst_root/$unit_pin");
            my ($unit_sense, $unit_hier, $unit_ref_pin) = split (/ /, $unit_root);
            #chop $unit_hier;
            $unit_hier=~ s/\/$//;
            next  unless (is_inst ($unit_hier)); #input ports fanins
            next if (is_power_net $unit_ref_pin);
            ($unit_module, $unit_inst_pin) = ($root_parent,"$unit_hier/$unit_ref_pin");
            ($flat_inst_pin) = ("$root_prefix$unit_hier/$unit_ref_pin");
            $flat_inst = "$root_prefix$unit_hier";
            next if ($eqc_map_result{"$unit_module $unit_hier $unit_ref_pin"}); #Skip if has been considered.
            
        }
        set_top ($flat_module);
        #kepp the driver pins that needed to compare. To avoid double comparision for inst/Z and inst/A
        next unless (is_cell $flat_inst); #A bug from gt218b eco 576573
        if (is_driver ($flat_inst_pin)) {
            $flat_drivers{"$flat_inst"} = "$flat_inst_pin";
        }
        my $fanin_width = get_fanin_width ($flat_inst_pin);
        my $fanin_depth = get_fanin_depth ($flat_inst_pin);
        $width_max = ($fanin_width > $width_max) ? $fanin_width: $width_max;
        set_top ($save_module);
        #Record the compare info
        push (@target_compare, [$fanin_depth, $fanin_width, $unit_module, $flat_module, $unit_inst_pin, $flat_inst_pin,$flat_inst]);
    }
    #comparision priority: smaller fanin_depth -> smaller fanin_width
    #use positional number: (depth * weight + width) to reduce the sort loop.
    my $high_weight = 10 ** (length ($width_max));
    @target_compare = sort {($high_weight * ${$a}[0] + ${$a}[1]) <=> ($high_weight * ${$b}[0] + ${$b}[1])}  (@target_compare);
    #Keep the outer mapping points in array, the file form: add_mapped_points $golden $revise
    my @match_array = ();
    if ($mf && (-e $mf)) {
        open (H_MF,$mf) or error "Could not open file $mf for read in THIS_SUB";
        while (<H_MF>) {
            my $line = $_;
            $line =~ s/\\//g;
            if ($line =~ s/^add_mapped_points\s+(\S+)\s+(\S+)/$1 $2/) {
                my ($golden,$revise) = split (/\s+/,$line);
               # set_source ($src1);
               # set_top ($root_parent);
               # (is_pin ($golden) || is_port ($golden)) or next;
               # set_source ($src2);
               # set_top ($top2);
               # (is_pin ($revise) || is_port ($revise)) or next;
               # $match_array{$golden} = $revise; array is better
                push (@match_array,$golden);
                push (@match_array,$revise);
            #    $matched_fanin{$revise}++;
            }
        }
    }
    my %target_pin; 
    foreach (@target_compare) {
        my @pin = @$_;
        $DEBUG and lprint "have $pin[5]\n";
        next if (${target_pin}{$pin[5]}++); #Compare once
        if ($flat_drivers{"$pin[6]"} and ($pin[5] ne $flat_drivers{"$pin[6]"})) {
            $DEBUG and lprint "skip $pin[5]\n";
            next; #Skip the input pin comparision if the output pin would be compared
        }
        lprint "Comparing $pin[2]\:$pin[4] \<\=\> $pin[3]\:$pin[5]\n";
        my $is_skip = 0;
        foreach (@skip_pins) {
            if ($_ eq "$pin[4]") {
                $is_skip = 1;
                lprint "Skip comparing pin $_\n";
                warn_once "Skip comparing golden pin $_\n";
            }
        }
        ($is_skip) and next;
       (compare_formal (-src1 => gv, -src2 => gv, -top1 => $pin[2], -top2 => $pin[3], -quiet =>, -map_pins => @match_array, -pins => 
       ($pin[4], $pin[5]))) or error "Pins unequal $pin[2]:$pin[4] <=> $pin[3]:$pin[5]";
    }
    lprint "Mapping correct\n";

END



Tsub compare_pins => << 'END';
    DESC {
        Compares the functionality of two nets.  Typically compares an RTL wire vs. a gate-level net.
    }
    ARGS {
        -src1:$src1 #Specify reference source.  Default is gv 
        -src2:$src2 #Specify target souce.  Default is gv
        -top1:$top1 #Specify top-level for source.  Default is current top-level
        -top2:$top2 #Specify top-level for target source.  Default is current top-level
        -Hidden=stop1:$stop1
        -Hidden=stop2:$stop2
        -one        #Run only one pattern to establish invert/non-invert relationship for a known match
        -full       #Force exhaustive comparison.  Default is to switch to random for high input counts
        -max:1+$max_inputs  #Max number of inputs before random sim is invoked.  Default is 12.
        -random:1+$random_cnt   #Number of patterns to run for random sims.  Default is 1000.
        -quiet      #Suppress informational messages
        -map_file:$mf
        -map_pins:@map_pins
        -pins:@pins
    }
    my $i;
    defined ($opt_quiet) or $opt_quiet = 0; 
    defined (@map_pins) or @map_pins = ();
    my $start_time =  scalar (localtime);
    $src1 or $src1 = 'gv';
    $M_gv_source or error "No gv source found\n";
    $src2 or $src2 = $M_gv_source;
    defined ($top1) or $top1 = get_root_parent ();
    defined ($top2) or $top2 = get_root_parent ();
    $max_inputs or $max_inputs = 100;
    $random_cnt or $random_cnt = 300;
    my $max_pattern_width = 19; 
    @pins == 2 or error "Exactly two pins required for THIS_SUB";
    my ($pin1, $pin2);
    my $random_mode = $opt_random;
    my $save_src = $M_source_names[$SRC];
    my $save_top = $TOP_MODULE;
    my $fpc_cnt = 0;
    my $equal = 0;
    my $inv_equiv = 0;
    my ($net1,$net2);
    my $flag_const_in = 0;
    set_flat_prefix ($top2);
    suspend_fan_stops ();
    COMPARE:  while (defined($pin1 = shift(@pins)) && defined($pin2 = shift(@pins))) {
        COMPARE_CONE: {
            set_source ($src2);
            set_top ($top2);
            is_pin ($pin2) or error "Pin $pin2 doesn't exist in module $TOP_MODULE";
            my $net2 = get_net (-of => $pin2);
            my $pin2_const_out;
            #my $flat_const_in;
            if (is_power_net ($net2)) {
                my ($inst,$ref,$pin)= get_pin_context ($pin2);
                my @outputs = get_output_pins ($inst);
                $net2 = get_net (-of => $outputs[0]);
                $pin2_const_out = $outputs[0];
                $flag_const_in++; 
            }
            my @fanin2 = get_func (-quiet => -dff => -q_only => -up_to_ptr => $stop2, $net2);
            my $function2 = pop (@fanin2);
            if ($flag_const_in) {
                #$net{'persm1_tlu/geometry_load/U322/ZN'} = 
                $function2 =~ s/(\$net\{\'$pin2_const_out\'\}\s\=\s.*?)(\b[0|1]\b)/$1!$2/; #invert the constant pin
            }
            $function2 =~ s/\!(?!\=)/ inv /g;
            $function2 =~ s/\~/ inv_bit /g;

            set_source ($src1);
            set_top ($top1);
            is_pin ($pin1) or error "Pin $pin1 doesn't exist in module $TOP_MODULE"; 
            # get the top view of net1
            my $root_parent = get_root_parent ($top1);
            my @maps = translate_module ($root_parent);
            @maps = grep (s/\S+\://, @maps); 
            foreach (@maps) { 
                $RTL_prefix = (qr/$pin2/) ? $_ :"";
            }
            my $flat_prefix;
            if ($root_parent eq $top1) {
                $flat_prefix = $RTL_prefix;
            } else  {
                @maps = translate_module ($top1);
                @maps = grep (s/\S+\://, @maps);
                if (@maps > 1)  { # "module $top1 was instantiated more than once, use the first one to compare: $flat_prefix";
                    my @t_flat_prefix = grep(substr($pin2,0,(length ($_))) eq "$_",@maps);
                    $flat_prefix = (@t_flat_prefix == 1) ? $t_flat_prefix[0]: $maps[0];
                }
                $flat_prefix = $maps[0];
            }
            my $unit_root_prefix = substr ($flat_prefix, (length ($RTL_prefix)));
            my $pin1_top = "$unit_root_prefix$pin1";
            set_top ($root_parent);
            is_pin ($pin1_top) or error "Could not find pin $pin1_top in $root_parent";
            
            $net1 = get_net (-of => $pin1_top);
            my $pin1_const_out;
            if (is_power_net ($net1)) { #1'b0/1 VVSS_gx, GND, VDD
              #get the output pin:
                my ($inst,$ref,$pin)= get_pin_context ($pin1_top);
                my @outputs = get_output_pins ($inst);
                $net1 = get_net (-of => $outputs[0]);
                $pin1_const_out = $outputs[0];
            }

            my @fanin1 = get_func (-quiet => -dff => -q_only => -up_to_ptr => $stop1, $net1);
            my $function1 = pop (@fanin1);
            if ($flag_const_in) {
                $function1 =~ s/(\$net\{\'$pin1_const_out\'\}\s\=\s.*?)(\b[0|1]\b)/$1!$2/;
            }
            $function1 =~ s/\!(?!\=)/ inv /g;
            $function1 =~ s/\~/ inv_bit /g;

            my %matched_fanin = ();
            my %match_pair = ();
            my @match_array = ();
            if ($mf && (-e $mf)) {
                open (H_MF,$mf) or error "Could not open file $mf for read in THIS_SUB";
                while (<H_MF>) {
                    my $line = $_;
                    $line =~ s/\\//g;
                    if ($line =~ s/^add_mapped_points\s+(\S+)\s+(\S+)/$1 $2/) {
                        my ($golden,$revise) = split (/\s+/,$line);
           #             set_source ($src1);
           #             set_top ($root_parent);
           #             (is_pin ($golden) || is_port ($golden)) or next;
           #             set_source ($src2);
           #             set_top ($top2);
           #             (is_pin ($revise) || is_port ($revise)) or next; 
                     #   $match_hash{$golden} = $revise;
                         push (@match_array,$golden);
                         push (@match_array,$revise);
                    #    $matched_fanin{$revise}++;
                    }
                }
            }
            #keep the map points from the file and command line
            %match_pair = (@match_array,@map_pins),
            #map 
            #src1 is golden, So the patterns are generated based on $pin1 inputs.
            #Modify $function2 inputs to the mapping ones in @fanin1 
            #Mannual map is needed for ports
            set_source $src2;
            set_top $top2;
            my %stop1_names;
            $stop1 and %stop1_names = array2hash (values (%{$stop1}));
            my @fanin1_orig ;
            my $port_num = 0;
            my $port_msg;
            foreach $fanin (@fanin1) { 
                my $fan_pin = ${$fanin}[1];
                next if (is_power_net ($fan_pin));
                my $golden_pin = "${$fanin}[0]${$fanin}[1]"; #The map from user specified file has the highest priority.
                if ($match_pair{$golden_pin}) {
                    warn_once "using map from file for $golden_pin in $top1:$pin1 <=> $top2:$pin2";    
                    $function2 = "\$net{'$match_pair{$golden_pin}'} = \$net{'$golden_pin'};\n" . $function2;
                    $matched_fanin{"$match_pair{$golden_pin}"}++;
                    next;
                }
                my $fan_inst_save = ${$fanin}[0];
                push (@fanin1_orig,"${$fanin}[0]${$fanin}[1]");
                if ($RTL_prefix && (${$fanin}[0])) { #S: no prefix added for port
                    substr (${$fanin}[0], 0, 0) = $RTL_prefix;
                } 
                my $fan_inst = ${$fanin}[0];
                chop $fan_inst;
                if ($fan_inst) { #: found the start inst, not port. 
                    if (!is_inst($fan_inst)) { #: the cell in fanin1 can not be found in flat. I think can be asserted to be optimized
                        next if ($matched_fanin{"$fan_inst/$fan_pin"});
                        my $test = map_primary_input_name (-quiet => $fan_inst);
                        if ($test and is_inst($test)) {
                            $fan_inst = $test;
                            $function2 = "\$net{'$test/${$fanin}[1]'} = \$net{'${$fanin}[0]${$fanin}[1]'};\n" . $function2;
                            lprint "Modified function to include assumed match '$test/${$fanin}[1]' = '${$fanin}[0]${$fanin}[1]'\n";
                            $matched_fanin{"$fan_inst/$pin"}++;
                        } else { #may had been optimized 
                        warn_once "Could not find primary inst matching $fan_inst in $src2 module $TOP_MODULE, maybe optimized?";
                        }
                        #I think the code is not necessary since -q_only used in get_func
                        #my $pin = "$fan_inst/$fan_pin";
                        #is_pin ($pin) 
                        #   or $fan_pin eq "Q" and is_pin ("$fan_inst/QN") and $pin = "$fan_inst/QN" and ++$matched_fanin{"$fan_inst/Q"}
                        #   or warn_once "Could not find primary pin matching $pin in $src2 module $TOP_MODULE"; 
                        #$matched_fanin{$pin}++;
                    } else { #: may be it can be found directly
                        my $pin = "$fan_inst/$fan_pin";
                        is_pin ($pin)
                            or $fan_pin eq "Q" and is_pin ("$fan_inst/QN") and $pin = "$fan_inst/QN" and ++$matched_fanin{"$fan_inst/Q"}
                            or warn_once "Could not find primary pin matching $pin in $src2 module $TOP_MODULE";
                        $matched_fanin{$pin}++;
                        $function2 = "\$net{'$fan_inst/${$fanin}[1]'} = \$net{'$fan_inst_save${$fanin}[1]'};\n" . $function2;
                    }
                }
                elsif ($stop1 and $stop1_names{$fan_pin}) { #Is a stop point
                }
                elsif ($fan_pin) { #Must be a port since no instance
                    next if ($match_pair{"$fan_pin"});
                    #keep the ports that Mender can't map.
                    $port_msg .= "$fan_pin ";    
                    $port_num++;
                    next;
                  #  if (!is_input($fan_pin)) {
                  #     my $test = map_primary_input_name (-quiet => $fan_pin);
                  #     if ($test and is_input($test)) {
                  #         $function2 = "\$net{'${$fanin}[0]${$fanin}[1]'} = \$net{'${$fanin}[0]$test'};\n" . $function2;
                  #         lprint "Modified function to include assumed match \$net{'${$fanin}[0]${$fanin}[1]'} = \$net{'${$fanin}[0]$test'}\n";
                  #     }
                  #     else {
                  #         warn_once "Could not find input matching $fan_pin in $src2 module $TOP_MODULE";
                  #     }
                  #  }
                  #  $matched_fanin{$fan_pin}++;
                }
            }
            $port_msg = " $port_num" . " port" . "s" x ($port_num > 1) . " found: " . $port_msg;
            if ($port_num) {
                warn_once "Skip the comparison of $top1:$pin1 <=> $top2:$pin2\n $port_msg";
                return 1; 
            }
            my @fanin_pins1 = @fanin1_orig;  # filter_fanin (@fanin1_orig); #Convert to pins, exclude 1'b0/1'b1
            my @fanin_pins2 = filter_fanin (@fanin2);
            my @unmatched_fanin2 = grep (!$matched_fanin{$_}, @fanin_pins2);
            #@unmatched_fanin2 and warn_once "Found the following unmatched fanin in $src2, but not $src1: " . join ("\n", @unmatched_fanin2);
            my @combined_fanin = (@fanin_pins1, @unmatched_fanin2);
            @C = @combined_fanin;
            my @var_list = sort by_word_index (@combined_fanin);
            @var_list = remove_duplicates (@var_list);
            @V = @var_list;
            if ($function1 =~ /\'\'/) {
                error "Internal parsing error for function $function1.  Please report bug";
            }
            if ($function2 =~ /\'\'/) {
                error "Internal parsing error for function $function2.  Please report bug";
            }
            $DEBUG_LOGIC and $function1 =~ s/(.*)/print q<$1> . "\n";\n$1/mg;
            $DEBUG_LOGIC and $function2 =~ s/(.*)/print q<$1> . "\n";\n$1/mg;
            #$function1 =~ s/\'([^\']+?)\'/"'" . unbracket_net_name ($1) . "'"/ge;      
            #$function2 =~ s/\'([^\']+?)\'/"'" . unbracket_net_name ($1) . "'"/ge;      
            unless ($opt_quiet) {
                lprint "Applying vectors to variable list:\n";
                print_array (@var_list);
            }
            local @vector;
            my ($result1, $result2);
            my $pattern_num = 0;
            my $var_cnt = @var_list;
            $F1 = $function1;
            $F2 = $function2;
            EVAL_CONE: {
                if ($opt_one) { 
                    #Single pattern to determine possible inverted or non-inv equiv
                    my $pattern = "0" x $var_cnt;
                    $equal = apply_compare_pattern ($function1, $function2, $pattern, @var_list, $pattern_num, $inv_equiv);
                    last COMPARE;
                }
                #basic pattern only
                if (($var_cnt < $max_inputs) && ($var_cnt > 8) && (!$opt_random) && (!$opt_full)) {
                    lprint "... Comparing ($pin1, $pin2) in basic pattern\n";
                    foreach $pattern (get_basic_patterns ($var_cnt)) {
                        $P = $pattern;
                        last COMPARE unless ($equal = apply_compare_pattern ($function1, $function2, $pattern, @var_list, $pattern_num, $inv_equiv));
                    }
                    if (1 == $flag_const_in) {warning "once\n";goto COMPARE_CONE;}
                    last COMPARE;
                }
                if (0) { #Not working yet.  See get_int_fan_conv_pts which also has problems
                #if ($var_cnt > 10) {
                    #Find internal partial fanin convergeance points (IPFCPs)
                    #This code attempts to find internal points within the fanin cones
                    #of each source and compare them separately to allow
                    #multi-step comparison
                    my $ilevel = 2;
                    my @ints1;
                    my @ins_all;
                    my %ins;
                    my $is_fcp;
                    my @fcp_nums1;
                    while ($ilevel < 100) { #Timeout counter
                        @ints1 = get_fanin_xlevel($ilevel, $net1);
                        @ins_all1 = ();
                        foreach $int (@ints1) {
                            my @ins = get_fanin_pins(-dff => -q_only => $int);
                            foreach $in (@ins) {
                                $ins{$in}++;
                            }
                            push (@ins_all1, \@ins);
                        }
                        foreach my $i (0..$#ins_all1) {
                            $is_fcp = 1;
                            foreach my $in (@{$ins_all1[$i]}) {
                                if ($ins{$in} > 1) {
                                    $is_fcp = 0;
                                    last;
                                }
                            }
                            if ($is_fcp) {
                                lprint "ICFCP: $ints1[$i]\n";
                                push (@fcp_nums1, $i);
                            }
                        }
                        #Now that we have identified ICFCPs at this level
                        #in source 1, try to match them up to ICFCPs in source 2.
                        #If we have a match, set stops, redo cone analysis, and push on match nets
                        $ilevel++;
                    }
                }
                my $pattern_cnt;
                if (!$opt_full && ($var_cnt >= $max_inputs) || $opt_random) {
                    $random_mode = 1;
                    $opt_quiet or lprint "Invoking random simulator\n";
                    $pattern_cnt = $var_cnt + $max_inputs; #random pattern used if $var_cnt is too large;
                }
                elsif ($opt_full && $opt_max && ($var_cnt > $max_inputs)) {
                    return "Overflow";
                }
                elsif ($var_cnt > $max_pattern_width) { #Cutoff to avoid ridiculously long processes
                    $pattern_cnt = 1 << $max_pattern_width;
                    warn_once "Overflow.  Not all patterns checked";
                }
                else {
                    $pattern_cnt = 2**$var_cnt;
                }
                my $pattern_decimal = 0;
                #floor the $pattern_cnt to $random_cnt by default.
                $pattern_cnt = ($opt_random) ? $random_cnt : (($pattern_cnt > $random_cnt) ? $random_cnt : $pattern_cnt);
                lprint "... Comparing ($pin1, $pin2)\n";
                unless ($opt_quiet) {
                    lprint "\nRunning $pattern_cnt comparisons.  Press ctrl-C to interrupt\n";
                    lprint "Running pattern .";
                }
                while ($pattern_num < $pattern_cnt) {
                    if (!($pattern_num % 256)) {
                        if ($opt_quiet) {
                            lprint "."; #Still need to print something as a sign of life
                        }
                        else {
                            lprint "..$pattern_num";
                        }
                    }
                    $pattern = $random_mode 
                            ? get_rand_pattern ($var_cnt) 
                            : dec2bin ($pattern_decimal++, $var_cnt);
                    last unless ($equal = apply_compare_pattern ($function1, $function2, $pattern, @var_list, $pattern_num, $inv_equiv));
                }
                #$opt_quiet and $var_cnt >= 8 and lprint "\n";
                $opt_quiet and lprint "\n";
                if (!$opt_quiet && $equal) {
                    lprint "..", $pattern_num - 1, "\n";
                    my $is_inv_txt = $inv_equiv ? " *INVERTED*" : "";
                    if ($random_mode) {
                        lprint "Nets are probably$is_inv_txt equivalent -- $pattern_cnt random patterns verified\n";
                    }
                    else {
                        lprint "Nets are$is_inv_txt equivalent -- all $pattern_cnt patterns verified\n";
                    }
                }
            } #EVAL_CONE
        if (1 == $flag_const_in) {goto COMPARE_CONE;}
        } #COMPARE_CONE:
    } #COMPARE:
    restore_fan_stops ();
    set_source ($save_src);
    set_top ($save_top) if ($top1||$top2);
    $inv_equiv ? -$equal : $equal;
#    my $end_time =  scalar (localtime);
#    lprint "comare random_cnt = $random_cnt; started at $start_time;  end at $end_time. \n";
END

Tsub compare_try => << 'END';
            my $tomenderFV = `cat test_bdd_debug`;
            my $mf_result = check_equiv_menderFV($tomenderFV);
END


Tsub compare_formal_shpd => << 'END';
    DESC {
        Compares the functionality of two pins.  Compares pins to perform gates-to-gates boolean equivalence.
    }
    ARGS {
        -src1:$src1 #Specify reference source.  Default is gv 
        -src2:$src2 #Specify target souce.  Default is gv
        -top1:$top1 #Specify top-level for source.  Default is current top-level
        -top2:$top2 #Specify top-level for target source.  Default is current top-level
        -o:$opt_log #The output file to store the menderFV log. Default is USERNAME_menderFV.log
        -random:1+$random_cnt   #Number of patterns to run for random sims.  Default is 1000.
        -quiet      #Suppress informational messages
        -in #Check if the functions are inverted. i.e funcA = inv funcA
        -v   #Verbose mode. Print equivalence check information for all signals in the golden design
        -v1  #Verbose mode. Print info for only signals found in both designs but are logically not equivalent
        -map_file:$mf #The map file in Cadence conformal format.
        -map_pins:@map_pins #mapping pins specified by user, has higher priority 
        -pins:@pins #pins will be compared, in the order: reference pin, target pin
        -no_map_port #Don't use Mender auto mapping rule for primary inputs
        -map_coe:$map_coe
    }
    my $i;
    defined ($opt_in) or $opt_in = 0; 
    defined ($opt_v) or $opt_v   = 0; 
    defined $opt_log or $opt_log = "$ENV{USER}_menderFV.log";
    defined $opt_no_map_port or $opt_no_map_port = 0;
    defined $map_coe or $map_coe = 1.5; #Default corelation map rule: The shorter signal should be a sub string of longer, and is no lesser than half length of it.
    
    defined ($opt_quiet) or $opt_quiet = 0; 
    defined (@map_pins) or @map_pins = ();
    my $start_time =  scalar (localtime);
    $src1 or $src1 = 'gv';
    $M_gv_source or error "No gv source found\n";
    $src2 or $src2 = $M_gv_source;
    defined ($top1) or $top1 = get_root_parent ();
    defined ($top2) or $top2 = get_root_parent ();
    $random_cnt or $random_cnt = 400;
    @pins == 2 or error "Exactly two pins required for THIS_SUB";
    my ($pin1, $pin2);
    my $save_src = $M_source_names[$SRC];
    my $save_top = $TOP_MODULE;
    my $fpc_cnt = 0;
    my $equal = 0;
    my $abort = 0;
    my $inv_equiv = 0;
    my ($net1,$net2);
    my $flag_const_in = 0;
    my $RTL_prefix = ();
    set_flat_prefix ($top2);
    suspend_fan_stops ();
    COMPARE:  while (defined($pin1 = shift(@pins)) && defined($pin2 = shift(@pins))) {
        COMPARE_CONE: {
            set_source ($src2);
            set_top ($top2);
            is_pin ($pin2) or error "Pin $pin2 doesn't exist in module $TOP_MODULE";
            my $net2 = get_net (-of => $pin2);
            my $pin2_const_out;
            #my $flat_const_in;
            if (is_power_net ($net2)) {
                my ($inst,$ref,$pin)= get_pin_context ($pin2);
                my @outputs = get_output_pins ($inst);
         #       $net2 = get_net (-of => $outputs[0]);
                $pin2_const_out = $outputs[0];
                $flag_const_in++; 
                lprint "constant out2 $outputs[0]\n";
                lprint "flag_const_in $flag_const_in\n";
            }
            my @fanin2 = get_func (-quiet => -dff => -q_only =>, $net2);
            my $function2 = pop (@fanin2);
            if ($flag_const_in) {
                #$net{'persm1_tlu/geometry_load/U322/ZN'} = 
                $function2 =~ s/(\$net\{\'$pin2_const_out\'\}\s\=\s.*?)(\b[0|1]\b)/$1!$2/; #invert the constant pin
            }
            $function2 =~ s/\!(?!\=)/ inv /g;
            $function2 =~ s/\~/ inv_bit /g;
            my $function2_bak= $function2;

            set_source ($src1);
            set_top ($top1);
            is_pin ($pin1) or error "Pin $pin1 doesn't exist in module $TOP_MODULE"; 
            # get the top view of net1
            my $root_parent = get_root_parent ($top1);
            
            if (exists $Translate_top[$M_source_nums{$src1}]{$top1}) { 
                $RTL_prefix = $RTL_prefixes[$M_source_nums{$src1}]{$top1};
            }
            else
            {
                my @maps = translate_module ($root_parent);
                my %map_par_prefix= ();
                foreach my $map_t (@maps) {
                    my ($par,$prefix) = split (/\:/,$map_t);
                    $map_par_prefix{$par} = $prefix;
                }
#            @maps = grep (s/\S+\://, @maps); 
                foreach (keys %map_par_prefix) { 
                    if ( ($_ eq $top2)) {
                        $RTL_prefix =  $map_par_prefix{$_};
                    }
                }
            }
            my $flat_prefix;
            if ($root_parent eq $top1) {
                $flat_prefix = $RTL_prefix;
            } else  {
                my @maps = translate_module ($top1);
                my %map_par_prefix= ();
                foreach my $map_t (@maps) {
                    my ($par,$prefix) = split (/\:/,$map_t);
                    push (@{$map_par_prefix{$par}} ,$prefix);
                }
                foreach (keys %map_par_prefix) {
                    if (($_ eq $top2) && ($pin2 =~ /$map_par_prefix{$_}[0]/)) {
                        $flat_prefix = $map_par_prefix{$_}[0];
					} elsif (($_ eq $top2)) {
                        ((scalar @{$map_par_prefix{$par}}) > 1) and error "module $top1 was instaniated more than once in $root_parent, Mender can't know your flat prefix, Please try to use the $pin2 in its parent module to compare";
						$flat_prefix = $map_par_prefix{$_}[0];	
					}
                }
            }
            my $unit_root_prefix = substr ($flat_prefix, (length ($RTL_prefix)));
            my $pin1_top = "$unit_root_prefix$pin1";
            set_top ($root_parent);
            is_pin ($pin1_top) or error "Could not find pin $pin1_top in $root_parent";
            
            $net1 = get_net (-of => $pin1_top);
            my $pin1_const_out;
            if (is_power_net ($net1)) { #1'b0/1 VVSS_gx, GND, VDD
              #get the output pin:
                my ($inst,$ref,$pin)= get_pin_context ($pin1_top);
                my @outputs = get_output_pins ($inst);
            #    $net1 = get_net (-of => $outputs[0]);
                $pin1_const_out = $outputs[0];
                lprint "constant out $outputs[0]\n";
            }


            my @fanin1 = get_func (-quiet => -dff => -q_only => , $net1);
            my $function1 = pop (@fanin1);
            if ($flag_const_in) {
                $function1 =~ s/(\$net\{\'$pin1_const_out\'\}\s\=\s.*?)(\b[0|1]\b)/$1!$2/;
            }
            $function1 =~ s/\!(?!\=)/ inv /g;
            $function1 =~ s/\~/ inv_bit /g;

            my %matched_fanin = ();
            my %match_pair = ();
            my @match_array = ();
            if ($mf && (-e $mf)) {
                open (H_MF,$mf) or error "Could not open file $mf for read in THIS_SUB";
                while (<H_MF>) {
                    my $line = $_;
                    $line =~ s/\\//g;
                    if ($line =~ s/^add_mapped_points\s+(\S+)\s+(\S+)/$1 $2/) {
                        my ($golden,$revise) = split (/\s+/,$line);
           #             set_source ($src1);
           #             set_top ($root_parent);
           #             (is_pin ($golden) || is_port ($golden)) or next;
           #             set_source ($src2);
           #             set_top ($top2);
           #             (is_pin ($revise) || is_port ($revise)) or next; 
                     #   $match_hash{$golden} = $revise;
                         push (@match_array,$golden);
                         push (@match_array,$revise);
                    #    $matched_fanin{$revise}++;
                    }
                }
                close (H_MF);
            }
            #keep the map points from the file and command line
            %match_pair = (@match_array,@map_pins),
            #map 
            #src1 is golden, So the patterns are generated based on $pin1 inputs.
            #Modify $function2 inputs to the mapping ones in @fanin1 
            #Mannual map is needed for ports
            set_source $src2;
            set_top $top2;
            my %stop1_names;
            $stop1 and %stop1_names = array2hash (values (%{$stop1}));
            my @fanin1_orig ;
            my $port_num = 0;
            my $port_msg;
            my %bdd_pair;
            my @fanin2_pins = filter_fanin (@fanin2); 
            foreach $fanin (@fanin1) { 
                my $fan_pin = ${$fanin}[1];
                next if (is_power_net ($fan_pin));
                my $golden_pin = "${$fanin}[0]${$fanin}[1]"; #The map from user specified file has the highest priority.
                if ($match_pair{$golden_pin}) {
                    warn_once "Using user specified map rule for $golden_pin in $top1:$pin1 <=> $top2:$pin2";    
                    $function2 = "\$net{'$match_pair{$golden_pin}'} = \$net{'$golden_pin'};\n" . $function2;
                    $bdd_pair{$golden_pin} = $match_pair{$golden_pin};
                    $matched_fanin{"$match_pair{$golden_pin}"}++;
                    next;
                }
                my $fan_inst_save = ${$fanin}[0];
                push (@fanin1_orig,"${$fanin}[0]${$fanin}[1]");
                my $fan_inst = ${$fanin}[0];
                chop $fan_inst;
		if ($RTL_prefix and $fan_inst) {
			substr ($fan_inst, 0, 0) = $RTL_prefix;
		}
                if ($fan_inst) { #: found the start inst, not port. 
                    if (!is_inst($fan_inst)) { #: the cell in fanin1 can not be found in flat. I think can be asserted to be optimized
                        next if ($matched_fanin{"$fan_inst/$fan_pin"});
                        my $test = map_primary_input_name (-quiet => $fan_inst);
                        if ($test and is_inst($test)) {
                            $fan_inst = $test;
                            $function2 = "\$net{'$test/${$fanin}[1]'} = \$net{'${$fanin}[0]${$fanin}[1]'};\n" . $function2;
                            $bdd_pair{"${$fanin}[0]${$fanin}[1]"} = "$test/${$fanin}[1]";
                            lprint "Modified function to include assumed match '$test/${$fanin}[1]' = '${$fanin}[0]${$fanin}[1]'\n";
                            $matched_fanin{"$fan_inst/$pin"}++;
                        } else { #may had been optimized 
                        warn_once "Could not find primary inst matching $fan_inst in $src2 module $TOP_MODULE, maybe optimized?";
                        $bdd_pair{"$fan_inst_save${$fanin}[1]"} = "UNMAPPED";
                        }
                        #I think the code is not necessary since -q_only used in get_func
                        #my $pin = "$fan_inst/$fan_pin";
                        #is_pin ($pin) 
                        #   or $fan_pin eq "Q" and is_pin ("$fan_inst/QN") and $pin = "$fan_inst/QN" and ++$matched_fanin{"$fan_inst/Q"}
                        #   or warn_once "Could not find primary pin matching $pin in $src2 module $TOP_MODULE"; 
                        #$matched_fanin{$pin}++;
                    } else { #: may be it can be found directly
                        my $pin = "$fan_inst/$fan_pin";
                        is_pin ($pin)
                            or $fan_pin eq "Q" and is_pin ("$fan_inst/QN") and $pin = "$fan_inst/QN" and ++$matched_fanin{"$fan_inst/Q"}
                            or lprint "Could not find primary pin matching $pin in $src2 module $TOP_MODULE";
                        $matched_fanin{$pin}++;
                        $function2 = "\$net{'$fan_inst/${$fanin}[1]'} = \$net{'$fan_inst_save${$fanin}[1]'};\n" . $function2;
                        $bdd_pair{"$fan_inst_save${$fanin}[1]"} = "$fan_inst/${$fanin}[1]";
                    }
                }
                elsif ($stop1 and $stop1_names{$fan_pin}) { #Is a stop point
                }
                elsif ($fan_pin) { #Must be a port since no instance
                    next if ($match_pair{"$fan_pin"});
                    if ((!$opt_no_map_port) and (is_member ($fan_pin,@fanin2_pins))) {
                        $bdd_pair{"$fan_pin"} = "$fan_pin";    
                        warn_once "Map primary input by naming restrict rule: $top1:$fan_pin <=> $top2:$fan_pin\n Can be turned off by: -no_map_port\n"; 
                        next;
                    } elsif (!$opt_no_map_port) {
                        my $co_ef = 0;
                        my $map_pin = 0;
                        foreach my $fanin2_pin (@fanin2_pins) {
                            (!(is_port $fanin2_pin)) and next;
                            my $co_tmp = corelation_sum ($fan_pin,$fanin2_pin);
                            if (($co_tmp > $co_ef) and ($co_tmp > $map_coe)) {
                                $co_ef = $co_tmp;
                                $map_pin = $fanin2_pin;
                            }
                        }
                        if ($map_pin) {
                            ($bdd_pair{"$fan_pin"} = "$map_pin");
                            warn_once "Map primary input by naming corelation rule: $top1:$fan_pin <=> $top2:$map_pin\n Can be turned off by: -no_map_port\n"; 
                            next;
                        }
                    }
                    #keep the ports that Mender can't map.
                    $port_msg .= "$fan_pin ";    
                    $port_num++;
                    next;
                  #  if (!is_input($fan_pin)) {
                  #     my $test = map_primary_input_name (-quiet => $fan_pin);
                  #     if ($test and is_input($test)) {
                  #         $function2 = "\$net{'${$fanin}[0]${$fanin}[1]'} = \$net{'${$fanin}[0]$test'};\n" . $function2;
                  #         lprint "Modified function to include assumed match \$net{'${$fanin}[0]${$fanin}[1]'} = \$net{'${$fanin}[0]$test'}\n";
                  #     }
                  #     else {
                  #         warn_once "Could not find input matching $fan_pin in $src2 module $TOP_MODULE";
                  #     }
                  #  }
                  #  $matched_fanin{$fan_pin}++;
                }
            }
            $port_msg = " $port_num" . " port" . "s" x ($port_num > 1) . " found: " . $port_msg;
            if ($port_num) {
                warn_once "Skip the comparison of $top1:$pin1 <=> $top2:$pin2\n $port_msg";
                return 1; 
            }

        
            my @write_out=();
            my $tomenderFV = "map_pins\:\n";
            #push (@write_out,"map_pins\:");
            foreach (keys %bdd_pair) {
            #    push (@write_out, "$_ \<\=\> $bdd_pair{$_}");
                $tomenderFV .= "$_ \<\=\> $bdd_pair{$_}\n";
            
            }
            #push (@write_out,"Golden\:");
            #push (@write_out,"$function1");
            #push (@write_out,"Revise\:");
            #push (@write_out,"$function2");
            $tomenderFV .= "Golden\:\n" . "$function1\n" . "Revise\:\n" . "$function2";
#            $tomenderFV    .= '\0';
#            $tomenderFV    .= "\0";

#           lprint "Golden:\n$function1\nRevise:\n$function2_bak\n";
#            my $menderfv_input_file = "$ENV{HOME}/test_bdd_input_$ENV{USER}.log";
            my $menderfv_input_file = "/tmp/test_bdd_input_$ENV{USER}.log";
            my $out_test = "./compare_formal.debug";

            open (F, ">$menderfv_input_file") or die "Cannot write to MENDERFV input file: $menderfv_input_file";
            open (F_TEST, ">$out_test") or die "Cannot write to MENDERFV input file: $out_test";
            #while (@write_out) {
            #    my $write = shift @write_out;
            #    print F "$write\n";
            #}
            print F "$tomenderFV\n";
            print F_TEST "$tomenderFV\n";
            close F;
            close F_TEST;
            #lprint "$tomenderFV\n";

            -e $opt_log || unlink $opt_log;
            # Append "/home/nv/bin/mender_utils" to LD_LIBRARY_PATH only if it is
            # not already present
            set_ld_library_path();

            my $invocation = "/home/nv/bin/menderFV -f $menderfv_input_file ";
#            my $invocation = "/home/scratch.rnadig_gt200/nv/cad/cadlib/menderFV/menderFV -f $menderfv_input_file ";
            if ($opt_in) {
              $invocation .= " -i ";
            }
            if ($opt_v) {
              $invocation .= " -v ";
            } elsif ($opt_v1) {
              $invocation .= " -p ";
            }
            
            $invocation .= " &> $opt_log ";
            
            my ($r1) = system ($invocation);
            my $retCode = $? >> 8;
            lprint `cat $opt_log` if (-e $opt_log);

#           my $tomenderFV = `cat test_bdd_debug`;
#           print "\n\nBEGIN\n $tomenderFV \nEND\n\n";
#           my $mf_result = check_equiv_menderFV ($tomenderFV);
#           my $mf_result = check_equiv_file test_bdd_debug;
            #lprint "Spirit mf is :$mf_result:\n";
            if ($retCode == 0) {
              lprint("Equivalent\n");
              unlink $menderfv_input_file;
              return (1);
            } else {
              lprint("$pin1 is NOT Equivalent to $pin2\n");
              return (0);
            }
            #TODO
            if (0 == $mf_result) {
                $equal = 1;
            } elsif (-1 == $mf_result) {
                $abort = 1;
            } else {
                $equal = 0;
            }
            if ($abort) {
               #invoke the simulation engine.
               lprint "Mender formal check aborted for 50s timeout, invoking simulation...\n";
               my @fanin_pins1 = @fanin1_orig;  # filter_fanin (@fanin1_orig); #Convert to pins, exclude 1'b0/1'b1
               my @fanin_pins2 = filter_fanin (@fanin2);
               my @unmatched_fanin2 = grep (!$matched_fanin{$_}, @fanin_pins2);
               #@unmatched_fanin2 and warn_once "Found the following unmatched fanin in $src2, but not $src1: " . join ("\n", @unmatched_fanin2);
               my @combined_fanin = (@fanin_pins1, @unmatched_fanin2);
               my @var_list = sort by_word_index (@combined_fanin);
               @var_list = remove_duplicates (@var_list);
               my $var_cnt = @var_list;
               @V = @var_list;
               if ($function1 =~ /\'\'/) {
                   error "Internal parsing error for function $function1.  Please report bug";
               }
               if ($function2 =~ /\'\'/) {
                   error "Internal parsing error for function $function2.  Please report bug";
               }
               $DEBUG_LOGIC and $function1 =~ s/(.*)/print q<$1> . "\n";\n$1/mg;
               $DEBUG_LOGIC and $function2 =~ s/(.*)/print q<$1> . "\n";\n$1/mg;
               my $pattern_num = 0;
               my $pattern_cnt = $random_cnt; 
               while ($pattern_num < $pattern_cnt) {
                   if (!($pattern_num % 256)) {
                       if ($opt_quiet) {
                           lprint "."; #Still need to print something as a sign of life
                       }
                       else {
                           lprint "..$pattern_num";
                       }
                   }
                   $pattern = get_rand_pattern ($var_cnt); 
                   last unless ($equal = apply_compare_pattern ($function1, $function2, $pattern, @var_list, $pattern_num, $inv_equiv));
               }
            }
        if (1 == $flag_const_in) {lprint "flat_const_in ok \n"; goto COMPARE_CONE;}
        } #COMPARE_CONE:
    } #COMPARE:
#    restore_fan_stops ();
    set_source ($save_src);
    set_top ($save_top) if ($top1||$top2);
    #$inv_equiv ? -$equal : $equal;
    $equal;
#    my $end_time =  scalar (localtime);
#    lprint "comare random_cnt = $random_cnt; started at $start_time;  end at $end_time. \n";
END

sub corelation_sum {
    #Capital sensitive
    my @r = split (//,$_[0]); 
    my @g = split (//,$_[1]); 
    my $RL = (scalar @r) -1;
    my $GL = (scalar @g) -1;
    ($RL < 0 or $GL < 0) and return 0;
    my $crl_min = min (scalar (@r), scalar (@g));
    my $crl_max = max (scalar (@r), scalar (@g));
    my @g_fill = (@g, split (//," " x $RL));
    my @r_fill = (@r, split (//," " x $GL));
    my $loop = $GL + $RL + 1;
    my $relate = 0;
    my $co_ef = 0;
    while ($loop) { 
        
        my $l = (scalar @r_fill);
        my $sum = 0;
        while ($l) {
            $l = $l - 1;
            ("$g_fill[$l]" eq " ") and next;
            if ("$g_fill[$l]" eq "$r_fill[$l]" ) {
                $sum = $sum + 1;
            }
        }
        my $shift_g = pop @g_fill;
        @g_fill = ($shift_g,@g_fill);
        $loop = $loop - 1;
        $relate = max ($relate,$sum);
    }
    my $co_ef_min = $relate / $crl_min;
    my $co_ef_max = $relate / $crl_max;
    $co_ef = $co_ef_min + $co_ef_max;
    return ($co_ef);
}

Tsub menderFV_turnoff_test => << 'END'; 
    DESC {
        parse the add_pin/instance_constraint from timing/fv_scripts/partition.lecsh
        dosen't include the NV_BLK_SRC0/1 place holders now.
    }
    ARGS {    
        -golden_container:$golden_container
        -revise_container:$revise_container
    }
    #($menderFV_use_notest) or return (1);
    my $DesignName = get_top ();
    #container precheck:
    (exists ($M_source_nums{$golden_container}) && exists ($M_source_nums{$revise_container})) or error "Unrecognized source container. Expected 1 of @M_source_names";
    my %constr = ();
    my $tot = get_project_home ();
    my $file_lec_par_constraint = "$tot/timing/fv_scripts/partition.lecsh";
    (-e "$file_lec_par_constraint") or return (1);
    open (FH, "<$file_lec_par_constraint") or die "Can not open $file_lec_par_constraint for read";
    while (<FH>) {
        my $match = $_;
        ($match =~ s/^\s+add\_(\S+?)\_constrai\S+?\s+(\d)\s+(\S+)\s+\-(\S+)/$1 $2 $3 $4/) or next;
        my @constraints = split (/\s+/,$match);
        if ($constraints[3] eq "both") {
            if ($constraints[0] eq "pin") {
                $constr{golden}{net}{"$constraints[2]"} = "$constraints[1]";
                $constr{revise}{net}{"$constraints[2]"} = "$constraints[1]";
            } elsif ($constraints[0] eq "instance") {
                $constr{golden}{inst}{"$constraints[2]"} = "$constraints[1]";
                $constr{revise}{inst}{"$constraints[2]"} = "$constraints[1]";    
            }
        } elsif ($constraints[3] eq "rev") {
             if ($constraints[0] eq "pin") {
                 $constr{revise}{net}{"$constraints[2]"} = "$constraints[1]";
             } elsif ($constraints[0] eq "instance") {
                 $constr{revise}{inst}{"$constraints[2]"} = "$constraints[1]";
             }
                        
        }
    }
    close (FH);
    (keys %constr) or return (1);
    ##set_case_analysis for golden 
    my $save_case_thru_flops = $Logic_propagate_case_thru_flops;
    $Logic_propagate_case_thru_flops = 1;

    set_source ($golden_container);
    my @golden_net_constrs = keys %{$constr{golden}{net}};
    foreach my $golden_net_constr (@golden_net_constrs) {
        my @nets = get_nets (-quiet => $golden_net_constr);
        foreach my $net (@nets) {
            my $value = "$constr{golden}{net}{$golden_net_constr}";
            set_case_analysis ($value,$net);
            lprint "set case analysis $value on net $net\n";
        }
    }
    my @golden_inst_constrs = keys %{$constr{golden}{inst}};
    foreach my $golden_inst_constr (@golden_inst_constrs) {
        my @insts = get_cells (-quiet => $golden_inst_constr);
        foreach my $inst (@insts) {
            my $value = "$constr{golden}{inst}{$golden_inst_constr}";
            my $ref = get_ref ($inst);
            if (is_end_ref $ref) { #should be flops
                my @outs = get_outputs_of $ref;
                if (is_pin "$inst/$outs[0]") {
                    set_case_analysis ($value,"$inst/$outs[0]");
                    lprint "set case analysis $value on pin $inst/$outs[0]\n";
                }
                
            }
        }
    }
    #set case analysis for revise 
    set_source ($revise_container);
    my @revise_net_constrs = keys %{$constr{revise}{net}};
    foreach my $revise_net_constr (@revise_net_constrs) {
        my @nets = get_nets (-quiet => $revise_net_constr);
        foreach my $net (@nets) {
            my $value = "$constr{revise}{net}{$revise_net_constr}";
            set_case_analysis $value, $net;
            lprint "set case analysis $value on net $net\n";
        }
    }
    my @revise_inst_constrs = keys %{$constr{revise}{inst}};
    foreach my $revise_inst_constr (@revise_inst_constrs) {
        my @insts = get_cells (-quiet => $revise_inst_constr);
        foreach my $inst (@insts) {
            my $value = "$constr{revise}{inst}{$revise_inst_constr}";
             my $ref = get_ref ($inst);
            if (is_end_ref $ref) { #should be flops
                my @outs = get_outputs_of $ref;
                if (is_pin "$inst/$outs[0]") {
                    set_case_analysis ($value,"$inst/$outs[0]");
                    lprint "set case analysis $value on pin $inst/$outs[0]\n";
                }
            }
        }
    }
    $Logic_propagate_case_thru_flops = $save_case_thru_flops;
END

Tsub test_bdd_run_auto => << 'END';
#        system("rm -rf _Inline");
#        system("mkdir _Inline");
#        $ENV{PATH} = "/home/utils/gcc-4.3.2/bin:$ENV{PATH}";
#        load_mpl "/home/nv/bin/mender_utils/load_menderFV.mpl";
     open (IFH, "<eq_confirmed.log") or die "error file not exits\n";
     while (<IFH>) {
         chomp $_;
         my $line = $_;
         my $line_2 = <IFH>;
         chomp $line_2;
         next unless ($line eq $line_2);
 #        set_source syn;
         next if (is_port ($line));
         next unless (is_flop ($line));
         my @pins = get_input_pins ($line);
         foreach my $pin (@pins) {
             if ($pin=~ qr/.*?\/[Dd]$/) {
                 my $fanin_num = get_fanin (-end => $pin);
                 last unless ($fanin_num > 50);
#                 lprint "comparing $pin\n";
                 my $start_time = scalar (localtime);
                 my $rtn = compare_formal (-src1 =>syn, -src2=> gv, -top1=> TS0, -top2=> TS0, -pins => ($pin,$pin));
                 my $end_time = scalar (localtime);
                 $start_time =~ s/^\S+\s+\S+\s+\S+\s+(\S+)\:(\S+)\:(\S+).*$/$1 $2 $3/;
                 $end_time =~ s/^\S+\s+\S+\s+\S+\s+(\S+)\:(\S+)\:(\S+).*$/$1 $2 $3/;
                 my @start_time = split (/ /,$start_time);
                 my @end_time = split (/ /,$end_time);
                 my $cost_time = ($end_time[1] * 60 + $end_time[2]) - ($start_time[1] * 60 + $start_time[2]);
                 lprint "$pin    $fanin_num    $cost_time\n";
                 ($rtn) or lprint "error $pin wrong !\n"; 
             }

         }
     }
    close (IFH);
END

sub set_ld_library_path 
{
    my %tmp_hash = ();

    foreach my $path (split(/\:/, $ENV{LD_LIBRARY_PATH})) {
      $tmp_hash{$path} = 1;
    }
    
    if (! defined $tmp_hash{"/home/nv/bin/mender_utils"}) {
      $ENV{LD_LIBRARY_PATH} = "/home/nv/bin/mender_utils:$ENV{LD_LIBRARY_PATH}";
    }
    
#    if (! defined $tmp_hash{"/home/scratch.rnadig_gt200/nv/cad/cadlib/menderFV"}) {
#        $ENV{LD_LIBRARY_PATH} = "/home/scratch.rnadig_gt200/nv/cad/cadlib/menderFV:$ENV{LD_LIBRARY_PATH}";
#    }
}   

Tsub menderFV_turnoff_test => << 'END'; 
    DESC {
        parse the add_pin/instance_constraint from timing/fv_scripts/partition.lecsh
        dosen't include the NV_BLK_SRC0/1 place holders now.
    }
    ARGS {    
        -golden_container:$golden_container
        -revise_container:$revise_container
    }
    #($menderFV_use_notest) or return (1);
    my $DesignName = get_top ();
    #container precheck:
    (exists ($M_source_nums{$golden_container}) && exists ($M_source_nums{$revise_container})) or error "Unrecognized source container. Expected 1 of @M_source_names";
    my %constr = ();
    my $tot = get_project_home ();
    my $file_lec_par_constraint = "$tot/timing/fv_scripts/partition.lecsh";
    (-e "$file_lec_par_constraint") or return (1);
    open (FH, "<$file_lec_par_constraint") or die "Can not open $file_lec_par_constraint for read";
    while (<FH>) {
        my $match = $_;
        ($match =~ s/^\s+add\_(\S+?)\_constrai\S+?\s+(\d)\s+(\S+)\s+\-(\S+)/$1 $2 $3 $4/) or next;
        my @constraints = split (/\s+/,$match);
        if ($constraints[3] eq "both") {
            if ($constraints[0] eq "pin") {
                $constr{golden}{net}{"$constraints[2]"} = "$constraints[1]";
                $constr{revise}{net}{"$constraints[2]"} = "$constraints[1]";
            } elsif ($constraints[0] eq "instance") {
                $constr{golden}{inst}{"$constraints[2]"} = "$constraints[1]";
                $constr{revise}{inst}{"$constraints[2]"} = "$constraints[1]";    
            }
        } elsif ($constraints[3] eq "rev") {
             if ($constraints[0] eq "pin") {
                 $constr{revise}{net}{"$constraints[2]"} = "$constraints[1]";
             } elsif ($constraints[0] eq "instance") {
                 $constr{revise}{inst}{"$constraints[2]"} = "$constraints[1]";
             }
                        
        }
    }
    close (FH);
    (keys %constr) or return (1);
    ##set_case_analysis for golden 
    my $save_case_thru_flops = $Logic_propagate_case_thru_flops;
    $Logic_propagate_case_thru_flops = 1;

    set_source ($golden_container);
    my @golden_net_constrs = keys %{$constr{golden}{net}};
    foreach my $golden_net_constr (@golden_net_constrs) {
        my @nets = get_nets (-quiet => $golden_net_constr);
        foreach my $net (@nets) {
            my $value = "$constr{golden}{net}{$golden_net_constr}";
            set_case_analysis ($value,$net);
            lprint "set case analysis $value on net $net\n";
        }
    }
    my @golden_inst_constrs = keys %{$constr{golden}{inst}};
    foreach my $golden_inst_constr (@golden_inst_constrs) {
        my @insts = get_cells (-quiet => $golden_inst_constr);
        foreach my $inst (@insts) {
            my $value = "$constr{golden}{inst}{$golden_inst_constr}";
            my $ref = get_ref ($inst);
            if (is_end_ref $ref) { #should be flops
                my @outs = get_outputs_of $ref;
                if (is_pin "$inst/$outs[0]") {
                    set_case_analysis ($value,"$inst/$outs[0]");
                    lprint "set case analysis $value on pin $inst/$outs[0]\n";
                }
                
            }
        }
    }
    #set case analysis for revise 
    set_source ($revise_container);
    my @revise_net_constrs = keys %{$constr{revise}{net}};
    foreach my $revise_net_constr (@revise_net_constrs) {
        my @nets = get_nets (-quiet => $revise_net_constr);
        foreach my $net (@nets) {
            my $value = "$constr{revise}{net}{$revise_net_constr}";
            set_case_analysis $value, $net;
            lprint "set case analysis $value on net $net\n";
        }
    }
    my @revise_inst_constrs = keys %{$constr{revise}{inst}};
    foreach my $revise_inst_constr (@revise_inst_constrs) {
        my @insts = get_cells (-quiet => $revise_inst_constr);
        foreach my $inst (@insts) {
            my $value = "$constr{revise}{inst}{$revise_inst_constr}";
             my $ref = get_ref ($inst);
            if (is_end_ref $ref) { #should be flops
                my @outs = get_outputs_of $ref;
                if (is_pin "$inst/$outs[0]") {
                    set_case_analysis ($value,"$inst/$outs[0]");
                    lprint "set case analysis $value on pin $inst/$outs[0]\n";
                }
            }
        }
    }
    $Logic_propagate_case_thru_flops = $save_case_thru_flops;
END

Tsub test_bdd_run_auto => << 'END';
#        system("rm -rf _Inline");
#        system("mkdir _Inline");
#        $ENV{PATH} = "/home/utils/gcc-4.3.2/bin:$ENV{PATH}";
#        load_mpl "/home/nv/bin/mender_utils/load_menderFV.mpl";
     open (IFH, "<eq_confirmed.log") or die "error file not exits\n";
     while (<IFH>) {
         chomp $_;
         my $line = $_;
         my $line_2 = <IFH>;
         chomp $line_2;
         next unless ($line eq $line_2);
 #        set_source syn;
         next if (is_port ($line));
         next unless (is_flop ($line));
         my @pins = get_input_pins ($line);
         foreach my $pin (@pins) {
             if ($pin=~ qr/.*?\/[Dd]$/) {
                 my $fanin_num = get_fanin (-end => $pin);
                 last unless ($fanin_num > 50);
#                 lprint "comparing $pin\n";
                 my $start_time = scalar (localtime);
                 my $rtn = compare_formal (-src1 =>syn, -src2=> gv, -top1=> TS0, -top2=> TS0, -pins => ($pin,$pin));
                 my $end_time = scalar (localtime);
                 $start_time =~ s/^\S+\s+\S+\s+\S+\s+(\S+)\:(\S+)\:(\S+).*$/$1 $2 $3/;
                 $end_time =~ s/^\S+\s+\S+\s+\S+\s+(\S+)\:(\S+)\:(\S+).*$/$1 $2 $3/;
                 my @start_time = split (/ /,$start_time);
                 my @end_time = split (/ /,$end_time);
                 my $cost_time = ($end_time[1] * 60 + $end_time[2]) - ($start_time[1] * 60 + $start_time[2]);
                 lprint "$pin    $fanin_num    $cost_time\n";
                 ($rtn) or lprint "error $pin wrong !\n"; 
             }

         }
     }
    close (IFH);
END

sub set_ld_library_path 
{
    my %tmp_hash = ();

    foreach my $path (split(/\:/, $ENV{LD_LIBRARY_PATH})) {
      $tmp_hash{$path} = 1;
    }
    
    if (! defined $tmp_hash{"/home/nv/bin/mender_utils"}) {
      $ENV{LD_LIBRARY_PATH} = "/home/nv/bin/mender_utils:$ENV{LD_LIBRARY_PATH}";
    }
}

Tsub get_nonunate_loads => << 'END'; 
    ARGS {
       # -plot I don't know why can't initial Mender GUI in a recursive sub.
        $in_pin
        -inst: $inst_flag
    }
#    my $in_pin = shift;
    (is_pin $in_pin or is_net $in_pin or is_port $in_pin or is_cell $in_pin) or error "$in_pin is not pin/net/port/cell\n";
    my @loads = get_loads ( -local =>, $in_pin);
    my @rtn = ();
    (@loads) or return ();
    foreach my $load (@loads) {
        ($load) or next;
        my $inst = get_inst_of_pin ($load);
        my $ref = get_ref ($inst);
        if (!is_unate_ref ($ref)) {
            if ($inst_flag) {
                push (@rtn, $inst);
            } else {
                push (@rtn, $load);
            }
        } else {
            push (@rtn,get_nonunate_loads (-inst => $inst_flag, $inst));
        }
    }

    return @rtn;
END

Tsub plot_nonunate_loads => << 'END';
    ARGS {
        $in_pin
    }
    my @lds = get_nonunate_loads ($in_pin);
    foreach (@lds)  {plot_conns_of $_;}

END

Tsub get_unate_loads => << 'END';
    ARGS {
        -plot
        $in_pin
    }
    my @rtn = get_fan2 (-insts =>, -fanout =>,  -unate =>,  -no_end =>, $in_pin);
    if ($opt_plot) {
        foreach (@rtn) {plot_conns_of $_;}
        return (@rtn);
    } else {
        return (@rtn);
    }
     
END


Tsub shpd_get_nets_hier => << 'END';
    #Full hier from current top to down.
    ARGS {
        -top: $top
        -net: $net
    }
    ($top) or error "Top $top not defined";
    ($net) or error "Net/pin $net not found in $top";
    push_top ($top);
    my @conns = get_conns (-net => -hier => ,$net); 
    if (@conns > 1) {
        warning "The input $net connected to a net through multiple hier";
    }
    my %net_top = (); 
    foreach (@conns) {
        my ($hier, $pin, $ref) = @{$_};
         $net_top{"$ref"} = "${hier}${pin}"; 
#          $net_top{"${hier}${pin}"} = "$ref"; 
#        lprint "${hier}${pin} $ref";
    }
    pop_top ();
    return (%net_top); 
END
#Post-process Mender autofix 
#For the resource-strict design, big buffers for transition fix is a big waste.
#$Eco_place_overlapping{$module}{$inst}
#To evaluate the dly incr from new cells
#To 
Tsub shpd_polish_trans_fix  => << 'END';
    DESC {
        Compares the functionality of two pins.  Compares pins to perform gates-to-gates boolean equivalence.
    }

    ARGS {
        -top: $top
    }
    lprint "undo\n"; 

END

Tsub find_holes_on_route  => << 'END';
    DESC {
        Giving a net with only one load, or the input/ouput pin of a net that has only one load,
        the sub helps to find holes on the route to insert a specified cell 
    }

    ARGS {
        -ref: $buf_ref
        -slide_delta: $slide_delta
        -legal_delta: $legal_delta
        -stop_multi_load
        $obj
    }
    
    ($buf_ref) or error "Incorrect leaf cell type: $buf_ref."; 
    ($obj) or error "Net/pin $obj not found.";
    my $top_save = get_top ();
    my $save_route_delta = $Eco_route_delta;
    my $save_route_slide = $Eco_route_slide;
    $Eco_route_delta = ($legal_delta) ? $legal_delta : ECO_ROUTE_DELTA ;
    $Eco_route_slide = ($slide_delta) ? $slide_delta : ECO_ROUTE_SLIDE ;
    $SPZ_DEBUG and lprint "route_delta $Eco_route_delta, route_slide:$Eco_route_slide\n";
    (is_pin $obj or is_net $obj) or error "Pin/net $obj not found.";
    (is_pin $obj) and ($obj = get_net (-of => $obj)); #Get the net of the input obj.
    my @rtn = ();

    my $top_local = get_top ();
    my $top_root = get_root_parent ();
    push_top ($top_root);
    my @prefixs = get_cells_of ($top_local);
    (@prefixs > 1) and error "Module $top_local instaniated more than once, Please go to $top_root to find holes."; 
    my $top_obj =  (@prefixs) ? "$prefixs[0]/$obj" : "$obj";
    (is_pin $top_obj or is_net $top_obj) or error "Pin/net $top_obj not found.";

    my $top = $top_root;
    %net_top = shpd_get_nets_hier (-top => $top, -net => $top_obj);
    #my $net = $net_top{"$top"}; 
    #(is_net $net) or error "Net $net not found"; 
    my $net = $top_obj; 

    my @net_chain = ();
    my $drv_root = get_driver ($net); #The driver accross all hier.

    #($drv_root) or "Dangling net $net\n";
    ##Trace to the startpt: the highest top leaf driver pin or port:
    ##my @conns_load = get_conns (-loads => -local =>, $drv_root);
    #my ($prefix, $top, $drv_local) = ("", $top_root,$drv_root); 
    #while (1) {
    #    #Connected to a port leads to another hierarchy.
    #    my @conns_load = get_conns (-loads => -local =>, $drv_local);
    #    my $net_drv = get_net (-of => $drv_local); #Must use get_net -of
    #    lprint "step0: $drv_local, $net_drv\n";
    #    unless (@conns_load == 1) {
    #         warning "Floating or multi-loading net $net in $top, Exactly one load required for THIS_SUB";
    #         return ();
    #    }
    #    my $top_pre = get_top (); 
    #    ($prefix, $top, $drv_local) = get_net_context ("$net_drv"); 
    #    lprint "step1 $net_drv,$prefix, $top, $drv_local\n";
    #    ("$top" eq "$top_root") or (push_top ($top));
    #    #my $local_pin = ("$top" eq "$top_root") ? "$prefix/$drv_local" : "$drv_local";
    #    my $net_local = "$drv_local";
    #    
    #    #$net_local = (is_port $conns_load[0][0]) ? "$conns_load[0][0]" : get_net (-of => $conns_load[0][0]); 
    #    #$net_local = (is_port "$local_pin") ? "drv_root$local_pin" : get_net (-of => "$local_pin"); 
    #    unless (get_route_length (-quiet => $net_local)) {
    #        warning "No route for net $net_local in $top, exit"; 
    #        return ();
    #    }
    #    my $route_length = get_route_length ($net_local);
    #
    #    #($net_top{$net_local} eq $top) or error "Fatal error, database mismatch in THIS_SUB.";
    #    push (@net_chain, "$prefix, $net_local, $route_length, $top");
    #    $SPZ_DEBUG and lprint "$net_local $route_length $top\n";
    #    last if (($conns_load[0][1] eq "$top_root") or (is_leaf "$conns_load[0][1]"));
    #    #pop_top ();
    #} #The net should be hooked on a port or a leaf pin at the highest level.

    #pop_top ();
#   # my $first_pin = $obj;
#   # my $ignore_thr = 150;
#   # my $buffer_length = 450;
#   # $Eco_route_delta = 10;
#   # $Eco_route_slide = 50;
#   # my $step = 30;
#   # my @rtn = ();
##  #  my @range = @_;
##  #  ((scalar @range) == 2) or error "range must have 2 elements\n";
#   # unless (is_port $net) {
#   #     lprint "exit $first_pin doesn't connected to a port\n";
#   # return 1;
#   # }
#   # my $route_length = get_route_length ($net);
#   # if ($route_length < $ignore_thr) { 
#   #     lprint "exit $first_pin Should be fixed in the neighbor partition\n";
#   #     return 1;
#   # }
#
    @net_chain = shpd_get_nets_in_order ($drv_root);
    #my @net_chain_r = reverse (@net_chain); #Find from load to drive during the process.
    my @net_chain_r = @net_chain; #Find from driver to load. 
    my $net_index = -1;
    foreach my $net_chain (@net_chain_r) {
        my ($hier, $net, $route_length, $module) = split (/\,\s+/,$net_chain); 
        $SPZ_DEBUG and lprint " In find hole:$hier, $net, $route_length, $module\n";
        $net_index ++;
        set_top ($top_root);
        my ($x_delta,$y_delta) = ($hier) ? get_object_xy ($hier) : (0,0);
        set_top ($module); #At the module of the current #TODO 

        my $loop = 0;
        my $step = 30;
        my $first_pin = (get_loads (-local => $net))[0];
        while (($route_length - $step * $loop) > $step) {
            my $load_dist = $route_length - $step * $loop;
            $SPZ_DEBUG and lprint "loop:$loop, $load_dist\n";
#            is_local_pin ($first_pin) and is_input_pin_name ($first_pin) or error "$first_pin is not a local load pin as required for THIS_SUB -on_route_from_load, top:$module";
            my ($lx, $ly) = get_pin_xy ($first_pin);
            my $legal_load_dist = $load_dist;
            my ($xr, $yr) = map_tran_buf_to_top ($net, $lx, $ly, $legal_load_dist);
            if (defined $Eco_route_delta) {
                my $dir = -1;
                my $factor = 0.25;
                my $near_dist = 1e8;
                my ($xn, $yn, $near_slide);
             #   my $route_len = get_route_length ($net);
                while (1) { 
                    #STOPPED HERE.  Make a real switch and take out this duplicated line
                    my $dist;
                    last if abs ($legal_load_dist - $load_dist) > $Eco_route_slide;
                    if ($legal_load_dist < $route_length and $legal_load_dist > 0) {
                        ($xr, $yr) = map_tran_buf_to_top ($net, $lx, $ly, $legal_load_dist);
                        ($dist, $xr, $yr) = get_legal_dist_for_insert_xy ($xr, $yr, $buf_ref);
                    } elsif ($legal_load_dist > $route_length and $legal_load_dist < 0 or abs (($legal_load_dist - $load_dist)) > $Eco_route_slide) {
                        #last;
                        $SPZ_DEBUG and lprint "stop Oscar here\n";
                        last;
                    }
                    if (defined ($dist)) {
                        if ($dist < $near_dist) {
                            ($xn, $yn) = ($xr, $yr);
                            $near_dist = $dist;
                            $near_slide = $legal_load_dist;
                        }
                        last if $dist <= $Eco_route_delta;
                    }
                    $legal_load_dist += $dir * $factor * $Eco_route_delta;
                    #$dir = -$dir;
                    #$factor += 0.25;
                    $SPZ_DEBUG and lprint "update arges: $dir,  $legal_load_dist,   $factor\n";
                }
                $legal_load_dist = $near_slide;
                if ($near_dist > $Eco_route_delta) {
                    #warning "PLACE_ON_ROUTE:  Failed to find legal location within \$Eco_route_delta ($Eco_route_delta um) along \$Eco_route_slide ($Eco_route_slide um) of route for net $net.  Placing within $near_dist um of route at a distance of $legal_load_dist (request was $load_dist) from load";
                    $SPZ_DEBUG and lprint "legalized too far, next\n";
                    $loop ++;
                    next;  #to next load_dist;
                } else {
    #                lprint "PLACE_ON_ROUTE:  Found legal location within $near_dist um of route for net $net at a distance of $legal_load_dist (request was $load_dist) from load\n";
                    #last;
               # abs ($legal_load_dist - $load_dist) < $Eco_route_slide or warning "Did not find legal location within \$Eco_route_slide (= $Eco_route_slide) um of desired location on route for net $net.  Requested $load_dist.  Found at $legal_load_dist um";
                    if (abs ($legal_load_dist - $load_dist) > $Eco_route_slide) { 
                        $SPZ_DEBUG and lprint "Slided too far, next\n";
                        $loop ++;
                        next; 
                    }
            #        ($xr, $yr) = ($xn, $yn);
                    my @net_chain_left = shpd_get_left_splice ($net_index, @net_chain_r);
                    my @net_chain_right = shpd_get_right_splice ($net_index, @net_chain_r);
                    my $left_length = 0;
                    my $right_length = 0;
                    foreach my $left (@net_chain_left) {
                        my ($hier, $net, $route_length, $module) = split (/\,\s+/,$left); 
                        $left_length += $route_length;
                    }

                    foreach my $right (@net_chain_right) {
                        my ($hier, $net, $route_length, $module) = split (/\,\s+/,$right);
                        $right_length += $route_length;
                    }
                    $left_length += ($route_length - $legal_load_dist);
                    $right_length += $legal_load_dist;
                    push (@rtn, "$module $net $xn,$yn $left_length $right_length");
                    $SPZ_DEBUG and lprint "Get out put: $module $net $xn,$yn $left_length $right_length\n";
                    $loop ++;
                    next ; 
                   # last;
                }
            }
        }
    }
 set_top $top_save;
(scalar @rtn) or return ("exit Can't find hole for $buf_ref $first_pin\n");
@rtn;
#my $lelal_dist = get_dist (get_pin_xy ($first_pin),@rtn);
#lprint "\#$first_pin\n";
#lprint "create_buffer $first_pin $buf_ref -xy @rtn \# $lelal_dist\n";
#lprint "distance: $lelal_dist\n";

END

sub shpd_get_left_splice {
    my $index = shift;
    my @array = @_;
    splice (@array,$index);
    @array;

}

sub shpd_get_right_splice {
    my $index = shift;
    my @array = @_;
    my @t = splice (@array,$index);
    shift @t;
    @t;

}

sub shpd_get_context_obj {
    my $obj = shift;
    my $uper_top = shpd_get_uper_module ($obj);
    my $uper_inst = shpd_get_uper_inst ($obj);
    my $local_drv = shpd_get_local_obj ($obj);
    return ($uper_top,$uper_inst,$local_drv);
}

sub shpd_get_nets_in_order {
    #$obj should be a driver leaf cell pin or a port in the current design.
    my @net_chain = ();
    my $obj = shift;
    my $top_save = get_top ();
    my $TOP_ROOT = get_root_parent (); #TODO: Now, force root top the highest top.
    #set_top ($TOP_ROOT); #Get the path from top level.
    (is_pin $obj or is_net $obj) or error "$obj is not a pin/net in $TOP_ROOT";
    #$obj = get_driver ($obj);
    ((is_pin $obj) and (!(is_net $obj)) and ((get_pin_dir $obj) eq "input")) and error "Pin $obj is not a driving pin";
    #$obj = (is_port $obj) ? $obj: get_net (-of => $obj);
    my @net_txt = shpd_get_context_obj ($obj); 

    while (1) {
        #Connected to a port leads to another hierarchy.
        set_top $net_txt[0];
        (is_pin ($net_txt[2]) or is_net ($net_txt[2])) or error "pin or net $net_txt[2] not found in $net_txt[0]";
        my @conns_load = get_conns (-loads => -local =>, $net_txt[2]);
        #my $net_drv = get_net (-of => $drv_local); #Must use get_net -of
        $SPZ_DEBUG and lprint "step0: $net_txt[0],$net_txt[1],$net_txt[2]\n";
        unless (@conns_load == 1) { #TODO: support stop_at option.
             warning "Floating or multi-loading net $net in $top, Exactly one load required for THIS_SUB";
             return ();
        }
        #my $top_pre = get_top (); 
        #($prefix, $top, $drv_local) = get_net_context ("$net_drv"); 
        #lprint "step1 $net_drv,$prefix, $top, $drv_local\n";
        #("$top" eq "$top_root") or (push_top ($top));
        #my $local_pin = ("$top" eq "$top_root") ? "$prefix/$drv_local" : "$drv_local";
        #my $net_local = "$drv_local";
        
        $net_local = (is_port $conns_load[0][0]) ? "$conns_load[0][0]" : get_net (-of => $conns_load[0][0]); 
        #$net_local = (is_port "$local_pin") ? "$local_pin" : get_net (-of => "$local_pin"); 
        unless (get_route_length (-quiet => $net_local)) {
            warning "No route for net $net_local in $top."; 
            #return ();
        }
        my $route_length = get_route_length (-quiet => $net_local);
        ($route_length) or ($route_length = 0);
        my $top = get_top (); 
        #($net_top{$net_local} eq $top) or error "Fatal error, database mismatch in THIS_SUB.";
        ($route_length) and (push (@net_chain, "$net_txt[1], $net_local, $route_length, $top"));
        $SPZ_DEBUG and lprint "$net_txt[1],$net_local $route_length $top\n";
        if (($conns_load[0][1] eq "$TOP_ROOT") or (is_leaf "$conns_load[0][1]")) {
            last;
        } else {
            set_top ($TOP_ROOT);
            my $drv =  ($net_txt[1]) ? "$net_txt[1]" . "/" . "$conns_load[0][0]" : "$conns_load[0][0]" ;
            $SPZ_DEBUG and lprint "Go on loop:$drv\n";
            (is_pin $drv) or error "Pin $drv not found in $TOP_ROOT\n";
            if ((get_pin_dir $drv) eq "output") {
                @net_txt = shpd_get_context_obj (get_net (-of =>$drv));
            } elsif ((get_pin_dir $drv) eq "input") {
                @net_txt = shpd_get_context_obj ($drv);
            } else {
                error "Found inout pin $drv in $TOP_ROOT\n";
            }
        }
        #pop_top ();
    } #The net should be hooked on a port or a leaf pin at the highest level.
    set_top ($top_save);
    @net_chain;
}

sub shpd_get_uper_module {
    my $rtn = ();
    my $obj = shift;
    my $TOP_ROOT = get_root_parent ();
    (is_pin $obj or is_port $obj or is_cell $obj or is_inst $obj or is_net $obj) or error "$obj is not a inst/cell/pin/port/net \n";
    my @hier = get_hier_list_obj ($HP_TEST,"$obj");
    shift @hier;
    my @hier_rank = (); 
#    my @inst_rank = ();
    push (@hier_rank, map ( ${$_}[0],@hier));
#    push (@inst_rank, map ( ${$_}[1],@hier)); 
    @hier_rank = sort_by_hier_rank (@hier_rank);
    if ($hier_rank[-1] eq "$TOP_ROOT") {
        $rtn = (); 
    } else {
        $rtn = $hier_rank[-1];
    }
    $rtn;
}

sub shpd_get_uper_inst {
    my $rtn;
    my $obj = shift;
    my $TOP_ROOT = get_root_parent ();
    (is_pin $obj or is_port $obj or is_cell $obj or is_inst $obj or is_net $obj) or error "$obj is not a inst/cell/pin/port/net \n";
    my @hier = get_hier_list_obj ($HP_TEST,"$obj");
    shift @hier;
    my @hier_rank = (); 
    my @inst_rank = ();
    push (@hier_rank, map ( ${$_}[0],@hier));
    push (@inst_rank, map ( ${$_}[1],@hier)); 
    @hier_rank = sort_by_hier_rank (@hier_rank);
    my @hier_inst = ();
    
    if ($hier_rank[-1] eq "$TOP_ROOT") {
        $rtn = ""; 
    } else {
        foreach (@hier) {
            last if (${$_}[0] eq "$hier_rank[-1]");
            push (@hier_inst, ${$_}[1]);
        }
        $rtn = join ("/",@hier_inst);
    }
    $rtn;
}

sub shpd_get_local_obj {
#Get the local pin/inst/net name of the giving pin/inst/net
    my $rtn;
    my $obj = shift;
    my $TOP_ROOT = get_root_parent ();
    (is_pin $obj or is_port $obj or is_cell $obj or is_inst $obj or is_net $obj) or error "$obj is not a inst/cell/pin/port/net \n";
    my @hier = get_hier_list_obj ($HP_TEST,"$obj");
    shift @hier;
    my @hier_rank = (); 
    my @inst_rank = ();
    push (@hier_rank, map ( ${$_}[0],@hier));
    push (@inst_rank, map ( ${$_}[1],@hier)); 
    @hier_rank = sort_by_hier_rank (@hier_rank);
    my @hier_inst = ();
    
    if ($hier_rank[-1] eq "$TOP_ROOT") {
        $rtn = "$obj"; 
    } else {
        my @hier_rev = reverse (@hier);
        foreach (@hier_rev) {
            push (@hier_inst, ${$_}[1]);
            last if (${$_}[0] eq "$hier_rank[-1]");
        }
        $rtn = join ("/",(reverse @hier_inst));
    }
    $rtn;
}

#sub shpd_on_route_buffer


Tsub get_lib_unchar => << 'END'; 
    DESC {
        The basic sub to return the uncharacterized cells in specified libs. Array returned.
    }

    ARGS {
        @files
    }
   my @unchar_cells = ();
   (%SPZ_M_libs_name2num) or (all_libs ());
   foreach my $file (@files) {
     chomp $file;
     my $libfile = $file;
     my $corner = get_lib_condition ($libfile); 
     unless ($corner) {
        $DEBUG and lprint "syn or formality lib.\n";
        if ($file =~ /(formality|synth)/) {
            $corner = $1;
        } else {
            error "Unrecognized lib condition: $file";
        }
     }

     open(FHI,"<$libfile") or die("Cant open $libfile");
     $DEBUG and lprint "Checking lib for uncharacterized cells: $libfile\n";
     while(<FHI>) {
      my $line = $_;

#    33   operating_conditions(typ) {
#    34     process     : 1;
#    35     temperature : 105;
#    36     voltage     : 0.81;
#    37     tree_type   : balanced_tree
#    38   }
#
#      my ($corner,$proc,$temp,$volt);
#      if ($line =~ /^\s*operating_conditions\((\S+)\)\s*\{/) {
#        $corner = $1
#        while (<FHI>) {
#            my $line_c = $_;
#            if ($line_c =~ /^\s*process\s*\:\s*(\S*)\;/) {
#               $proc = $1;
#            } elsif ($line_c =~ /^\s*temperature\s*\:(\S*)\;/) {
#               $temp = $1;
#            } elsif ($line_c =~ /^\s*voltage\s*\:(\S*)\;/) {
#               $volt = $1; 
#            }
#        }
#      }

      if ($line =~ m/^\s*\/\*\s+Model:\s+(\S+)\s+\-\s+characterized Source:\s*(\S+)/) { 
         my $cell = $1; 
         my $source = $2; 
         while (<FHI>) {
           my $line_r = $_;
           next unless ($line_r =~ /^\s*nv_char_status\s*\:\s*(\S+)\s*\;/);
           my $source_char = 0;
           my $char_status = $1;
           $char_status =~ s/\"//g;
           last if (($char_status eq "generic-nochar") or ($char_status eq "characterized"));
           exists $Timing_corner_name{$corner}
            or exists $Timing_corner_abbr{$corner}
                and $corner = $Timing_corner_abbr{$corner}
            or (($corner eq 'synth') or ($corner eq 'formality')) 
            or error "Unrecognized timing corner: $corner.  Expected one of:  " . join (" ", keys (%Timing_corner_name));

           my $lib_num = $SPZ_M_libs_name2num{$libfile}; #For performance.
           push (@{$unchar_cells[0]{$cell}{lib}} ,"$char_status $lib_num");
           my $corner_name = (exists $Timing_corner_name{$corner}) ? $Timing_corner_name{$corner}: $corner;
           push (@{$unchar_cells[0]{$cell}{corner}} ,"$corner_name");
           #push  $unchar_cells[0]{$cell}{char_status} .= ",$char_status";
           push (@{$unchar_cells[1]{$corner}}, $cell);

           last;
         }
       }
     }
   }
   $DEBUG and (@unchar_cells) and lprint "un-char cells found in @files\n";
   return (@unchar_cells);

END

Tsub report_lib_unchar => << 'END'; 
    ARGS {
        -corner:@conds
        -all 
        -timing_only 
        -skip:@pattern
    }

    (1 == (@conds + $opt_all + $opt_timing_only)) or error "Only one of the options allowed: -corner, -all, -timing_only";
    my @libs = ();
    #Get the permitted libs:
    all_libs ();
    if ($opt_all) {
        @libs = all_libs (); 
        #@libs = all_libs (); 
    } elsif ($opt_timing_only) {
        @libs = grep ((get_lib_condition ($_)),all_libs ());
    } elsif (@conds) {
        my %corner_name = %Timing_corner_abbr;
        $corner_name{synth} = 'synth';
        $corner_name{formality} = 'formality';
        my @corner_abbr = map ($corner_name{$_},@conds);
        (@corner_abbr < @conds) and error "Unrecognized corner specified, Expect of " . join (" ", values (%corner_name));

        foreach my $file (all_libs ()) {
            my $corner = get_lib_condition ($file);
            unless ($corner) {
               $DEBUG and lprint "Syn or formality lib, need to check the option.\n";
               if ($file =~ /(formality|synth)/) {
                   $corner = $1;
               } else {
                   error "Unrecognized lib condition: $file";
               }
            }
            is_member ($corner, @corner_abbr) and push (@libs,$file);
        }
    } elsif (@pattern) {
        @pattern = map (glob2regex_txt ($_), @pattern);
        my @all_libs = all_libs (); 
        foreach my $lib (@all_libs) {
            if (grep ($lib =~ /$_/,@pattern)) {
                #push (@libs,$lib);
                next;
            }
            push (@libs,$lib);
        }
    }
    #Get the unchared cells:
    my @unchar_cells = get_lib_unchar (@libs);

    #Print:
    foreach my $corner (keys %{$unchar_cells[1]}) {
        my @cells = @{$unchar_cells[1]{$corner}}; 
        #my @unchar = map ("$_\t$unchar_cells[0]{$_}{char_status}\t$unchar_cells[0]{$_}{lib}",@cells);
        $corner = (exists $Timing_corner_name{$corner}) ? ($Timing_corner_name{$corner}) : $corner;
        if (@cells) { 
        lprint "---Start library characterization status check---\n";
        lprint "---Report uncharacterized cells in $corner---\n";
           foreach my $cell (@cells) {
               #my @corners = remove_duplicates (@{$unchar_cells[0]{$cell}{corner}});
               #lprint "$cell  " . join (" ", @corners) . "\n" ;
               lprint "$cell\n";
           }
        } else {
            lprint "---No uncharacterized cells found in $corner---\n";
        }
    }
    
    lprint "---Detail resources for the uncharacterized cells---\n";
    foreach my $cell (keys %{$unchar_cells[0]}) {
        lprint "$cell\n";
        foreach my $lib (@{$unchar_cells[0]{$cell}{lib}}) {
            my ($attr,$lib_num) = split (/\s+/,$lib);
            lprint "\t$attr, $SPZ_M_libs_num2name{$lib_num}\n";
        }
    }

END

Tsub check_gv_status  => << 'END';
    ARGS {
        -top:$module
        -used
    
        -unchar
        -corner:@conds
        -skip:@pattern
        -timing_only
        -all
    }
    (defined $module) and set_top $module;
    my $top = get_top ();
    my @unchar_cells = (); #get_lib_unchar (all_libs());
    my %cells_used = ();
    my @cells_unchar = ();
    if ($opt_unchar) {
        my @libs = ();
        (1 == (@conds + $opt_all + $opt_timing_only)) or error "Only one of the options allowed: -corner, -all, -timing_only";
        #Get the permitted libs:
        if ($opt_all) {
            @libs = all_libs (); 
            $DEBUG and lprint "@libs\n";
        } elsif ($opt_timing_only) {
            @libs = grep ((get_lib_condition ($_)),all_libs ());
            $DEBUG and lprint "@libs\n";
        } elsif (@conds) {
            my %corner_name = %Timing_corner_abbr;
            $corner_name{synth} = 'synth';
            $corner_name{formality} = 'formality';
            my @corner_abbr = map ($corner_name{$_},@conds);
            (@corner_abbr < @conds) and error "Unrecognized corner specified, Expect of " . join (" ", values (%corner_name));

            foreach my $file (all_libs ()) {
                my $corner = get_lib_condition ($file);
                unless ($corner) {
                   $DEBUG and lprint "syn or formality lib, need to check the option.\n";
                   if ($file =~ /(formality|synth)/) {
                       $corner = $1;
                   } else {
                       error "Unrecognized lib condition: $file";
                   }
                }
                is_member ($corner, @corner_abbr) and push (@libs,$file);
            }
            $DEBUG and lprint "@libs\n";
         } 
         if (@pattern) {
             @pattern = map (glob2regex_txt ($_), @pattern);
             my @all_libs = (); 
             foreach my $lib (@libs) {
                 if (grep ($lib =~ /$_/,@pattern)) {
                     #push (@libs,$lib);
                     next;
                 }
                 push (@all_libs,$lib);
             }
             @libs = @all_libs;
        }

        #Get the unchared cells:
        @unchar_cells = get_lib_unchar (@libs);
    }
    foreach my $module (keys %M_ref_nums_src) {
        (is_leaf $module) or next;
#        (is_ram_ref $module) and next;
        #It's a leaf cell
        my $cell_num = get_cells_of ($module);
        if ($opt_unchar) {
            if ((defined $unchar_cells[0]{$module}) and ($cell_num)) {
                push (@cells_unchar, "$module")
            }
        }
        if ($opt_used) {
            #($cell_num) and (push (@cells_used, "$module\t$cell_num"));
            ($cell_num) and $cells_used{$module} = $cell_num;
        }
    }
    if ($opt_unchar) {
        lprint "---Starting characterization status check in $top---\n";
        unless (@cells_unchar) {
            lprint "---No uncharacterized cells found in $top---\n";
        } else {
           # return (table_tab (@cells_unchar));
            foreach my $cell (@cells_unchar) {
                lprint "---Uncharacterized cells found in $top---\n";
                lprint "$cell\n";
                foreach my $lib (@{$unchar_cells[0]{$cell}{lib}}) {
                    my ($attr,$lib_num) = split (/\s+/,$lib);
                    lprint "\t$attr, $SPZ_M_libs_num2name{$lib_num}\n";
                }
            }
        }
    }
    if ($opt_used) {
        lprint "---Start leaf cells statistic in $top---\n";
        my @cells = sort {$cells_used{$b} <=> $cells_used{$a}} (keys %cells_used);
        my $total_cell_num = sum (values %cells_used);
        $DEBUG and lprint "---Total leaf cell num: $total_cell_num\n";
        my %cell_rate = ();
        foreach (@cells) {
            $cell_rate{$_} = sprintf ("%.3f","$cells_used{$_}" / $total_cell_num); 
        }
        my @cells_rtn = map ("$_\t$cells_used{$_}\t$cell_rate{$_}",@cells);
        unshift (@cells_rtn,"CELL\tINST_NUM\tRATIO");
        @cells_rtn_t = table_tab (@cells_rtn);
        splice (@cells_rtn_t,1,0, "-" x length ($cells_rtn_t[0]));
        foreach my $rtn  (@cells_rtn_t) {lprint "$rtn\n"};
    }

END

sub all_libs  {
    my $proj = get_proj_name (); 
    unless (keys %SPZ_M_libs_name2num) {
    lprint "---Finding libs in /home/libs/${proj}_timing\n";
        my @libs = (glob  "/home/libs/${proj}_timing/*/*/syn.A01/*.lib");
        my $index = 0;
        foreach my $lib (@libs) {
            $SPZ_M_libs_name2num{$lib} = $index;
            $SPZ_M_libs_num2name{$index} = $lib;
            $index ++;
        }
    }
    keys (%SPZ_M_libs_name2num);
}

sub get_proj_name {
    my $proj = ();
    my $tot = get_project_home ();
    open (TREE,"$tot/tree.make") or die "Can't open tree.make in shpd_get_proj_name";
    while (<TREE>) {
        my $line = $_;
        if ($line =~ s/export\s+PROJECTS\s+\S+\s+(\S+)\s*$/$1/) {
            $proj = $line;
            last;
        }
    }
    close (TREE);
    return ($proj);
}


#my $proj = get_proj_name ();
#my $top = get_top ();
#my $ipo = get_ipo_num (get_top ());
#my $ipo_re = ($ipo) ? ("ipo${ipo}") : "" ;
#
#open_log "$proj/rep/${top}.${ipo_re}.mender.uncharcheck.txt";
#
#(defined $ENV{SKIP_LIBS}) or  ($ENV{SKIP_LIBS} = "*slow2* *po2th* *hv*slow*");
#my @skip_libs = (defined $ENV{SKIP_LIBS}) ? split (/\s+/,$ENV{SKIP_LIBS}) : () ;
#(defined $ENV{SKIP_LIBS}) and (lprint "Skip checking libs with the pattern: $ENV{SKIP_LIBS}\n");
#my @corners   = (defined $ENV{CORNERS}) ? split (/\s+/,$ENV{CORNERS}) : () ;
#my $do_lib_rpt = (defined $ENV{DO_CHECKLIB}) ? defined $ENV{DO_CHECKLIB} : 0 ; 
#my $do_gv_rpt = (defined $ENV{DO_CHECKGV}) ? defined $ENV{DO_CHECKGV} : 1 ; 
#
#
#if ($do_lib_rpt) {
#    if (defined ($ENV{'ALL_LIBS'}) and ($ENV{'ALL_LIBS'} == 1)) {
#        report_lib_unchar (-all => );
#    } else {
#        report_lib_unchar (-timing_only, -skip => @skip_libs, -corner =>  @corners);
#    }
#}
#
#if ($do_gv_rpt) {
#    if (defined ($ENV{'ALL_LIBS'}) and ($ENV{'ALL_LIBS'} == 1)) {
#        check_gv_status (-top => $top, -unchar =>, -used =>, -all =>);
#    } else {
#        check_gv_status (-top => $top, -unchar =>, -used =>, -timing_only =>, -skip => @skip_libs, -corner => @corners);
#    }
#}
#
#close_log "$proj/rep/${top}.${ipo_re}.mender.uncharcheck.txt";

#/home/scratch.spzhang_gf100/perl_brick/pdelay_stats.mpl
############################################
#  Author: Spirit Zhang (spzhang@nvidia.com)
#  Date:   Mar/05/2010
############################################


#############
#Back Ground
#############

#The real speed of a piece of silicon is measured by the system frequency
#that silicon can run at, but it's not practical to do over large quantities
#so we need a way to estimate the system frequency without putting it in the
#system. Before 40nm we have been relying on speedos which is just a simple
#ring oscillator that is mostly transistor delay. Starting from 40nm we have
#found miscorrelation between speedo numbers and system frequencies so we need
#a better method. That method is called pdelay which is just a collection of
#test patterns that exercise speed-representing paths on testers and see how
#fast they can run without failing. The work needed here is to figure out how
#to find these speed-representing paths to cover enough of the PVT spectrum.
#########################################################

Tsub get_pdly_paths => << 'END'; 
    my $init_time = scalar (localtime);
    lprint "Starting THIS_SUB @_\n($init_time)\n";

###################################################
#Date structure of the path parser:
###################################################
#@Pdelay-> ([
#            \%ppath -> {
#                         {startpt} = "$startpoint";
#                         {endpt} = "$endpoint";
#                         {group} = "$Rep_group";
#                         {period} = "$period";
#                         {launch} = "$launch";
#                         {launch_dly} = start point insertion delay
#                         {capture} = "$capture";
#                         {capture_dly} = end point insertion delay 
#                         {skew} = capture_dly - launch_dly; 
#                         {corner} = "$corner";
#                         {slack} = "$slack";
#                         {edge} = "$l_edge $c_edge";
#                         {uncert} = "$uncert";
#                         {clkinfo} = "$endclk $period";
#                         {is_mcp} = "UNKNOWN";
#                         {is_macro_inside} = 1;
#                         {pdly} = \%pdly -> {
#                                                {net_dly} = total net delay of the path;
#                                                {net_length} = total routing_length;
#                                                {path_dly} = total path dly;
#                                                {cell_cnt} = total cell num on the path;
#                                                {route} -> {
#                                                            M1 = %net_routing_length;
#                                                            M2 = ...;
#                                                            ...
#                                                }
#                                                {cell_dly} -> {
#                                                            HVT = %HVT cells;
#                                                            PO2 = %PO2 cells;
#                                                            ...
#                                                }
#                         }
#            }
#           ],
#
#           [
#            ...
#           ],
#
#)
    DESC {

    }
     ARGS {
         -skip_latches    #Skip paths to latches, enabled by default.
         -skip_macro_inside    #Skip paths to macros, enabled by default.
         -skip_rampins:@rampins_skip    #Skip paths to rampins, SHOLD only by default.
         -skip_mcp    #Skip MCP pths, enabled by default.
         -slack_lesser_than:$slack_thr    #Skip paths with slack lesser than the threshold, 10000 by default.
         -fanin_lesser_than:$fanin_thr    #Skip paths to a high-fanin end points, threshold 500 by default.
         -only_clocks:@only_clocks    #Only care these clock domains, wildchard supported.
         -skip_clocks:@skip_clocks    #Skip these clock domains, wildchard supported.
         -wire_length_thr:$wire_length_thr #Skip paths with total net length lesser than the threshold in distr stats, 500 by default.
         -gate_num_thr:$gate_num_thr #Skip paths with gates number lesser than the threshold, 0 by default.
         -delay_ratio:$dly_ratio     #Skip paths with (wire delay) / (path delay) lesser than the ratio. unknown by default.
         -wire_vector:$vector_wire #The wire selection vector in hash ref,eg. -wire_vector {M2 => 60, M4 => 80}
         -cell_vector:$vector_cell #The cell selection vector in hash ref.
         -dump_code:$datecode    #The datecode to name the output file.
         -dump_raw  #Dump the raw data. disabled by default
         -dump_distr    #Dump the distributions for each clock, disabled by default
         -dump_sel    #Dump the selected paths, disabled by default

         -reps:@Reps
         -no_perc  #Print the table in percentage instead of path number.
#         -force_parse #Force to re-parse the reports.
     }

   #input: the timing report

   #Define constants:

   ##Define the considered cell type, curently, 4 of them:
   my @SEL_REFS = qw (HVT PO2 SVT LVT);

   #Define the Ram skip pins list:
   my @ram_skip = qw (SHOLD);

   #define the wire/cell ruler:
   my @ruler_cell = qw(0 5 10 20 30 40 50 60 70 80 90 100);
   #my @ruler_cell = qw  (0       5       10       40       50       60       100);
   my @ruler_wire = qw(0 5 10 20 30 40 50 60 70 80 90 100);
   #my @ruler_wire = qw  (0       5       10       40       50       60       100);
   


   (scalar  @PDLY_REFS)              or (@PDLY_REFS                  = @SEL_REFS);
   (defined $opt_skip_latches)       or ($opt_skip_latches           = 1);
   (defined $opt_skip_mcp)           or ($opt_skip_mcp               = 1);
   (defined $opt_skip_macro_inside)  or ($opt_skip_macro_inside      = 1);
   (scalar  @rampins_skip)           or (@rampins_skip               = @ram_skip); #Only SHOLD pins skipped now*******
   (defined $slack_thr)              or ($slack_thr                  = 10000);
   (defined $fanin_thr)              or ($fanin_thr                  = 500);
   (scalar  @only_clocks)            or (@only_clocks                = ());
   (scalar  @skip_clocks)            or (@skip_clocks                = ());
   (defined $wire_length_thr)        or ($wire_length_thr            = 500);
   (defined $gate_num_thr)           or ($gate_num_thr               = 0);
   (defined $dly_ratio)              or ($dly_ratio                  = "UNKNOWN");
   (defined $vector_wire)            or (grep (${$vector_wire}{$_}   = 127, (values %METAL_LAYERS))); #Init with -1 to disable the selector by default.
   (defined $vector_cell)            or (grep (${$vector_cell}{$_}   = 127, (@PDLY_REFS)));
   (defined $datecode)               or ($datecode                   = "default");
   (@Reps)                           or error "reports must be specified -reps";


   my $PdlyRef = sp_path_parser (
#Comment the filters since they're selected in the wrapper.
#                                  -slack_lesser_than => $slack_thr, 
#                                  -skip_clocks => @skip_clocks, 
#                                  -only_clocks => @only_clocks,
#                                  -wire_length_thr => $wire_length_thr, 
#                                  -gate_num_thr=> $gate_num_thr,
#                                  -delay_ratio => $dly_ratio,
                                  -reps => @Reps,
                                  -dump_code => $datecode
                                );
   my %filtered = ();
   my %clkinfo = ();
   my %coll_groups = ();
   my @Pdly_selected = ();

   my %cnt_var = (
      cnt_total_paths    => 0,
      cnt_parsed_paths   => 0,

#      cnt_min_skip       => 0, Already skipped in the parser.
#      cnt_input_skip     => 0, Already skipped in the parser.
#      cnt_output_skip    => 0, Already skipped in the parser.
#      cnt_maxdly_skip    => 0, Already skipped in the parser.
      cnt_slack_skip     => 0,
      cnt_group_skip     => 0,
      cnt_wire_skip      => 0,
      cnt_gate_skip      => 0,
      cnt_ratio_skip     => 0,
      cnt_latch_skip     => 0,
      cnt_macro_skip     => 0,
      cnt_rampin_skip    => 0,
      cnt_mcp_skip       => 0,
      cnt_filtered_paths => 0,
   );


   my $cnt_latch_skip = 0;
   my $cnt_macro_skip = 0;
   my $cnt_slack_skip = 0;
   my $cnt_rampin_skip = 0;
   my $cnt_mcp_skip = 0;
   my $cnt_filtered_paths = 0;
   #Parse the clock info to decide MCPs, and BTW, skip macro inside paths, etc.:
   #Idea to get MCPs:
    #1. Get all of the capture time of the same edge triggered paths and remove the duplicated elemes. The basic period should be in the list, without half-cycle path period.
    #2. To see if any of the clock required time (capture - launch) is multiple times of any elems in the list above.
    #3. If so, MCP got.

    #print Dumper ($PdlyRef);

    foreach my $pref (@{$PdlyRef}) {
        my ($clk,$per) = split (/\s+/,"${$pref}{clkinfo}");
        ($per > 0) or error "Wrong clock cycle $clk:$per";
        my ($l_edge, $c_edge) = split (/\s+/,${$pref}{edge});
        ($l_edge eq $c_edge) or next;  #Basic period and MCP paths shouldn't be checked at different edge, avoid half-cycle path.
        #Cycles in typ was 30% cut off, so the basic period could be more than 1.
        #if (!scalar (@{$clkinfo{$clk}})) {
        unless (grep (($per eq $_), @{$clkinfo{$clk}})) {
            push (@{$clkinfo{$clk}},$per);

        }
    }

    foreach my $clk (keys %clkinfo) {
        my @ps = sort {$a<=>$b} (@{$clkinfo{$clk}});
        foreach my $p (@ps) {
            unless (scalar (grep (((is_integer $_) && ($_ > 1)),map ($p/$_,@ps)))) {
                push (@{$clkinfo{baseperi}{$clk}},$p);
            }
        }
    }

    foreach my $pref (@{$PdlyRef}) {
        my ($clk,$per) = split (/\s+/,"${$pref}{clkinfo}");
        #if (scalar (grep ((is_integer $_ && $_ > 1),map ($_/$per,@{$clkinfo{$clk}})))) { #If it can devide any of the elems
        $per = "${$pref}{capture}" - "${$pref}{launch}";
        ($per > 0) or error "Get clock timing range $per";
        if (scalar (grep (((is_integer $_) && ($_ > 1)),map ($per/$_,@{$clkinfo{baseperi}{$clk}})))) { #If it can devide any of the elems
            ${$pref}{is_mcp} = 1;
            lprint "Found mcp from ${$pref}{startpt} to ${$pref}{endpt}, period:$per,@{$clkinfo{baseperi}{$clk}}\n";
        }
    #    } elsif (scalar (grep ((is_integer $_ && $_ > 1),map ($per/$_,@{$clkinfo{$clk}})))) { #If it can be devided by  any of the elems
    #        ${$pref}{is_mcp} = 1;
    #        lprint "Found mcp from ${$pref}{startpt} to ${$pref}{endpt}, period:$per,@{$clkinfo{$clk}}\n";
    #    } elsif ((grep ((1 == $_),map ($per/$_,@{$clkinfo{$clk}})))) {
    #        #push (@{$clkinfo{$clk}},$per);
    #        #(@{$clkinfo{$clk}} > 2) and warning "Please double check, more than 2 periods for $clk @{$clkinfo{$clk}} found";
    #    } else {
    #        push (@{$clkinfo{$clk}},$per);
    #        (@{$clkinfo{$clk}} > 2) and warning "Please double check, more than 2 periods for $clk @{$clkinfo{$clk}} found";

    #    }
    }
    my %sel_wire_msg = ();
    my %sel_cell_msg = ();
    $sel_wire_msg{head} = "Startpoint Endpoint " . join (" ",@PDLY_REFS) . " " . join (" ", sort (values %METAL_LAYERS)) . "\n";
    $sel_cell_msg{head} = $sel_wire_msg{head};


    #The loop to filter the paths:
    foreach my $pref (@{$PdlyRef}) {

        $cnt_var{cnt_total_paths} ++ ;

#        if ($wire_length_thr > ${$pref}{pdly}{net_length}) {
#            lprint "Skip path to ${$pref}{endpt} without enough wire length $wire_length_thr\n";
#            $cnt_var{cnt_wire_skip} ++;
#            next;
#        }
        if ($gate_num_thr > ${$pref}{pdly}{cell_cnt}) {
            lprint "Skip path to ${$pref}{endpt} without enough gate number $gate_num_thr\n";
            $cnt_var{cnt_gate_skip} ++; 
            next;
        }
#        if (($dly_ratio ne 'UNKNOWN') && ($dly_ratio >  "${$pref}{pdly}{net_dly}" / "${$pref}{pdly}{path_dly}")) {
#            lprint "Skip path to ${$pref}{endpt} without enough wire delay ratio\n";
#            $cnt_var{cnt_ratio_skip} ++ ;
#            next;
#        }
        if ($opt_skip_latches) {
             my ($inst,$module,$pin) = get_pin_context (${$pref}{endpt});
             (is_latch_ref $module) and (lprint "Skip path to latch:${$pref}{endpt}\n") and ($cnt_var{cnt_latch_skip} ++) and next;
        }
        if ($opt_skip_mcp) {
            (1 == ${$pref}{is_mcp}) and (lprint "Skip mcp path to ${$pref}{endpt}\n") and ($cnt_var{cnt_mcp_skip} ++) and next;
        }
        if ($opt_skip_macro_inside) {
            (1 == ${$pref}{is_macro_inside}) and (lprint "Skip paths to ${$pref}{endpt} inside macro\n") and ($cnt_var{cnt_macro_skip} ++) and next;
        }
        if (defined $slack_thr) {
            ($slack_thr < ${$pref}{slack}) and (lprint "Skip paths to ${$pref}{endpt} over the slack threshold\n") and ($cnt_var{cnt_slack_skip} ++) and next;
        }
        if (scalar @rampins_skip) {
            my ($inst,$ref,$pin) = get_pin_context ("${$pref}{endpt}");
            if (is_ram_ref $ref ) {
                 if (grep (${$pref}{endpt} =~ /$_$/, @rampins_skip)) {
                    lprint "Skip paths to ${$pref}{endpt} in rampin skip list\n";
                    $cnt_var{cnt_rampin_skip} ++;
                    next;
                }
            }
        }
        if (scalar @only_clocks) {
          unless (grep ((${$pref}{group} =~ /$_/), @only_clocks)) {
              $cnt_var{cnt_group_skip} ++ ;
              next;
          }
        }
        if (scalar @skip_clocks) {
          if (grep ((${$pref}{group} =~ /$_/), @skip_clocks)) {
             $cnt_var{cnt_group_skip} ++ ;
             next;
          }
        }

        #Startting to handle the collected database:
        $cnt_var{cnt_filtered_paths} ++;
        $cnt_var{cnt_parsed_paths} ++ ;
        $coll_groups{all}{"${$pref}{group}"} ++;
        my $asserted_wire = 0;
        foreach my $layer (keys %{${$pref}{pdly}{route}}) {
            (${$pref}{pdly}{net_length} < $wire_length_thr) and ($cnt_var{cnt_wire_skip} ++) and last;
            ($dly_ratio ne 'UNKNOWN') && ($dly_ratio >  "${$pref}{pdly}{net_dly}" / "${$pref}{pdly}{path_dly}") and ($cnt_var{cnt_ratio_skip} ++) and last;
            my $ruler_elem = distr_calc (${$pref}{pdly}{route}{$layer},\@ruler_wire); 
            $filtered{"${$pref}{group}"}{wire}{$layer}{$ruler_elem} ++;
            $asserted_wire = 1;
        }
        ($asserted_wire) and ($coll_groups{wire}{"${$pref}{group}"} ++);
        $asserted_cell = 0;
        foreach my $attr (keys %{${$pref}{pdly}{cell_dly}}) {
#            next if (${$pref}{pdly}{cell_dly}{$attr} < 0.1);
            my $ruler_elem = distr_calc (${$pref}{pdly}{cell_dly}{$attr},\@ruler_cell); 
            $filtered{"${$pref}{group}"}{cell}{$attr}{$ruler_elem} ++;
            $asserted_cell = 1;
        #    $coll_groups{cell}{"${$pref}{group}"} ++;
        }
        
       ($asserted_cell) and ($coll_groups{cell}{"${$pref}{group}"} ++);
        #Select paths:

       ($opt_dump_raw) and (push (@Pdly_selected, $pref));

       my @sel_wire_items = vector_sel (${$pref}{pdly}{route}, $vector_wire); 
       my @sel_cell_items = vector_sel (${$pref}{pdly}{cell_dly}, $vector_cell); 

       my @path_info = ();
       push (@path_info,${$pref}{startpt},${$pref}{endpt});
       push (@path_info, map (${$pref}{pdly}{cell_dly}{$_},@PDLY_REFS)); 
       push (@path_info, map (${$pref}{pdly}{route}{$_},sort (values %METAL_LAYERS))); 

       foreach (@sel_wire_items) {
          $sel_wire_msg{${$pref}{group}}{$_} .= join (" ",@path_info) . "\n"; 
       }
    
       foreach (@sel_cell_items) {
            $sel_cell_msg{${$pref}{group}}{$_} .= join (" ",@path_info) . "\n";
       }
    }

   foreach (sort (keys %cnt_var)) {
       my $fout = sprintf "%10d", $cnt_var{$_};
       my $fitem = sprintf "%-18s",$_;
       lprint "$fitem: $fout\n";
   }

  #(defined $fanin_thr) and (lprint "Collected paths: $cnt_filtered_paths ++\n");

  lprint "\nTotal filtered paths: $cnt_var{cnt_filtered_paths}\n";
    
    DUMP_TABLE:{
        ($opt_dump_distr) or (lprint "Skip dumping distribution table.\n") and (goto DUMP_SEL);
        open (FD, "> ./pdly_distr.wire${wire_length_thr}.${datecode}.txt") or error "Can't open file to write";
        lprint "Wire distribution stats:\n\n";
        print FD "Wire distribution stats:\n\n";
        foreach my $clk (sort (keys %filtered)) {
            
            my $total_path_num = (defined $opt_no_perc) ? 0 : "$coll_groups{wire}{$clk}";
            my @wire_out = bidia_format ($filtered{$clk}{wire}, $total_path_num, \@ruler_wire);
            #my @wire_out = bidia_format ($filtered{$clk}{wire}, 1, \@ruler_wire);
            lprint "$clk (collected paths:$coll_groups{wire}{$clk}):\n";
            print FD "$clk (collected paths:$coll_groups{wire}{$clk}):\n";
            foreach (@wire_out) {lprint "$_\n";}
            lprint "\n";
            print FD join("\n",@wire_out) ;
            print FD "\n"; 
        }

        print FD "Cell distribution stats:\n\n";
        lprint "Gate delay stats:\n\n";
        foreach my $clk (sort (keys %filtered)) {
            my $total_path_num = (defined $opt_no_perc) ? 0 : "$coll_groups{cell}{$clk}";
            my @cell_out = bidia_format ($filtered{$clk}{cell}, $total_path_num, \@ruler_cell);
            lprint "$clk (collected paths:$coll_groups{cell}{$clk}):\n";
            print FD "$clk (collected paths:$coll_groups{cell}{$clk}):\n";
            foreach (@cell_out) {lprint "$_\n";}
            lprint "\n";
            print FD join("\n",@cell_out) ;
            print FD "\n"; 
        }
        close (FD);
        my $end_time = scalar (localtime);
    }
    #foreach (@sel_wire_items) {
    DUMP_SEL:{
        ($opt_dump_sel) or (lprint "Skip dumping selected paths.\n") and (goto DUMP_RAW);
        lprint "==========The selected paths==========\n";
        foreach (values %METAL_LAYERS) {
            foreach my $clk  (keys %{$coll_groups{wire}}) {
            ($sel_wire_msg{$clk}{$_}) or next;
            my $fout = "./pdly_sel_wire.${clk}.${_}.${$vector_wire}{$_}.${datecode}.txt";
            open (FO,">$fout") or error "Can't open file $fout to write";
            print FO "$sel_wire_msg{head}";
            print FO "$sel_wire_msg{$clk}{$_}";
            close FO;
            }
        }
        foreach ( @PDLY_REFS) {
            #foreach my $clk  (keys %coll_groups) {
            foreach my $clk  (keys %{$coll_groups{cell}}) {
            ($sel_cell_msg{$clk}{$_}) or next;
            my $fout = "./pdly_sel_gate.${clk}.${_}.${$vector_cell}{$_}.${datecode}.txt";
            open (FO,">$fout") or error "Can't open file $fout to write";
            print FO "$sel_cell_msg{head}";
            print FO "$sel_cell_msg{$clk}{$_}";
            close FO;
            }
        }
    }
    #return (\@Pdly_selected);
    #write the paths selected: 
   # foreach my $clk (keys %coll_groups) {
    DUMP_RAW:{
        ($opt_dump_raw) or (lprint "Skip dumping raw datSkip dumping raw dataa\n") and (return 1) ;
        foreach my $clk  (keys %{$coll_groups{all}}) {
            lprint "P-delay raw data dumping for $clk\n";
            my $fout = "./pdly_raw.${clk}.${datecode}.txt";
            open (FO, ">$fout");
            print FO "$sel_cell_msg{head}";
            foreach my $pref (@Pdly_selected) {
                (${$pref}{group} eq $clk) or next;
                my @path_info = ();
                push (@path_info,${$pref}{startpt},${$pref}{endpt});
                push (@path_info, map (${$pref}{pdly}{cell_dly}{$_},@PDLY_REFS));
                push (@path_info, map (${$pref}{pdly}{route}{$_},sort (values %METAL_LAYERS)));
                print FO join (" ",@path_info) . "\n";
        

            }
            close (FO);
        }
    }
    lprint "THIS_SUB started at:\n($init_time)\n";
    lprint "Ened at            :\n($end_time)\n";


END

Tsub sp_path_parser => << 'END'; 
    ARGS {
        -slack_lesser_than:$slack_thr
        -fanin_lesser_than:$fanin_thr
        -only_clocks:@only_clocks  #wildchard surported.
        -skip_clocks:@skip_clocks
        -wire_length_thr:$wire_length_thr #paths whose nets shorter than will be ignored in the parser.
        -gate_num_thr:$gate_num_thr #paths whose gates number lesser than will be ignored in the parse.
        -delay_ratio:$dly_ratio #(wire delay) / (path delay)
        -dump_code:$datecode

        -reps:@Reps
    }

#input: the timing report
  
  (defined $slack_thr)              or ($slack_thr              = 100);
  (defined $opt_fanin_lesser_than)  or ($opt_fanin_lesser_than  = 500);
  (scalar  @only_clocks)            or (@only_clocks            = ());
  (scalar  @skip_clocks)            or (@skip_clocks            = ());
  (defined $wire_length_thr)        or ($wire_length_thr        = 0);
  (defined $gate_num_thr)           or ($gate_num_thr           = 0);
  (defined $dly_ratio)              or ($dly_ratio              = "UNKNOWN");
  (defined $datecode)               or ($datecode               = "");
  (@Reps)                           or error "reports not defined";
  
  if (@{$RAWDATA}) {
      lprint "Using the raw data exists in the session\n"; 
      return ($RAWDATA); 
  }
  my %input_reps = array2hash (@Reps);
  my $dumped_source = "./mender_path_parser.${datecode}.mpl";
  if (-e "$dumped_source") {
        lprint "Loading the datebase from $dumped_source ... \n";
        load_mpl ($dumped_source);
        %input_reps = array2hash (@Reps);
        my %dumped_reps = sp_dumped_reps ();
        print_hash (%input_reps);
        print_hash (%dumped_reps);
        unless ((grep ((1 != $input_reps{$_}) ,(keys %dumped_reps))) or (grep ((1 != $dumped_reps{$_}) ,(keys %input_reps)))) {
            lprint "Using the previously dumped data from " . join (", ", (keys %dumped_reps));
            lprint "\n";
            $RAWDATA = sp_dumped_data ();
            return ($RAWDATA);
        }

   }
   my $init_time = scalar (localtime);
   lprint "Starting THIS_SUB @_\n($init_time)\n";
   lprint "Parsing reports: @Reps\n";



  (@only_clocks) and (@only_clocks = map (glob2regex_txt ($_), @only_clocks));
  (@skip_clocks) and (@skip_clocks = map (glob2regex_txt ($_), @skip_clocks));
  my @viol_files    = @Reps;
  my @Pdelay      = ();
  my $viol_file     = ();
  @viol_files or print "ERROR: no viol files feed for gate_stats!\n ";
  $SIG{PIPE} = sub {};
  my ($startpoint,$endpoint,$Rep_group,$Rep_type,$end_path,$startclk,$endclk,$l_edge,$c_edge,$launch,$capture,$period,$uncert,$clock_skew,$slack,$start_clock_delay,$end_clock_delay,%ppath,%pdly,$is_mcp,$is_macro_inside);

  foreach $viol_file (@viol_files) {

    my %cnt_vars = (
      cnt_total_paths    => 0,
      cnt_parsed_paths   => 0,
      cnt_min_skip       => 0,
      cnt_input_skip     => 0,
      cnt_output_skip    => 0,
      cnt_maxdly_skip    => 0,
      cnt_slack_skip     => 0,
      cnt_group_skip     => 0,
      cnt_wire_skip      => 0,
      cnt_gate_skip      => 0,
      cnt_ratio_skip     => 0,
    );

    print "File $viol_file not found\n" and next  unless (-e $viol_file);
    if ($viol_file =~ /\.gz$/) {
        open (VIOL, "gunzip -c   $viol_file |") or print "ERROR input $viol_file not found";
    }
    else {
        open (VIOL, $viol_file) or print " ERROR input $viol_file not found";
    }
    my $base = $viol_file;
    $base =~ s/^.*\///;
    my $corner = (get_timing_corner_from_report_file (-quiet => $viol_file)) ? get_timing_corner_from_report_file (-quiet => $viol_file): $base;
    #my $base = $viol_file;

    my $get_path = 0;
    LINE:while (<VIOL>) {

      if (/^\s*Startpoint:\s+(\S+)/) {
 #         mty ($startpoint,$endpoint,$rep_group,$rep_type,$end_path,$startclk,$endclk,$clock_skew,$slack,$start_clock_delay,$end_clock_delay);
          #Reset varaibles when come to a new path:
          $cnt_vars{cnt_total_paths} ++;
          $get_path = 1;
          %ppath = ();
          %pdly = ();
          $pdly{net_dly} = 0;
          map ($pdly{route}{$_} = 0, (values %METAL_LAYERS));
          $pdly{net_length} = 0;
          map ($pdly{cell_dly}{$_} = 0, @PDLY_REFS);
          $pdly{cell_cnt} = 0;
          $pdly{path_dly} = 0;
          $startpoint = $1;
          $endpoint = "";
          $Rep_group = "";
          $Rep_type = "";
          $startclk = "UNKNOWN";
          $endclk = "UNKNOWN";
          $uncert = 0;
          $launch = 10000;
          $start_clock_delay = 0;
          $capture = 10000;
          $end_clock_delay = 0;
          $period = 0;
          $clock_skew = 0;
          $l_edge = "UNKNOWN";
          $c_edge = "UNKNOWN";
          $is_macro_inside = 1 ;#"UNKNOWN";
          if (/clocked by\s+(\w+)/ #GT-style
              or /(?:clocked by\s+|clock\s+|clock source\s+\')(\w+)\S*\)/ #PT unwrapped style
              or /\(/ #PT input port
          ) { 
              $startclk = $1;
          } 
          else {
              $_ = <VIOL>;
              if (/(?:clocked by\s+|clock\s+|clock source\s+\')(\w+)\S*\)/) {
                  $startclk = $1; #PT-style
              } else {
                  #Probably a port.  Redo and processs endpt
                  redo;
              }
          }
          next;
      }
      ($get_path) or next;
      if (/^\s*Endpoint:\s+(\S+)/) {
          $endpoint = $1;
          if (/clocked by\s+(\w+)/ #GT-style
              or /(?:clocked by\s+|clock\s+|clock source\s+\')(\w+)\S*\)/ #PT unwrapped style
              or /\(/ #PT output port
          ) { 
              $endclk = $1;
          }
          else {
              $_ = <VIOL>;
              if (/(?:clocked by\s+|clock\s+|clock source\s+\')(\w+)\S*\)/) {
                  $endclk = $1; #PT-style
              } else {
                  #Probably a port 
                  redo;
              }
          }

          next;
      } #get the start point and end point 
      if ("UNKNOWN" eq $startclk or "UNKNOWN" eq $endclk) {
           next;
      }
      if (/^\s*Path Group\:\s+(\S+)/) {
          $Rep_group = $1;
          #lprint "dly_stat is $pdly\n";
          #(defined $pdly) and ($get_path = 0) and (goto LINE); #Skip double count for the same path.
          if (scalar @only_clocks) {
            unless (grep (($Rep_group =~ /$_/), @only_clocks)) {
                $get_path = 0; 
                $cnt_vars{cnt_group_skip} ++ ;
#                lprint "Skip $Rep_group\n";
            }
            
          }

          if (scalar @skip_clocks) {
            if (grep (($Rep_group =~ /$_/), @skip_clocks)) {$get_path = 0; $cnt_vars{cnt_group_skip} ++ ;};
          }
          next;
      }
      if (/^\s*Path Type\:\s+(\S+)/) {
          $Rep_type = $1;
          next;
      }
      if ("min" eq $Rep_type) { #We only care max path here for P-delay stats.
          $get_path = 0;
          lprint "Ignore min path to $endpoint\n";
          $cnt_vars{cnt_min_skip} ++;
          next;
      }
      if (/^\s*Point  /) {
          $startpoint or error "Path  without startpoint defined in report $viol_file\n";
          $endpoint or error "Path  without endpoint defined in report $viol_file\n";
          $Rep_group or error "Path  without group defined in report $viol_file\n";
          $Rep_type or error "Path  without type defined in report $viol_file\n";
          next;
      }

      #In path
      if (/^\s*clock (\S+) \((\S+) edge\).*\s+(\S+)\s+\S+$/) {
          my $name; $name = $1;
          ($l_edge,$launch) = ($2,$3);
          ($l_edge eq 'fall' or $l_edge eq 'rise') or error "unknown edge $l_edge in $startpoint";
          ($name eq "$startclk") or warning "Mismatch capture clock name $name and $startclk";
          #($launch == 0) and error "Launch time of $startclk is 0";
          next;
      }
      if(/^\s+clock (network|tree) delay \((propagated|ideal)\)\s+(\S+)\s+/ or /^\s+clock source (latency)(\s+)(\S+)/) {
          $start_clock_delay = $3;
          ($start_clock_delay > 0) or error "Non positive start clock insertion delay found to $endpoint";
          my $startpoint_bak = $startpoint;
          $startpoint =~ s/\[/\\[/g;
          $startpoint =~ s/\]/\\]/g;
          my $endpoint_bak = $endpoint;
          $endpoint =~ s/\[/\\[/g;
          $endpoint =~ s/\]/\\]/g;
          #Ignore paths leading to latch;
          my $last_line;
          while  (<VIOL>) {
            my $line = $_;
            if ($line =~ qr/$startpoint(.*?)\s+\((\S+)\)\s+/) {
              if ($2 eq "in") {
                $cnt_vars{cnt_input_skip} ++;
                $get_path = 0; 
                lprint "Path from input port:$startpoint ignored\n";
                goto LINE;
              }
              $startpoint = "$startpoint_bak" . "$1";
            } 

            if ($line =~ /\s*(\S+)\s\((\S+)\)\s+(\S+)\s+(\S+)\s[&*]\s+(\S+)\s[rf]/) {
                my $pin = $1;
                my $ref = $2;
                my $delay = $4;
                (is_pin $pin) or next;
                (is_leaf $ref) or next; #It maybe a cross hier path.
                my $ref_attr = sp_get_ref_attr ($ref);
                my $pin_dir = get_pin_dir ($pin);

                if ('input' eq $pin_dir) {
                    $pdly{net_dly} += $delay;
                    my $net = get_net (-of => $pin);
                    my $wire_route_info = sp_wire_stats ($net); 
                    my $route_length = get_route_length ($net);

                    $pdly{net_length} += $route_length;
                    foreach my $layer (keys %{$wire_route_info}) {
                        $pdly{route}{$layer} += ${$wire_route_info}{$layer}{layer};
                    }

                } elsif ('output' eq $pin_dir) {
                    $pdly{cell_dly}{$ref_attr} += $delay;
                    $pdly{cell_cnt} ++;

                } else {
                    error "Inout pin $pin found in the timing path from $startpoint";
                }

                my ($uper_module) = sp_get_uper_module ($pin);
                (is_macro_module $uper_module) or ($is_macro_inside = 0);
                
                $pdly{path_dly} += $delay; 
             }
                #if ($pin =~ qr/$endpoint(.*?)/) {
             if ($line =~ /^\s*data arrival time/) {
                 #lprint "match endpoint times $pin\n";
                 my $ref = "";
                 if ($last_line =~ /^\s*(\S+)\s*\((\S+)\)/) {
                     $endpoint = $1;
                     #(is_pin $endpoint) or error "wrong pin got: $last_line $endpoint";
                     my $ref = $2; 
                 } else {error "Endpoint parsed unproper!"};

                 if ($ref eq "out"){
                     $cnt_vars{cnt_output_skip} ++;
                     $get_path = 0; 
                     lprint "Path leading to output port:$endpoint ignored\n"; 
                     goto LINE;
                 }
                 #Skip short wire path:
                 if ((defined $wire_length_thr) && ($pdly{net_length} < $wire_length_thr)) {
                    $cnt_vars{cnt_wire_skip} ++ ;
                    $get_path = 0; 
                    lprint "Path to $endpoint with wire length $pdly{net_length} \< threshold:$wire_length_thr, ignored\n"; 
                    goto LINE;
                 }
                 #Skip few gate num path:
                 if ((defined $gate_num_thr) && ($pdly{cell_cnt} < $gate_num_thr)) {

                     $cnt_vars{cnt_gate_skip} ++ ;
                     $get_path = 0;
                     lprint "Path to $endpoint with gate num $pdly{cell_cnt} \< threshold:$gate_num_thr, ignored\n";
                     goto LINE;
                 }
                 #Skip path without enough net delay ratio.
                 if (($dly_ratio ne 'UNKNOWN') && ($dly_ratio >  "$pdly{net_dly}" / "$pdly{path_dly}")) {
                   $cnt_vars{cnt_ratio_skip} ++ ;
                   $get_path = 0;
                   lprint "Path to $endpoint with wire delay ratio $pdly{net_dly} : $pdly{path_dly} \< threshold:$dly_ratio, ignored\n";
                   goto LINE;

                 }

                 foreach my $layer (keys %{$pdly{route}}) {
                     $pdly{route}{$layer} = sprintf  ("%.2f" ,100 * ("$pdly{route}{$layer}" /  "$pdly{net_length}"));
                 }
                 foreach my $attr (keys %{$pdly{cell_dly}}) {
                     $pdly{cell_dly}{$attr} = sprintf  ("%.2f" ,100 * ("$pdly{cell_dly}{$attr}" /  "$pdly{path_dly}"));
                 }

                 #%{$dly_stats{$corner}{$Rep_group}{$pin}} = %pdly;
                 
                 #undef $pdly;
                 #Updae the endpoint.
                 #$endpoint = $pin;
                 last;
             }
            # }
             $last_line = $line;
          }
          # clock gpcclk (rise edge)               1.472      1.472

          #^\s*clock (\S+) \((\S+) edge\).*\s+(\S+)\s+\S+$
          while (<VIOL>) {
              my $line = $_;
              if ($line =~ /^\s*clock (\S+) \((\S+) edge\).*\s+(\S+)\s+\S+$/) {
                my $name = ();
                ($name, $c_edge, $capture) = ($1, $2, $3);
                ($c_edge eq 'fall' or $c_edge eq 'rise') or error "unknown edge $c_edge in $endpoint"; 
                ($name eq "$endclk") or warning "Mismatch capture clock name $name and $endclk";
                ($capture == 0) and error "Capture time of $endclk is 0";
               # $period = $capture - $launch;
                $period = $capture;
                ($period > 0) or error "Wrong period calculated for $endclk:period $period $capture $launch $endpoint $startpoint";
                last;
              }

             if ($line =~ /^\s*max_delay\s+\S+\s+\S+/) {
                lprint "Ingnore paths constraint by max_delay\n";
                $cnt_vars{cnt_maxdly_skip} ++;
                $get_path = 0;
                goto LINE;
             } #Ignore max_delay paths;
             ($line =~ /^\s+clock (network|tree) delay \((propagated|ideal)\)\s+(\S+)\s+/) and error "Path to $endpoint without capture clk defined\n";
          }

          while (<VIOL>) {
              if(/^\s+clock (network|tree) delay \((propagated|ideal)\)\s+(\S+)\s+/) {
                  $end_clock_delay = $3;
                  $clock_skew = sprintf "%.3f", ($end_clock_delay - $start_clock_delay);
                  ($end_clock_delay > 0) or error "Non positive $end_clock_delay found to $endpoint";
              }
              #inter-clock uncertainty -0.050      3.474
              elsif (/^\s+(?:inter\-)?clock uncertainty\s+([\-\d]\S*)/) {
                  $uncert = $1;
              }

              elsif (/^\s+data required time\s+\S+$/) {last;}
          }

      }

      if (/^\s*slack/ or /^\s*\(Path is unconstrained\)/) {
          ($slack) = /(\S+)\s*$/;
          if ($slack =~ /unconstrained/) {
              $slack = "unconstrained"; #Drop parenthesis
          }
          $slack = ($slack =~ /\d+/) ? (sprintf "%.3f",$slack) : $slack;
          if ($slack < $slack_thr) {
          $ppath{startpt} = "$startpoint";
          $ppath{endpt} = "$endpoint";
          $ppath{group} = "$Rep_group";
          $ppath{period} = "$period";
          $ppath{launch} = "$launch";
          $ppath{launch_dly} = "$start_clock_delay";
          $ppath{capture_dly} = "$end_clock_delay";
          $ppath{skew} = $clock_skew;
          $ppath{capture} = "$capture";
          $ppath{corner} = "$corner";
          $ppath{slack} = "$slack";
          $ppath{edge} = "$l_edge $c_edge";
          $ppath{uncert} = "$uncert";
          $ppath{is_macro_inside} = "$is_macro_inside";
          $ppath{clkinfo} = "$endclk $period";
          %{$ppath{pdly}} = %pdly; 
          push (@Pdelay,{%ppath});
 #         formatlprint "Push data into Pdelay $endpoint\n";
          $cnt_vars{cnt_parsed_paths} ++;

          } else {
            $cnt_vars{cnt_slack_skip} ++;
          }

          $get_path = 0;
      }
    }
    my $dgn = (sum (values %cnt_vars)) - $cnt_vars{cnt_total_paths};

    foreach (sort (keys %cnt_vars)) {
        my $fout = sprintf "%10d", $cnt_vars{$_};
        my $fitem = sprintf "%-17s",$_;
        lprint "$fitem: $fout\n";
    }

    ($cnt_vars{cnt_total_paths} == $dgn) or error "Something wrong with the path parser in THIS_SUB ? $viol_file \n";
    close (VIOL);
  }

#  push (@Pdelay,{total_paths_rep => $cnt_total_paths, 
#                 parsed_paths    => $cnt_parsed_paths, 
#                 min_skipped     => $cnt_min_skip, 
#                 input_skipped   => $cnt_input_skip, 
#                 output_skipped  => $cnt_output_skip, 
#                 maxdly_skipped  => $cnt_maxdly_skip});
#
  my $var_rep = '*' . "input_reps";
  my $var_data = '*' . "Pdelay";
  open (FO, ">$dumped_source") or error "Can't open file to write";
  print FO "sub sp_dumped_reps {\n";
  print FO "my ";
  print FO Dumper(\%input_reps);
  print FO "\t\treturn \%{\$VAR1};\n}\n";
  print FO "sub sp_dumped_data {\n";
  print FO "my ";
  print FO Dumper (\@Pdelay);
  print FO "\t\treturn \$VAR1;\n}\n";
  close (FO);
  $RAWDATA = \@Pdelay;
  return ($RAWDATA);

END

sub sp_wire_stats {
    my $net = shift;
    (is_net $net) or error "Net $net not found in the design";
    my $length = get_route_length (-quiet =>, $net);
    ($length) or error "Route info for net $net not found";
    my @segs = get_route_info (-segments =>, $net);
    my %rtn = ();
    foreach my $seg (@segs) {
        my @seg_arr = @{$seg};
        $rtn{"$seg_arr[2]"}{layer} = (defined $rtn{"$seg_arr[2]"}{layer}) ? $rtn{"$seg_arr[2]"}{layer} + "$seg_arr[3]" : "$seg_arr[3]";
    }
    foreach my $layer (keys %rtn) {
        $rtn{$layer}{ratio} = sprintf ("%.2f", 100 * ("$rtn{$layer}{layer}" / $length));
    }
    return (\%rtn);
} 

sub sp_get_ref_attr {
    my $ref = shift;
    (is_leaf $ref) or error "Ref $ref isn't a leaf cell";

    if (is_th_ref $ref) {
        return 'HVT';
    } elsif (is_po2_ref $ref) {
        return 'PO2';
    } elsif ($ref =~ /LVT$/) {
        return 'LVT';
    } else {
        return 'SVT';
    }
}

sub sp_get_uper_module {
    my $rtn = ();
    my $obj = shift;
    my $TOP_ROOT = get_root_parent ();
    #my $TOP_ROOT = get_top ();
    (is_pin $obj or is_port $obj or is_cell $obj or is_inst $obj or is_net $obj) or error "$obj is not a inst/cell/pin/port/net \n";
    my @hier = get_hier_list_obj ($HP_TEST,"$obj");
    shift @hier;
    my @hier_rank = ();
#    my @inst_rank = ();
    push (@hier_rank, map ( ${$_}[0],@hier));
#    push (@inst_rank, map ( ${$_}[1],@hier));
    @hier_rank = sort_by_hier_rank (@hier_rank);
    if ($hier_rank[-1] eq "$TOP_ROOT") {
        $rtn = "$TOP_ROOT";
    } else {
        $rtn = $hier_rank[-1];
    }
    $rtn;
}


sub distr_calc {
    my $value = shift;
    my $ruler = shift;
    my $pre_ru = ${$ruler}[-1];
    foreach ((reverse @{$ruler})) {
        if ($value > $_) {  #in the range (rule1, rule2];
            return ($pre_ru);
        } elsif ($value == ${$ruler}[0]) {
            return ${$ruler}[1];
        } 
        $pre_ru = $_;
    }

}

sub bidia_format {
    my @fout = ();  
    my @tout = ();  
    my @rtn = ();  
    my $in = shift; #Referrence of hash.
    my $total_num = shift;
    my $ru = shift; #Referrence of ruler, sorted array,.

    my $space = " " x 7; # x 6;
#    my $head = "   ";  #"\t "; 
    $head = join ("",map ("${space}$_\t",@{$ru}));
    #First line
    push (@fout,$head);
#    print Dumper($in);

    foreach my $item (sort (keys %{$in})) {
        my $out = "$item\t";
        my $in_ru = 0;
        foreach my $ru (@{$ru}) {
            #($in_ru ++ == 0) and ($out .= " \t")  and next; #Always no data inside the first ruler elem 
            ($in_ru ++ == 0) and  next; #Always no data inside the first ruler elem 
            my $value;
            if (! $total_num < 1) {
                $value = sprintf ("%.2f", 100 * ("${$in}{$item}{$ru}" / "$total_num"));
                $value = ($value == 0) ? "" : "$value" ;
            } elsif ($total_num == 0) {
                $value = "${$in}{$item}{$ru}";
            } else {
                error "Total num should no lesser than 1 or 0";
            }
            $out .= "$value\t";
        }
    push (@fout,$out);
    }

    @tout = table_tab (@fout);
    
    my $line = $tout[0];
    $line =~ s/\d/\+/g;
    $line =~ s/\s/\-/g;
    while ($line =~ s/\+\+/-\+/g) {
        ;
    }
    foreach my $ll (@tout) {
        push (@rtn,$ll);
        push (@rtn,$line);
    }
    return (@rtn);
#           0    10    20    30    40    50    60    70    80    90    100 
#----------+-------+-----+-----+-----+-----+-----+-----+-----+-----+------+-----------
# M3                  1                                                
#----------+-------+-----+-----+-----+-----+-----+-----+-----+-----+------+-----------
# M5                  1                                                
#----------+-------+-----+-----+-----+-----+-----+-----+-----+-----+------+-----------
# M2                              1                                    
#----------+-------+-----+-----+-----+-----+-----+-----+-----+-----+------+-----------
# M4           1                                                      
#----------+-------+-----+-----+-----+-----+-----+-----+-----+-----+------+-----------
# M6                              1                                          
#----------+-------+-----+-----+-----+-----+-----+-----+-----+-----+------+-----------

} 

sub vector_sel {
#The selector returns the keys if the value in the sel hash is lesser than the corresponding value from the same key in the sample hash.
#Be sure that the keys in selector is the subset of that in the sample hash.
    my $sample = shift; #Hash referrence from the databese
    my $sel = shift; #Hash referrence from the selection vector
    my @rtn = ();
    foreach my $s_key (keys %{$sel}) {
        unless (grep (($s_key eq $_), (keys %{$sample}))) {
            error "Bad vector keys giving: $s_key, should be one of" . join (" ", (keys %{$sample}));
        }
        if (${$sel}{$s_key} < ${$sample}{$s_key}) {
            push (@rtn, $s_key);
        }
    }    
    @rtn;
}

#sub m_dumper {
#    my $dumped_source = shift;
#    my $data_dump = shift;
#    my $
#   open (FO, ">$dumped_source") or error "Can't open file to write";
#   print FO "sub sp_dumped_reps {\n";
#   print FO "my ";
#   print FO Dumper(\%input_reps);
#   print FO "\t\treturn \%{\$VAR1};\n}\n";
#   print FO "sub sp_dumped_data {\n";
#   print FO "my ";
#   print FO Dumper (\@Pdelay);
#   print FO "\t\treturn \$VAR1;\n}\n";
#   close (FO);
#
#
#}
#
#Key words skew.
sub shpd_late_by_step {
##Need to create_buffer_at before calling this sub.
##Will update it to be more cool
    my $pin = shift;
    my $viol = shift; #positive value of viol.
    my $step = 20;
    my $dly = 0.03;

    my ($x, $y_orig) = get_pin_xy ($pin);
    my $viol = $viol - $dly;
    my $buf_num = ceil ($viol / $dly);
    my $loop = $buf_num;
    my $pos = 1;
    while ($loop) {
        my $delta = ($pos) * $step;
        $y = $y_orig + $delta;
       # create_buffer ($pin CKBD1 -xy $x $y;)

        $pos = inv_bit ($pos) ;
        $loop --;
    }
}


Tsub center_buffer  => << 'END';
    DESC {
    Insert buffer on route at the center of the giving nets. It's a sub for Ben's request.
    }

    ARGS {
        -length_thr: $length_thr
        @nets
    }

    (defined $length_thr) or ($length_thr = 300);
    my $top = get_top ();
    foreach my $net (@nets) {
        (is_net $net) or error "Can't find net $net in the design $top";
        my $route_length; 
        my @holes = find_holes_on_route (-ref => BUFFD4, $net);

        my ($m,$n,$or,$drv_d,$load_d) = split (/\s+/,$holes[0]);
        $route_length = $drv_d + $load_d;



         if ($route_length < $length_thr) {
             lprint "Skip buffer insertion on net $net, length is $route_length\n";
             next;
         }
         my $ref = "";
         if ($route_length > 400) {
             $ref = 'CKBD12';
         } else {
             $ref = 'BUFFD8';
         }
         my $mid = $route_length / 2;
         my $delta = $mid * 0.1;


        my @holes = find_holes_on_route (-ref => $ref, $net);
        my $find_hole = 0;
        while (1) {
            foreach my $hole (@holes) {
                $hole =~ s/,/ /;
                my ($module,$net,$x,$y,$drv_dis,$load_dis) = split (/\s+/,$hole);
                lprint "drv_dis:$drv_dis,delta:$delta\n";
                if ((abs ($drv_dis - $mid)) <= $delta)  {
                     set_top $module;
                     my $drv = get_driver (-local => $net);
                     create_buffer ($drv, $ref, -on_route =>, -name_cell => "${net}_center_buf", -xy => ($x,$y));
                     $find_hole = 1;
                     set_top $top;
                     last;
                }
           }
           if ($find_hole) {
                $find_hole = 0;
                last;
           }
           $delta += 20;
           if ($delta > $mid)  {
                lprint "Can't found proper holes to insert $ref on $net\n";
                last;
           }
        }
    }

END

sub report_macro_scanout_hold_path {
    my @rtn = ();
    my @path_detail = ();
    my @endpts = ();
    my @cmds = ();
    my @scan_outs = ();

    my @macro_insts = get_macros ();
    foreach my $mi (@macro_insts) {
        my @outputs = get_output_pins ($mi);
        foreach my $out (@outputs) {
            ($out =~ /scanout$/) and (push (@scan_outs,$out));
        }
    }
    foreach my $scan_out (@scan_outs) {
        
        my @fanout =  get_fanout (-top =>  -unate => -in =>, $scan_out);
        ($fanout[-1][1] =~ /scanin$/ and (is_macro_module $fanout[-1][2])) or next; #to the same macro through scanin
        my ($pre_out, $module_out, $pin_out) = get_pin_context ($scan_out);
        my $scan_in = "$fanout[-1][0]" . "$fanout[-1][1]";
        my ($pre_in, $module_in, $pin_in) = get_pin_context ($scan_in);
        ($module_out eq $module_in) or next;

        #my %end_dly_hash = mrt (-delay =>"min",  -through =>"$scan_out", -rtn_end_delay_hash=>);
        my %ful_dly_hash = mrt (-delay =>"min",  -through =>"$scan_out", -rtn_full_delay_hash=>);
        my $endpt = (keys %end_dly_hash)[0];
        my $startpt = (keys %ful_dly_hash)[0];
        $endpt =~ s/\s+//;
        $startpt =~ s/\s+//;
        foreach my $pin (keys %ful_dly_hash) {
            $pin =~ s/\s+//;
            my ($inst,$module,$cpin) = get_pin_context ($pin);
            if (is_driver $pin) {
                (is_end_ref $module) and ($startpt = $pin);
            } elsif (is_end_ref $module) {
                $endpt = $pin;
            }
        }
        ($endpt and $startpt) or error "Failed to get the start or end point for min path through $scan_out\n";
        my ($inst_end,$m_end,$p_end)  = get_pin_context ($endpt);
        my ($inst_start,$m_start,$p_start)  = get_pin_context ($startpt);
        my $cp_end_ref = get_clock_ref_pins ($m_end);
        my $cp_start_ref = get_clock_ref_pins ($m_start);
        ($cp_end_ref and $cp_start_ref) or error "Failed to get ref cp pin of $m_end or $m_start\n"; 
        my $end_fu = get_root_fast ("${inst_end}/$cp_end_ref");
        my $start_fu = get_root_fast ("${inst_start}/$cp_start_ref");
        if ($end_fu eq $start_fu) {
            $SPZ_DEBUG and lprint "Skip the path on the same clock tree: $scan_out\n";
            next; #They are on the same tree.
        } else {
            if (is_pin $end_fu and is_pin $start_fu) {
                my ($fu_inst_end,$fu_ref_end,$fu_pin_end) = get_pin_context ($end_fu);
                my ($fu_inst_st,$fu_ref_st,$fu_pin_st) = get_pin_context ($start_fu);
                if (is_latch_ref ($fu_ref_end) and is_latch_ref ($fu_ref_st)) {
                    my $cp_fu_end = get_clock_ref_pins ($fu_ref_end);
                    my $cp_fu_st = get_clock_ref_pins ($fu_ref_st);
                    my $root_end = get_root_fast ("${fu_inst_end}/$cp_fu_end");
                    my $root_st = get_root_fast ("${fu_inst_st}/$cp_fu_st");
                    if ($root_end eq $root_st) {
                        $SPZ_DEBUG and lprint "Skip the path on the same clock tree: $scan_out\n";
                        next;
                    }
                }
            }
        } 
        #Judge if the start&end point are on the same clock node.
        my @rtn_t = mrt (-delay =>"min",  -through =>"$scan_out");
        foreach my $out (@fanout) {
            my $pin = "${$out}[0]" . "${$out}[1]";
            my $inst = get_inst_of_pin ($pin);
            ($inst) or error "bug in tmp_report_macro_scan, ping Spirit Zhang\n";
            ((is_buf_ref ${$out}[2]) and ($inst =~ /^eco[0-9]+/)) or next;
            my $cmd = "remove_unate $inst\n";
            push (@cmds, $cmd);
        }
        push (@path_detail,@rtn_t); 
        push (@endpts, $endpt);
    }
    my $msg_1 = "Please add the following endpoints to the skip file specified in user config file:\n";
    my $msg_2 = "\nPlease double check and remove the previous Mender hold fix:\n";
    my $msg_3 = "\nPlease forward the detail path to macro owner:\n";
    push (@rtn, $msg_1,@endpts,$msg_2,@cmds,$msg_3, @path_detail);
    @rtn;
}


Tsub shpd_copy_from  => << 'END';
    DESC {
        Automatically copy the module to a new one.Use to duplicate latch when skew clocks.
    }

    ARGS {
        -from: $length_thr
        -to: $newmodule
    }

END
