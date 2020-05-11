Tsub get_region_chain => << 'END';
    DESC {
        generate region chain report with -pin, !! Port or Flop/D* supported
            -plot show region-chain in mender-GUI
            -limit set max-chain number in report/GUI, default is 5
        Example:
            get_region_chain gtbf0paf0/gtb_f0_retime/inst_GTB0FBP0ltc02top_retime_fb2ltc_slice02_rdat_pd_2_W141_RT1_730_1_gtbf0paf0/u_retime_reg/D;
            get_region_chain gtcx0xsw/XBAR/u_NV_MXBAR_CS_top/top/pri_rtm_wrap/pri_rtm_xsw0_0/pri_rtm_node/priv_nxt_reg_mflop4_16523/D0 -limit 1 -plot;
            
    }
    ARGS {
        -plot
        -limit:$limit
        $pin
    }
    if (not defined ($limit)) {
        $limit = 5;
    }
    my ($a,%fanin_chain) = trace_fanin_region_chain($pin,{});
    my ($b,%fanout_chain) = trace_fanout_region_chain($pin,{});
    my %full_chain;
    foreach my $s_key (keys %fanin_chain) {
        $full_chain{$s_key} = $fanin_chain{$s_key};
    }
    foreach my $s_key (keys %fanout_chain) {
        $full_chain{$s_key} = $fanout_chain{$s_key};
    }
    my @region_chains = trace_region_chain(%full_chain);
    my $chain_count = 0;
    if ($limit >= scalar(@region_chains)) {
        $limit = scalar(@region_chains);
    }
    lprintf("%-6s%-120s%-1s%-120s\n","dist","startpoint","","endpoint");
    if (defined $opt_plot) {
        plot;
        plot_all_partition;
    }
    for(my $chain_count = 0;$chain_count < $limit;$chain_count = $chain_count + 1) {
        lprintf "\#".($chain_count + 1)."\n";
        $chain = $region_chains[$chain_count];
        $chain =~ s/^NULL\-\>//g;
        my @chain_arr = split(/->/,$chain);
        my $chain_len = @chain_arr;
        #----plot region----# 
        if (defined $opt_plot) {
            foreach my $chain_pin (@chain_arr) {
                plot_pin_region($chain_pin);
            }
        }
        #----plot chain----# 
        my @all_colors = ("red","brown","blue","violet","orange");
        my $line_color = $all_colors[($chain_count%5)];        
        for (my $i = 0;$i <= ($chain_len -2);$i = $i + 1) {
            my @start_arr = split(/ /,map_pin_region($chain_arr[$i]));
            my @end_arr = split(/ /,map_pin_region($chain_arr[$i+1]));
            if (get_flow_type eq "anno") {
                my $start_pin = cp_of_cell_pin($chain_arr[$i]);
                my $end_pin = $chain_arr[$i+1];
                @dist = get_path_dist(-from=>$start_pin,-to=>$end_pin,"-rtn_dist");
                if (defined $opt_plot) {
                    mrt(-from=>$start_pin,-to=>$end_pin,"-plot",-line_color=>$line_color);
                    my @start_xy = get_pin_xy($start_pin);
                    my @end_xy = get_pin_xy($end_pin);
                    my $plot_text_x = ($start_xy[0] + $end_xy[0])/2 + (($chain_count-2)*10);
                    my $plot_text_y = ($start_xy[1] + $end_xy[1])/2 + (($chain_count-2)*10);

                    if ($chain_count == 0) {
                        plot_text(int($dist[0]),$plot_text_x,$plot_text_y,-size=>"1");
                    }
                }
                lprintf("%-6s%-120s%-1s%-120s\n",int($dist[0]),cp_of_cell_pin($start_pin),"",$end_pin);
            } elsif ((get_flow_type eq "flat") or (get_flow_type eq "noscan")) {
                my @partition_base_start = (0,0);
                my @partition_base_end = (0,0);
                if (not is_port($chain_arr[$i])) {
                    @partition_base_start = get_cell_xy(get_pin_partition_hier($chain_arr[$i]));
                }  
               if (not is_port($chain_arr[$i+1])) {
                    @partition_base_end = get_cell_xy(get_pin_partition_hier($chain_arr[$i+1]));
                } 
                my @start_xy = ($partition_base_start[0] + $start_arr[1] + $start_arr[3]/2,$partition_base_start[1] + $start_arr[2] + $start_arr[4]/2);
                my @end_xy = ($partition_base_end[0] + $end_arr[1] + $end_arr[3]/2,$partition_base_end[1] + $end_arr[2] + $end_arr[4]/2);
                my $plot_text_x = ($start_xy[0] + $end_xy[0])/2 + (($chain_count-2)*10);
                my $plot_text_y = ($start_xy[1] + $end_xy[1])/2 + (($chain_count-2)*10);
                my $dist_flat = int(get_dist($start_xy[0],$start_xy[1],$end_xy[0],$end_xy[1]));
                if (defined $opt_plot) {
                    plot_line($start_xy[0],$start_xy[1],$end_xy[0],$end_xy[1],-arrow=>"last");
                    if ($chain_count == 0) {
                        plot_text(int($dist_flat),$plot_text_x,$plot_text_y,-size=>"1");
                    }
                }
                lprintf ("%-6s%-120s%-1s%-120s\n",$dist_flat,cp_of_cell_pin($chain_arr[$i]),"",$chain_arr[$i+1]);
            }
        }
        lprint "\n";
    }
