Tsub capture_merge_vios => << 'END';
    DESC {
        To estimate the violation cover for merging ftm and sa mdoes 
        Need to load violation files first.
    }
    ARGS {
        -dc_merge:$opt_dc_merge   # to specify the merge run datecode 
        -dc_indiv:$opt_dc_indiv   # to sepcify the individual runs datecode 
        -type:$opt_type           # max or min
    }

    if (!$opt_dc_merge || !$opt_dc_indiv || !$opt_type) {
        die "Please specify the datecodes or max/min.\n" ;
    }

    # To get the specified violations.
    my @dc_merges = split (/\s+/, $opt_dc_merge) ;
    my @dc_indivs = split (/\s+/, $opt_dc_indiv) ;

    my $type = $opt_type ;

    my @vios_merges = () ;
    my @vios_indivs = () ; 

    foreach my $dc (@dc_merges) {
        push @vios_merges, (all_vios (-filter => "datecode eq \'$dc\' and slack < 0 and type eq \'$type\'")) ;
    }
    foreach my $dc (@dc_indivs) {
        push @vios_indivs, (all_vios (-filter => "datecode eq \'$dc\' and slack < 0 and type eq \'$type\'")) ;
    }

    # main loop to parse the violations
    my %end_pins_merges = () ; 
    my %end_pins_indivs = () ; 


    foreach my $i (0..$#vios_merges) {
        my $corner    = attr_of_vio ('project_corner'  => "$vios_merges[$i]") ;
        my $end_pin   = attr_of_vio ('end_pin' => "$vios_merges[$i]") ;
        my $start_pin = attr_of_vio ('start_pin' => "$vios_merges[$i]") ;
        my $slack     = attr_of_vio ('slack'   => "$vios_merges[$i]") ;
        $end_pins_merges{$corners}{$end_pin}{$start_pin} = $slack ;
        print "merge $i \n" ;
    }

    foreach my $i (0..$#vios_indivs) {
        my $corner    = attr_of_vio ('project_corner'  => "$vios_indivs[$i]") ;
        my $end_pin   = attr_of_vio ('end_pin' => "$vios_indivs[$i]") ;
        my $start_pin = attr_of_vio ('start_pin' => "$vios_indivs[$i]") ;
        my $slack     = attr_of_vio ('slack'   => "$vios_indivs[$i]") ;
        $end_pins_indivs{$corners}{$end_pin}{$start_pin} = $slack ;
        print "indiv $i\n" ;
    }

    my $unexist_num = 0 ;
    my $worse_num   = 0 ;
    my $better_num  = 0 ;
    my $equal_num   = 0 ;

    my %unexist = () ;
    my %better  = () ;

    foreach my $corner (sort keys %end_pins_indivs) {
        foreach my $end_pin (sort keys %{$end_pins_indivs{$corner}}) {
            foreach my $start_pin (sort keys %{$end_pins_indivs{$corner}{$end_pin}}) {
                if (!exists $end_pins_merges{$corner}{$end_pin}{$start_pin}) {
                    $unexist_num = $unexist_num + 1 ;
                    $unexist{$corner}{$end_pin}{$start_pin} = "Merge : $end_pins_merges{$corner}{$end_pin}{$start_pin} Indiv : $end_pins_indivs{$corner}{$end_pin}{$start_pin}"
                } elsif ($end_pins_merges{$corner}{$end_pin}{$start_pin} > $end_pins_indivs{$corner}{$end_pin}{$start_pin}) { 
                    $worse_num = $worse_num + 1 ;
                } elsif ($end_pins_merges{$corner}{$end_pin}{$start_pin} < $end_pins_indivs{$corner}{$end_pin}{$start_pin}) {
                    $better_num = $better_num + 1 ;
                    $better{$corner}{$end_pin}{$start_pin} = "Merge : $end_pins_merges{$corner}{$end_pin}{$start_pin} Indiv : $end_pins_indivs{$corner}{$end_pin}{$start_pin}"
                } elsif ($end_pins_merges{$corner}{$end_pin}{$start_pin} == $end_pins_indivs{$corner}{$end_pin}{$start_pin}) {
                    $equal_num = $equal_num + 1 ;
                } else {
                    print "Double check $corner $end_pin $start_pin merge : $end_pins_merges{$corner}{$end_pin}{$start_pin} indiv : $end_pins_indivs{$corner}{$end_pin}{$start_pin}\n" ;
                }
            }
        }
    }

    print "Not Covered    : $unexist_num\n" ;
    foreach my $corner (sort keys %unexist) {
        foreach my $end_pin (sort keys %{$unexist{$corner}}) {
            foreach my $start_pin (sort keys %{$unexist{$corner}{$end_pin}}) {
                print "Not Covered : $corner $start_pin $end_pin $unexist{$corner}{$end_pin}{$start_pin}\n"
            }
        }
    }
    print "Worse Covered  : $worse_num\n" ;
    print "Better Covered : $better_num\n" ;
    foreach my $corner (sort keys %better) {
        foreach my $end_pin (sort keys %{$better{$corner}}) {
            foreach my $start_pin (sort keys %{$better{$corner}{$end_pin}}) {
                print "Not Covered : $corner $start_pin $end_pin $better{$corner}{$end_pin}{$start_pin}\n"
            }
        }
    }
    print "Equal Covered  : $equal_num\n" ;

END
