Tsub plot_dist_from_file => << 'END';
    DESC {
          To plot the start end pairs from file. 
    }
    ARGS {
        -i:$infile     # To specify the input file
        -plot          # To plot the start_end pairs 
        -o:$output     # To specify the output file
        -w:$threshold  # To set a threshold value for reporting/plotting 
    }

load "/home/junw/mpl/load_def_region_files.mpl" ;

open IN, "$infile" or die "can't open file $infile\n"; 

if (defined $output) {
    open OUT, "> $output" or die "can't write to file $output\n" ;
}

if (defined $opt_plot) {
    plot_all_partitions ;
}

my %dists = () ; 
my %ordering = () ;

while (<IN>) {
    chomp ;
    my $line = $_ ;
    if ($line =~ /(max|min).*\)/) {
        $line =~ s/.*\) // ;
    }else{
        next ;
    }
    $line =~ /(\S+)\s+(\S+)/ ;
    my $start_pin = $1 ;
    my $end_pin   = $2 ;
    my $start_par ;
    my $end_par ;
    my @start_xy ;
    my @end_xy ;
    my $dist = 0 ;


    if ((is_port $start_pin) && !(is_port $end_pin)) {
        $start_par = "PORT" ; 
        $end_par   = get_pin_par_name $end_pin ;
        @start_xy  = get_port_xy $start_pin ;
        @end_xy    = get_pin_xy $end_pin ; 
    } elsif (!(is_port $start_pin) && (is_port $end_pin)) {
        $start_par = get_pin_par_name $start_pin ;
        $end_par   = "PORT" ;
        @start_xy  = get_pin_xy $start_pin ;
        @end_xy    = get_port_xy $end_pin ; 
    } else { 
        $start_par = get_pin_par_name $start_pin ;
        $end_par   = get_pin_par_name $end_pin ; 
        @start_xy = get_pin_xy $start_pin ;
        @end_xy   = get_pin_xy $end_pin ; 
    }

    #my @path_pins = get_all_pins_of_path ($start_pin, $end_pin) ;         
    #foreach my $i (0..$#path_pins) {
    #    my $pin_par = get_pin_par_name $path_pins[$i] ;
    #    push $ordering{$start_par}{$end_par}, $pin_par ; 
    #    if ($i > 0) {
    #        my $local_dist = get_dist ($path_pins[$i-1], $path_pins[$i]) ;
    #        $dist = $dist + $local_dist ;
    #    }
    #}
    my $dist = get_dist (@start_xy, @end_xy) ;

    if (defined $threshold) {
    
    } else {
        $threshold = 0 ;
    }
    if ($dist < $threshold) { 
        next ;
    } else {
        $dists{$start_par}{$end_par} = $dist ; 
        if (defined $output) {
            printf OUT ("%.3f\t%s\t%s\n", $dist, $start_pin, $end_pin) ; 
        } 
        if (defined $opt_plot) {
            #plot_line (-arrow=>"last", -name => "start_end_${start_par}_to_${end_par}", @start_xy, @end_xy, -color => "red") ;
        }
    }
}


close IN ;

printf ("%9s\t%15s    %-15s\n", "DIST", "START_PAR", "END_PAR") ;

foreach my $start_par (keys %dists) {
    foreach my $end_par (keys %{$dists{$start_par}}) {
        printf ("%-10.3f\t%15s => %-15s\n", $dists{$start_par}{$end_par}, $start_par, $end_par) ;
    }
}

if (defined $output) {
    close OUT ;
}

END

sub plot_all_partitions {
    my %all_mods = map  ({$_ => 1} (get_modules ("*"))) ;
    my @pars_ref = grep (exists $all_mods{$_}, (all_partitions)) ;
    foreach my $par_ref (@pars_ref) {
        my @par_cells = get_cells_of $par_ref ;
        plot (-no_label => @par_cells) ;
    }
}

sub get_pin_par_name {
    my $pin = shift;
    my @all_refs  = get_hier_list_txt ( "-ref", -of_pin => $pin);
    my @all_insts = get_hier_list_txt ( "-inst", -of_pin => $pin);
    my $par_name = "";
    while (my ($index, $value) = each @all_refs) {
        if (attr_of_ref("is_partition",$value)) {
            $par_name = $par_name."$all_insts[$index]";
            return $par_name ;
        } else {
            $par_name = $par_name."$all_insts[$index]/" ;
        }
    }
};

sub get_all_pins_of_path {
    my $from_pin = shift;
    my $to_pin   = shift;
    #print "INFO: get pins of $from_pin => $to_pin\n";
    my @path_lists = get_path_delay (-from => $from_pin => -to => $to_pin => -rtn_from_in => -wire_model => none);
    my @pin_lines = grep (/^\s\s\S*\s\([^(net)]+\)\s/,@path_lists);
    my @pins = map (get_pins_from_path_line($_),@pin_lines);
    return \@pins
}

sub get_pins_from_path_line {
    my @li = split;
    return $li[0]
}


sub get_path_ordering_pin {

    my $all_pins_of_path = shift;
    my @all_pars = ();
    my @order_pins = ();
    foreach (@$all_pins_of_path) {
        next if (attr_of_pin ("is_hier",$_));
        my $cur_par = get_pin_par_only $_;
        unless ($cur_par eq $all_pars[$#all_pars]) {
            push @order_pins,$_;
            push (@all_pars,$cur_par);
        }
    }
    return \@order_pins;
};

