
# Derived from Mender's core get_ref_size_eff routine
Tsub get_ref_size_eff_rf => << 'END';
    :PROFILE
	DESC {
		Returns the normalized effective drive strength relative to an inverter (both rise and fall edge)
		See_also: get_ref_size
	}
	ARGS {
		$ref		#cell type
		$out_pin
		-flag_unknown   #return -1 if unknown (default is 12 with warning)
	}
	if ($ref eq "mcp_top_buf") {
		$ref = "CLKBUFX20";
	}
	my $ref_num = m_get_ref_name2num ($ref);
	$out_pin or ($out_pin) = get_outputs_of_sort ($ref);
	$out_pin or return 0;
	my $out_pin_num = m_get_pin_name2num ($ref_num, $out_pin);
        # Would need to define 2 more effective sizes here (R,F)
	# my $size_eff_r = $M_attr_src[$ref_num][SIZE_EFF_R][$Timing_corner_num]{$out_pin_num};
	# my $size_eff_f = $M_attr_src[$ref_num][SIZE_EFF_F][$Timing_corner_num]{$out_pin_num};
	my ($size_eff_r, $size_eff_f) = (0, 0);
	{
		load_corner_libs ();
		my $init_tran = $WH_default_tran;
		if (!$Timing_base_tran_r[$Timing_corner_num]) {
			wh_lib_init ();
			my $small_cell = $WH_invx2;
			my $size = get_ref_size ($small_cell);
			$size or error "Base size is 0 for $WH_invx2";
			my $pin_cap = get_pin_cap ($small_cell);
			my ($in_pin) = get_inputs_of ($small_cell);
			my ($out_pin) = get_outputs_of ($small_cell);
			my $test_cap = 5 * $pin_cap;

			my $tran1_r = get_cell_delay ($small_cell, $in_pin, $out_pin, $init_tran, $test_cap, "tr"); #Rise time when driving itself
			$tran1_r or $tran1_r = 0.1 and warn_once "Internal error in calculation of transition time for pin $out_pin on cell $small_cell";
			my $tran2_r = get_cell_delay ($small_cell, $in_pin, $out_pin, $init_tran, 2 * $test_cap, "tr"); #Rise time when driving itself
			$tran2_r or $tran2_r = 0.2 and warn_once "Internal error in calculation of transition time for pin $out_pin on cell $small_cell";
			$Timing_base_tran_r[$Timing_corner_num] = ($test_cap / (($tran2_r - $tran1_r) * $size));

			my $tran1_f = get_cell_delay ($small_cell, $in_pin, $out_pin, $init_tran, $test_cap, "tf"); #Rise time when driving itself
			$tran1_f or $tran1_f = 0.1 and warn_once "Internal error in calculation of transition time for pin $out_pin on cell $small_cell";
			my $tran2_f = get_cell_delay ($small_cell, $in_pin, $out_pin, $init_tran, 2 * $test_cap, "tf"); #Rise time when driving itself
			$tran2_f or $tran2_f = 0.2 and warn_once "Internal error in calculation of transition time for pin $out_pin on cell $small_cell";
			$Timing_base_tran_f[$Timing_corner_num] = ($test_cap / (($tran2_f - $tran1_f) * $size));

			$Timing_base_test_cap[$Timing_corner_num] = $test_cap / $size;
		}
		my ($in_pin) = get_arc_pins_in ($ref, $out_pin);
		unless ($in_pin) { #Output only cell e.g. TIELO
			$size_eff_r = 2; #Default size
			$size_eff_f = 2; #Default size
		}
		else {
			my $pin_cap = get_pin_cap ($ref, $in_pin);
			$pin_cap or $pin_cap = 5 * get_pin_cap ($WH_invx2);  #Test cap in case input pin is an internal pin so therefore no pin cap
			if (!exists ($CELL_TIMING{"$Timing_corner:$ref:$in_pin:$out_pin"})) {
				my $rgx = quotemeta ("$Timing_corner:$ref:") . '\S+' . quotemeta (":$out_pin") . '$';
				my ($arc) = grep (/$rgx/, keys %CELL_TIMING);
				if (!$arc) {
					$size_eff_r = -1;
					$size_eff_f = -1;
					warn_once "Transition timing unknown for pin $out_pin of cell $ref.  Modeling as a $WH_clkbufx12.";
				}
				else {
					$in_pin = (split (/:/, $arc))[2];
				}
			}
			if (!$size_eff_r) {
				my $test_cap = 5 * $pin_cap;
				my $i;
				foreach $i (0 .. 2) { #Iterate on test_cap selection
					my $tran1 = get_cell_delay ($ref, $in_pin, $out_pin, $init_tran, $test_cap, "tr", undef, "-quiet"); #Rise time when driving 5x itself
					$tran1 or $tran1 = 0.1;# and warn_once "Internal error in calculation of transition time for pin $out_pin on cell $ref";
					my $tran2 = get_cell_delay ($ref, $in_pin, $out_pin, $init_tran, 2 * $test_cap, "tr", undef, "-quiet"); #Rise time when driving 10x itself
					$tran2 or $tran2 = 0.2;# and warn_once "Internal error in calculation of transition time for pin $out_pin on cell $ref";
					if ($tran2 <= $tran1 + $AZERO) {
						$size_eff_r = -1;
						last;
					}
					my $base_tran = safe_div0 ($test_cap, ($tran2 - $tran1));
					$size_eff_r = $base_tran / $Timing_base_tran_r[$Timing_corner_num];
					$test_cap = $size_eff_r * $Timing_base_test_cap[$Timing_corner_num]; 
				}
			}
			if (!$size_eff_f) {
				my $test_cap = 5 * $pin_cap;
				my $i;
				foreach $i (0 .. 2) { #Iterate on test_cap selection
					my $tran1 = get_cell_delay ($ref, $in_pin, $out_pin, $init_tran, $test_cap, "tf", undef, "-quiet"); #Rise time when driving 5x itself
					$tran1 or $tran1 = 0.1;# and warn_once "Internal error in calculation of transition time for pin $out_pin on cell $ref";
					my $tran2 = get_cell_delay ($ref, $in_pin, $out_pin, $init_tran, 2 * $test_cap, "tf", undef, "-quiet"); #Rise time when driving 10x itself
					$tran2 or $tran2 = 0.2;# and warn_once "Internal error in calculation of transition time for pin $out_pin on cell $ref";
					if ($tran2 <= $tran1 + $AZERO) {
						$size_eff_f = -1;
						last;
					}
					my $base_tran = safe_div0 ($test_cap, ($tran2 - $tran1));
					$size_eff_f = $base_tran / $Timing_base_tran_f[$Timing_corner_num];
					$test_cap = $size_eff_f * $Timing_base_test_cap[$Timing_corner_num]; 
				}
			}
		}
	}
	if ($size_eff_r < 0.001) {
		if (!$size_eff_r) {
			warn_once "Transition timing unknown for pin $out_pin of cell $ref.  Modeling as a $WH_clkbufx12.";
		} else {
			warn_once "Transition timing could not be calculated for pin $out_pin of cell $ref.  Modeling as a $WH_clkbufx12.";
		}
		if ($opt_flag_unknown and $size_eff_r == -1) {
			#size_eff_r == -1 is a flag for unknown
			return (-1);
		}
		$ref ne $WH_clkbufx12 or error "Could not determine drive strength of $WH_clkbufx12.  Verify correct libs have been loaded.";
		($size_eff_r, $size_eff_f) = get_ref_size_eff_rf ($WH_clkbufx12);
	} 
	($size_eff_r, $size_eff_f);