END

Tsub map_pin_region => << 'END';
    DESC {
        Map region information for specific pin via *_RETIME.tcl & *ICC_timing_region.tcl
        Example:
            map_pin_region gtbf0lts1/gtb_f0_retime/inst_GTB0FBP0ltc02top_retime_fb2ltc_slice02_rdat_pd_2_W141_RT3_730_3_gtbf0lts1/u_retime_reg/CP;
            map_pin_region  gtcx0xsw/XBAR/u_NV_MXBAR_CS_top/top/pri_rtm_wrap/pri_rtm_xsw1_0/pri_rtm_node/priv_nxt_reg_mflop4_4001/D3;
    }
    ARGS {
        $pin
    }
    if (not (defined $pin)) {
        lprint "No Pin Specified\n";
    } else {
        my $org_pin = $pin;
        if (not is_port($pin)) {
            if (is_merged_flop($pin)) {
                $pin =  get_demerged_name($pin);
            }
            my %hash = read_pin_region_infor($org_pin);
            foreach my $s_key (keys %hash) {
                if ($s_key !~ /^.*\s+.*$/) {
                    my $s_key_map = $s_key;
                    $s_key_map =~ s/\/\*$//;
                    $s_key_map =~ s/\*/\.\*/g;
                    $s_key_map =~ s/\//\\\//g;
                    if ($pin =~ /$s_key_map/) {
                        foreach my $key (grep {$hash{$s_key} ~~ $hash{$_}} keys %hash) {
                            if ($key =~ /\d+\s+\d+/) {
                                my $rtn_str = $hash{$s_key}." ".$key;
                                return $rtn_str;
                            }
                        }
                    }
                }
            }
        }
    }
    return "";
END

sub read_pin_region_infor {
    my ($pin) = @_;
    my $partition = get_pin_partition($pin);
    my $rev = (getenv USE_LAYOUT_REV);
    my $proj = ${PART};
    my $ipo_dir = "/home/${proj}_layout/tot/layout/${rev}/blocks";
    my %region_infor;
    if (-e "$ipo_dir/$partition/control/${partition}_RETIME.tcl") {
        open(region,"$ipo_dir/$partition/control/${partition}_RETIME.tcl");
        while (my $line = <region>) {
            $line =~ s/^\s+//;
            $line =~ s/\n//;
            if ($line =~ /nvb_create_region/) {
                @s_line_arr = split(/ /,$line);
                $region_infor{int($s_line_arr[2])." ".int($s_line_arr[3])." ".int($s_line_arr[4])." ".int($s_line_arr[5])} = $s_line_arr[1];
            } elsif ($line =~ /nvb_add_to_region/) {
                @s_line_arr = split(/ /,$line);
                $region_infor{$s_line_arr[2]} = $s_line_arr[1]
            }
        }
        close region;
    } else {
        lprint "Not exists Region File: $ipo_dir/$partition/control/${partition}_RETIME.tcl \n";
    }
    #read timing region
    if (-e "$ipo_dir/$partition/control/${partition}_ICC_timing_region.tcl") {
        open(region,"$ipo_dir/$partition/control/${partition}_ICC_timing_region.tcl");
        while (my $line = <region>) {
            $line =~ s/^\s+//;
            $line =~ s/\n//;
            if ($line =~ /nvb_create_region/) {
                @s_line_arr = split(/ /,$line);
                $region_infor{int($s_line_arr[2])." ".int($s_line_arr[3])." ".int($s_line_arr[4])." ".int($s_line_arr[5])} = $s_line_arr[1];
            } elsif ($line =~ /nvb_add_to_region/) {
                @s_line_arr = split(/get_cells/,$line);
                $s_line_arr[0] =~ s/^\s+//;
                $s_line_arr[1] =~ s/^\s+//;
                @s_region_pattern_arr = split(/ /,$s_line_arr[1]);
                $s_region_pattern_arr[0] =~ s/\{//;
                $s_region_pattern_arr[0] =~ s/\}//;
                @s_region_name_arr = split(/ /,$s_line_arr[0]);
                $region_infor{$s_region_pattern_arr[0]} = $s_region_name_arr[1];
            }
        }
        close region;
    } 
    return %region_infor;
}

