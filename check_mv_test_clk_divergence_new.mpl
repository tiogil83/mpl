Tsub check_mv_test_clk_divergence => << 'END';
    DESC {
       To check the test clock divergence in mv session.
       The input is the mv clock divergence summary report and check if the level shifters are fanouts for dft switch. 
    }
    ARGS {
        -i:$input         # the mv clock disvergence summary report
        -o:$output        # dump out the report file 
    }

if (!(defined $input)) {
    die "Please sepcify the mv clock divergence summary report file.\n" ;
}

if (!(defined $output)) {
    $output = $input ;
    $output =~ s/.*\/(\S+)\.rep/$1.out.txt/ ;
}

open IN, "$input" or die "Can't open file $input\n" ;
open OUT, "> $output" or die "Can't write to file $output\n" ; 

my $l_fl  = 0 ;
my $c_fl  = 0 ; 
my $l_pin = "" ;
my $c_pin = "" ;
my $l_ls  = "" ;
my $c_ls  = "" ;
my $i = 1 ;

while (<IN>) {
#Clock : jtag_reg_tck_sdleaf has 7 paths across different LS Detailed_Report_Legend = 1
#      Pin: gaas0bsi/inst_NV_bsi_macro/SYS/bsi/u_bsi_ls/u_nvvdd2vauxs/UI_ls_nvvdd_vauxs_clocks_1/DOUT, Power_Domain: LDO_BSI_vauxs, Clock: jtag_reg_tck_sdleaf
#      Pin: gaas0bsi/inst_NV_bsi_macro/SYS/bsi/u_bsi_ls/u_nvvdd2vauxs/UI_ls_nvvdd_vauxs_clocks_0/DOUT, Power_Domain: LDO_BSI_vauxs, Clock: jtag_reg_tck_sdleaf

#    Launch  LS_Pin: gaas0xv/clks/gaas0xv/cb_group_ctbuf4_ANC1211_GAAS0XV/UI_00/DOUT,
#    Capture LS_Pin: gaas0xv/clks/gaas0xv/cb_group_ctbuf4_ANC1225_GAAS0XV/UI_00/DOUT,
#--

    chomp ;
    print OUT "Working on Line $i\n" ;
    my $line = $_ ;
    if (!$l_fl && !$c_fl && $line =~ /^\s+Launch\s+LS_Pin: / ) {
        $l_pin = $line ;
        $l_pin =~ s/.*LS_Pin: (\S+)\/DOUT.*/$1\/DIN/ ; 
        #if (grep ((/u_NV_CLK_dft_switch\/UI_dft_switch_cg_shiftclk\/Q \(.*\)|\/stripe_1_serdes_divider\/u_NV_CLK_SERDES_CTRL_wrapper\/UI_test_serdesShift_clk_mux\/Z\(.*\)/), (get_fan2 ('-fanin' => $l_pin)))) {
        #    my @ls = grep ((/u_NV_CLK_dft_switch\/UI_dft_switch_cg_shiftclk\/Q \(.*\)|\/stripe_1_serdes_divider\/u_NV_CLK_SERDES_CTRL_wrapper\/UI_test_serdesShift_clk_mux\/Z\(.*\)/), (get_fan2 ('-fanin' => $l_pin))) ;
        if (grep ((/u_NV_CLK_dft_switch\/UI_dft_switch_cg_shiftclk\/Q \(.*\)|stripe_1_serdes_divider\/u_NV_CLK_SERDES_CTRL_wrapper\/UI_test_serdesShift_clk_mux\/Z|stripe_1_serdes_divider\/u_NV_CLK_SERDES_CTRL_wrapper\/UI_SerdesSlowClk/), (get_fan2 ('-fanin' => $l_pin)))) {
            my @ls = grep ((/u_NV_CLK_dft_switch\/UI_dft_switch_cg_shiftclk\/Q \(.*\)|stripe_1_serdes_divider\/u_NV_CLK_SERDES_CTRL_wrapper\/UI_test_serdesShift_clk_mux\/Z|stripe_1_serdes_divider\/u_NV_CLK_SERDES_CTRL_wrapper\/UI_SerdesSlowClk/), (get_fan2 ('-fanin' => $l_pin))) ;
            $l_ls = $ls[0] ;
            $l_ls =~ s/(.*)\/[Q|Z].*/$1/ ;
        } elsif (grep (/\/cb_group_ccm_.*\/stripe_Jtag_reg_clk/, (get_fan2 ('-fanin' => $l_pin)))) {
            my @ls = grep (/\/cb_group_ccm_.*\/stripe_Jtag_reg_clk/, (get_fan2 ('-fanin' => $l_pin))) ;
            $l_ls = $ls[0] ;
            $l_ls =~ s/(.*)\/Z.*/$1/ ;
        } else {
            $l_ls = "" ;
        }
        $l_fl = 1 ;
        $c_fl = 0 ;
        $i = $i + 1 ;
        next ;
    } elsif ($l_fl && !$c_fl && $line =~ /^\s+Capture\s+LS_Pin: / ) {
        $c_pin = $line ;
        $c_pin =~ s/.*LS_Pin: (\S+)\/DOUT.*/$1\/DIN/ ;
        if (grep ((/u_NV_CLK_dft_switch\/UI_dft_switch_cg_shiftclk\/Q \(.*\)|stripe_1_serdes_divider\/u_NV_CLK_SERDES_CTRL_wrapper\/UI_test_serdesShift_clk_mux\/Z|stripe_1_serdes_divider\/u_NV_CLK_SERDES_CTRL_wrapper\/UI_SerdesSlowClk/), (get_fan2 ('-fanin' => $c_pin)))) {
            my @ls = grep ((/u_NV_CLK_dft_switch\/UI_dft_switch_cg_shiftclk\/Q \(.*\)|stripe_1_serdes_divider\/u_NV_CLK_SERDES_CTRL_wrapper\/UI_test_serdesShift_clk_mux\/Z|stripe_1_serdes_divider\/u_NV_CLK_SERDES_CTRL_wrapper\/UI_SerdesSlowClk/), (get_fan2 ('-fanin' => $c_pin))) ;
            $c_ls = $ls[0] ;
            $c_ls =~ s/(.*)\/[Q|Z].*/$1/ ;
        } elsif (grep (/\/cb_group_ccm_.*\/stripe_Jtag_reg_clk/, (get_fan2 ('-fanin' => $c_pin)))) {
            my @ls = grep (/\/cb_group_ccm_.*\/stripe_Jtag_reg_clk/, (get_fan2 ('-fanin' => $c_pin))) ;
            $c_ls = $ls[0] ;
            $c_ls =~ s/(.*)\/Z.*/$1/ ;
        } else {
            $c_ls = "" ;
        }
        $l_fl = 1 ;
        $c_fl = 1 ;
        $i = $i + 1 ;
    } 
    if ($l_fl && $c_fl && ($l_ls || $c_ls)) {
        if ($l_ls ne $c_ls) {
            print OUT "Passing : $l_pin $l_ls $c_pin $c_ls l : $l_fl c : $c_fl\nLine : $line\n" ;
        } else {
            print OUT "Checking : $l_pin $l_ls $c_pin $c_ls l : $l_fl c : $c_fl\nLine : $line\n" ;
        }
        $l_fl = 0 ;
        $c_fl = 0 ;
        $l_ls = "" ;
        $l_ls = "" ;
    } elsif ($l_fl && $c_fl && !($l_ls || $c_ls)) {
        print OUT "Checking : $l_pin $l_ls $c_pin $c_ls l : $l_fl c : $c_fl\nLine : $line\n" ;
    } else {
        print OUT "Skipping : $line\n" ;
    }
}

close IN ;
close OUT ;

    
END