END

# TODO: Add support for effective cap calculations on wire loads
#
Tsub get_cell_timing_info => << 'END'; 
	DESC {
         Print timing info for a given list of cell references (can use wildcards).  NOTE: wire loads just get added as a lumped cap.  No effective cap calculation is performed.
	}
	ARGS {
         -corner: $corner           # Use this corner for all analysis (default is to use current corner for max, "fast" corner for min) 
         -min_corner: $min_corner   # Use this corner for all min timing analysis (default is "fast" corner) 
         -leak_corner: $leak_corner # Use this corner for all leakage info (default is -corner value, or current corner) 
         -rise: $rise       # rise time for data inputs (default: 0.05n)
         -fall: $fall       # fall time for data inputs (default: 0.05n)
         -clkrise: $clkrise # rise time for clocks (default: 0.05n)
         -clkfall: $clkfall # fall time for clocks (default: 0.05n)
         -tran: $tran       # if defined, then set all rise and fall times to this value 
         -pin_load:  $pin_load  # cell / pin to use as a load (default: \$WH_invx1/I)
         -wire_load: $wire_load # length of wire route (used as additional load, default: 0) 
         -load_cap:  $load_cap  # Specify actual load in pf.  If specified, will be used instead of default "get_pin_cap(pin_load) \+ (wire_load \* cap_per_dist)" calc.
         -flop_details      # print additional flop cell details 
         -latch_details     # print additional latch cell details 
         -sortby: $sortby   # specify which column in the table to sort by (leftmost is column 1) 
         -rsort             # reverse sort 
         -fo3               # use a fanout of 3 cap for delay calculations.  This is 3 \* the cells largest input pin cap. 
         -fo4               # use a fanout of 4 cap for delay calculations.  This is 4 \* the cells largest input pin cap.
         -rf                # generate a table with separate rise / fall data as well 
         -only_used         # Only generate info for flops used in the current design
         -generic           # Include generic (uncharacterized) cell results.  Not recommended as this data is usually unreliable.
         -func              # Show all cells functionally compatible with first given reference cell
         -scan              # Include scan inputs for flop characterization 
         -samebasename      # Only show functionally equiv cells with the same base name 
         @refcells 
	}

  $opt_scan or $opt_scan = 0;
  $rise or $rise = 0.05;
  $fall or $fall = 0.05;
  $clkrise or $clkrise = 0.05;
  $clkfall or $clkfall = 0.05;
  if (!defined $pin_load) {
    $WH_invx1 or error "\$WH_invx1 isn't defined.  This is used as the default load cell.  You can override with -pin_load option.";
    my ($loadcell) = get_module(-quiet, $WH_invx1);
    $loadcell or error "Can't find default load cell: $WH_invx1, please specify your own load pin using the -pin_load option.";
    my ($loadpin) = get_inputs_of($loadcell);
    $pin_load = "$loadcell/$loadpin";
  }
  $wire_load or $wire_load = 0;
  $load_cap or $load_cap = 0;
  if ($load_cap) {
    $pin_load = 0;
    $wire_load = 0;
  }
  # Make column 1 the first column in the results list
  $sortby or $sortby = 1; $sortby--;
  if ($tran) {
    $rise = $tran;
    $fall = $tran; 
    $clkrise = $tran;
    $clkfall = $tran;
  }

  my $debug = 0;
  my @results = ();

  # Calculate the full load cap 
  #
  # Todo: Add support for effective cap calculations
  # my $ctot = $wlen * $cap_per_dist; 
  # my $rtot = $wlen * $res_per_dist; 
  # my @stree = create_linear_steiner_tree($rtot, $ctot, $lpincap, $pi); 
  # my ($eff_cap_r, $eff_cap_f, $out_tran_r, $out_tran_f, @rc_model) =
  #   get_net_rc_model("junk", $in_pin, $in_pin, $itranr, $itranf, -stree => @stree, -drv_ref_pin => ref_pin_of_name("$cellref/$out_pin"));
  #
  my $pin_cap = 0;
  my $wire_cap = 0;
  if (!$load_cap) {
    if ($pin_load) {
      my ($load_module, $load_pin) = split("/", $pin_load);
      if (!defined $load_pin) { $load_pin = ""; }
      if (defined $load_module and get_module(-quiet, $load_module)) {
        if (grep(/^$load_pin$/, get_inputs_of($load_module))) {
          $pin_cap = get_pin_cap ($load_module, $load_pin);
        } else {
          error "Can't find pin cap for $pin_load.  $load_module does not have an input named $load_pin.";
        }
      } else {
        error "Can't find pin cap for $pin_load.  The library containing $load_module has not been loaded.";
      }
    }
    if ($wire_load) {
      $wire_cap = $wire_load * $Cap_per_dist; 
    }
    $load_cap = $wire_cap + $pin_cap; 
  } 
  
  if ($corner) {
    push_timing_corner($corner);
    if (!$min_corner) {
      $min_corner = $corner;
    }
  }
  my $max_corner = get_timing_corner(); 
  if (!$min_corner) {
    $min_corner = $max_corner;
    $min_corner =~ s/slow/fast/; 
    my @allcorners = list_timing_corners(-all);
    my $corner_exists = grep(/^${min_corner}$/, @allcorners);
    $corner_exists or error "Tried to set default min corner to $min_corner which doesn't exist, please use the -corner or -min_corner option to set manually";
    # We do this as a double check that the corner exists
    push_timing_corner($min_corner);
    pop_timing_corner();
  }
  if ($corner) {
    pop_timing_corner($corner);
  }
  $leak_corner or $leak_corner = $max_corner;

  lprint "Quick characterization\n";
  lprint "Timing corners used:  max = $max_corner, min = $min_corner\n";
  lprint "Input transition time: ${rise}ns r ${fall}ns f\n";
  lprint "Clock transition time: ${clkrise}ns r ${clkfall}ns f\n";
  if ($opt_fo3) {
    lprint "Using FO3 load\n";
  } elsif ($opt_fo4) {
    lprint "Using FO4 load\n";
  } else {
    if ($wire_load) {
      lprint "Wire load: $wire_load um = $wire_cap pf\n";
    } 
    if ($pin_load) {
      lprint "Pin load: $pin_load = $pin_cap pf\n";
    }
    if ($load_cap) {
      lprint "Total load: $load_cap pf\n";
    }
  }
  lprint "\n";
  lprint "NOTE: Hold values are at min corner.  CK->Q and setup are at max corner.\n";
  lprint "      MAX means the worst case from the rising and falling transition cases.\n\n";

  my @allrefs = map(get_modules($_), @refcells);
  my ($firstref) = @allrefs;
  if ($firstref) {
    if ($opt_func or $opt_samebasename) {
      @allrefs = get_alternative_lib_cells($firstref);
    }
    # Optionally prune cells with different base name
    if ($opt_samebasename) {
      my $origbase = get_ref_base_name($firstref);
      @allrefs = grep((get_ref_base_name($_) eq $origbase), @allrefs); 
    }
  }

  # Find and remove uncharacterized reference cells from the list 
  @uncharefs = ();
  if (!$opt_generic) {
    foreach my $ref (@allrefs) {
      my $cref = ref_of_name($ref);
      push_timing_corner($max_corner);
      if (!attr_of_ref(is_char_full, $cref) and !attr_of_ref(is_char_final, $cref)) { 
        push(@uncharefs, $ref); 
        warning "Excluding $ref because it isn't characterized in corner: $max_corner\n";
      } 
      pop_timing_corner();
      if ($min_corner ne $max_corner) {
        push_timing_corner($min_corner);
          if (!attr_of_ref(is_char_full, $cref) and !attr_of_ref(is_char_final, $cref)) { 
            push(@uncharefs, $ref); 
            warning "Excluding $ref because it isn't characterized in corner: $min_corner\n";
          } 
        pop_timing_corner();
      }
    }
    @allrefs = get_missing(@allrefs, @uncharefs);
  }

  my @floprefs = grep(is_flop_ref_name($_), @allrefs); 
  my @latchrefs = grep(is_latch_ref_name($_), @allrefs); 
  @combrefs = get_missing(@allrefs, @floprefs);

  #====================================================================================================
  # Work on combinational cells
  #====================================================================================================
  my @cresults = ();
  foreach my $cellref (@combrefs) {
    lprint "COMB: $cellref\n" if $debug;
    my $num_of_cell = scalar(get_cells_of($cellref));
 
    my $maxpcap = max(map(get_pin_cap($cellref, $_), get_inputs_of($cellref)));
    if ($opt_fo3) {
      $load_cap = 3 * $maxpcap;
    } elsif ($opt_fo4) {
      $load_cap = 4 * $maxpcap;
    }

    my $area = sprintf("%0.3f", get_area($cellref)); 
    push_timing_corner($leak_corner);
    my $leak = sprintf("%0.3f", get_ref_leakage($cellref)); 
    pop_timing_corner();

    my @out_ref_pins = get_outputs_of ($cellref);
    foreach my $out_pin (@out_ref_pins) {
      my ($driver, $drivef) = get_ref_size_eff_rf (-flag_unknown => $cellref, $out_pin);
      $driver = sprintf("%0.3f", $driver);
      $drivef = sprintf("%0.3f", $drivef);
      my $drive = min($driver, $drivef);

      my @in_ref_pins = get_arc_pins_in($cellref, $out_pin); 
      foreach my $in_pin (@in_ref_pins) {
        # my $arc_sense_num = get_cell_arc_sense_num($cellref, $in_pin, $out_pin);  # 0 for pos_unate, 1 for neg_unate, or 2 for non_unate
        my $arc_sense = get_cell_arc_sense($cellref, $in_pin, $out_pin);  # 1 for pos_unate, -1 for neg_unate, or 0 for non_unate
        my $pcap = sprintf("%0.5f", get_pin_cap($cellref, $in_pin));

        my ($rdelay, $fdelay, $rtrans, $ftrans);

        push_timing_corner("max.${max_corner}");
        my $maxrdelay = sprintf("%0.4f", get_cell_delay($cellref, $in_pin, $out_pin, ($arc_sense > 0) ? $rise : $fall, $load_cap, "dr"));
        my $maxfdelay = sprintf("%0.4f", get_cell_delay($cellref, $in_pin, $out_pin, ($arc_sense > 0) ? $fall : $rise, $load_cap, "df"));
        my $maxdelay = max($maxrdelay, $maxfdelay); 
        my $maxrtrans = sprintf("%0.4f", get_cell_delay($cellref, $in_pin, $out_pin, ($arc_sense > 0) ? $rise : $fall, $load_cap, "tr"));
        my $maxftrans = sprintf("%0.4f", get_cell_delay($cellref, $in_pin, $out_pin, ($arc_sense > 0) ? $fall : $rise, $load_cap, "tf"));
        my $maxtrans = max($maxrtrans, $maxftrans); 
        if ($arc_sense == 0) {
          # if non_unate, then do the other sense as well and pick the worst.
          # In this case, we've already calculated the negative unate case above so look at positive unate case as well here
          my $omaxrdelay = sprintf("%0.4f", get_cell_delay($cellref, $in_pin, $out_pin, $rise, $load_cap, "dr"));
          my $omaxfdelay = sprintf("%0.4f", get_cell_delay($cellref, $in_pin, $out_pin, $fall, $load_cap, "df"));
          $maxrdelay = max($maxrdelay, $omaxrdelay); 
          $maxfdelay = max($maxfdelay, $omaxfdelay); 
          $maxdelay = max($maxrdelay, $maxfdelay); 
          my $omaxrtrans = sprintf("%0.4f", get_cell_delay($cellref, $in_pin, $out_pin, $rise, $load_cap, "tr"));
          my $omaxftrans = sprintf("%0.4f", get_cell_delay($cellref, $in_pin, $out_pin, $fall, $load_cap, "tf"));
          $maxrtrans = max($maxrtrans, $omaxrtrans); 
          $maxftrans = max($maxftrans, $omaxftrans); 
          $maxtrans = max($maxrtrans, $maxftrans); 
        }
        pop_timing_corner();

        push_timing_corner("min.${min_corner}");
        my $minrdelay = sprintf("%0.4f", get_cell_delay($cellref, $in_pin, $out_pin, ($arc_sense > 0) ? $rise : $fall, $load_cap, "dr"));
        my $minfdelay = sprintf("%0.4f", get_cell_delay($cellref, $in_pin, $out_pin, ($arc_sense > 0) ? $fall : $rise, $load_cap, "df"));
        my $mindelay = min($minrdelay, $minfdelay); 
        my $minrtrans = sprintf("%0.4f", get_cell_delay($cellref, $in_pin, $out_pin, ($arc_sense > 0) ? $rise : $fall, $load_cap, "tr"));
        my $minftrans = sprintf("%0.4f", get_cell_delay($cellref, $in_pin, $out_pin, ($arc_sense > 0) ? $fall : $rise, $load_cap, "tf"));
        my $mintrans = min($minrtrans, $minftrans); 
        if ($arc_sense == 0) {
          # if non_unate, then do the other sense as well and pick the worst.
          # In this case, we've already calculated the negative unate case above so look at positive unate case as well here
          my $ominrdelay = sprintf("%0.4f", get_cell_delay($cellref, $in_pin, $out_pin, $rise, $load_cap, "dr"));
          my $ominfdelay = sprintf("%0.4f", get_cell_delay($cellref, $in_pin, $out_pin, $fall, $load_cap, "df"));
          $minrdelay = min($minrdelay, $ominrdelay); 
          $minfdelay = min($minfdelay, $ominfdelay); 
          $mindelay = min($minrdelay, $minfdelay); 
          my $ominrtrans = sprintf("%0.4f", get_cell_delay($cellref, $in_pin, $out_pin, $rise, $load_cap, "tr"));
          my $ominftrans = sprintf("%0.4f", get_cell_delay($cellref, $in_pin, $out_pin, $fall, $load_cap, "tf"));
          $minrtrans = min($minrtrans, $ominrtrans); 
          $minftrans = min($minftrans, $ominftrans); 
          $mintrans = min($minrtrans, $minftrans); 
        }
        pop_timing_corner();

        my $dlyvar = "NA"; 
        if ($mindelay != 0) {
          $dlyvar = sprintf("%0.2f", $maxdelay / $mindelay); 
        }

        if ($opt_rf) {
          push(@cresults, "$cellref\t$num_of_cell\t${in_pin}->${out_pin}\t$pcap\t$maxrdelay\t$maxfdelay\t$maxrtrans\t$maxftrans\t$minrdelay\t$minfdelay\t$minrtrans\t$minftrans\t$driver\t$drivef\t$dlyvar\t$area\t$leak");
        } else {
          push(@cresults, "$cellref\t$num_of_cell\t${in_pin}->${out_pin}\t$pcap\t$maxdelay\t$maxtrans\t$mindelay\t$mintrans\t$drive\t$dlyvar\t$area\t$leak");
        }
      }
    }

  }

  #====================================================================================================
  # Work on flops (has different reporting than combinational cells)
  #====================================================================================================
  my @fresults = ();
  my @fresults2 = ();
  foreach my $cellref (@floprefs, @latchrefs) {

    lprint "FLOP: $cellref\n" if $debug;

    my $num_of_cell = scalar(get_cells_of($cellref));

    # # Check setup on all data and enable inputs to the flop, keep worst one
    # my @flop_in_pins = (get_flop_ref_ports_of_type ($cellref, 'D'), get_flop_ref_ports_of_type ($cellref, 'E'),
    #                     get_flop_ref_ports_of_type ($cellref, 'OSK'), get_flop_ref_ports_of_type ($cellref, 'ORK'));
    # 
    # # Special handling for PAIR flop inputs
    # # TODO: Report this problem to David B
    # if (!scalar(@flop_in_pins)) {
    #   @flop_in_pins = grep(/^(D|E)[0-9]*_[0-9]*/, get_inputs_of($cellref));
    # }
    #
    # my @flop_in_pins = (get_flop_ref_ports_of_type ($cellref, 'D'), get_flop_ref_ports_of_type ($cellref, 'E'),

    my @ckpins = ref_pins_of_seq_ref(-type => 'ck', ref_of_name($cellref));
    my @dpins = map(data_ref_pins_of_clock_ref_pin($_), @ckpins);
    if (!$opt_scan) {
      @dpins = grep(!attr_of_ref_pin(is_scan => $_), @dpins); 
    }

    if (!scalar(@dpins)) {
      warning "Didn't find data inputs pins for $cellref, skipping\n";
      next;
    }

    # get ref name of ref pin (convert to text)
    my @flop_in_pins = map(attr_of_ref_pin(ref_pin_name => $_), @dpins);

    my $area = sprintf("%0.3f", get_area($cellref)); 
    push_timing_corner($leak_corner);
    my $leak = sprintf("%0.3f", get_ref_leakage($cellref)); 
    pop_timing_corner();

    my $clock_ref_pin;
    my $max_setup_r = -10000;
    my $max_setup_f = -10000;
    my $max_hold_r = -10000;
    my $max_hold_f = -10000;
    my $max_ipcap = -10000;
    foreach my $pin (@flop_in_pins) {
      lprint "INPUT_PIN: $pin\n" if $debug;
      # Find the associated clock pin
      ($clock_ref_pin) = get_constraint_ref_clk_pins ($cellref, $pin);
      lprint "CLOCK_REF_PIN: $clock_ref_pin\n" if $debug;
      if (!$clock_ref_pin) {
        lprint "ERROR: Cant find clock pin for $cellref $pin\n";
        next;
      }
      # Select proper tran time based on if this is a rising or falling edge triggered flop
      # TODO: Not sure what the clean way to handle this is 
      my $active_clk_tran = $clkrise;
      if ($clock_ref_pin =~ /N$/) {
        $active_clk_tran = $clkfall;
      } 

      my $pcap = sprintf("%0.5f", get_pin_cap($cellref, $pin));

      push_timing_corner("max.${max_corner}");
      my $setup_r = sprintf("%0.4f", get_cell_timing ($cellref, $clock_ref_pin, $pin, $rise, $active_clk_tran, "sr")); 
      my $setup_f = sprintf("%0.4f", get_cell_timing ($cellref, $clock_ref_pin, $pin, $fall, $active_clk_tran, "sf"));
      pop_timing_corner();
      my $maxsetup = max($setup_r, $setup_f); 

      push_timing_corner("min.${min_corner}");
      my $hold_r = sprintf("%0.4f", get_cell_timing ($cellref, $clock_ref_pin, $pin, $rise, $active_clk_tran, "hr")); 
      my $hold_f = sprintf("%0.4f", get_cell_timing ($cellref, $clock_ref_pin, $pin, $fall, $active_clk_tran, "hf"));
      pop_timing_corner();
      my $maxhold = max($hold_r, $hold_f); 

      if ($opt_flop_details or $opt_latch_details) {
        if ($opt_rf) {
          push(@fresults2, "$cellref\t$num_of_cell\t${pin}->${clock_ref_pin}\t$pcap\t$setup_r\t$setup_f\t$hold_r\t$hold_f\t$area\t$leak");
        } else {
          push(@fresults2, "$cellref\t$num_of_cell\t${pin}->${clock_ref_pin}\t$pcap\t$maxsetup\t$maxhold\t$area\t$leak");
        }
      }

      # Keep track of max values 
      $max_setup_r = max($setup_r, $max_setup_r); 
      $max_setup_f = max($setup_f, $max_setup_f); 
      $max_hold_r = max($hold_r, $max_hold_r); 
      $max_hold_f = max($hold_f, $max_hold_f); 
      $max_ipcap = max($pcap, $max_ipcap);

    }
    my $maxsetup = max($max_setup_r, $max_setup_f); 
    my $maxhold = max($max_hold_r, $max_hold_f); 
 
    # Check all flop outputs

    my $max_delay_r = -10000;
    my $max_delay_f = -10000;
    my $max_trans_r = -10000;
    my $max_trans_f = -10000;
    my $max_cpcap = -10000;
    my $maxpcap = max(map(get_pin_cap($cellref, $_), @flop_in_pins));
    if ($opt_fo3) {
      $load_cap = 3 * $maxpcap;
    } elsif ($opt_fo4) {
      $load_cap = 4 * $maxpcap;
    }
    foreach my $pin (get_outputs_of($cellref)) {
      lprint "OUTPUT_PIN: $pin\n" if $debug;
      my ($driver, $drivef) = get_ref_size_eff_rf (-flag_unknown => $cellref, $pin);
      $driver = sprintf("%0.3f", $driver);
      $drivef = sprintf("%0.3f", $drivef);
      my $drive = min($driver, $drivef);

      ($clock_ref_pin) = get_arc_pins_in_favor_clk($cellref, $pin);
      lprint "CLOCK_REF_PIN: $clock_ref_pin\n" if $debug;
      if (!$clock_ref_pin) {
        lprint "ERROR: Cant find clock pin for $cellref\n";
        next;
      }
      # Select proper tran time based on if this is a rising or falling edge triggered flop
      # TODO: Not sure what the clean way to handle this is 
      my $active_clk_tran = $clkrise;
      if ($clock_ref_pin =~ /N$/) {
        $active_clk_tran = $clkfall;
      } 

      my $pcap = sprintf("%0.5f", get_pin_cap($cellref, $clock_ref_pin));

      push_timing_corner("max.${max_corner}");
      my $maxrdelay = sprintf("%0.4f", get_cell_timing ($cellref, $clock_ref_pin, $pin, $active_clk_tran, $load_cap, "dr")); 
      my $maxfdelay = sprintf("%0.4f", get_cell_timing ($cellref, $clock_ref_pin, $pin, $active_clk_tran, $load_cap, "df"));
      my $maxrtrans = sprintf("%0.4f", get_cell_timing ($cellref, $clock_ref_pin, $pin, $active_clk_tran, $load_cap, "tr")); 
      my $maxftrans = sprintf("%0.4f", get_cell_timing ($cellref, $clock_ref_pin, $pin, $active_clk_tran, $load_cap, "tf"));
      pop_timing_corner();
      my $maxdelay = max($maxrdelay, $maxfdelay); 
      my $maxtrans = max($maxrtrans, $maxftrans); 

      push_timing_corner("min.${min_corner}");
      my $minrdelay = sprintf("%0.4f", get_cell_timing ($cellref, $clock_ref_pin, $pin, $active_clk_tran, $load_cap, "dr")); 
      my $minfdelay = sprintf("%0.4f", get_cell_timing ($cellref, $clock_ref_pin, $pin, $active_clk_tran, $load_cap, "df"));
      my $minrtrans = sprintf("%0.4f", get_cell_timing ($cellref, $clock_ref_pin, $pin, $active_clk_tran, $load_cap, "tr")); 
      my $minftrans = sprintf("%0.4f", get_cell_timing ($cellref, $clock_ref_pin, $pin, $active_clk_tran, $load_cap, "tf"));
      pop_timing_corner();
      my $mindelay = max($minrdelay, $minfdelay); 
      my $mintrans = max($minrtrans, $minftrans); 

      my $dlyvar = sprintf("%0.2f", $maxdelay / $mindelay); 

      # For latches we should have already stored this info above
      if (is_flop_ref_name($cellref) and $opt_flop_details) {
        if ($opt_rf) {
          push(@cresults, "$cellref\t$num_of_cell\t${clock_ref_pin}->${pin}\t$pcap\t$maxrdelay\t$maxfdelay\t$maxrtrans\t$maxftrans\t$minrdelay\t$minfdelay\t$minrtrans\t$minftrans\t$driver\t$drivef\t$dlyvar\t$area\t$leak");
        } else {
          push(@cresults, "$cellref\t$num_of_cell\t${clock_ref_pin}->${pin}\t$pcap\t$maxdelay\t$maxtrans\t$mindelay\t$mintrans\t$drive\t$dlyvar\t$area\t$leak");
        }
      }

      # Keep track of max values 
      $max_delay_r = max($maxrdelay, $max_delay_r); 
      $max_delay_f = max($maxfdelay, $max_delay_f); 
      $max_trans_r = max($maxrtrans, $max_trans_r); 
      $max_trans_f = max($maxftrans, $max_trans_f); 
      $max_cpcap = max($pcap, $max_cpcap);

    }
    my $maxdelay = sprintf("%0.4f", max($max_delay_r, $max_delay_f)); 
    my $maxtrans = sprintf("%0.4f", max($max_trans_r, $max_trans_f)); 

    my $totdly = $maxsetup + $maxdelay;
    my $totwindow = $maxsetup + $maxhold;

    if ($opt_rf) {
      push(@fresults, "$cellref\t$num_of_cell\t$max_delay_r\t$max_delay_f\t$max_trans_r\t$max_trans_f\t$max_setup_r\t$max_setup_f\t$max_hold_r\t$max_hold_f\t$totdly\t$totwindow\t$area\t$leak");
    } else {
      push(@fresults, "$cellref\t$num_of_cell\t$maxdelay\t$maxtrans\t$maxsetup\t$maxhold\t$totdly\t$totwindow\t$area\t$leak");
    }
  }
 
  if (@cresults) {
    if ($opt_rsort) {
      @cresults = sort {(split(/\t/, $b))[$sortby] <=> (split(/\t/, $a))[$sortby]} (@cresults);
    } else {
      @cresults = sort {(split(/\t/, $a))[$sortby] <=> (split(/\t/, $b))[$sortby]} (@cresults);
    }
    if ($opt_rf) {
      unshift(@cresults, "CELL\tNUM\tARC\tPINCAP\tMAXRDLY\tMAXFDLY\tMAXRTRAN\tMAXFTRAN\tMINRDLY\tMINFDLY\tMINRTRAN\tMINFTRAN\tDRIVER\tDRIVEF\tDLYVAR\tAREA\tLEAK");
    } else {
      unshift(@cresults, "CELL\tNUM\tARC\tPINCAP\tMAXDLY\tMAXTRAN\tMINDLY\tMINTRAN\tDRIVE\tDLYVAR\tAREA\tLEAK");
    }
    @cresults = table_tab(@cresults);
    push(@results, @cresults);
    push(@results, "");
    # print_array(@results);
  }

  if (@fresults2) {
    if ($opt_rsort) {
      @fresults2 = sort {(split(/\t/, $b))[$sortby] <=> (split(/\t/, $a))[$sortby]} (@fresults2);
    } else {
      @fresults2 = sort {(split(/\t/, $a))[$sortby] <=> (split(/\t/, $b))[$sortby]} (@fresults2);
    }
    if ($opt_rf) {
      unshift(@fresults2, "CELL\tNUM\tARC\tINCAP\tRSETUP\tFSETUP\tRHOLD\tFHOLD\tAREA\tLEAK");
    } else {
      unshift(@fresults2, "CELL\tNUM\tARC\tINCAP\tSETUP\tHOLD\tAREA\tLEAK");
    }
    @fresults2 = table_tab(@fresults2);
    push(@results, @fresults2);
    push(@results, "");
  }

  if (@fresults) {
    if ($opt_rsort) {
      @fresults = sort {(split(/\t/, $b))[$sortby] <=> (split(/\t/, $a))[$sortby]} (@fresults);
    } else {
      @fresults = sort {(split(/\t/, $a))[$sortby] <=> (split(/\t/, $b))[$sortby]} (@fresults);
    }
    if ($opt_rf) {
      unshift(@fresults, "CELL\tNUM\tMAX_CK->Q_R\tMAX_CK->Q_F\tMAXRTRAN\tMAXFTRAN\tRSETUP\tFSETUP\tRHOLD\tFHOLD\tSETUP+DLY\tSETUP+HOLD\tAREA\tLEAK");
    } else {
      unshift(@fresults, "CELL\tNUM\tMAX_CK->Q\tMAXTRAN\tSETUP\tHOLD\tSETUP+DLY\tSETUP+HOLD\tAREA\tLEAK");
    }
    @fresults = table_tab(@fresults);
    push(@results, @fresults);
  }
 
  @results;
 
END