sub get_keys_by_value {
    my ($value,%hash) = @_;
    return grep {$value ~~ $hash{$_}} keys %hash;
}

sub get_pin_partition {
    my ($pin) = @_;
    return name_of_ref(par_ref_of_pin($pin));
}

sub plot_pin_region {
    my ($pin) = @_;
    my $pin_mapped_region_infor = map_pin_region($pin);
    if ($pin_mapped_region_infor ne "") {
        my @pin_mapped_region_infor_arr = split(/ /,$pin_mapped_region_infor);
        my $region_name = $pin_mapped_region_infor_arr[0];
        my $region_x_base = $pin_mapped_region_infor_arr[1];
        my $region_y_base = $pin_mapped_region_infor_arr[2];
        my $region_x_len = $pin_mapped_region_infor_arr[3];
        my $region_y_len = $pin_mapped_region_infor_arr[4];
        my @partition_base = get_cell_xy(get_pin_partition_hier($pin));
        my $region_x_0_chiplet = $partition_base[0] + $region_x_base;
        my $region_x_1_chiplet = $region_x_0_chiplet + $region_x_len;
        my $region_y_0_chiplet = $partition_base[1] + $region_y_base;
        my $region_y_1_chiplet = $region_y_0_chiplet + $region_y_len;
        my @text_xy = ($region_x_0_chiplet,($region_y_0_chiplet + $region_y_1_chiplet)/2 -10);
        if (not($Phys_gui_exists[$Phys_gui_num])) {
            plot;
            plot_all_partition;
        } 
        plot_rect($region_name,$region_x_0_chiplet,$region_y_0_chiplet,$region_x_1_chiplet,$region_y_1_chiplet,-fill=>"pink");
        plot_text($region_name,$text_xy[0],$text_xy[1],-size=>"1");
    }
}

sub get_pin_partition_hier {
    # support those partitions in sub-chiplet
    my ($pin_name) = @_;
    my $base_name = attr_of_cell(base_name,name_of_cell(cell_of_pin($pin_name)));
    my $hier_name = name_of_cell(cell_of_pin($pin_name));
    $hier_name =~ s/$base_name//g;
    $hier_name =~ s/\/$//g;
    return $hier_name;
}

sub expand_chiplet_in_partitions {
    my ($top,@par_hier) = @_;
    my @all_cells;
    if ($top eq "") {
        @all_cells = get_cells "*";
    } else {
        @all_cells = get_cells $top."/*";
    }
    foreach my $s_cell (@all_cells) {
        my $s_ref_name = attr_of_cell(ref_name,name_of_cell($s_cell));
        if (attr_of_ref(is_chiplet,$s_ref_name) == 1) {
            ($top,@par_hier) = expand_chiplet_in_partitions(name_of_cell($s_cell),@par_hier);
        } else {
            push(@par_hier,$s_cell);
        }
    }
    return ($top,@par_hier);
}

sub plot_all_partition {
    my ($a,@all_partitions) = expand_chiplet_in_partitions("",());
    foreach my $s_partition (@all_partitions) {
        plot $s_partition;
    }
}

sub is_merged_flop {
    my ($pin_name) = @_;
    if (attr_of_pin(ref_name,$pin_name) =~ /DF.*SC\d/) {
        return 1
    } else {
        return 0
    }
}

sub rm_redudant {
    my @new_list = ();
    foreach my $s_item (@_) {
        $is_new = 1;
        foreach my $s_item_new (@new_list) {
            if ($s_item_new eq $s_item) {
                $is_new = 0;
            }
        }
        if ($is_new eq 1) {
            push(@new_list,$s_item)
        }
    }
    return (@new_list);
}

sub get_all_chain_end {
    my (%hash) = @_;
    my @all_chain_end;
    foreach my $key (keys %hash) {
        if ($hash{$key} =~ /NULL/) {
            push(@all_chain_end,$key);
        }
    }
    return @all_chain_end;
}

