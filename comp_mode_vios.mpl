use strict ;

Tsub comp_mode_vios => << 'END';
    DESC {
        To check the vios coverage between modes.
        Usage : 
            comp_mode_vios -ref_mode "shift" -impl_mode "shift_xtr shift_tam"
    }
    ARGS {
        -ref_mode:$ref_mode     #to specify the refernence mode.
        -impl_mode:$impl_modes  #to specify the implement modes. 
    }

if (!(defined $ref_mode) || !(defined $impl_modes)) {
    die ("Need the options for reference mode and implement modes\n") ;
}

print "Reference mode      : $ref_mode\n" ;
print "Implementation mode : $impl_modes\n" ;

# parsing reference violations
my @ref_vios = () ;
my %ref_vio  = () ;

my $filter = "(mode eq ${ref_mode}_max or mode eq ${ref_mode}_min) and (type eq 'max' or type eq 'min') and slack < 0" ;
#print "$filter\n" ;
@ref_vios = all_vios (-filter => "$filter") ;

foreach my $i (0..$#ref_vios) {
    my $corner  = attr_of_vio ('project_corner' => "$ref_vios[$i]") ;
    my $end_clk = attr_of_vio ('end_clk' => "$ref_vios[$i]") ;
    my $end_pin = attr_of_vio ('end_pin' => "$ref_vios[$i]") ;
    my $slack   = attr_of_vio ('slack'   => "$ref_vios[$i]") ;
    if (!(exists $ref_vio{$corner}{$end_pin})) {
        $ref_vio{$corner}{$end_pin} = $slack ;
    } elsif ($ref_vio{$corner}{$end_pin} > $slack) {
        $ref_vio{$corner}{$end_pin} = $slack ;
    } else {
        next ;
    }
    #print "REF $corner $end_clk $end_pin $slack\n" ;
    #if ($end_clk eq 'test_serdes1f_clk_st_ph0_xtr' || $end_clk eq 'test_serdes1f_clk_s0_nst_xtr' || $end_clk eq 'test_serdes1f_clk_st_ph1_xtr' || $end_clk eq 'test_core_clk_leg') {
    #    foreach my $j (0..7) {
    #        $end_clk = "test_serdes1f_clk_st${j}_xtr" ;
    #        $ref_vio{$corner}{$end_clk}{$end_pin} = $slack ;
    #        #print "REF $corner $end_clk $end_pin $slack\n" ;
    #    }
    #    $ref_vio{$corner}{test_core_clk_leg}{$end_pin} = $slack ;
    #    $ref_vio{$corner}{test_serdes1f_clk_st_ph0_xtr}{$end_pin} = $slack ;
    #    $ref_vio{$corner}{test_serdes1f_clk_st_ph1_xtr}{$end_pin} = $slack ;
    #    #print "REF $corner test_core_clk_leg $end_pin $ref_vio{$corner}{test_core_clk_leg}{$end_pin}\n" ;
    #} 
    #print "REF $end_pin $corner $end_clk $slack\n" ;
}

# main loop

my %impl_only   = () ;
my %impl_worse  = () ;
my %impl_better = () ;
my %impl_equal  = () ;

my $flg_only   = 0 ;
my $flg_worse  = 0 ;
my $flg_better = 0 ;
my $flg_equal  = 0 ;

my %impl_only_hist = () ;
my %impl_worse_hist = () ;

open FIL, "> FILTERED.txt" ;

