proc retiming_analysis {chiplet} {

    ## Prevent reporting latch thru latch.  Otherwise we get transparency window report which Mender does not handle
    set_app_var timing_enable_through_paths false

	global DATECODE
	global partitions
	global ipo_dir
	global type
    global partitions

    set top [get_object_name [current_design]]
	#############################
	## All inter-partition paths (including retiming-to-retiming)..
	#############################
    #set allPar_PinList [get_pins -of [get_cells]]

    if {$top == "nv_top" || $top == "nvs_top"} {
	    set allPar_PinList [get_pins -of [get_cells]]
    } else {
        set allPar_PinList []
        foreach par_ref [split $partitions " "] {
            set par_insts [get_object_name [get_cells -quiet -hier * -filter "ref_name == $par_ref"]]
            foreach par_inst [split $par_insts " "] {
                append_to_collection allPar_PinList [get_pins -quiet -of [get_cells -quiet $par_inst]]
            }
        } 
    }

	nvidia_timestamp_msg "get_retime_paths.tcl: gather INTERPAR collection"
	set paths_INTERPAR [get_timing_paths -include_hierarchical_pins -through $allPar_PinList -start_end_pair -slack_lesser_than INFINITY];
	nvidia_timestamp_msg "get_retime_paths.tcl: done INTERPAR collection"

	#############################
	## All retiming flop hops (intra-partition)..
        ## tu1xx: remove for now .. expecting quad flop and new mapping files
        ## update: support dual/qual flop 
	#############################
	set paths_RETIMING []
    set paths_RETIMING_NonRETIMING []

	if {$top ne "nv_top" && $top ne "nvs_top"} {
        #set paths_RETIMING ""
        set myRT_dualPinList_mod []
        set myRT_dualPinList_mod_clk []

        if {$type == "anno"} {
	    # dual flop mapping will be auto-loaded in function nv_mbm_get_merged
            nvidia_timestamp_msg "get_retime_paths.tcl: gather RT pins in dual flops";
            set myRT_dualPinList_mod [nv_mbm_get_merged -pin_regexp .*_RT.*/D]
        }

        # signle RT flop
        set myRT_other     [get_cells -hier .* -regexp -filter {full_name =~ ".*_RT[0-9].*" && is_sequential == true}]
        set myRT_other_pin [get_pins -of $myRT_other -filter {direction == in && lib_pin_name !~ *SI* && lib_pin_name !~ *SE* && is_clock_pin != true}]
        
        nvidia_timestamp_msg "get_retime_paths.tcl: gather RT collection"
        set myRT_all                  $myRT_dualPinList_mod;
        append_to_collection myRT_all $myRT_other_pin;
        
        ## Forcing outputs as RT-to-RT paths only (toss interPar, as they are covered in paths_INTERPAR)..
        ## include non-RT to RT paths
        set paths_RETIMING [get_timing_paths -include_hierarchical_pins -to $myRT_all -start_end_pair -slack_lesser_than INFINITY -exclude $allPar_PinList];
        unset myRT_dualPinList_mod
        unset myRT_all
        unset myRT_other_pin
        unset myRT_other
        nvidia_timestamp_msg "get_retime_paths.tcl: done RT->RT NonRT->RT collection"  

        ## Add RT-> Non RT;
        set my_RT_Q_pins []

        append_to_collection myRT_list_Q [get_pins */*_RT*/Q -quiet]
        append_to_collection myRT_list_Q [get_pins */*_RT*/QN -quiet]
        if {$type == "anno"} {
            append_to_collection myRT_list_Q [nv_mbm_get_merged -inst_regexp .*_RT.*/Q]
            append_to_collection myRT_list_Q [nv_mbm_get_merged -inst_regexp .*_RT.*/QN]
        }
        set paths_RETIMING_NonRETIMING [get_timing_paths -include_hierarchical_pins -through $my_RT_Q_pins -start_end_pair -slack_lesser_than INFINITY -exclude $allPar_PinList]

        unset my_RT_Q_pins
        nvidia_timestamp_msg "get_retime_paths.tcl: done RT-> NonRT"          
    }

	#############################
	## Generate Report
	#############################
	set all_paths $paths_RETIMING;
	append_to_collection -unique all_paths $paths_INTERPAR;
    append_to_collection -unique all_paths $paths_RETIMING_NonRETIMING;

	echo "get_retime_paths.tcl: SUMMARY"
	echo "get_retime_paths.tcl: paths_retiming (cnt)= [sizeof_collection $paths_RETIMING]"
	echo "get_retime_paths.tcl: paths_INTERPAR (cnt)= [sizeof_collection $paths_INTERPAR]"
	echo "get_retime_paths.tcl: ------------------------"
	echo "get_retime_paths.tcl: all_paths      (cnt)= [sizeof_collection $all_paths]"

    set RepFile "./$chiplet.$DATECODE.rep.flat"
    
    redirect $RepFile {nv_report_clock_attributes}
    foreach_in_collection retiming_path_filtered $all_paths {
        redirect -append $RepFile {rt -include_hier $retiming_path_filtered}
    }

	echo "get_retime_paths.tcl: REPORT at ./$chiplet.$DATECODE.rep.flat";
	nvidia_timestamp_msg "get_retime_paths.tcl: done for report dumping."

    unset allPar_PinList;
    unset all_paths;
    unset paths_INTERPAR;
    unset paths_RETIMING;
}


define_proc_attributes retiming_analysis \
        -info {calculate chip setup/hold, output max/min} \
        -define_args {
                {chiplet "chiplet" "value" string required}
        }