sub find_key_by_value {
    my ($value,%hash) = @_;
    $value =~ s/\[/\\\[/g;
    $value =~ s/\]/\\\]/g;
    foreach my $key (keys %hash) {
        if ($hash{$key} =~ /$value/) {
            return $key; 
        }
    }
    return "";
}

sub trace_route {
    my ($p,$chain,%hash) = @_;
    if ($p ne "NULL") {
        $p = find_key_by_value($p,%hash);
        $chain = $p."->".$chain;
        ($p,$chain,%hash) = trace_route($p,$chain,%hash);
    }
    return ($p,$chain,%hash);
}

sub trace_region_chain {
    my (%hash) = @_;
    my @rtn_chains;
    foreach my $end (get_all_chain_end(%hash)) {
        my($a,$chain,%t) = trace_route($end,$end,%hash);
        push(@rtn_chains,$chain);
    }
    return @rtn_chains;
}

sub trace_fanin_region_chain {
    (my $pin,my %region_pipe) = @_;
    if ($pin !~ /XTR/ && $pin !~ /DFT/ && $pin !~ /_1500/) {
        @fanin_pins = filter_fanin_pins(name_of_pin_list(all_fanin(-to=>$pin,"-flat")));
        my $map_pin;
        if (is_port($pin) or attr_of_pin("is_data",$pin)) {
            $map_pin = $pin;
        } else {
            $map_pin = d_of_flop_q($pin);
        }
        if (is_loop_design(cp_of_cell_pin($map_pin),filter_fanin_pins(name_of_pin_list(all_fanin(-to=>$pin,"-start","-flat"))))) {
            $region_pipe{"NULL"} = $map_pin;
        } else {
            foreach my $s_pin (@fanin_pins) {
                if ((is_port($s_pin)) or (attr_of_pin("is_q",$s_pin))) {
                    if (find_end_loop($s_pin) eq 1) {
                        $region_pipe{$s_pin} = $pin;
                        if ($region_pipe{"NULL"} ne "") { 
                            $region_pipe{"NULL"} = $s_pin.",".$region_pipe{"NULL"};
                        } else {
                            $region_pipe{"NULL"} = $s_pin;
                        }
                    } elsif ((find_end_loop($s_pin) ne 1) && (attr_of_pin("is_q",$s_pin))) {
                        $region_pipe{d_of_flop_q($s_pin)} = $pin;
                        $pin = d_of_flop_q($s_pin);
                        ($pin,%region_pipe) = trace_fanin_region_chain(d_of_flop_q($s_pin),%region_pipe);
                    }                 
                }
            }
        }
    } else {
        if ($region_pipe{"NULL"} ne "") { 
            $region_pipe{"NULL"} = $pin.",".$region_pipe{"NULL"};
        } else {
            $region_pipe{"NULL"} = $pin;
        }
    }
    return ($pin,%region_pipe);
}


sub trace_fanout_region_chain {
    my ($pin,%region_pipe) = @_;
    if ($pin !~ /DFT/ && $pin !~ /XTR/ && $pin !~ /_1500/) {
        my @q_pins = name_of_pin(q_pins_of_data_pin($pin));
        @fanout_pins = get_data_pins_list(name_of_pin_list(all_fanout(-from=>$q_pins[0],-end,"-flat")));
        if (not is_loop_design($pin,@fanout_pins)) {
            foreach my $s_fanout (@fanout_pins) {
                if ($region_pipe{$pin} ne "") {
                    $region_pipe{$pin} = $s_fanout.",".$region_pipe{$pin};
                } else {
                    $region_pipe{$pin} = $s_fanout;
                }
                if (find_end_loop($s_fanout) eq 1) {
                    $region_pipe{$s_fanout} = "NULL";
                }
            }
            foreach my $s_fanout (@fanout_pins) {
                if (find_end_loop($s_fanout) ne 1) {
                    $pin = $s_fanout;
                    ($pin,%region_pipe) = trace_fanout_region_chain($pin,%region_pipe);
                }
            }
        } else {
            $region_pipe{$pin} = "NULL";
        }
    } else {
        $region_pipe{$pin} = "NULL";
    }
    return ($pin,%region_pipe);
}

sub is_loop_design {
    my ($pin,@pin_arr) = @_;
    foreach my $item (@pin_arr) {
        if ($pin eq $item) {
            return 1;
        }
    }
    return 0;
}