my @modes = split (/\s+/, $impl_modes) ;
foreach my $impl_mode (@modes) {
    #print "reference mode      : $ref_mode\n" ;
    #print "implementation mode : $mode\n" ;
    my $impl_filter =  "(mode eq ${impl_mode}_max or mode eq ${impl_mode}_min) and (type eq 'max' or type eq 'min') and (start_par !~ /UNKNOWN/ and end_par !~ /UNKNOWN/) and slack < 0" ;
    #print "$impl_filter\n" ;
    my @impl_vios = () ;
    @impl_vios = all_vios (-filter => "$impl_filter") ;
    foreach my $i (0..$#impl_vios) {
        my $corner  = attr_of_vio ('project_corner' => "$impl_vios[$i]") ;
        my $mode    = attr_of_vio ('mode' => "$impl_vios[$i]") ;
        my $end_clk = attr_of_vio ('end_clk' => "$impl_vios[$i]") ;
        my $end_pin = attr_of_vio ('end_pin' => "$impl_vios[$i]") ;
        my $slack   = attr_of_vio ('slack'   => "$impl_vios[$i]") ;
        #print "IMPL $mode $end_pin $corner $end_clk $slack $ref_vio{$corner}{$end_clk}{$end_pin}\n" ;
        if (!(exists $ref_vio{$corner}{$end_pin})) {
            if ($end_pin =~ /\/d$/) {
                print FIL "$end_pin $slack\n" ;
                next ;
            }
            $impl_only{$mode}{$corner}{$end_clk}{$end_pin} = $slack ;
            foreach my $j (0..9) {
                my $th1 = -($j*0.003) ;
                my $th2 = -($j+1)*0.003 ;
                if ($slack < $th1 && $slack >= $th2) {
                    if (exists $impl_only_hist{$mode}{$corner}{$th1}) {
                        $impl_only_hist{$mode}{$corner}{$th1} = $impl_only_hist{$mode}{$corner}{$th1} + 1 ;
                    } else {
                        $impl_only_hist{$mode}{$corner}{$th1} = 1 ;
                    }
                }  
            }
            if ($slack < -0.03) {
                if (exists $impl_only_hist{$mode}{$corner}{-0.03}) {
                    $impl_only_hist{$mode}{$corner}{-0.03} = $impl_only_hist{$mode}{$corner}{-0.03} + 1 ;
                } else {
                    $impl_only_hist{$mode}{$corner}{-0.03} = 1 ;
                }
            }
            $flg_only = 1 ;
        } elsif ($slack > $ref_vio{$corner}{$end_pin}) {
            #print "$mode $corner $end_pin $slack $ref_vio{$corner}{$end_pin} \n" ;
            $impl_better{$mode}{$corner}{$end_clk}{$end_pin} = $slack ;
            $flg_better = 1 ;
        } elsif ($slack < $ref_vio{$corner}{$end_pin}) {
            #print "$mode $corner $end_pin IMPL : $slack REF : $ref_vio{$corner}{$end_pin}\n" ;
            my $diff = $slack - $ref_vio{$corner}{$end_pin} ; 
            foreach my $j (0..9) {
                my $th1 = -($j*0.003) ;
                my $th2 = -($j+1)*0.003 ;
                if ($diff < $th1 && $diff>= $th2) {
                    if (exists $impl_worse_hist{$mode}{$corner}{$th1}) {
                        $impl_worse_hist{$mode}{$corner}{$th1} = $impl_worse_hist{$mode}{$corner}{$th1} + 1 ;
                    } else {
                        $impl_worse_hist{$mode}{$corner}{$th1} = 1 ;
                    }
                }
            }
            if ($slack < -0.03) {
                if (exists $impl_worse_hist{$mode}{$corner}{-0.03}) {
                    $impl_worse_hist{$mode}{$corner}{-0.03} = $impl_worse_hist{$mode}{$corner}{-0.03} + 1 ;
                } else {
                    $impl_worse_hist{$mode}{$corner}{-0.03} = 1 ;
                }
            }
            $impl_worse{$mode}{$corner}{$end_clk}{$end_pin} = $slack ;
            $flg_worse = 1 ;
        } else {
            $impl_equal{$mode}{$corner}{$end_clk}{$end_pin} = $slack ;
            $flg_equal = 1 ;
        } 
    }
}

close FIL ;

# dump reports
my $pwd = $ENV{PWD} ;
if ($flg_only) {
    print "\nViolations only exists in implementation modes:\n" ;
    print "Detailed report file : $PWD/IMPL_ONLY.txt\n\n" ;
    open OUT, "> IMPL_ONLY.txt" ;
    foreach my $mode (sort keys %impl_only) {
        print "$mode : \n\n" ;
        my @corners = keys %{$impl_only{$mode}} ;
        my $length  = get_max_array_length (@corners) ; 
        foreach my $corner (sort keys %{$impl_only{$mode}}) {
            printf ("%-${length}s : ", $corner) ;
            my $pin_num = 0 ;
            foreach my $end_clk (sort keys %{$impl_only{$mode}{$corner}}) {
                foreach my $end_pin (sort keys %{$impl_only{$mode}{$corner}{$end_clk}}) {
                    $pin_num = $pin_num + 1 ;
                    print OUT "ONLY $mode $corner $end_clk $end_pin REF_SLACK : $impl_only{$mode}{$corner}{$end_clk}{$end_pin}\n" ;
                }
            }
            print "$pin_num \n" ;
            print "-" x 122 ;
            print "\n" ;
            foreach my $i (0..10) {
                my $th = -$i*0.003 ;
                printf ("|%9s " , $th) ;
            }
            print "|\n" ;
            print "-" x 122 ;
            print "\n" ;
            foreach my $i (0..10) {
                my $th = -$i*0.003 ;
                printf ("|%9s " , $impl_only_hist{$mode}{$corner}{$th}) ;
            }
            print "|\n" ;
            print "-" x 122 ;
            print "\n" ;
        }
    }
    close OUT ;
}

