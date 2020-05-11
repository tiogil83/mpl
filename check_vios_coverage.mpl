Tsub check_vios_coverage => << 'END';
    DESC {
       To check the vios coverage between corners. 
    }
    ARGS {
        -top:$top         #top block name
        -dir:$dir         #reports dir, ./<$proj>/rep by default
        -dc:$datecode     #reports datecode
        -filter:$filter   #to filter violations
        -corners:$corners #to specify corners for analysis
        -cover            #to check how much the chosen corners can cover all the corners
        -cls              #to clear privios vios
    }

unless (defined $top) {
    $top = "*" ;
}

my $proj = $ENV{NV_PROJECT} ;
chomp $proj ;
unless (defined $dir) {
    $dir = "$ENV{PWD}/${proj}/rep" ;
}
if ($dir =~ /(.*)\/$/) {
    $dir = $1 ; 
}

unless (defined $datecode) {
    die "Please point one datecode.\n" ;
} 

unless (defined $filter) {
    $filter = "" ;
}

if (defined $opt_cover && !(defined $corners)) {
    die "If want to check the cover, should chose corners.\n" ;
}

if (defined $opt_cls) {
    clear_vios ;
}

my @vio_files = () ;

my @dcs = split (/\s+/, $datecode) ;
foreach (@dcs) {
    print "Datecode : $_\n" ;
}

my @corners = () ;

if (defined $corners) {
    @corners = split (/\s+/, $corners) ; 
    foreach (@corners) {
        print "Corner : $_\n" ;
    } 
}

if (!(defined $opt_cover)) {
    foreach my $corner (@corners) {
        foreach my $dc (@dcs) { 
            push @vio_files , (glob "$dir/$top*$corner*$dc*unified.pba.viol.gz") ;
        }
    }
} else {
    foreach my $dc (@dcs) { 
        push @vio_files , (glob "$dir/$top*$dc*unified.pba.viol.gz") ;
    }
} 

my @all_corners  = () ;
print "Found the violation files as below:\n" ;

@vio_files = remove_duplicates @vio_files ;

# to load the viols
my @loaded_vios = get_files (-type => vios) ;

if ($#loaded_vios > -1) {
    foreach my $vio_file (@vio_files) {
        if (grep {$_ eq $vio_file} @loaded_vios) {
            next ;
        } else {
            load $vio_file ;
            next ; 
        }
    }
} else {
    load @vio_files ;
}

@loaded_vios = get_files (-type => vios) ;
foreach (@loaded_vios) {
    if (-e $_) {
        my $corner = $_ ;
        $corner =~ s/.*\.pt\.(.*?)\..*/$1/ ;
        print "\t$_\n" ; 
        push @all_corners, $corner ; 
    }
}

my $length = get_max_array_length (@all_corners) ;
$length = $length + 3 ;

if ($filter ne "") {
    print "\nThe violation filter is :\n \"$filter\"\nPleae double check.\n" ;
}


my @vios = all_vios (-filter => "$filter") ;

my %vios_corner  = () ;
my %vios_pin     = () ;
my @all_end_pins = () ;

foreach my $i (0..$#vios) {
    my $corner  = attr_of_vio ('project_corner'  => "$vios[$i]") ;
    my $end_pin = attr_of_vio ('end_pin' => "$vios[$i]") ;
    my $slack   = attr_of_vio ('slack'   => "$vios[$i]") ;
    #print "$end_pin $corner $slack\n" ; 
    $vios_corner{$corner}{$end_pin} = $slack ;
    $vios_pin{$end_pin}{$corner} = $slack ;
    push @all_end_pins, $end_pin ;
}

#foreach my $corner (sort keys %vios_corner) {
#    my @end_pin = sort keys %{$vios_corner{$corner}} ;
#    print "end_pin : $#end_pin\n" ;
#} 

@all_end_pins = remove_duplicates @all_end_pins ;
my $fep_num = $#all_end_pins + 1 ;
print "\nThere are total $fep_num end points.\n" ;
print "END_POINTS PERCENTAGE IN EACH CORNER:\n\n" ;

printf ("%${length}s : %8d %8.2f\%\n", "Total", "$fep_num", "100") ;
my @fep_pins        = () ;
my %fep_corner_num  = () ;
my %fep_corner_perc = () ;

foreach my $corner (@all_corners) {
    @fep_pins                 = sort keys %{$vios_corner{$corner}} ; 
    $fep_corner_num{$corner}  = $#fep_pins + 1 ;
    $fep_corner_perc{$corner} = $fep_corner_num{$corner}/$fep_num*100 ; 
}

