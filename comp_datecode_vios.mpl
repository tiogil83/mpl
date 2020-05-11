use strict ;

Tsub comp_datecode_vios => << 'END';
    DESC {
        To check the vios coverage between datecodes.
        Usage : 
            comp_datecode_vios -ref_dc "2019Mar17_all_ST_revP5p0_merge" -impl_dc "2019Mar16_20_revP5p0_merge 2019Mar16_20_tam_revP5p0_tam 2019Mar16_all_ST_revP5p0_xtr"
    }
    ARGS {
        -ref_dc:$ref_dc     #to specify the refernence datecode.
        -impl_dc:$impl_dcs  #to specify the implement datecode. 
        -filter:$opt_filter     #to filter out some end_pins 
    }

if (!(defined $ref_dc) || !(defined $impl_dcs)) {
    die ("Need the options for reference datecode and implement datecodes\n") ;
}

print "Reference datecode      : $ref_dc\n" ;
print "Implementation datecode : $impl_dcs\n" ;

# parsing reference violations
my @ref_vios = () ;
my %ref_vio  = () ;

my $filter = "(datecode eq \'$ref_dc\') and (type eq 'max' or type eq 'min') and slack < 0" ;
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
        next;
    }
}

# main loop

my %impl_only   = () ;
my %impl_worse  = () ;
my %impl_better = () ;
my %impl_equal  = () ;

my %impl_only_hist  = () ;
my %impl_worse_hist = () ;

my $flg_only   = 0 ;
my $flg_worse  = 0 ;
my $flg_better = 0 ;
my $flg_equal  = 0 ;

my @dcs = split (/\s+/, $impl_dcs) ;
foreach my $impl_dc (@dcs) {
    my @impl_vios = () ;
    my $impl_filter  = "" ;
    if (defined $opt_filter) {
        print "Extra filter : $opt_filter \n" ;
        $impl_filter = "(datecode  eq \'$impl_dc\') and (type eq 'max' or type eq 'min') and $opt_filter and slack < 0" ; 
    } else {
        $impl_filter = "(datecode  eq \'$impl_dc\') and (type eq 'max' or type eq 'min') and slack < 0" ;
    }
    @impl_vios = all_vios (-filter => "$impl_filter") ;
    foreach my $i (0..$#impl_vios) {
        my $corner  = attr_of_vio ('project_corner' => "$impl_vios[$i]") ;
        my $mode    = attr_of_vio ('mode' => "$impl_vios[$i]") ;
        my $dc      = attr_of_vio ('datecode' => "$impl_vios[$i]") ;
        my $end_clk = attr_of_vio ('end_clk' => "$impl_vios[$i]") ;
        my $end_pin = attr_of_vio ('end_pin' => "$impl_vios[$i]") ;
        my $slack   = attr_of_vio ('slack'   => "$impl_vios[$i]") ;
        if (!(exists $ref_vio{$corner}{$end_pin})) {
            #if ($end_pin =~ /\/d$/ || $end_pin =~ /xtr_tam_config_mux_pg\/UJ_DFT_TAM_pipe_MTM_SO_reg_/ || $end_pin eq 'gaas0pc/clks/gaas0pc/nchostnafll/nchostnafll_freq_pid_fr_clk_cntr_nchostnafll/u_NV_CLK_FR_counter_v2/u_HS_FR_counter_core/clk_spare_cell_frcounter_0/UI_clk_spare_cell_reg/SI')  {
            #    next ;
            #}
            if (!(exists $impl_only{$dc}{$corner}{$end_pin})) {
                $impl_only{$dc}{$corner}{$end_pin} = $slack ;
                foreach my $j (0..9) {
                    my $th1 = -($j*0.003) ;
                    my $th2 = -($j+1)*0.003 ;
                    if ($slack < $th1 && $slack >= $th2) {
                        if (exists $impl_only_hist{$dc}{$corner}{$th1}) {
                            $impl_only_hist{$dc}{$corner}{$th1} = $impl_only_hist{$dc}{$corner}{$th1} + 1 ;
                        } else {
                            $impl_only_hist{$dc}{$corner}{$th1} = 1 ;
                        }
                    }
                }
                if ($slack < -0.03) {
                    if (exists $impl_only_hist{$dc}{$corner}{-0.03}) {
                        $impl_only_hist{$dc}{$corner}{-0.03} = $impl_only_hist{$dc}{$corner}{-0.03} + 1 ;
                    } else {
                        $impl_only_hist{$dc}{$corner}{-0.03} = 1 ;
                    }
                }
                $flg_only = 1 ;
            } else {
                next ;
            }
        } elsif ($slack > $ref_vio{$corner}{$end_pin}) {
            $impl_better{$dc}{$corner}{$end_pin} = $slack ;
            $flg_better = 1 ;
        } elsif ($slack < $ref_vio{$corner}{$end_pin}) {
            if (!(exists $impl_worse{$dc}{$corner}{$end_pin})) {
                my $diff = $slack - $ref_vio{$corner}{$end_pin} ; 
                $impl_worse{$dc}{$corner}{$end_pin} = $slack ;
                foreach my $j (0..9) {
                    my $th1 = -($j*0.003) ;
                    my $th2 = -($j+1)*0.003 ;
                    if ($diff < $th1 && $diff >= $th2) {
                        if (exists $impl_worse_hist{$dc}{$corner}{$th1}) {
                            $impl_worse_hist{$dc}{$corner}{$th1} = $impl_worse_hist{$dc}{$corner}{$th1} + 1 ;
                        } else {
                            $impl_worse_hist{$dc}{$corner}{$th1} = 1 ;
                        }
                    }
                }
                if ($diff < -0.03) {
                    if (exists $impl_worse_hist{$dc}{$corner}{-0.03}) {
                        $impl_worse_hist{$dc}{$corner}{-0.03} = $impl_worse_hist{$dc}{$corner}{-0.03} + 1 ;
                    } else {
                        $impl_worse_hist{$dc}{$corner}{-0.03} = 1 ;
                    }
                }

                $flg_worse = 1 ;
            } else {
                next ;
            }
        } else {
            $impl_equal{$dc}{$corner}{$end_pin} = $slack ;
            $flg_equal = 1 ;
        } 
    }
}

