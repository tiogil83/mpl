sub check_mcmm_feasibility { 
	my ($cell , $corner_ptr , $new_ref) = @_ ; 
	$DEBUG_cmf and lprint_obj "Chceking <<$cell>> for $new_ref \n";
	my @out_pins = output_pins_of_cell ($cell);
	return 0 if scalar (grep (get_slack (-min => $_) <0 , names_of_objs @out_pins)) > 0  ; 
	my @corners = @{$corner_ptr} ; 
	my $module_num = m_get_ref_name2num (attr_of_cell  (base_design_ref_name => $cell)) ;
	my $base_cell_name = attr_of_cell (base_name => $cell); 
	my $orig_ref = name_of_obj (ref_of_cell ($cell));
	foreach my $corner (@corners) { 
		$DEBUG_cmf and lprint "checking for corner $corner \n";
		set_timing_corner ($corner) ;
		foreach my $out_pin (@out_pins) {
			foreach my $edge_type ("r", "f") { 
				my $slack_attr = $edge_type eq "r" ? "slack_min_r": "slack_min_f";
				my $out_pin_slack = attr_of_pin ($slack_attr => $out_pin) ; 
				next if $out_pin_slack > 1000 ; 
				my @arcs = arcs_of_pins (-to => $out_pin) ;
				foreach my $arc (@arcs)  { 
					$DEBUG_cmf and lprint_obj "<<$arc>>\n";
					   my ($in_pin ) = from_pin_of_arc  ($arc)  ;
					   my $sense = sense_of_arc ($arc) ;
					   my $in_edge_type = ($sense == -1) ? ( ($edge_type eq "r") ? "f" : "r" ) : $edge_type ;
					   my $in_slack_attr = $in_edge_type eq "r" ? "slack_min_r": "slack_min_f";
					   my $in_pin_slack = attr_of_pin ($in_slack_attr => $in_pin) ; 
					   next unless $in_pin_slack eq $out_pin_slack ; 
					   my $to_pin_name = name_of_obj ($out_pin) ; 
					   my $in_pin = name_of_obj $in_pin ; 
					   my $to_flag = $edge_type eq "r" ? "-rise_to" : "-fall_to" ; 
					   my $orig_delay = get_path_delay (-from => $in_pin => $to_flag => $to_pin_name => -delay => "min" => -rtn_delay => -first ) ; 
					   x_change_link ($module_num , $base_cell_name , $new_ref )  ;
					   my $new_delay = get_path_delay (-from => $in_pin => $to_flag => $to_pin_name => -delay => "min" => -rtn_delay => -first) ; 
					   x_change_link ($module_num , $base_cell_name , $orig_ref )  ;
					   my $change_in_delay = $new_delay - $orig_delay ;
					   return 0 if $change_in_delay < 0 and abs ($change_in_delay ) > abs ($out_pin_slack) ; 
				}
			}
		}
			
	}
	return 1 ; 
}


