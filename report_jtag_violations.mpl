Tsub report_jtag_violations => << 'END';
    DESC {
       To report jtag timing violations. 
    }
    ARGS {
        -top:$top         #top block name
        -func:$func_dc    #function reports datecode
        -test:$shift_dc   #shift reports datecode
        -cls              #to clear vios
    }

if ($opt_cls) {
    clear_vios ; 
}

my $proj = $ENV{NV_PROJECT};

chomp $top ;
chomp $func_dc ;
chomp $shift_dc ;
chomp $proj ;

my $func_dir ;
my $shift_dir ;

if ($top eq '') {
   die ("we need a top module.\n") ;
}

if ($top eq 'nv_top') {
    $func_dir = "/home/scratch.${proj}_master" ;
    $shift_dir = "/home/scratch.${proj}_test_shift" ;
} else {
   $func_dir = "/home/scratch.${proj}_${top}" ; 
   $shift_dir = "/home/scratch.${proj}_test_${top}"
}

#print "$func_dir\n" ;
#print "$shift_dir\n" ;

my @violation_files = () ;
my @shift_violation_files = () ;

if ($func_dc eq '') {
    @violation_files = () ;
} else {
        @violation_files = <${func_dir}/${proj}/${proj}/timing/${proj}/rep/${top}*${func_dc}*.pba.viol.gz> ;
        push @violation_files, <${func_dir}_2/${proj}/${proj}/timing/${proj}/rep/${top}*${func_dc}*.pba.viol.gz> ;
        push @violation_files, <${func_dir}_3/${proj}/${proj}/timing/${proj}/rep/${top}*${func_dc}*.pba.viol.gz> ;
        push @violation_files, <${func_dir}/${proj}_FNL*/${proj}/timing/${proj}/rep/${top}*${func_dc}*.pba.viol.gz> ;
}

if ($shift_dc eq '') {
    @shift_violation_files = () ;
} else {
    @shift_violation_files =  <${shift_dir}/${proj}/timing/${proj}/rep/${top}.*0p55v*shift_fmax*.${shift_dc}.*pba.viol.gz> ;
    push @shift_violation_files, <${shift_dir}/${proj}/${proj}/timing/${proj}/rep/${top}.*0p55v*shift_fmax*.${shift_dc}.*pba.viol.gz> ;
    push @shift_violation_files, <${shift_dir}/${proj}*/${proj}/timing/${proj}/rep/${top}.*0p55v*shift_fmax*.${shift_dc}.*pba.viol.gz> ;
    print "${shift_dir}/${proj}/timing/${proj}/rep/${top}.*0p55v*shift_fmax*.${shift_dc}.*pba.viol.gz\n" ;
    print "${shift_dir}/${proj}/${proj}/timing/${proj}/rep/${top}.*0p55v*shift_fmax*.${shift_dc}.*pba.viol.gz\n" ;
    print "${shift_dir}/${proj}*/${proj}/timing/${proj}/rep/${top}.*0p55v*shift_fmax*.${shift_dc}.*pba.viol.gz\n" ;
}

push @violation_files, @shift_violation_files ;

if ($#violation_files == -1) {
    die ("no violation files found.\n") ;
}

load_vios @violation_files ;

foreach my $viol_file (@violation_files) {
    print "$viol_file\n" ;
}

if ($top eq 'nv_top') {
    print "SETUP: \n" ;
    print "\n" ;
    print 'MENDER > report_vios (-filter => "slack < 0 and type eq \'max\' and (start_clk =~ /jtag/ or end_clk =~ /jtag/)", -show => "bin(setup) wns(setup) count(end_pin) worst(id)", -by => "is_inter_chiplet mode project_corner start_chiplet end_chiplet",)' ;
    print "\n" ;
    print (join "\n", (report_vios (-filter => "slack < 0 and type eq \'max\' and (start_clk =~ /jtag/ or end_clk =~ /jtag/)", -show => "bin(setup) wns(setup) count(end_pin) worst(id)", -by => "is_inter_chiplet mode project_corner start_chiplet end_chiplet",))) ;
    print "\n" ;
    print "HOLD: \n" ;
    print "\n" ;
    print 'MENDER > report_vios (-filter => "slack < 0 and type eq \'min\' and (start_clk =~ /jtag/ or end_clk =~ /jtag/)", -show => "bin(hold) wns(hold) count(end_pin) worst(id)", -by => "is_inter_chiplet mode project_corner end_chiplet",)' ;
    print "\n" ;
    print (join "\n", (report_vios (-filter => "slack < 0 and type eq \'min\' and (start_clk =~ /jtag/ or end_clk =~ /jtag/)", -show => "bin(hold) wns(hold) count(end_pin) worst(id)", -by => "is_inter_chiplet mode project_corner end_chiplet",))) ;
    print "\n" ;
} else {
    print "SETUP: \n" ;
    print "\n" ;
    print 'MENDER > report_vios (-filter => "slack < 0 and type eq \'max\' and (start_clk =~ /jtag/ or end_clk =~ /jtag/)", -show => "bin(setup) wns(setup) count(end_pin) worst(id)", -by => "mode start_pin project_corner end_par",)' ;
    print "\n" ;
    print (join "\n", (report_vios (-filter => "slack < 0 and type eq 'max' and (start_clk =~ /jtag/ or end_clk =~ /jtag/)", -show => "bin(setup) wns(setup) count(end_pin) worst(id)", -by => "mode start_pin project_corner end_par",))) ;
    print "\n" ;
    print "HOLD: \n" ;
    print "\n" ;
    print 'MENDER > report_vios (-filter => "slack < 0 and type eq \'min\' and (start_clk =~ /jtag/ or end_clk =~ /jtag/)", -show => "bin(hold) wns(hold) count(end_pin) worst(id)", -by => "mode project_corner start_par end_par",)' ;
    print "\n" ;
    print (join "\n", (report_vios (-filter => "slack < 0 and type eq 'min' and (start_clk =~ /jtag/ or end_clk =~ /jtag/)", -show => "bin(hold) wns(hold) count(end_pin) worst(id)", -by => "mode project_corner start_par end_par",))) ;
    print "\n" ;
}

END
