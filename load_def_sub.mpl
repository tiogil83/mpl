Tsub load_def => << 'END';
	if ($OPT_NO_PNR or $Timing_fix_info_only) {
		lprint "Ignored THIS_SUB @_ disabled by -no_pnr at invocation\n";
		return 1;
	}
	DESC {
		Loads specified DEF file.
		If set_verilog_build_from_layout is true, it will also append non-netlist cells and ports to the existing loaded netlist.
		Family: load_layout
		Family: load_files
		See_also: set_verilog_build_from_layout
	}
	ARGS {
		-eco	#Treats the file as an ECO (making it reversible with undo_eco/init_eco and including it in write_eco/write_placement).  Default is to treat it as normal design data.
		-add    #Merges new DEF into old DEF with new DEF overriding old if there are conflicts.
		-route	#Loads routing info from DEF file.  This option is on by default unless mender was invoked with -no_route
		-no_cells  #Skip COMPONENTS section
		-no_ports   #Skip PINS section
		-no_route	#Ignore routing info from DEF file to reduce memory
		-no_lef #Skip loading LEF.  Default is for DEF read to also trigger LEF read.
		-blackbox #Only load pin locations to mesh with a blackboxed netlist
		-replace	#Force new DEF to be loaded.  Default is to ignore repeat invocations and only return a warning.
		-module:$module	#Specify top-level for this DEF.  Default is based on file name
		-rtn_module_names #Return list of modules sourced from this file. 
		-rename:$rename_rule #Apply renaming rule created by define_rename_rule
		-keep_layer_pattern:$layer_pattern #Due to limitations in Perl regexps, DEF routes are limited to 1GB.  This is too small for power grids
			# in many 7nm partitions, and we need to isolate only layers that we care about.  Use this option to specify the layers that
			# must be kept.  Wildcards and alternation are allowed e.g. TM* or M7A|M8A. This may also be set to a default value using set_def_keep_layers()
		$file_name
	}
	if (!$OPT_NO_PLUGINS and defined (&load_util)) {
		load_util (-info_only => 'Technology'); #load technology.pm
	}
	if ($ENV{'MENDER_AUTO_ILM_MODULES'}) {
		lprint "MENDER_AUTO_ILM_MODULES environment variable set.  Applying now ... \n";
		$main::Auto_ilm_applied++ or set_auto_ilm (grep (is_partition_module ($_), find_modules (-quiet => split (/\s+/, $ENV{'MENDER_AUTO_ILM_MODULES'}))));
	}
	if ($main::M_keep_layer_pattern and !$layer_pattern) {
		$layer_pattern = $main::M_keep_layer_pattern;
	}
	#---
	clean_file_name (\$file_name);
	if ($Eco_mode_apply) {
		warn_append "Ignored the following command(s) disabled by eco_apply_mode:", "\n> ECO \"$Eco_name\": load_def @_";
		return 1;
	}
	$opt_blackbox or $opt_blackbox = $Default_load_blackbox;
	$opt_no_route or $OPT_NO_ROUTE or $opt_blackbox or $opt_route = 1;
	my $file_type = $opt_eco ? "DEF ECO" : "DEF";
	-e ($file_name) or error "$file_type input $file_name not found";
	unless ($module) { #Unless user defined
		$module = $file_name;
		$module =~ s/^\S+\///; #Remove dir if present
		$module =~ s/^(\S+?)\..*/$1/;
		$module =~ s/_placement$//;
		$module =~ s/_regions$//;
		$module =~ s/_fp_pin$//;
		$rename_rule and $module = get_rename ($rename_rule, ref => $module); #Also renamed when DESIGN is encountered
		if (!is_module ($module)) {
			$module =~ s/_macro$//;
			is_module ($module) or $module =~ s/_fp$//;
			if (!is_module ($module)) {
				my $test_module = $module;
				$test_module =~ s/_\w+$//;
				if (is_module ($test_module)) {
					$module = $test_module;
				}
			}
		}
	}
	if ($ENV{'MENDER_USE_DEF_CACHE'} and !$M_in_cache_route) {
		launch_def_route_db($file_name, $module);
	}
	$opt_no_lef or &load_lefs (); #Use & to avoid passdown of args from get_args option in load command
	$M_in_cache_route or loaded_project_setup_yaml () or load_project_setup_yaml ('-quiet');
	local $_; #Protect loop variable if used
	my @modules;
	my $module_ref;
	my $module_num;
	if (!is_module ($module)) {
		if ($Verilog_build_from_layout) {
			#Will build later
			
		} elsif ($M_in_cache_route) {
		} else {
			if (is_chip_module ($module)) {
				#Had this as an error earlier, but it messed up T194 SDC gen which depends on loading all DEF to avoid maintaining separate lists for each chiplet
				lprint "WARNING: Module $module netlist should be loaded before DEF file: $file_name.  DEF will not be applied!\n";
				return ();
			} else {
				error "Module $module not recognized (derived from file name $file_name).  Netlists must be loaded before DEF unless you are intentionally using the DEF as a netlist (use set_verilog_build_from_layout for that purpose).";
			}
		}
	} else {
		$module_ref = ref_of_name ($module);
		$module_num = x_num_of_ref ($module_ref);
	}
	if (!$opt_replace and !$opt_add and !$opt_eco and $M_place_info{$module}{$file_type}) {
		warning "Ignored attempt to load a second DEF file for module $module.  Use one of -replace|-add|-eco if you want to force it.";
		return 0;
	}
	else {
		delete $M_route{$module}; #Reset route cache (even if -add so that new routes are honored)
	}
	save_top ();
	$Save_legal_placement = $Eco_legal_placement;
	$Save_legal_port_placement = $Eco_legal_port_placement;
	if ($opt_eco) {
		set_eco_legal_placement ('off'); #Must be off because incoming cell order is not guaranteed to be legal at every moment until the end
		set_eco_legal_port_placement ('off'); 
	}
	my $rows_reset = 0;
	my $bad_net_cnt = 0;
	my @bad_net_example = ();
	my $for_leaf = 0;
	my @maybe_ilm_blocks;
	my $has_props;
	if ($file_name =~ /\.gz$/) {
		open (IN, "/bin/gunzip -c --stdout $file_name |") or error "$file_type input $file_name not found";
	}
	else {
		open (IN, $file_name) or error "$file_type input $file_name not found";
	}
	my $route_msg = $opt_route ? "with route" : "no route";
	aprint "Reading $file_type ($route_msg):  $file_name ";
	my %compass2angle = (
		N => 0,
		W => 90,
		S => 180,
		E => 270,
	);
	my ($pct, $incr_pct, $incr_size) = get_chunk_info ($file_name);
	my $load_size;	
	my $size_cmp = $incr_size;
	my $blank_pct;
	my $pct_msg;
	my $net_cnt = 0;
	my $unit = 0.001;
	my ($x0, $y0) = (0, 0); #origin
	my ($line, $port, $inst);
	my $miss_cnt;
	my $miss_example;
	my $total_cnt;
	my $flop_cnt_partial;
	my $file_sep = $/;
	$/ = ";";  #Slurp to end of rule
	my $unplaced_cnt;
	my $min_row_data;
	my %special_net;
	my $unit_conflict = 0;
	my @move_cells;
	my $has_non_n_ports;
	my ($port_cnt, $cell_cnt, $net_cnt); 
	while (<IN>) {
		COPY (track_load) {
			$load_size += length;
			if (remove_def_comments()) {
				#Final semicolon was commented out, so add next line
				while (!/;$/) {
					my $next_line = <IN>;
					last unless (length ($next_line));
					$next_line =~ s/\#.*//gm;
					$_ .= $next_line;
				}
			}
			if ($load_size > $size_cmp and !$opt_eco) {
				$pct_msg = "$pct%..";
				print $blank_pct, $pct_msg;
				$blank_pct = "\b" x length($pct_msg); 
				$pct += $incr_pct;
				$size_cmp += $incr_size;
			}
		}
		s/^\s+//s;
		if (/^PINS/) {
			if ($opt_no_ports or $M_in_cache_route) {
				while (!/^\s*END/s) {
					$_ = <IN> or error "Premature end of $file_type $file_name (within PINS section)";
					PASTE (track_load);
				}
				s/^\s*END \S+\s*//s;
				redo;
			}
			my ($port);
			local $M_geo_quiet = 1;
			GET_PINS: while (<IN>) {
				PASTE (track_load);
				last GET_PINS unless $_;
				PARSE_PIN: {
					if (/^\s*\-\s+(\S+)/s) {
						$port = $1;
						$port =~ s/\\//go;
					} elsif (!length ($_) or /^\s*END/s) {
						s/^\s*END \S+\s*//s;
						last GET_PINS;
					} else {
						error "Expected to find port name in port section.  Found: @{[substr ($_, 0, 100)]}";
					}
				}
				$port_cnt++;
				my $is_phys_port;
				#---
				# Set physical info if found
				my ($layer, $mask, $xp0, $yp0, $xp1, $yp1, $type, $x, $y, $orient);
				my $eco_move;
				if (
					($type, $x, $y, $orient) = /\+\s+(PLACED|FIXED|COVER)\s+\(\s*(\S+)\s+(\S+)\s*\)\s*(\S+)/s
				) { 
					my $first_pos = pos ();
					my $poly;
					my $is_poly_first = /\+\s+(LAYER|POLYGON)/ && $1 eq "POLYGON";
					!$is_poly_first and ($layer) = /\+\s+LAYER\s+(\S+)/ and ($xp0, $yp0, $xp1, $yp1) = /\(\s+(\S+)\s+(\S+)\s+\)\s+\(\s+(\S+)\s+(\S+)\s+\)/s
						or #Support rectangular polygons, used in ICC floorplanning
						($layer) = /\+\s+POLYGON\s+(\S+)/ and ($poly) = /\(\s*([^\+\;]+)/s;
					COPY (process_poly) {
						if ($poly) {
							#Polygon
							$poly =~ tr/\(\)/  /;
							my @pts = split (/\s+/, $poly);
							if ($poly =~ /\*/) {
								for (my $i = 0; $i < @pts; $i++) {
									next unless $pts[$i] eq '*';
									$i >= 2 or error "Did not expect '*' before second coordinate in polygon definition: ($poly";
									$pts[$i] = $pts[$i - 2];
								}
							}
							$x0 || $y0 and error "Not expecting non (0,0) origin (DIEAREA origin) for POLYGON blockages.  Please ask Cad-Backend-Tools\@nvidia.com to add support.";
							##@pts = map ($_ * $unit, @pts);
							my $bound = bound_of_xys (@pts);
							clean_bound ($bound);
							local $main::M_geo_quiet = 1;
							my @rects = rects_of_bound (-force_rect => $bound);
							if (@rects == 1) {
								clean_rect ($rects[0]);
								($xp0, $yp0, $xp1, $yp1) = @{$rects[0]};
							} else {
								my $enc_rect = enclosing_rect_of_bound ($bound);
								($xp0, $yp0, $xp1, $yp1) = @{$enc_rect};
							}
						}
					}
					($mask) = /MASK\s+(\S+)/;
                                        pin_transform_to_north(\$x, \$y, \$orient, \$xp0, \$yp0, \$xp1, \$yp1);
					$orient eq "N" or $has_non_n_ports = 1;
					$is_phys_port = $port =~ /\.extra\d+/;
					if ($opt_eco) { 
						$eco_move = [$port, $x * $unit - $x0, $y * $unit - $y0, -bound => [$xp0, $yp0, $xp1, $yp1], -orient => $orient, -layer => $layer];
					} else {
						#x, y, side, layer, bound_x0, bound_y0, bound_x1, bound_y1
						$M_layer2num{$layer} or create_layers ($layer);
						$M_xy_port{$module}{$port} = [$x * $unit - $x0, $y * $unit - $y0, undef, $M_layer2num{$layer},$xp0*$unit, $yp0*$unit, $xp1*$unit, $yp1*$unit, $orient, $mask];
						if ($Route_create_map) {
							set_xy_map2 ($layer, [[m_get_xy_f2i ($xp0*$unit, $yp0*$unit, $xp1*$unit, $yp1*$unit)]], 0);
						}

						if ($type eq "FIXED" or $type eq "COVER") {
							$M_xy_port_fixed{$module_num}{$port} = 1;
						}
						if ($opt_blackbox and !$for_leaf) {
							my $inst;
							foreach ("BBOX_DRV_$port", "BBOX_LOAD_$port") {
								if (is_local_inst($_)) {
									$inst = $_;
									last;
								}
							}
							$inst and x_move_cell ($module, $inst, $x * $unit - $x0, $y * $unit - $y0);
						}
						my @other_ports;
						if (/\+ PORT/ and !$opt_eco) {
							s/\+ PORT/; PORT/g; #Replace with semicolons to make loop below consistent:
							/\+\s+(PLACED|FIXED|COVER)/gs;
							my $first_pos = pos ();
							while (/ PORT\s(.*?);/gs) {
								my $port_pos = pos ();
								next unless ($port_pos > $first_pos);
								my $port_ln = $1;
								my ($type, $px, $py, $porient) = $port_ln =~ /\+\s+(PLACED|FIXED|COVER)\s+\(\s*(\S+)\s+(\S+)\s*\)\s*(\S+)/s;
								if (!defined ($px)) {
									($px, $py, $porient) = ($x, $y, $orient); #Default to main port, if not specified
								}
								my ($layer, $mask, $xp0, $yp0, $xp1, $yp1, $poly);
								($layer) = $port_ln =~ /\+\s+LAYER\s+(\S+)/ and ($xp0, $yp0, $xp1, $yp1) = $port_ln =~ /\(\s+(\S+)\s+(\S+)\s+\)\s+\(\s+(\S+)\s+(\S+)\s+\)/s
									or #Support rectangular polygons, used in ICC floorplanning
									($layer) = $port_ln =~ /\+\s+POLYGON\s+(\S+)/ and ($poly) = $port_ln =~ /\(\s*([^\+\;]+)/s;
								($mask) = $port_ln =~ /MASK\s+(\S+)/;
								PASTE (process_poly);
								push (@other_ports, 
									[$px * $unit - $x0, $py * $unit - $y0, undef, $M_layer2num{$layer},$xp0*$unit, $yp0*$unit, $xp1*$unit, $yp1*$unit, $porient, $mask]
								);
								$M_layer2num{$layer} or create_layers ($layer);
								if ($Route_create_map) {
									set_xy_map2 ($layer, [[m_get_xy_f2i ($xp0*$unit, $yp0*$unit, $xp1*$unit, $yp1*$unit)]], 0);
								}
							}
						}
						scalar (@other_ports) and $M_xy_port{$module}{$port}[PORT_MULTI_PTR] = \@other_ports;
					}
				}
				if ($Verilog_build_from_layout or $is_phys_port) {
					#Must come at end so regexp does not overwrite one above!
					my $dir;
					if ($is_phys_port) {
						#Use internal port to represent physical_only ports in netlist
						$dir = "n";
					} else {
						/DIRECTION\s*(\w+)/ and $dir = $M_dir_abbr{$1};
					}
					my $port_num;
					unless ($port_num = $M_port_nums_src{$module_num}{$port} and m_get_port_num2dir ($module_num, $port_num) eq $dir) {
						$dir and set_module_port($module_num, $dir, $port);
					}
					if ($is_phys_port) {
						my $net;
						if (/\+\s+NET\s+(\S+)/) {
							$net = $1;
							$net =~ s/\\//go;
						}
						if ($net) {
							unless (m_is_net_m ($module, $net)) {
								m_create_net ($module, $net);
							}
							my $net_obj = net_of_name (-design => $module_ref, $net);
							my $port_obj = port_pin_of_name (-design => $module_ref, $port);
							$M_phys_port2net{$module_ref}{$port_obj} = $net_obj;
							push (@{$M_net2phys_ports{$module_ref}{$net_obj}}, $port_obj);
						} else {
							warning "Within THIS_SUB for module $module, no NET found for physical port $port";
						}
					}
				}
				unless ($is_phys_port) {
					/ USE\s+(POWER|GROUND)/ and set_power_net (-val => (($1 eq "POWER") ? 1 : 0), $port);
					if ($eco_move and !x_same_xy ($M_xy_port{$module}{$port}, [@{$eco_move}[1, 2]])) {
						move_port (@$eco_move);
					}
				}
			}
			redo;
		}
		elsif (/^VIAS/) {
			if ($opt_eco or $M_in_cache_route) {
				COPY (skip_eco_section) {
					$M_in_cache_route or info_once "Only processing PINS and COMPONENTS in DEFs loaded with -eco switch.  Other sections are ignored.";
					while (<IN>) {
						PASTE (track_load);
						if (!length ($_) or /^\s*END/s) {
							s/^\s*END \S+\s*//s;
							last;
						}
					}
					redo;
				}
			} else {
				while (<IN>) {
					PASTE (track_load);
					last unless $_;
					if (/^\s*\- \S+/s) {
						process_def_via ($_, $file_name);
					} elsif (!length ($_) or /^\s*END/s) {
						s/^\s*END \S+\s*//s;
						last;
					} else {
						 error "Expected to find via name in VIAS section.  Found @{[substr ($_, 0, 100)]}";
					}
				}
				redo;
			}
		}
		elsif (/^COMPONENTS/) {
			if ($opt_no_cells or $M_in_cache_route) {
				while (!/^\s*END/s) {
					$_ = <IN> or error "Premature end of $file_type $file_name (within COMPONENTS section)";
					PASTE (track_load);
				}
				s/^\s*END \S+\s*//s;
				redo;
			}
			my ($x, $y, $orient, $ref);
			while (1) {
				$_ = <IN> or error "Premature end of $file_type $file_name (within COMPONENTS section)";
				PASTE (track_load);
				if (/^\s*END/s) {
					s/^\s*END \S+\s*//s;
					last;
				}
				next if $opt_blackbox;
				next if $for_leaf;
				/^\s*\- (\S+)\s+(\S+)/g 
					or /^\s*\#/g and s/^\s*\#.*?\n//s and /^\s*\- (\S+)\s+(\S+)/g
					or error "Unexpected line in COMPONENTS section:  @{[substr ($_, 0, 100)]}";
				$cell = $1;
				$ref = $2;
				$total_cnt++;
				if ($flop_cnt_partial < 200 and is_module ($ref) and is_flop_ref_name ($ref)) {
					$flop_cnt_partial++;
				}
				my $fixed = 0;
				$cell_cnt++;
				my $is_placed = 1; #Clear below if untrue
				COPY (process_placement) {
					if (($x, $y, $orient) = /\G\s+\+ PLACED\s+\(\s*(\S+)\s+(\S+)\s*\)\s*(\S+)/gc) {
					} elsif (($x, $y, $orient) = /\G\s+\+ FIXED\s+\(\s*(\S+)\s+(\S+)\s*\)\s*(\S+)/gc and $fixed = 1) {
					} elsif (($x, $y, $orient) = /\G\s+\+ COVER\s+\(\s*(\S+)\s+(\S+)\s*\)\s*(\S+)/gc and $fixed = 1) {
					} else {
				}
						/\G\s+\+ SOURCE\s+\S+/gc;
						/\G\s+\+ HALO/gc;
						PASTE (process_placement);
							$is_placed = 0;
						}
					}
				$cell =~ s/\\//g;
				if ($rename_rule) {
					$ref = get_rename ($rename_rule, ref => $ref);
					$cell = get_rename ($rename_rule, cell => $cell);
				}
				$is_placed or ++$unplaced_cnt;
				if ($is_placed) {
					if ($orient =~ s/^F//) {
						$orient .= "-m";
						$orient =~ tr/WE/EW/;  #switch to match Milkyway and Magma convention which has mirror before rotation
					}
					$orient =~ s/^(\w)/$compass2angle{$1}/;
					exists $compass2angle{$1} or error "Bad orientation $1 for placement of cell $cell in @{[substr ($_, 0, 100)]}";
				}
				if ($XY_lock_fillers and is_fill_ref ($ref)) {
					$fixed = 1;
				}
				my $fill_cell;
				if ($inst_num = x_get_inst_name2num_top ($cell)
					or $cell =~ /xofiller/ 
						and !$XY_lock_fillers #Handle in elsif below
						and $fill_cell = filler2spare_name ($cell)
						and $inst_num = x_get_inst_name2num_top ($fill_cell)
						and $cell = $fill_cell
				) {
					if ($is_placed) {
						$x = $x * $unit - $x0;
						$y = $y * $unit - $y0;
						if ($opt_eco) {
							unless (x_same_xyo ($M_xy_top{$cell}, [$x, $y, $orient])) {
								l_move_cell ($cell, $x, $y, $orient);
								push (@move_cells, [$cell, $x, $y, $orient]);
							}
						} else {
							$M_xy_top{$cell} = [$x, $y, $orient];
							unless ($opt_no_legal) {
								substr ($M_xyp_top, $inst_num * $XY_WIDTH, 12) = m_get_xy_f2p ($x, $y) . 
									pack ('C4', 0, $fixed, 0, $M_orient_nums{$orient}); #M_xyp_pos = 0, fixed, priority, orient
							}
						}
					}
				}
				elsif ($Verilog_build_from_layout || $XY_lock_fillers) {
					is_module ($ref) or create_module (-no_undo => $ref);
					is_local_inst ($cell) or x_create_cell ($module_num, $cell, $ref);
					if ($is_placed) {
						$x = $x * $unit - $x0;
						$y = $y * $unit - $y0;
						x_move_cell ($TOP_MODULE, $cell, $x, $y, $orient, $fixed);
					}
				}
				elsif ($cell =~ /$M_maybe_fill_cell/ || $ref =~ /filler/i and !$opt_eco) {
					#Don't warn since fillers are often added well before tapeout during trial runs
				}
				elsif ($cell) {
					$miss_cnt++;
					$miss_example or $miss_example = $cell;
					if ($is_placed) {
						my $ref_num = x_get_ref_name2num ($ref);
						if (!$ref_num) {
							warn_append ("Missing library and physical data for the following unknown cell types in $file_type $file_name.  Ignored these cells:  ", " " . $ref);
						}
						elsif ($M_attr_src[$ref_num][WIDTH]) { #If known width, calculate blockage now.  Otherwise (e.g. for macros) postpone for apply_ilm_blockages()
							if ($orient =~ /90|270/) {
								push (@maybe_ilm_blocks, m_get_xy_f2p ($x, $y, $x + $M_attr_src[$ref_num][HEIGHT], $y + $M_attr_src[$ref_num][WIDTH]));
							} else {
								push (@maybe_ilm_blocks, m_get_xy_f2p ($x, $y, $x + $M_attr_src[$ref_num][WIDTH], $y + $M_attr_src[$ref_num][HEIGHT]));
							}
						} else {
							push (@{$M_ilm_blockage{$module}}, m_get_xy_i2p($ref_num) . m_get_xy_f2p ($x, $y) . pack ('l*', $M_orient_nums{$orient}));
						}
					}
				}
				if ($has_props) {
					my %prop_vals = /\+\s+PROPERTY\s+(\S+)\s+(\S+)/g;
					if (scalar keys %prop_vals) {
						my $cell_obj = cell_of_name (-quiet => $cell);
						if ($cell_obj) {
							$M_def_prop{$cell_obj} = \%prop_vals; 
						}
					}
				}
			}
			redo;
		}
		elsif (/^BLOCKAGES/) {
			if ($opt_eco or $M_in_cache_route) {
				PASTE (skip_eco_section);
			} else {
				local $M_geo_quiet = 1;
				while (!/^\s*END/s) {
					$_ = <IN> or error "Premature end of $file_type $file_name (within BLOCKAGES section)";
					PASTE (track_load);
					next if $opt_blackbox;
					next if $for_leaf;
					/^\s+\- (LAYER\s*\S*)/gsc or /^\s+\- (\S+)/gsc or next;
					/\G\s*\+\s+MASK\s+\S+\s+/gsc;
					my $type = $1;
					my $is_layer = $type =~ /^LAYER/;
					my $layer;
					$is_layer and ($layer) = $type =~ /LAYER (\S+)/;
					my $is_soft = 0;
					my $other_fields = ''; #For partial, soft, pushdown fields, etc
					while (pos () < length ()) {
						/\G\s*\;/gsc || /\G\s*\-/gsc and last;
						if (/\G\s*(RECT)/gsc or /\G\s*(POLYGON)/gsc) {
							my @block_packs;
							if ($1 eq 'RECT') {
								unless (/\G\s*\(\s*(\S+)\s+(\S+)\s*\)\s*\(\s*(\S+)\s+(\S+)\s*\)/gsc) {
									/\G(\s*\S*\s*\S*)/gsc;
									error "Expected rectangle coordinates after RECT in blockages.  Found $1.";
								}
								@block_packs = (m_get_xy_f2p ($1 * $unit - $x0, $2 * $unit - $y0, $3 * $unit - $x0, $4 * $unit - $y0));
							} else {
								#Polygon
								my ($bound) = /\G\s*\(\s*([^\+\;]+)/gsc 
									or error "Expected POLYGON after + POLYGON for boundary.";
								$bound =~ tr/\(\)/  /;
								my @pts = split (/\s+/, $bound);
								if ($bound =~ /\*/) {
									for (my $i = 0; $i < @pts; $i++) {
										next unless $pts[$i] eq '*';
										$i >= 2 or error "Did not expect '*' before second coordinate in polygon definition: ($bound";
										$pts[$i] = $pts[$i - 2];
									}
								}
								$x0 || $y0 and error "Not expecting non (0,0) origin (DIEAREA origin) for POLYGON blockages.  Please ask Cad-Backend-Tools\@nvidia.com to add support.";
								@pts = map ($_ * $unit, @pts);
								my $bound = bound_of_xys (@pts);
								clean_bound ($bound);
								my @rects = rects_of_bound (-force_rect => $bound);
								if (@rects) {
									@block_packs = (map (m_get_xy_f2p (@{$_}), @rects));
								} else {
									lprint "WARNING (ERROR) Incomplete boundary for blockage ($type).  Ignoring this blockage:  @{$bound}\n";
								}
							}
							push (@{$M_blockage{$module}{$type}{$other_fields}}, @block_packs);
							if (!$is_soft and $Route_create_map) {	
								foreach my $block_pack (@block_packs) {
									set_xy_map2 ($type eq 'PLACEMENT' ? 'cell' : $layer, [[m_get_xy_p2i ($block_pack)]], 0);
								}
							}
						} else {
							/\G(\s*\+\s+SPACING\s+\S+)/gsc and $is_layer 
							or /\G(\s*\+\s+PUSHDOWN)/gsc
							or /\G(\s*\+\s+EXCEPTPGNET)/gsc
							or /\G(\s*\+\s+FILLS)/gsc
							or /\G(\s*\+\s+PARTIAL\s*\S+)/gsc and $is_soft = 1 #Density/soft blockage
							or /\G(\s*\+\s+SOFT)/gsc and $is_soft = 1 #Density/soft blockage 
							or /\G(\s+)/gsc #Plain whitespace
							or /\G(.*)/gsc and warning "Did not find expected blockage bounds in file $file_name for line: $_.  Found $1";
							$other_fields .= $1;
						}
					}
					if (/\G\s*(\S+)/gsc) {
						$1 eq "LAYER" or error "Unsupported field \"$1\" found in BLOCKAGES section of DEF";
					}
				}
				s/^\s*END \S+\s*//s;
				redo;
			}
		}
		elsif (/^SPECIALNETS/) {
			if ($opt_eco) {
				PASTE (skip_eco_section);
			} else {
				my $special_label = "SPECIAL\n";
				COPY (process_nets) {
					if ($ENV{'MENDER_USE_DEF_CACHE'} and !$M_in_cache_route) {
						$M_def_route{$module} = {};
						$M_def_db{$module} = $file_name;
						last; #Cache will handle it	
					}
					$opt_eco and error "NETS/SPECIALNETS field not supported for load_def -eco.  If this is not an ECO DEF, leave off the -eco flag.";
					$unit_conflict and error "DEF file \"$file_name\" for module $module has units ('UNITS DISTANCE MICRONS' attribute) that are inconsistent with previous DEF file(s) for this module.  Route updates are not supported for this case.  (Use get_files -type def to see previously loaded DEF files).";
					my $auto_ilm = $main::M_auto_ilm_module{$module};
					my $is_ilm_net = $auto_ilm ? get_io_hash (-nets => $module) : {};
					if ($opt_route) {
						my ($net, $net_num);
						my $max_len = 2**30 - 1;
						GET_NETS: while (1) {
							$_ = <IN> or error "Premature end of $file_type $file_name (within NETS/SPECIALNETS section)";
							PASTE (track_load);
							NET_PARSE: {
								if (length($_) > $max_len and !$ENV{"MENDER_NO_DEF_FILTER"}) {
									#Hack to reduce to Perl's supported regexp size by filtering out irrelevant metal layer (M0)
									my $shorter_net;
									my $step_len = 2**24 - 1;
									my $layer_pattern_rgx = glob2regex_space_list_txt($layer_pattern);
									my $eat_now = 0;
									my $eat_nxt = 0;
									for ($i = 0; $i < length($_); $i += $step_len) {
										my @part_defs;
										if ($Route_discard_shield) {
											# Remove cases where it straddles across segmented regions
											$rstr = substr($_, $i + $eat_nxt, $step_len - $eat_nxt);
											$eat_nxt = 0;
											my $back_track = 9900;
											if (length($rstr > ($back_track + 100))) {
												my $estr = substr($rstr, -$back_track) . substr ($_, $i + $step_len, $back_track);
												while ($estr =~ /(\+\s+SHIELD[^;\+]+)/g) {
													if (pos($estr) > $back_track and pos($estr) - length($1) < $back_track) {
														$eat_now = $back_track - (pos($estr) - length($1));
														$eat_nxt = pos($estr) - $back_track;
														last;
													}
												}
											}
											if ($eat_now) {
												$rstr = substr($rstr, 0, -$eat_now);
												$eat_now = 0;
											}
											if ($rstr =~ /SHIELD/) {
												$rstr =~ s/\+\s+SHIELD[^;\+]+//gs;
											}
											@part_defs = split(/\n/, $rstr);
											
											
										} else {
											@part_defs = split(/\n/, substr($_, $i, $step_len));
										}
										my $first_ln = shift(@part_defs); # possibly incomplete
										my $last_ln = pop(@part_defs); # possibly incomplete
										if ($layer_pattern) {
											@part_defs = grep (/$layer_pattern_rgx/o
												|| ((!/ NEW /o) && !/ M[0-8]/o && !/DRCFILL/o && !/ [TV]M\d/o)
											, @part_defs);
										} else {
											@part_defs = grep ((!/ NEW /o || /VIA/o) && !/ M[01456]/o && !/DRCFILL/o && !/ TM\d/o, @part_defs);
											#---
											# Shrink unneeded data for power DRCs:
											@part_defs = grep (!(!/VIA/o && /^  \+ FIXED/o), @part_defs);
										}
										grep (s/\+ SHAPE FOLLOWPIN /+ SHAPE Z /, @part_defs);
										grep (s/\+ MASK \d+//, @part_defs);
										grep (s/ MASK \d+//, @part_defs);
										grep (s/^\s+//, @part_defs);
										#---
										$shorter_net .= $first_ln . "\n";
										$shorter_net .= join("\n", @part_defs);
										$shorter_net .= "\n" . $last_ln;
									}
									$_ = $shorter_net;
									if (length($_) > $max_len) {
										lprint("WARNING: Net $net is beyond limits of pack_def_route handling\n");
									}
								}
								if (substr($_, 0, 2000) =~ /^\s*\- (\S+)/s) {
									$net = $1;
								} elsif (!length ($_) or substr($_, 0, 20) =~ /^\s*END/s) {
									s/^\s*END \S+\s*//s;
									last GET_NETS;
								} elsif (substr($_, 0, 20) =~ /^\s*#/ and s/^\s*#.*?\n//s) {
									redo NET_PARSE;
								} else {
									#length ($_) < (2**31 - 1) 
									#	or error "Found an unexpectedly long routing definition.  Currently, the maximum supported string length is 2**31.  "
									#	. "If you do not need routing data, you can start mender using the -no_route option (-mender_args -no_route -in timingshell).  "
									#	. "Or if support is required (such as for mender fixall), please email $SUPPORT_EMAIL.\n"
									#	. "This route is unexpectedly long:\n@{[substr ($_, 0, 500)]} ..."; 
									error "Expected to find net name in net section.  Found @{[substr ($_, 0, 100)]}";
								}
								$net_cnt++;
								$net =~ s/\\//go;
								$net_num = x_get_net_name2num_top ($net);
								if (!$net_num) {
									if ($Verilog_build_from_layout || $M_in_cache_route) {
										$net_num = x_create_net ($module_num, $net);
									} else {
										if (is_port ($net) or $net =~ /VDD|VSS|GND|VAUX|mojave_filler/i) { #Dangling port
										} else {
											$bad_net_cnt++; 
											push (@bad_net_example, $net);
										}
										$Route_create_map or next GET_NETS;
									}
								}
								if ($auto_ilm) {
									$is_ilm_net->{x_net_of_num ($net_num)} or next GET_NETS;
								}
								if ($Verilog_build_from_layout) {
									my $route_pos = 
										/\+ (?:ROUTED|COVER|FIXED|NOSHIELD|SHIELD)/g ? pos ($_)
										: length ($_);
									foreach my $conn (substr ($_, 0, $route_pos) =~ /\(\s+(\S+\s+\S+)/gs) {
										my ($inst, $ref_pin) = split (/\s+/, $conn);
										$inst =~ s/\\//go;
										if ($rename_rule) {
											$inst = get_rename ($rename_rule, cell => $inst);
										}
										$ref_pin =~ s/\\//go;
										if ($inst eq "*") {
											#Global connect
											my $inst_idx_n = $#M_inst_names_top;
											foreach my $inst_num (V_PACK_LIST_INST_START .. $inst_idx_n) {
												my $ref_num = vec ($M_inst_packs_src[$module_num][$inst_num], V_PACK_INST_REF_NUM, 32);
												my $port_num = m_get_pin_name2num_q ($ref_num, $ref_pin);
												$port_num and x_connect_net_num ($module_num, $net_num, $inst_num, $ref_num, $port_num);
											
											}
										} elsif ($inst eq 'PIN') {
											#Port connect 
											unless ($ref_pin =~ /\.extra\d*$/) {
												x_connect_port ($module_num, $net, $ref_pin);
											}
										} elsif (m_is_inst ($module_num, $inst)) {
											x_connect_net ($module_num, $net, $inst, $ref_pin, '-f');
										}
									}
								}
								my $is_pg;
								if (length($_) < 2**31) {
									/ USE\s+(POWER|GROUND)/ and ($is_pg = 1) and set_power_net (-val => (($1 eq "POWER") ? 1 : 0), $net);
								} else {
									substr($_, -1000) =~ / USE\s+(POWER|GROUND)/ and ($is_pg = 1) and set_power_net (-val => (($1 eq "POWER") ? 1 : 0), $net);
								}
								if (length($_) > 2**29 or s/^.*?(\bNEW |\+)/$1/s) { #Jump past pin definitions, and only save route if pins are present
									if (length($_) > 2**29) {
										#Cannot rely on full string regex
										my $route_start = 0;
										my $head = substr($_, 0, 100);
										if ($head =~ /\b(NEW |\+)/g) {
											$route_start = pos($head) - length($1);
										} else {
											my $head = substr($_, 0, 900000000);
											if ($head =~ /\b(NEW |\+)/g) {
												$route_start = pos($head) - length($1);
lprint "Route start at for $net at $route_start\n";
											}
										}
										$_ = substr($_, $route_start);
									}
									if ($Route_create_map) { 
										if ($is_pg) {
											$net_num or $net_num = x_create_net_top_q ($net);
											lprint " .. creating route map for net $net ($module)\n";
										}
										pack_def_route2 ($special_label ? ('-special') : (), $_, 0, $net_num, 0);
									} 
									if ($net_num || $M_in_cache_route) {
										my $primary_key = $M_in_cache_route ? substr($net, 0, 2) : $TOP_MODULE;
 										if ($special_label) {
											$M_def_route{$primary_key}{$net} = $special_label . $_;
											$special_net{$net}++;
										} elsif ($special_net{$net}) {
											$M_def_route{$primary_key}{$net} .= "\nCONT " . $_; #Append net to special net
										} else {
											$M_def_route{$primary_key}{$net} = $_; 
										}
									}
								}
								
							}
						}
						redo;
					} else { #!opt_route
						while (!/^\s*END/s) {
							$_ = <IN> or error "Premature end of $file_type $file_name (within NETS/SPECIALNETS section)";
							PASTE (track_load);
						}
						s/^\s*END \S+\s*//s;
						redo;
					}
				}
			}
		}
		elsif (/^NETS/) {
			if ($opt_eco) {
				PASTE (skip_eco_section);
			} else {
				my $special_label = "";
				PASTE (process_nets);
			}
		}
		elsif (s/^\s*END \S+\s*//s) { #Must have been an END for an unsupported construct
			redo;
		}
		elsif (/UNITS DISTANCE MICRONS (\d+)/) {
			my $f2i = $1; #Floating point to int map
			$unit = 1 / $f2i;
			if (!$opt_replace and $M_def_unit_factor{$module} and !almost_equal ($M_def_unit_factor{$module}, $unit)) {
				$unit_conflict = 1;
				warning "DEF for module $module uses units that conflict with a previous setting.  This can cause incorrect routing to be generated.  Conflict seen in file:  $file_name";
			} else {
				$M_def_unit_factor{$module} = $unit;
				$M_xy_f2i_factor{$module} = $f2i;
			}
		}
		elsif (/^DIEAREA /) {
			if ($opt_eco or $M_in_cache_route) {
			} else {
				if (tr/\(/\(/ > 2) {
					my ($bound_list) = /DIEAREA\s*(\(.*\))/s;
					length ($bound_list) or error "Did not find expected DIEAREA bounds for line: @{[substr ($_, 0, 100)]}";
					($x0, $y0) = set_module_bound (-rtn_origin => $module, -unit => $unit, $bound_list);
				} else {
					my (@bounds) = /DIEAREA\s*\(\s*(\S+)\s+(\S+)\s*\)\s*\(\s*(\S+)\s+(\S+)\s*\)/s;
					@bounds == 4 or error "Did not find expected DIEAREA bounds for line: @{[substr ($_, 0, 100)]}";
					($x0, $y0) = set_module_bound (-rtn_origin => $module, -unit => $unit, -rect => @bounds);
				}
			}
		}
		elsif (/^NONDEFAULTRULES/) {
			if ($opt_eco) {
				PASTE (skip_eco_section);
			} else {
				while (<IN>) {
					PASTE (track_load);
					my $rule;
					while (/\+ [^"]+"[^"]+$/) {
						#Missing close quote.  Must be a semicolon in middle of string, so append next
						$_ .= (<IN> or last);
					}
					s/\+ //g;
					if (/^\s*\- (\S+)/sg) {
						$rule = $1;
					} elsif ($_ eq "\n") {
						next;
					} elsif (!length ($_) or /^\s*END/s) { #No length would indicate end of file
						s/^\s*END \S+\s*//s;
						last;
					} else {
						error "Expected nondefault rule name, but found '@{[substr ($_, 0, 100)]}' within NONDEFAULTRULES section of $file_type $file_name";
					}
					/\G\s+/sgc; #Skip whitespace
					my ($layer);
					while (/\G(\S+)/gc) {
						$1 eq "LAYER" and /\G\s+(\S+)/sgc and $layer = $1
						or $1 eq "SPACING" and /\G\s+(\S+)/sgc and $M_layer_attr{$layer}{"s"}{"$rule:$module_num"} = $1 * $unit
						or $1 eq "WIDTH" and /\G\s+(\S+)/sgc and $M_layer_attr{$layer}{"w"}{"$rule:$module_num"} = $1 * $unit
						or $1 eq "VIA" and /\G\s+(\S+)/sgc 
						or $1 eq "PROPERTY" and (/\G\s+\S+\s+\".*?\"/sgc or /\G\s+\S+\s+\S+/sgc); #Quoted or unquoted prop value	
						/\G\s+/sgc; #Skip whitespace
					}
				}
				redo;
			}
		}
		elsif (/^ROW/) {
			unless ($opt_eco or $M_in_cache_route) { #Ignore if -eco
				$rows_reset++ or $M_row_list{$module} = {}; #reset
				my ($type, $row_name, $site_name, $x, $y, $orient, $do, $x_cnt, $by, $y_cnt, $step, $x_width, $y_width) = split (/\s+/, $_);
				foreach $num ($x, $y, $x_width, $y_width) { $num *= $unit }
				if ($orient =~ s/^F//) {
					$orient .= "-m";
					$orient =~ tr/WE/EW/;  #switch to match Milkyway and Magma convention which has mirror before rotation
				}
				$orient =~ s/^(\w)/$compass2angle{$1}/;
				exists $compass2angle{$1} or error "Bad orientation $1 for placement of cell $cell in @{[substr ($_, 0, 100)]}";
				my $row_data = [$x - $x0, $y - $y0, $M_orient_nums{$orient}, $x_cnt, $y_cnt, $x_width, $y_width, $site_name];
				my $offset_idx = ($y_cnt > 1) ? 0 : 1; #Use x-value for vertical row offsets, y-value for horizontal
				if (!$min_row_data or ${$row_data}[$offset_idx] < ${$min_row_data}[$offset_idx]) {
					$min_row_data = $row_data;
				}
				push (@{$M_row_list{$module}{m_get_xy_f2i($y)}}, $row_data);
			}
		}
		elsif (/^TRACKS/) {
			unless ($opt_eco) {
				my ($dir, $start, $count, $space, $layer, $mask); 
				($dir, $start) = /TRACKS\s+(\S+)\s+(\S+)/;
				($count) = /DO\s+(\S+)/;
				($space) = /STEP\s+(\S+)/;
				($mask) = /MASK\s+(\S+)/;
				($layer) = /LAYER\s+(\S+)/;
				foreach my $num ($start, $space) { $num *= $unit }
				my $track_data = [$start, $count, $space, $mask];
				push (@{$M_track_list{$module}{$layer}{$dir}}, $track_data);
			}
		}
		elsif (/^REGIONS/) {
			# Example:
			# REGIONS 85 ;
			# - aes ( 504699 237299 ) ( 574700 317100 ) + TYPE GUIDE ; 
			# - alu0_h_add ( 398300 277200 ) ( 413000 317100 ) + TYPE GUIDE ; 
			# END REGIONS
			if ($opt_eco or $M_in_cache_route) {
				PASTE (skip_eco_section);
			} else {
				while (!/^\s*END/s) {
					$_ = <IN> or error "Premature end of $file_type $file_name (within REGIONS section)";
					PASTE (track_load);
					last unless $_;
					next if $for_leaf;
					my $name;
					if (/^\s*\- (\S+)/gs) {
						$name = $1;
						@{$M_region{$module}{$name}} = ();
						while (pos () < length ()) {
							/\G\s*\;/gsc and last;
							if (/\G\s*\+\s*TYPE\s+(\S+)/gsc) {
								$M_region_data{$module}{$name} = [$1];
								next; 
							}
							/\G\s*\(\s*(\S+)\s+(\S+)\s*\)\s*\(\s*(\S+)\s+(\S+)\s*\)/gsc 
								or error "Did not find correctly formatted region bounds for line: @{[substr ($_, 0, 100)]}";
							push (@{$M_region{$module}{$name}}, m_get_xy_f2p ($1 * $unit - $x0, $2 * $unit - $y0, $3 * $unit - $x0, $4 * $unit - $y0));
						}
						/\G\s*(\S+)/gsc and error "Unsupported field \"$1\" found in BLOCKAGES section of DEF";
					} elsif (!length ($_) or /^\s*END/s) {
						s/^\s*END \S+\s*//s;
						last;
					} else {
						 error "Expected to find properly formatted REGIONS definition.  Found @{[substr ($_, 0, 100)]}";
					}
				}
				delete $M_region{$module}{"*DEFAULT*"}; #Reset default
				redo;
			}
		}
		elsif (/^GROUPS/) {
			# Example:
			# GROUPS 83 ;
			# - alu0_h_add
			#      fps_int\/int_fp0\/alu\/high\/add
			#      fps_int/int_fp0/alu/high/add*
			#      + REGION alu0_h_add ;
			# - alu1_h_near 
			#      fps_int\/int_fp1\/alu\/high\/near
			#      fps_int/int_fp1/alu/high/near*
			#      + REGION alu1_h_near ;
			# END GROUPS
			while (!/^\s*END/s) {
				$_ = <IN> or error "Premature end of $file_type $file_name (within REGIONS section)";
				PASTE (track_load);
				last unless $_;
				next if $for_leaf;
				my $name;
				if (/^\s*\- (\S+)/gs) {
					$name = $1;
					%{$M_group{$module}{$name}} = ();
					while (pos () < length ()) {
						/\G\s*\;/gsc and last;
						if (/\G\s*\+\s*REGION\s+(\S+)/gsc) {
							$M_group{$module}{$name}{'region'} = $1;
							next; 
						}
						if (/\G\s*(\S+)/gsc) {
							my $patt = $1;
							$patt =~ s/\\//g;
							push (@{$M_group{$module}{$name}{'patts'}}, $patt);
							next;
						}
					}
				} elsif (!length ($_) or /^\s*END/s) {
					s/^\s*END \S+\s*//s;
					last;
				} else {
					 error "Expected to find properly formatted GROUPS definition.  Found @{[substr ($_, 0, 100)]}";
				}
			}
			redo;
		
		}
		elsif (/^DESIGN\s+(\S+)/) {
			if ($Verilog_build_from_layout or $M_in_cache_route) {
				$module = $1;
				$rename_rule and $module = get_rename ($rename_rule, ref => $module); #Also renamed above based on file name to match
				if (!$Verilog_replace_modules and is_module ($module)) {
					#Already loaded
				} else {
					create_module (-no_undo => -overwrite => $module, -lib => 'def');
				}
				$module_ref = ref_of_name ($module);
			}
			lprint " (module $module)\n";
			$main::M_auto_ilm_module{$module} and lprint " .. Auto ILM is applied to module $module\n";
			if ($opt_replace) {
				delete $M_phys_port2net{$module_ref};
				delete $M_net2phys_ports{$module_ref};
			}
			if (is_leaf ($module)) {
				$for_leaf = 1;
			} else {
				set_top ($module);
			}
			$module_num = m_get_ref_name2num ($module);
			if ($for_leaf) {
				$opt_route = 0;
			}
			elsif (!($opt_eco or $opt_add and defined ($M_xy{$module}))) {
				delete $M_blockage{$module};
				defined ($M_ilm_blockage_limit) or $M_ilm_blockage_limit = 10; 
				@{$M_ilm_blockage{$module}} = ();
				if (!exists $M_xy{$module}) {
					$M_xy{$module} = {};
					$M_xyp{$module} = "";	
				}
				unless ($opt_no_legal) {
					$M_xyp{$module} .= pack ('l*', $XY_MISSING_CODE, $XY_MISSING_CODE, 0) x (@M_inst_names_top - length ($M_xyp{$module}) / $XY_WIDTH); 
				}
				*M_xy_top = $M_xy{$module};
				*M_xyp_top = \$M_xyp{$module};
				length $M_xyp_top == (@M_inst_names_top * $XY_WIDTH) or error "Mismatch in M_xyp size";
				delete $M_xy_map{$module};
				$XY_WIDTH == 12 or error "Internal error.  Need to update M_xyp pack";
			}
			else {
				unless ($opt_no_legal) {
					$M_xyp{$module} .= pack ('l*', $XY_MISSING_CODE, $XY_MISSING_CODE, 0) x (@M_inst_names_top - length ($M_xyp{$module}) / $XY_WIDTH); 
				}
				*M_xy_top = $M_xy{$module};
				*M_xyp_top = \$M_xyp{$module};
				length $M_xyp_top == (@M_inst_names_top * $XY_WIDTH) or error "Mismatch in M_xyp size";
				$XY_WIDTH == 12 or error "Internal error.  Need to update M_xyp pack";
			}
			push (@modules, $module);
		}
		elsif (/^(PROPERTYDEFINITIONS)/) {
			my $section = $1;
			s/$section//;
			$has_props = 1;
			while (!/^\s*END/s
				and !/^\s*PINS /s #Workaround for prior mender bug
			) {
				$M_def_prop_defs{$module} .= $_;
				PASTE (track_load);
				$_ = <IN> or error "Premature end of $file_type $file_name (within $section section)";
			}
			s/^\s*END \S+\s*//s;
			$M_def_prop_defs{$module} =~ s/\b(END \S+).*/$1/s;
			redo;
		}
		elsif (/^(FILLS|SCANCHAINS|PINPROPERTIES)/) {
			while (!/^\s*END|\nEND /s) {
				$_ = <IN> or error "Premature end of $file_type $file_name (within $section section)";
				PASTE (track_load);
			}
			s/^\s*END \S+\s*//s or s/.*\nEND \S+\s*//s;
			redo;
		}
		elsif (/^(VERSION|DIVIDERCHAR|BUSBITCHARS|TECHNOLOGY|GCELLGRID|NAMESCASESENSITIVE|COMPONENTMASKSHIFT)/) {
		}
		elsif (/^\s*$/) {
		}
		else {
			/(\S+\s*\S*)/;
			lprint " .. Ignoring section '$1' in DEF\n";
		}
	}
	close (IN);
	$/ = $file_sep;
	unless ($opt_eco) {
		print $blank_pct;
		lprint "100%..";
		$M_place_info{$module}{$file_type} = get_file_full_path ($file_name);
	}
	$port_cnt or $port_cnt = 0;
	$cell_cnt or $cell_cnt = 0;
	$net_cnt or $net_cnt = 0;
	lprint "  [$port_cnt ports, $cell_cnt cells, $net_cnt nets]\n";
	$OPT_LOAD_SPEF and auto_load_rc ();
	if ($M_abuf_place{$module}) {
		lprint " .. placing previously created assign buffers\n";
		foreach my $cell_net (@{$M_abuf_place{$module}}) {
			my ($cell, $out_net) = @$cell_net;
			if (attr_of_ref_pin (is_placed => "$module/$out_net")) {
				x_move_cell ($module, $cell, get_pin_xy ($out_net));
			}
		}
		delete $M_abuf_place{$module};
	}
	restore_top ();
	delete $M_set_fixed_dont_touch{$module};
	if ($miss_cnt) {
		my $miss_cnt_pct = sprintf ("%.1f", $miss_cnt / $total_cnt * 100);
		if ($miss_cnt_pct > $M_ilm_blockage_limit) {
			info "Treated $module DEF as an ILM DEF.  ($miss_cnt_pct% of cells were not found in the netlist and were treated as blockages.  Use set_ilm_blockage_limit if the missing cells should instead be ignored.)";
			push (@{$M_blockage{$module}{'PLACEMENT'}{''}}, @maybe_ilm_blocks);
		} else {
			warning ("$miss_cnt cells ($miss_cnt_pct\%) found in $module DEF, but not netlist e.g. $miss_example.  "
				. "The extra DEF cells have been ignored.  Decrease the ilm_blockage_limit (see man set_ilm_blockage_limit) if they should instead be treated as blockages");
		}
	}
	
	!@bad_net_example or warning "Found $bad_net_cnt net(s) in $module DEF, but not in netlist.  Ignored these net(s) e.g. " . join (", ", @bad_net_example[0..min ($#bad_net_example, $Def_error_limit, 1)]);
	$unplaced_cnt and warning "Found $unplaced_cnt cell(s) marked as UNPLACED in DEF.  Perhaps you unintentionally have a prelayout DEF?";
	delete $M_region_sorted{$module};
	unless ($opt_eco) {
		$PDEF_INFO{$module}++;
		delete $M_xy_map{$module};
		delete $M_donors_identified{$module};
		delete $M_res_calc{$module};
	}
	if ($M_row_list{$module} and $min_row_data) {
		my $vert_rows = ${$min_row_data}[$XY_row_y_cnt] > 1;
		$M_place{$module}{"dir"} = $vert_rows ? "v" : "h";
		$M_place{$module}{"row_offset"} = ${$min_row_data}[$vert_rows ? $XY_row_x : $XY_row_y];
		$M_place{$module}{"row_step"} = ${$min_row_data}[$vert_rows ? $XY_row_x_width : $XY_row_y_width];
		$M_place{$module}{"col_offset"} = ${$min_row_data}[$vert_rows ? $XY_row_y : $XY_row_x];
		$M_place{$module}{"col_step"} = ${$min_row_data}[$vert_rows ? $XY_row_y_width : $XY_row_x_width];
		$M_place{$module}{"row_defined"} = 1;
	}
	$XY_max_priority = 254;
	%XY_centroid = ();
	$M_steiner_tree_net = "";
	$_ = $save;
	$has_non_n_ports and set_enable_port_orientation ('on');
	if ($opt_eco) {
		set_eco_legal_placement ($Save_legal_placement);
		undef $Save_legal_placement;
		set_eco_legal_port_placement ($Save_legal_port_placement);
		undef $Save_legal_port_placement;
		# Need a second pass to actually legalize cells now that they are in desired locations.  
		# Legalizing earlier would move cells out of the way in the wrong order
		foreach my $move (@move_cells) {
			l_move_cell (@$move);
		}
	}
	reset_abutments ();
	reset_pr_cache ();
	if ($flop_cnt_partial > 195 or $total_cnt > 0.05 * scalar (@{$M_inst_names_src[$module_num]}) ) {
		#This is for detection that partial placement has already been loaded during model_delays and budgeting
		$main::M_partial_placement{$module} = 1;
	}
	set_files (-type => THIS_SUB => $file_name);
	delete $M_def_db_read{$module};
	if ($M_in_cache_route) {
		foreach my $name_key (keys %M_def_route) {
			write_def_route_db($file_name, $module, $name_key, $M_def_route{$name_key});
		}
		lprint("Writing dir\n");
		write_def_dir_db($file_name, $module, [keys %M_def_route]);
	}
	$opt_rtn_module_names ? (wantarray ? @modules : join (" ", @modules)) : 1;
END
