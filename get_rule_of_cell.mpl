Tsub get_rule_of_cell => << 'END';
    DESC {
        To get the routeRule of retime cell 
    }
    ARGS {
        @objs
    }

    if (!@objs) {
        error "No cells listed.\n" ;
        return () ;
    }

    ################
    ### env vars ###
    ################

    my $chip      = $CONFIG->{CHIP_NAME};
    my $litter    = $CONFIG->{LITTER_NAME} ;
    my $chip_root = `depth` ; 
    chomp $chip_root ;

    ###################################
    ### parsing routeRules pm files ###
    ###################################

    my $routeRulesdir = "$chip_root/ip/retime/retime/1.0/vmod/include/interface_retime" ;
    my %Rules = () ;
    my @allRules = () ;

    my @chiplets = sort keys %{$CONFIG->{partitioning}{chiplets}} ;
    foreach my $chiplet (@chiplets) {
        my $routeRulesFile = "$routeRulesdir/interface_retime_${litter}_${chiplet}_routeRules.pm" ;
        if (-e $routeRulesFile) {
    
            my $Rule_name = "" ;
            my $Rule_pipe = "" ;
    
            open IN, "$routeRulesFile" or die "Can't open file $routeRulesFile\n" ;
            while (<IN>) {
                chomp ;
                my $line = $_ ;
                if ($line =~ /\s+name\s+=>\s+\"(\S+)\"/) {
                    $Rule_name = $1 ;
                    push @allRules, $Rule_name ;
                } elsif ($line =~ /.*pipeline_steps.*=>\s+\"(\S+)\"/) {
                    $Rule_pipe = $1 ;
                    foreach my $pipe (split (",", $Rule_pipe)) {
                        $Rules{$chiplet}{$Rule_name}{$pipe} = 1 ;
                    }
                }
            }
            close IN ;
        } else {
            next ;
        }
    }
 
    ############################
    ### to print the reports ###
    ############################
    my $max_chiplet = get_array_max_length (@chiplets) ;
    my $max_rule    = get_array_max_length (@allRules) ;
    my $max_obj     = get_array_max_length (@objs) ;
    my $find_flg    = 0 ;

    foreach my $cell_name (@objs) {
        if ($cell_name =~ /_retime_.*_RT/) {
            my $pipe = $cell_name ;
            $pipe =~ s/.*_RT.*?_(\S+?)\/.*/$1/ ; 
            foreach my $chiplet (sort keys %Rules) {
                foreach my $rule (sort keys %{$Rules{$chiplet}}) {
                    if (exists $Rules{$chiplet}{$rule}{$pipe}) {
                        printf ("%${max_obj}s : %${max_chiplet}s %${$max_rule}s\n", $cell_name, $chiplet, $rule) ;
                        $find_flg = 1 ;
                    } 
                }
            }
            if (!$find_flg) {
                printf ("%${max_obj}s : Not Found Any Matched Rule.\n", $cell_name) ;
            }
        } else {
            printf ("%${max_obj}s : Not a Retime flop.\n", $cell_name) ;
        }
    }


END

sub get_array_max_length {
    my @input = @_ ;
    my $max   = 0  ;
    foreach (@input) {
        my $length = length ($_) ;
        #print "$length\n" ;
        if ($length > $max) {
            $max = $length ;
        }
    }
    return $max ;
}

