Tsub plot_misr_groups => << 'END';
    DESC {
          To plot the misr groups ordering. 
    }
    ARGS {
        -i:$infile #To specify the input file, this should be the yaml file. eg : //layout/ga100/revP2.6/blocks/NV_gaa_s0/dft/NV_gaa_s0.misrgroup.noscan.flat.yml 
        -plot      #To plot the ordering
    }

open IN, "$infile" or die "can't open file $infile\n"; 
my %misr_groups = () ;
my $group_num = 0 ;

while (<IN>) {
    chomp ;
    my $line = $_ ;
    my $par ;
    my $i ;
    if ($line =~ /^  group(.*):/) {
        $group_num = $1 ;
        $i = 0 ;
        next; 
    } elsif ($line =~ /^  - (.*):/) {
        $par = $1 ; 
        if ($par =~ /\\|\s+/) {
            $par =~ s/\\//g ;
            $par =~ s/\s+//g ;    
        }
        $misr_groups{$group_num} = $misr_groups{$group_num}." $par" ;
        next ;
    } else {
        next ;
    }
}

close IN ;

if (defined $opt_plot) {
    plot_macros -no_labels ;
    clear_plot ;
    plot_all_partitions ;
}

foreach (0..$group_num) {
    my $grp = $misr_groups{$_} ;
    $grp =~ s/^ // ;
    $grp =~ s/ / => /g ;
    print "group $_ : $grp\n" ;

}
my @misr_order = () ; 
my @color = qw (blue black green red) ;

foreach (0..$group_num) {
    @misr_order = split (" ", $misr_groups{$_}) ;
    my $line_color = $color[-$_] ;
    my $par_num = $#misr_order + 1 ;
    print "group $_ $line_color : $par_num partitions\n" ;

    my %misr_cell_coor = () ;
          
      
    printf ("%-20s%10s%10s%-10s\n", "partition", "coor_x", "coor_y", " distance") ;
    
    foreach $i (0..$#misr_order) {
       my $cell = $misr_order[$i] ;
       my $cell_xy = attr_of_cell ("phys_centroid_point" => $cell) ;
       $misr_cell_coor{$i}{x} = $cell_xy->[0] ;
       $misr_cell_coor{$i}{y} = $cell_xy->[1] ; 
       if ($i > 0) {
          if (defined $opt_plot) {
            plot_line(-arrow=>"last", -name => "misr_ordering", $misr_cell_coor{$i-1}{x}, $misr_cell_coor{$i-1}{y}, $misr_cell_coor{$i}{x}, $misr_cell_coor{$i}{y}, -color => "$line_color");
          }
          my $dist = get_dist ($misr_cell_coor{$i-1}{x}, $misr_cell_coor{$i-1}{y}, $misr_cell_coor{$i}{x}, $misr_cell_coor{$i}{y}) ;
          printf ("%-20s%10.3f%10.3f distance : %10.3f\n", $cell, $misr_cell_coor{$i}{x}, $misr_cell_coor{$i}{y}, $dist ) ;
       } else {
          printf ("%-20s%10.3f%10.3f\n", $cell, $misr_cell_coor{$i}{x}, $misr_cell_coor{$i}{y})  ;
       }
    } 
}

END

sub plot_all_partitions {
    plot_macros -no_labels ;
    clear_plot ;
    my %all_mods = map  ({$_ => 1} (get_modules ("*"))) ;
    my @pars_ref = grep (exists $all_mods{$_}, (all_partitions)) ;
    foreach my $par_ref (@pars_ref) {
        my @par_cells = get_cells_of $par_ref ;
        plot (-no_label => @par_cells) ;
    }
}