Tsub legalize_sites_full => << 'END';
	DESC {
		Fully legalize specified sites and/or cells according to 20nm conventions
		Specifically, incremental legalization issues are addressed i.e. making the placement as legal as it was before an ECO.
	}
	ARGS {
		-rows_at:@row_coords #Y-values of rows
		-only_report  #Report, but do not fix violations 
		-dont_claim_holes #Do not claim holes
		-eco #Only report/fix errors due to ECOs.  All ECOed rows will be examined.
		-all_rows #Run on all rows.  Default is only rows specified by -rows_at, or ECO rows if -eco is used
	}
	## Always favor vt
	##	-enable:@enable #Allowed values are placement and/or vt.  By default, vt is preferentially adjusted if slack tables are loaded.  Otherwise, placement is preferentially adjusted.
	##---
	## Check enable
	#@enable or @enable = $M_slack_table_loaded ? ("vt") : ("placement");
	#my @bad_enable = grep (!is_member ($_, qw (vt placement)), @enable);
	#@bad_enable and error "Within THIS_SUB, specified invalid enable.  Expected vt or placement.";
	##---
	##my %allow = array_to_hash (@enable);
	my $min_vt_width = attr_of_process ('min_vt_width_def') - $AZERO;
	my $min_vt_width_iso = attr_of_process ('min_vt_width_def') - $AZERO;
	$M_min_vt_width_test and $min_vt_width = $M_min_vt_width_test;
	$min_vt_width > 0 or return ();
	$DEBUG_lesf and lprint "Min vt width : $min_vt_width \n";
	#TODO: also do near neighbor swap i.e. if pre_vt_width is small enough just flip it with current vt, if it would help
	if ($opt_all_rows) { 
		my @all_row_data = get_ref_legal_rows_attr (-module  => $TOP_MODULE ,  row_data  ) ;
		@row_coords = map ( $all_row_data[$_][0] ,  0..$#all_row_data) ;
	}
	my @eco_coords;
	if ($opt_eco and !@row_coords) {
		my %y_eco;
		foreach my $cell_name (attr_of_eco (change_link_cell_names => current_eco ()), attr_of_eco (ever_placed_cell_names => current_eco ())) {
			next unless is_local_inst ($cell_name);
			my ($x, $y) = get_cell_xy ($cell_name);
			$y_eco{$y}++;
		}
		@eco_coords = keys (%y_eco);			
	}
	my $row_count = scalar (@row_coords) + scalar (@eco_coords);
	@eco_coords and lprint "   .. checking $row_count ECOed rows for min VT rule\n";
	#TODO: also do near neighbor swap i.e. if pre_vt_width is small enough just flip it with current vt, if it would help
	foreach my $row_i (@row_coords, @eco_coords) {
		my $site = first_site_of_row (-at => $row_i);
		my $pre_free_width = 0; #Open area to left that can be counted toward meeting current track requirement.  (Only set if there is a hole to left)
		my $pre_vt_width = 0; #Area to left that is already a certain vt type (could be cell or a hole already claimed by a particular vt type)
		my $pre_vt_type; #Required vt type to left
		my $pre_cell;
		my $pre_site;
		my $pre_pre_cell; #last cell for island left of left island
		my $pre_pre_vt_width; #width of island left of left island
		my $past_end = 0;
		while ($site or !$past_end++) {
			my $wipe_left = -1 ;
			my $join_to_pre_site = -1 ; 
			my $this_site = $past_end ? $pre_site : $site;
			my $cell = $site ? cell_of_site ($site) : "";
			$DEBUG_lesf and lprint_obj "\ncurrent site <<$site>> \n";
			if ($cell or $past_end) {
				my ($ref, $width, $vt_type);
				unless ($past_end) {
					#Found a cell
					$ref = ref_of_cell ($cell);
					$width = attr_of_ref (width => $ref);
					$vt_type = attr_of_ref (vt_type_only => $ref);
					$DEBUG_lesf and lprint_obj "-- <<$ref>> ($width), $vt_type <<$cell>> \n ";
				}
				if (!$past_end and $pre_vt_type eq $vt_type) {
 					#Same vt type as previous, so just continue it
					$DEBUG_lesf and lprint_obj "same vt type , adding width $width to pre_vt_width  $pre_vt_width, moving pre_cell to <<$cell>>  \n";
					$pre_vt_width += $width;  
					$pre_cell = $cell;
				} else {
					#Different vt type:
					# Need to check if previous was already wide enough, or else fix it.  Then begin a new vt region
					$DEBUG_lesf and lprint "Checking previous $pre_vt_type (vs $vt_type) island of $pre_vt_width vs $min_vt_width\n";
					$DEBUG_lesf and lprint_obj "pre_cell : <<$pre_cell>> ($pre_vt_type, $pre_vt_width) and pre_pre_cell : <<$pre_pre_cell>> ($pre_pre_vt_type , $pre_pre_vt_width) \n";
					if ($pre_vt_width and $pre_vt_width < $min_vt_width) {
						$DEBUG_lesf and lprint "pre_vt_width is $pre_vt_width \n";
						#Previous vt island is too small
						VT_FIX: {
							if ($pre_vt_type eq 'SVT') {
								#Okay to waive small SVT islands
								$DEBUG_lesf and lprint "previous vt type is SVT, so could be small \n";
								last VT_FIX;
							}
							my $by_eco = ((
								$cell and attr_of_cell (is_eco_base => $cell)) ne ""
								or $pre_cell and attr_of_cell (is_eco_base => $pre_cell) ne "" 
								or $pre_pre_cell and attr_of_cell (is_eco_base => $pre_pre_cell) ne ""
								) ? 1 : 0 ;
							if ($opt_eco and !$by_eco) { 
								#Not caused by ECO.  Do not care.
								last VT_FIX;
							}
							#---
							# Check for isolated VT islands 
							# If not within 1 track of any other VT island (including vertically), the we can use more relaxed rule
							my $tight_cell;
							if ($pre_vt_width >= $min_vt_width_iso) { #Could possibly waive if isolated and iso rule is smaller than default rule
								#No longer applicable in 20 and 16nm processes.  May apply in the future.
								my ($y0_pre, $x1_pre, $height) = attrs_of_site (r0 => c1 => height => $pre_site);
								my $x0_pre = $x1_pre - $pre_vt_width;
								my $y1_pre = $y0_pre + $height;
								my @pre_sites = sites_of_rect ([$x0_pre, $y0_pre, $x1_pre, $y1_pre]);
								my $xy_near = attr_of_process ('track_width');
								my @pre_sites_near = sites_of_rect ([$x0_pre - $xy_near - $AZERO, $y0_pre - $xy_near, $x1_pre + $xy_near + $AZERO, $y1_pre + $xy_near]);
								my @near_sites = get_missing (@pre_sites_near, @pre_sites);
								my $is_near_vt = 0;
								foreach my $near_site (@near_sites) {
									my $near_cell = cell_of_site ($near_site);
									next unless ($near_cell);
									my $near_ref = ref_of_cell ($near_cell);
									my $near_vt_type = attr_of_ref (vt_type_only => $near_ref);
									if ($near_vt_type and $near_vt_type ne "SVT") {
										#Check for touch and one track overlap/space rule
										my ($nx0, $nwidth) = attrs_of_cell (x => width => $near_cell);
										my $nx1 = $nx0 + $nwidth;
										if (
											#On left side with <= 1 track overlap
											   $nx0 < $x0_pre and $nx1 <= $x0_pre + $xy_near
											#On right side with <= 1 track overlap
											or $nx1 > $x1_pre and $nx0 >= $x1_pre - $xy_near
										) {
											$is_near_vt = 1;
											$DEBUG_lesf and lprint_obj "Tighter Vt rule applies to <<$pre_cell>> due to <<$near_cell>>\n";
											$tight_cell = $near_cell;
											last;
										}
									}
								}
								if (!$is_near_vt) {
									$DEBUG_lesf and lprint_obj "Waived <<$pre_cell>> with smaller VT rule because it is isolated from other VT regions\n";
									last VT_FIX;
								}
							}
							#---
							# Need to fix
							#---
							my ($x, $y, $name, $ref_name) = attrs_of_cell (x => y => name => ref_name => $pre_cell) ;
							my $tight_msg;
							$tight_cell and $tight_msg = " due to proximity of <<$tight_cell>>";
							lprint_obj "Cell $name ($ref_name) at [$x, $y] forms an illegal $pre_vt_type island (width $pre_vt_width)$tight_msg\n";
							#---
							if ($opt_only_report) { 
							} else {
								my $pre_rank = rank_of_vt_type (attr_of_ref (vt_type => ref_of_cell ($pre_cell))); #Use full vt type (vt + po)
								my $rank = $past_end ? 1e6 : rank_of_vt_type (attr_of_ref (vt_type => ref_of_cell ($cell)));

								#We just passed an island that was too small (the "pre_*" island)
								#So, should we make the current cell lower vt (faster) to match the island, or should we lower the cell to the left of the island?
								#The answer depends on which change has the smallest impact on timing/power and how much of the previous island would need to be changed.
								#Using area below as an approximate stand-in for timing/power impact.
								#---
								# Find the island to the left of this one
								# Also re-compute pre_vt_width, since the island may be separated by a hole that was previously claimed, but now being overtaken
								my ($pre_pre_ref, $pre_pre_rank, $pre_pre_vt_ref_name);
								if ($pre_pre_cell) {
									$DEBUG_lesf and lprint_obj "cell : <<$cell>>, pre cell  : <<$pre_cell>> ,  pre pre cell <<$pre_pre_cell>> \n";
									COPY (set_pre_pre_cell_info) {
										$pre_pre_ref = ref_of_cell ($pre_pre_cell);
										$pre_pre_rank = rank_of_vt_type (attr_of_ref (vt_type => $pre_pre_ref));
										($pre_pre_vt_ref_name) = get_vt_ref (-highest_po => -usable => name_of_ref ($pre_pre_ref), $pre_vt_type);
									}
									$DEBUG_lesf and lprint "pre pre rank is $pre_pre_rank and pre rank is $pre_rank , current rank $rank \n";
									if ($pre_pre_rank >= $pre_rank) { #Left-side island was higher vt (slower), so it could be made faster
									#### SP : Should not create hold violation 
										$DEBUG_lesf and lprint "left side is higher rank , pre pre rank : $pre_pre_rank, pre rank : $pre_rank \n";
										my $pre_vt_width_full = attr_of_site (width => $pre_site);
										my $pre_pre_site = nearby_site_of_site (-col => -1, $pre_site);
										my $current_cell = cell_of_site ($pre_pre_site) ;
										while (!$current_cell or 
												(updated_cell_of_cell ($current_cell) ne updated_cell_of_cell ($pre_pre_cell)) 
											  ) {
											$DEBUG_lesf and lprint_obj "Moving to left sites untill we move past <<$pre_pre_cell>>, reached <<$current_cell>>, updating pre_vt_width \n";
											$pre_vt_width_full += attr_of_site (width => $pre_pre_site);
											$pre_pre_site = nearby_site_of_site (-col => -1, $pre_pre_site);
											$pre_pre_site or error "Internal Error.  Did not find previous vt island";
											$current_cell = cell_of_site ($pre_pre_site) ;
											$DEBUG_lesf and lprint_obj "<<$pre_pre_site>> <<$current_cell>> and <<$pre_pre_cell>> \n";
										}
										my $went_left = 0;
										while (
											$pre_pre_vt_width > $AZERO 
											and $pre_vt_width < $min_vt_width  #Need to grow island
											and $pre_pre_vt_ref_name #And there is a usable vt for the left-side island
											and 
												$pre_pre_rank < $rank #Left side is closer in rank to island
												|| $pre_pre_rank == $rank && attr_of_ref (area_comp_hier => $pre_pre_ref) < attr_of_ref (area_comp_hier => $ref) #Or same rank but less area than right
												|| $past_end
												|| is_dont_touch_cell ($cell) #Or no choice to go right
											and (!$pre_pre_cell and !(is_dont_touch_cell ($pre_pre_cell)))
										) {
											#Better to takeover left
											$pre_vt_width > $pre_vt_width_full or $pre_vt_width = $pre_vt_width_full; #This just happens on the first iteration as the intervening hole is claimed
											#---
											if ($pre_pre_cell) {
												# Join pre_pre_site with pre_site
												unless (@Min_timing_corners)  { 
													foreach my $table ( grep (/\-type\s+min/ , list_timing_tables))  { 
														my ($timing_corner, $rc_corner) = $table =~ /\-corner\s+(\S+).*\-rc_corner\s+(\S+)/ ; 
														push (@Min_timing_corners , "$timing_corner.${rc_corner}");
													}
												}

												my $feasible = 1 ; 
												#$feasible = check_mcmm_feasibility ( $pre_pre_cell , \@Min_timing_corners, $pre_pre_vt_ref_name) ; 
												last if $feasible == 0 ;
												size_cell (name_of_cell ($pre_pre_cell), $pre_pre_vt_ref_name);
											} else {
												#Just taking over a hole encoutered to the left of a previous pre_pre_cell
											}
											$went_left++;
											COPY (advance_pre_site) {
												my $site_width = attr_of_site (width => $pre_pre_site);
												$pre_vt_width += $site_width;
												$pre_pre_vt_width -= $site_width;
												$pre_pre_site = nearby_site_of_site (-col => -1, $pre_pre_site);
												last unless $pre_pre_site;
												$pre_pre_cell = cell_of_site ($pre_pre_site);
											}
											#Todo:  for 20nm, first cell will be enough, but future processes might also need to take over holes or split holes between pre_site island and left if vt track count increases
											if ($pre_pre_cell) {
												PASTE (set_pre_pre_cell_info);
											}

										}
										if ($went_left and $pre_pre_site and $pre_pre_vt_width > $AZERO and $pre_pre_vt_width < $min_vt_width) {
											#Now left island may have become too small.  In that case, we would need to completely overtake it
											while ($pre_pre_vt_width > $AZERO) {
												if ($pre_pre_cell) {
													PASTE (set_pre_pre_cell_info);
													size_cell (name_of_cell ($pre_pre_cell), $pre_pre_vt_ref_name);
												}
												PASTE (advance_pre_site);
											}
										}
									} #Left-side island was higher vt (slower), so it could be made faster
								}  ### if pre_pre_cell , fix 
							
								if ($pre_vt_width < $min_vt_width) {
									# Still too small, even after overtaking as much as practical to the left.
									# Either need to spread right or wipe out the island
									# If the current island is lower vt, then wipeout the island to match it.  Else let the island spread right over current cell.
									my ($vt_ref_name) = $ref ? get_vt_ref (-highest_po => -usable => name_of_ref ($ref), $pre_vt_type) : "";
									if ($past_end) {
										error "Could not fix undersized VT island involving <<$pre_cell>> at end of row because cells to the left were either dont_touched had dont_used VT types.";
									} elsif (
										!$vt_ref_name
										or is_dont_use ($vt_ref_name)
										or is_dont_touch_cell (-ref => $cell)
										or $rank < $pre_rank  #Current cell is faster.  Do not want to make it slower to match island.
									) {
										$DEBUG_lesf and lprint "Neither left ($pre_pre_rank) nor right ($rank) side could match the island ($pre_rank).  Wipe it out, by either making it match left island or current cell, whichever is closer in vt rank. \n";
										$wipe_left = ($pre_pre_cell and $pre_pre_rank <= $pre_rank and $pre_pre_rank > $rank) ? 1 : 0 ;
										$DEBUG_lesf and lprint "wipe_lef : $wipe_left \n";
										my $pre_vt_type_new = ($wipe_left == 1 )  
											? attr_of_ref (vt_type => ref_of_cell ($pre_pre_cell)) 
												#Better to wipe left (change island to match vt type on left-side island)
											: $vt_type;
										while ($pre_vt_width > $AZERO) {
											my $temp_pre_width = attr_of_site (width => $pre_site);
											$DEBUG_lesf and lprint "substracting $temp_pre_width from $pre_vt_width \n";
											$pre_vt_width -= $temp_pre_width;
											if ($wipe_lef == 0) { 
												$width += $temp_pre_width ;
											} else { 
												$pre_pre_vt_width += $temp_pre_width ;
											}
											my $pre_cell = cell_of_site ($pre_site);
											if ($pre_cell) {
												my $pre_ref = ref_of_cell ($pre_cell);
												my ($vt_ref_name) = $ref ? get_vt_ref (-highest_po => -usable => name_of_ref ($pre_ref), $pre_vt_type_new) : "";
												lprint_obj "ERROR : Didn't find $pre_vt_type_new for <<$pre_ref>> \n" unless $vt_ref_name ;
												size_cell (name_of_cell ($pre_cell), $vt_ref_name) if $vt_ref_name;
											}
											$pre_site = nearby_site_of_site (-col => -1, $pre_site) ;
											$DEBUG_lesf and lprint "pre vt width $pre_vt_width \n";
										}
									} else {
										#---
										$DEBUG_lesf and lprint "Join current site with pre_site (from island) \n";
										$join_to_pre_site = 1 ;
										size_cell (name_of_cell ($cell), $vt_ref_name);
										my $site_width = attr_of_ref (width => $vt_ref_name);
										$pre_vt_width += $site_width;
									}
								} ## pre_vt is still < $min_vt 
							}## not-just reporting  
						}# VT_FIX 
					} ## if pre_vt_width < $min_width 
					if ($wipe_left == 1)  { 
						$pre_pre_cell = $pre_cell;
						## $pre_pre_vt remains the same 
						## $pre_pre_width is already updated above , dont change 
						$pre_vt_type = $vt_type ;
						$pre_cell = $cell ;
						$pre_vt_width = $width ;
					} elsif ($wipe_left == 0)  { 
						$pre_cell = $cell;
						$pre_vt_type = $vt_type ;
						$pre_vt_width = $width ; ## width already upddated
						## width is already update 
						## pre_pre_cell pre_pre_width pre_pre_vt_type  should be as is 
					} else { 
						## default 
						if ($join_to_pre_site == 1 ) { 
							#pre_pre doesnt change 
							#pre_vt_width is already updated (increased) 
							#pre_vt_type doesnt change 
							$pre_cell = $cell ; 
						} else { 
							$pre_pre_cell = $pre_cell;
							$pre_pre_vt_width = $pre_vt_width;
							$pre_pre_vt_type = $pre_vt_type ; 
							$pre_cell = $cell;
							$pre_vt_width = $width;
							$pre_vt_type = $vt_type;
						}
					}
					$DEBUG_lesf and lprint_obj "Updated pre_cell : <<$pre_cell>> ($pre_vt_type, $pre_vt_width) and pre_pre_cell : <<$pre_pre_cell>> ($pre_pre_vt_type, $pre_pre_vt_width)\n";
				}
				if ($pre_free_width) {
					#This occurs if we had just encountered a hole that was not claimed by the previous site.  Combine it with the continuing or new island.
					unless ($opt_dont_claim_holes)  { 
						$pre_vt_width += $pre_free_width;
						$pre_free_width = 0;
						$DEBUG_lesf and lprint "Hole not claimed, hence combining it to continuing new island , new pre_vt_width is $pre_vt_width \n";
					}
				}
			} else {
				$DEBUG_lesf and lprint "Found a hole\n";
				my $width = attr_of_site (hole_width => $this_site);
				unless ($dont_claim_holes) { 
					if ($pre_vt_type ne 'SVT') { 
						if ($pre_vt_width and $pre_vt_width < $min_vt_width and $width > attr_of_process('track_width')) {
							$DEBUG_lesf and lprint "Previous island (involving pre_cell) needs to claim all or part of this hole because it is still too small.\n";
							my $min_allowed_claim = 2 * attr_of_process ('track_width');
							my $need_width = $min_vt_width - $pre_vt_width;
							$need_width = ($need_width < $min_allowed_claim) ? $min_allowed_claim : $need_width ; ## Cant claim less than FILL2
							my $claim_width = min ($need_width, $width);
							$claim_width = (($width - $claim_width) < $min_allowed_claim  ) ? $width : $claim_width ; ## cant create a violation by creating FILL1 
							$pre_vt_width += $claim_width;
							$DEBUG_lesf and lprint "claimed $claim_width, hence new width is $pre_vt_width \n";
							$width -= $claim_width;
						}
					} else { 
						$DEBUG_lesf and lprint "Not claiming hole as pre_vt type is SVT \n";
					}
					$pre_free_width += $width; #Future island can claim leftovers
					$DEBUG_lesf and lprint "	.. unclaimed $pre_free_width.  PRE_width = $pre_vt_width ($pre_vt_type)\n";
				}
			}
			$past_end and last;
			$pre_site = $site;
			$site = nearby_site_of_site (-col => 1, $site);
		} #while site
		
	}
END




