foreach my $corner (sort {$fep_corner_perc{$b} <=> $fep_corner_perc{$a}} keys %fep_corner_perc) {
    printf ("%${length}s : %8d %8.2f\%\n", "$corner", "$fep_corner_num{$corner}", "$fep_corner_perc{$corner}") ; 
}

print "\n\nWORST_POINTS PERCENTAGE IN EACH CORNER:\n\n" ;

my %wns_corners = () ;
my %uniq        = () ;

foreach my $end_pin (sort keys %vios_pin) {
    my $wns = "" ;
    foreach my $corner (sort keys %{$vios_pin{$end_pin}}) {
        if (exists $vios_pin{$end_pin}{$corner}) {
           if ($vios_pin{$end_pin}{$corner} < $wns) {
               $wns = $corner ; 
           } 
        }
    }
    if (exists $wns_corners{$wns}) {
        $wns_corners{$wns} = $wns_corners{$wns} + 1 ;
    } else {
        $wns_corners{$wns} = 1 ; 
    }
    my @uniq_corners = sort keys %{$vios_pin{$end_pin}} ;
    if ($#uniq_corners == 0) {
        if (exists $uniq{$uniq_corners[0]}) {
            $uniq{$uniq_corners[0]} = $uniq{$uniq_corners[0]} + 1 ; 
        } else {
            $uniq{$uniq_corners[0]} = 1 ;
        } 
    }
}

printf ("%${length}s : %8d %8.2f\%\n", "Total", "$fep_num", "100") ;
foreach my $corner (sort {$wns_corners{$b} <=> $wns_corners{$a}} keys %wns_corners) {
    my $wns_fep_corner_num  = $wns_corners{$corner} ;
    my $wns_fep_corner_perc = $wns_fep_corner_num/$fep_num*100 ;
    printf ("%${length}s : %8d %8.2f\%\n", "$corner", "$wns_fep_corner_num", "$wns_fep_corner_perc") ;  
}

print "\n\nUNIQUE_END_POINTS PERCENTAGE IN EACH CORNER:\n\n" ;

my $total_uniq_num = 0 ;
foreach my $corner (sort keys %uniq) {
    $total_uniq_num = $total_uniq_num + $uniq{$corner} ;
} 
printf ("%${length}s : %8d %8.2f\%\n", "Total", "$total_uniq_num", "100") ;

foreach my $corner (sort {$uniq{$b} <=> $uniq{$a}} keys %uniq) {
    my $uniq_num  = $uniq{$corner} ;
    my $uniq_perc = $uniq_num/$total_uniq_num*100 ;
    printf ("%${length}s : %8d %8.2f\%\n", "$corner", "$uniq_num", "$uniq_perc") ;
} 


if (defined $opt_cover) {
    print "\n\nCoverage by chosen corners:\n\n" ;
    printf ("%${length}s : %8.2f%% %8.2f\%\n", "Total", "100", "100") ;
    my @corner_vios = () ;
    foreach my $corner (sort {$fep_corner_perc{$a} <=> $fep_corner_perc{$b}} keys %fep_corner_perc) {
        if (grep {$_ eq $corner} @corners) {
            my @corner_vio = keys $vios_corner{$corner} ;
            push @corner_vios, @corner_vio ; 
            @corner_vios = remove_duplicates @corner_vios ;
            my $acc_num  = $#corner_vios + 1 ;
            my $acc_perc = $acc_num/$fep_num*100 ;
            #print "$acc_num $acc_perc\n" ;
            printf ("%${length}s : %8.2f%% %8.2f\%\n", "$corner", "$fep_corner_perc{$corner}", "$acc_perc") ;
        }
    }
    
    print "\n\nCoverage by chosen corners for KevinX:\n\n" ;
    printf ("%${length}s : %8.2f%% %8.2f\%\n", "Total", "100", "100") ;
    my @corner_vios = () ;
    foreach my $corner (@corners) {
        if (grep {$_ eq $corner} @corners) {
            my @corner_vio = keys $vios_corner{$corner} ;
            push @corner_vios, @corner_vio ;
            @corner_vios = remove_duplicates @corner_vios ;
            my $acc_num  = $#corner_vios + 1 ;
            my $acc_perc = $acc_num/$fep_num*100 ;
            #print "$acc_num $acc_perc\n" ;
            printf ("%${length}s : %8.2f%% %8.2f\%\n", "$corner", "$fep_corner_perc{$corner}", "$acc_perc") ;
        }
    }

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