sub print_k_list {
    my ($name,@in_list) = @_;
    foreach my $item (@in_list) {
        lprint "debug print list $name $item \n";
    }
}


sub remove_from_list {
    my ($s_pin,@list) = @_;
    my @rtn_list;
    foreach my $item (@list) {
        if ($s_pin ne $item) {
            push(@rtn_list,$item);
        }
    }
    return @rtn_list;
}

sub get_data_pins_list {
    my @rtn_list;
    foreach my $s_pin (@_) {
        if (is_port($s_pin) or ((attr_of_pin(is_data,$s_pin)) && $s_pin !~ /\/SI\d*/ && $s_pin !~ /\/E\d*$/ && $s_pin !~ /\/WE\d*$/)) {
            push(@rtn_list,$s_pin);
        }
    }
    return @rtn_list;
}

sub is_in_list {
    my ($item,@list) = @_;
    foreach my $s_item (@list) {
        if ($item eq $s_item) {
            return 1;
        }
    }
    return 0;
}

sub name_of_pin_list {
    my @names_of_pins = ();
    foreach my $s_item (@_) {
        push(@names_of_pins,name_of_pin($s_item));
    }
    return @names_of_pins;
}

sub name_of_cell_list {
    my @names_of_cells = ();
    foreach my $s_item (@_) {
        push(@names_of_cells,name_of_cell($s_item))
    }
    return @names_of_cells;
}

sub find_end_loop {
    my ($pin) = @_;
    my $end_loop = 1;
    if (((map_pin_region($pin) ne "") && $pin !~ /\/SI\d*/) && ($pin !~ /DFT/) && ($pin !~ /XTR/) && ($pin !~ /_1500/)) {
        $end_loop = 0;
    }
    return $end_loop;
}

sub find_original {
    my @rtn_arr= ();
    foreach my $s_item (@_) {
        if ((map_pin_region($s_item) eq "") && $s_item !~ /\/SI\d*/) {
            push(@rtn_arr,$s_item);
        }
    } 
    return @rtn_arr;
}

sub find_region {
    my @region_cell_pin = ();
    foreach my $s_item (@_) {
        if ($s_item =~ /region/) {
            push(@region_cell_pin,$s_item);
        }
    }
    return @region_cell_pin;
}

sub flop_d_of_fanout {
    my @flop_data_pins = ();
    foreach $s_pin (@_) {
        if ($s_pin =~ /\/D\d*$/) {
            push(@flop_data_pins,$s_pin);
        }
    }
    return @flop_data_pins;
}

sub data_of_flop_cp {
   my ($flop_cp) = @_;
   my @flop_data_pins = ();
   $flop_cp =~ s/\/CP//g;
   foreach $s_item (get_pins($flop_cp."/*")) {
       if ($s_item =~ /\/D/) {
           push(@flop_data_pins,name_of_pin($s_item));
       }
   }
   return @flop_data_pins;
}

sub d_of_flop_q {
   my ($flop_data) = @_;
   my @flop_data_pins = name_of_pin(data_pin_of_q_pin($flop_data));
   return $flop_data_pins[0];
}

sub cp_of_cell_pin {
    my ($flop_d) = @_;
    if ((not is_port($flop_d)) && (not is_clock_pin($flop_d))) {
        my @flop_cp_pins = name_of_pin(clock_pins_of_cell(cell_of_pin($flop_d)));
        return $flop_cp_pins[0];
    } else {
        return $flop_d;
    }
}

sub filter_fanin_pins {
    (my @fanins) = @_;
    my @rtn_list;
    foreach my $fanin_pin (@fanins) {
        if (($fanin_pin !~ /\/d$/) && ($fanin_pin !~ /\/clk/) && ($fanin_pin !~ /XTR/) && ($fanin_pin !~ /JTAG/) && ($fanin_pin !~ /_1500/) && ($fanin_pin !~ /xtr/)) {
            push(@rtn_list,$fanin_pin);
        }
    }
    return @rtn_list;
}

sub get_flow_type {
    my $top = get_top;
    my $flow_type = "";
    if ($M_file_gv{$top} =~ /$top.*ipo.*gv.*gz/) {
        $flow_type = "anno";
    } elsif ($M_file_gv{$top} =~ /$top\.flat\.gv\.gz/) {
        $flow_type = "flat";
    }  elsif ($M_file_gv{$top} =~ /$top\.noscan.*gv.*gz/) {
        $flow_type = "noscan";
    } 
    return $flow_type;
}
