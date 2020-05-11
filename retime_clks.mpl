use strict ;

Tsub netLength_clks => << 'END';
    DESC {
        To get all the clks on netLength report. 
    }

    ARGS {
        -in:$in           # input file, the netLength report 
        -out:$out         # output file, $in.clks.txt by default
        -header:$header   # to check the chiplet nets from top view, need to set header, eg : "sx0_0/"
    }

    if (!defined $out) {
        $out = $in . ".clks.txt" ;
    }

    if (!defined $header) {
        $header = "" ;
    }

    my %nets    = () ;
    my %new     = () ;
    my %fi_clks = () ;
    my %fo_clks = () ;

    open IN, $in or die "Can't open file $in\n" ; 
    
    while (<IN>) {
        chomp ;
        my $line = $_ ;
        if ($line =~ /^NET: (.*)$/) {
            my $net_name = $1 ; 
            $nets{$net_name} = 1 ;
        }
    }

    close IN ;

    foreach my $net_name (sort keys %nets) {
        $net_name =~ /^(\S+).*/ ;
        my $net   = $1 ;
        if ($net_name =~ /^(\S+) \d/) {
            my @net_names = get_nets (-quiet, "$header$net\[\*\]") ;
            if ($#net_names == -1) {
                $new{$net_name} = 1 ;
            } else {
                foreach my $thr_net (@net_names) {
                    my @fis = get_fan2 (-fanin, -end, -quiet, $thr_net) ; 
                    my @fos = get_fan2 (-fanout, -end, -quiet, $thr_net) ; 
                    @fis = grep ($_ !~ /\/Jreg_lat_reg/, (grep ($_ !~ /^GND/, @fis))) ;
                    @fos = grep ($_ !~ /\/Jreg_lat_reg/, (grep ($_ !~ /^GND/, @fos))) ;
                    #print "$thr_net\n" ;
                    foreach my $fi_pin (@fis) {
                        $fi_pin =~ s/(\S+) .*/$1/ ;
                        if ((is_power_net $fi_pin) || ($fi_pin =~ /Jreg_lat_reg/)) {
                            next ;
                        }
                        #print "$fi_pin " ;
                        my $clk = gpc $fi_pin ;
                        #print "$clk\n" ;
                        if (exists $fi_clks{$net_name}) {
                            if (grep ($clk eq $_, @{$fi_clks{$net_name}})) {
                                next ;
                            } else {
                                push @{$fi_clks{$net_name}}, $clk ;
                            }
                        } else {
                            push @{$fi_clks{$net_name}}, $clk ;
                        }
                    }
                    foreach my $fo_pin (@fos) {
                        $fo_pin =~ s/(\S+) .*/$1/ ;
                        if ((is_power_net $fo_pin) || ($fo_pin =~ /Jreg_lat_reg/)) {
                            next ;
                        }
                        #print "$fo_pin " ;
                        my $fo_cp_pin = "" ;
                        my $clk = "" ;
                        if (is_port $fo_pin) {
                            $fo_cp_pin = $fo_pin ;
                            next ;
                            # $clk = gpc $fo_cp_pin ;
                        } else { 
                            my @fo_cp_pins = _get_clk_pin (-inst => (get_cell (-of => $fo_pin))) ;
                            if ($fo_pin =~ /\/SRC_D_NEXT$/) {
                                $fo_cp_pin = $fo_pin ;
                                $fo_cp_pin =~ s/\/SRC_D_NEXT$/\/DST_CLK/ ; 
                            } elsif ($fo_pin =~ /\/SRC_D$/) {
                                $fo_cp_pin = $fo_pin ;
                                $fo_cp_pin =~ s/\/SRC_D$/\/SRC_CLK/ ;
                            } elsif ($#fo_cp_pins == 0) {
                                $fo_cp_pin = $fo_cp_pins[0] ;
                                $clk = gpc $fo_cp_pin ;
                            } else {
                                die "$thr_net $fo_pin\n" ;
                            }
                        }
                        if (exists $fo_clks{$net_name}) {
                            if (grep ($clk eq $_, @{$fo_clks{$net_name}})) {
                                next ;
                            } else {
                                push @{$fo_clks{$net_name}}, $clk ;
                            }
                        } else {
                            push @{$fo_clks{$net_name}}, $clk ;
                        }
                    }
                }
            }
        } else {
            my @net_names = get_nets (-quiet, "$header$net") ;
            if ($#net_names == -1) {
                $new{$net_name} = 1 ;
            } else {
                foreach my $thr_net (@net_names) {
                    my @fis = get_fan2 (-fanin, -end, -quiet, $thr_net) ;
                    my @fos = get_fan2 (-fanout, -end, -quiet, $thr_net) ;
                    @fis = grep ($_ !~ /\/Jreg_lat_reg/, (grep ($_ !~ /^GND/, @fis))) ;
                    @fos = grep ($_ !~ /\/Jreg_lat_reg/, (grep ($_ !~ /^GND/, @fos))) ;
                    #print "$thr_net\n" ;
                    foreach my $fi_pin (@fis) {
                        $fi_pin =~ s/(\S+) .*/$1/ ;
                        if ((is_power_net $fi_pin) || ($fi_pin =~ /Jreg_lat_reg/)) {
                            next ;
                        }
                        #print "$fi_pin " ;
                        my $clk = gpc $fi_pin ;
                        #print "$clk\n" ;
                        if (exists $fi_clks{$net_name}) {
                            if (grep ($clk eq $_, @{$fi_clks{$net_name}})) {
                                next ;
                            } else {
                                push @{$fi_clks{$net_name}}, $clk ;
                            }
                        } else {
                            push @{$fi_clks{$net_name}}, $clk ;
                        }
                    }
                    foreach my $fo_pin (@fos) {
                        $fo_pin =~ s/(\S+) .*/$1/ ;
                        if ((is_power_net $fo_pin) || ($fo_pin =~ /Jreg_lat_reg/)) {
                            next ;
                        }
                        #print "$fo_pin " ;
                        my $fo_cp_pin = "" ;
                        my $clk = "" ;
                        if (is_port $fo_pin) {
                            $fo_cp_pin = $fo_pin ;
                            next ;
                            # $clk = gpc $fo_cp_pin ;
                        } else {
                            my @fo_cp_pins = _get_clk_pin (-inst => (get_cell (-of => $fo_pin))) ;
                            if ($fo_pin =~ /\/SRC_D_NEXT$/) {
                                $fo_cp_pin = $fo_pin ;
                                $fo_cp_pin =~ s/\/SRC_D_NEXT$/\/DST_CLK/ ;
                            } elsif ($fo_pin =~ /\/SRC_D$/) {
                                $fo_cp_pin = $fo_pin ;
                                $fo_cp_pin =~ s/\/SRC_D$/\/SRC_CLK/ ;
                            } elsif ($#fo_cp_pins == 0) {
                                $fo_cp_pin = $fo_cp_pins[0] ;
                                $clk = gpc $fo_cp_pin ;
                            } else {
                                die "$thr_net $fo_pin\n" ;
                            }
                        }
                        if (exists $fo_clks{$net_name}) {
                            if (grep ($clk eq $_, @{$fo_clks{$net_name}})) {
                                next ;
                            } else {
                                push @{$fo_clks{$net_name}}, $clk ;
                            }
                        } else {
                            push @{$fo_clks{$net_name}}, $clk ;
                        }
                    }
                }
            }
        }
    } 

    open OUT, "> $out" or die "Can't write to file $out\n" ;

    foreach my $key (sort keys %new) {
        print OUT "NET: $key # new\n" ;
    }

    foreach my $key (sort keys %nets) {
        my $fi_clk = join (" ", @{$fi_clks{$key}}) ;
        my $fo_clk = join (" ", @{$fo_clks{$key}}) ;
        print OUT "NET : $key # SCLK : $fi_clk ECLK : $fo_clk\n" ;
    } 

    close OUT ;
END
 