if ($flg_worse) {
    print "\nViolations worse in implementation modes:\n" ;
    print "Detailed report file : $PWD/IMPL_WORSE.txt\n\n" ;
    open OUT, "> IMPL_WORSE.txt" ;
    foreach my $mode (sort keys %impl_worse) {
        print "$mode : \n\n" ;
        my @corners = keys %{$impl_worse{$mode}} ;
        my $length  = get_max_array_length (@corners) ;
        foreach my $corner (sort keys %{$impl_worse{$mode}}) {
            printf ("%-${length}s : ", $corner) ;
            my $pin_num = 0 ;
            foreach my $end_clk (sort keys %{$impl_worse{$mode}{$corner}}) {
                foreach my $end_pin (sort keys %{$impl_worse{$mode}{$corner}{$end_clk}}) {
                    $pin_num = $pin_num + 1 ;
                    my $diff = $impl_worse{$mode}{$corner}{$end_clk}{$end_pin} - $ref_vio{$corner}{$end_pin} ;
                    print OUT "WORSE $corner $end_clk $end_pin IMPL_SLACK : $impl_worse{$mode}{$corner}{$end_clk}{$end_pin} REF_SLACK : $ref_vio{$corner}{$end_pin} DIFF : $diff\n" ;
                }
            }
            print "$pin_num \n" ;
            print "-" x 122 ;
            print "\n" ;
            foreach my $i (0..10) {
                my $th = -$i*0.003 ;
                printf ("|%9s " , $th) ;
            }
            print "|\n" ;
            print "-" x 122 ;
            print "\n" ;
            foreach my $i (0..10) {
                my $th = -$i*0.003 ;
                printf ("|%9s " , $impl_worse_hist{$mode}{$corner}{$th}) ;
            }
            print "|\n" ;
            print "-" x 122 ;
            print "\n" ;
        }
    }
    close OUT ;
}

if ($flg_better) {
    #print "Violations better in implementation modes:\n" ;
    #print "Detailed report file : IMPL_BETTER.txt\n" ;
    open OUT, "> IMPL_BETTER.txt" ;
    foreach my $mode (sort keys %impl_better) {
        #print "\t$mode : \n" ;
        my @corners = keys %impl_better ;
        my $length  = get_max_array_length (@corners) ;
        foreach my $corner (sort keys %{$impl_better{$mode}}) {
            #printf ("\t\t%-${length}s : ", $corner) ;
            my $pin_num = 0 ;
            foreach my $end_clk (sort keys %{$impl_better{$mode}{$corner}}) {
                $pin_num = $pin_num + 1 ;
                print OUT "BETTER $corner $end_clk $end_pin IMPL_SLACK : $impl_better{$mode}{$corner}{$end_clk}{$end_pin} REF_SLACK : $ref_vio{$corner}{$end_pin}\n" ;
            }
        }
    }
    close OUT ;
}

if ($flg_equal) {
    open OUT, "> IMPL_EQUAL.txt" ;
    foreach my $mode (sort keys %impl_equal) {
        foreach my $corner (sort keys %{$impl_equal{$mode}}) {
            foreach my $end_clk (sort keys %{$impl_equal{$mode}{$corner}}) {
                foreach my $end_pin (sort keys %{$impl_equal{$mode}{$corner}{$end_clk}}) {
                    print OUT "EQUAL $end_pin $mode $corner $end_clk: $impl_equal{$mode}{$corner}{$end_clk}{$end_pin} $ref_vio{$corner}{$end_pin}\n" ;
                }
            }
        }
    }
    close OUT ;
}


sub get_max_array_length {
    my @array = @_ ;
    my $max_leng = 0 ;
    foreach (@array) {
        my $length = length $_ ;
        if ($length > $max_leng) {
            $max_leng = $length ;
        }
    }
    return $max_leng ;
}


END