# dump reports
if ($flg_only) {
    print "Violations only exists in implementation datecodes:\n" ;
    print "Detailed report file : IMPL_DATECODE_ONLY.txt\n" ;
    open OUT, "> IMPL_DATECODE_ONLY.txt" ;
    foreach my $dc (sort keys %impl_only) {
        print "$dc : \n\n" ;
        my @corners = keys %{$impl_only{$dc}} ;
        my $length  = get_max_array_length (@corners) ;
        foreach my $corner (sort keys %{$impl_only{$dc}}) {
            printf ("%-${length}s : ", $corner) ;
            my $pin_num = 0 ;
            foreach my $end_pin (sort keys %{$impl_only{$dc}{$corner}}) {
                $pin_num = $pin_num + 1 ;
                print OUT "ONLY $datecode $corner $end_pin REF_SLACK : $impl_only{$dc}{$corner}{$end_pin}\n" ;
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
                printf ("|%9s " , $impl_only_hist{$dc}{$corner}{$th}) ;
            }
            print "|\n" ;
            print "-" x 122 ;
            print "\n" ;
        }
    }
    close OUT ;
}

if ($flg_worse) {
    print "Violations worse in implementation datecodes :\n" ;
    print "Detailed report file : IMPL_DATECODE_WORSE.txt\n" ;
    open OUT, "> IMPL_DATECODE_WORSE.txt" ;
    foreach my $dc (sort keys %impl_worse) {
        print "$dc : \n\n" ;
        my @corners = keys %{$impl_worse{$dc}} ;
        my $length  = get_max_array_length (@corners) ;
        foreach my $corner (sort keys %{$impl_worse{$dc}}) {
            printf ("%-${length}s : ", $corner) ;
            my $pin_num = 0 ;
            foreach my $end_pin (sort keys %{$impl_worse{$dc}{$corner}}) {
                $pin_num = $pin_num + 1 ;
                my $diff = $impl_worse{$dc}{$corner}{$end_pin} - $ref_vio{$corner}{$end_pin} ;
                print OUT "WORSE $corner $end_pin IMPL_SLACK : $impl_worse{$dc}{$corner}{$end_pin} REF_SLACK : $ref_vio{$corner}{$end_pin} DIFF : $diff\n" ;
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
                printf ("|%9s " , $impl_worse_hist{$dc}{$corner}{$th}) ;
            }
            print "|\n" ;
            print "-" x 122 ;
            print "\n" ;
        }
    }
    close OUT ;
}

if ($flg_better) {
    open OUT, "> IMPL_DATECODE_BETTER.txt" ;
    foreach my $dc (sort keys %impl_better) {
        my @corners = keys %impl_better ;
        my $length  = get_max_array_length (@corners) ;
        foreach my $corner (sort keys %{$impl_better{$dc}}) {
            my $pin_num = 0 ;
            foreach my $end_pin (sort keys %{$impl_better{$dc}{$corner}}) {
                $pin_num = $pin_num + 1 ;
                print OUT "BETTER $corner $end_pin IMPL_SLACK : $impl_better{$dc}{$corner}{$end_pin} REF_SLACK : $ref_vio{$corner}{$end_pin}\n" ;
            }
        }
    }
    close OUT ;
}

if ($flg_equal) {
    open OUT, "> IMPL_DATECODE_EQUAL.txt" ;
    foreach my $dc (sort keys %impl_equal) {
        foreach my $corner (sort keys %{$impl_equal{$dc}}) {
            foreach my $end_pin (sort keys %{$impl_equal{$dc}{$corner}}) {
                print OUT "EQUAL $end_pin $dc $corner : $impl_equal{$dc}{$corner}{$end_pin} $ref_vio{$corner}{$end_pin}\n" ;
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
