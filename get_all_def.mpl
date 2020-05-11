Tsub get_all_def_files => << 'END';
    DESC {
        get_all_def_files -o def.txt
    }
    ARGS {
        -o:$output                      # to sepcify the output file
    }

open OUT, "> $output" or die "Can't write to file $output\n" ;
# dont care about legal placement
set_eco_legal_placement never ;

# get macros, partitions, chiplets
my $top        = get_top ;
my $project    = $ENV{NV_PROJECT} ;
my $ipo_dir    = $ENV{IPO_DIR} ;    
my $common_dir = "${ipo_dir}/${project}_top/control";


my %all_mods = map  ({$_ => 1} (get_modules ("*"))) ;
my @macros   = grep ((exists $all_mods{$_}), (all_macros)) ;
my @parts    = grep ((exists $all_mods{$_}), (all_partitions)) ;
my @chiplets = grep ((exists $all_mods{$_}), (all_chiplets)) ;

# report
print "# top : $top\n";
print "# Start to load def/region files ... \n" ;
#print "# chiplets: \n";
#foreach my $mod (@chiplets) {
#   print "#   |-> $mod\n";
#}
#print "# partitions:\n";
#foreach my $mod (@parts) {
#   print "#   |-> $mod\n";
#}
#print "# macros:\n";
#foreach my $mod (@macros) {
#   print "#   |-> $mod\n";
#}

# load macros defs:
foreach my $part (@macros) {

 # full_def
    if  (-e "${ipo_dir}/macros/${part}/control/${part}.def.gz") {
        print OUT "${ipo_dir}/macros/${part}/control/${part}.def.gz" ;
        print OUT "\n" ;
    } elsif  (-e "${ipo_dir}/macros/${part}/control/${part}.def") {
        print OUT "${ipo_dir}/macros/${part}/control/${part}.def" ;
        print OUT "\n" ;
    } else {
        # print "# no def file found for ${part}\n";
    }
}
# load partition _fp defs and regioning files
foreach my $part (@parts) {

 # full_def
    if  (-e "${ipo_dir}/${part}/control/${part}.def.gz") {
        print OUT "${ipo_dir}/${part}/control/${part}.def.gz" ;
        print OUT "\n" ;
    } elsif  (-e "${ipo_dir}/${part}/control/${part}.def") {
        print OUT "${ipo_dir}/${part}/control/${part}.def" ;
        print OUT "\n" ;
 # full_def from hfp
    } elsif  (-e "${ipo_dir}/${part}/control/${part}.hfp.fulldef.gz") {
        print OUT "${ipo_dir}/${part}/control/${part}.hfp.fulldef.gz" ;
        print OUT "\n" ;
    } elsif  (-e "${ipo_dir}/${part}/control/${part}.hfp.fulldef") {
        print OUT "${ipo_dir}/${part}/control/${part}.hfp.fulldef" ;
        print OUT "\n" ;
 # fp.def
    } elsif  (-e "${ipo_dir}/${part}/control/${part}_fp.def") {
        print OUT "${ipo_dir}/${part}/control/${part}_fp.def" ;
        print OUT "\n" ;
 # retime regions
        if (-e "${ipo_dir}/${part}/control/${part}_ICC.tcl") {
            print OUT "${ipo_dir}/${part}/control/${part}_ICC.tcl" ;
            print OUT "\n" ;
        }
 # partition pins
        if (-e "${ipo_dir}/${part}/control/${part}.hfp.pin.def") {
            print OUT "${ipo_dir}/${part}/control/${part}.hfp.pin.def" ;
            print OUT "\n" ;
        }
 # dft_regions
        if (-e "${ipo_dir}/${part}/control/${part}.dft_regions.tcl") {
            print OUT "set_top $part" ;
            print OUT "\n" ;
            print OUT "${ipo_dir}/${part}/control/${part}.dft_regions.tcl" ;
            print OUT "\n" ;
            print OUT "set_top $top" ;
            print OUT "\n" ;
        }
    } else {
        print "# No def or ICC.tcl file found for ${part}\n";
    }
}

# if there a chiplet _fp.def?
foreach my $part (@chiplets) {
 # fp.def
    if  (-e "${ipo_dir}/${part}/control/${part}_fp.def")         {
        print OUT "${ipo_dir}/${part}/control/${part}_fp.def" ;
        print OUT "\n" ;
 # Chiplet pins
        if (-e "${ipo_dir}/${part}/control/${part}.hfp.pin.def") {
            print OUT "${ipo_dir}/${part}/control/${part}.hfp.pin.def" ;
            print OUT "\n" ;
        }
    } else {
        print "# No def or ICC.tcl file found for ${part}\n";
    }
}

#of top is nv_top , will read top fp.def
my $top_level_inst ;
foreach my $chiplet (keys $CONFIG->{partitioning}{chiplets}) { 
    if (exists $CONFIG->{partitioning}{chiplets}{$chiplet}{is_toplevel}) {
        my $top_level_inst = $chiplet ;
    }
    if ($top eq $top_level_inst) {
        if  (-e "${ipo_dir}/${top_level_inst}/control/${top_level_inst}_fp.def") {
            print OUT "${ipo_dir}/${top_level_inst}/control/${top_level_inst}_fp.def" ;
        } else {
            print "#No dft file find for $top_level_inst\n" ;
        }
    }
}
# load hcoff.data
print OUT "${common_dir}/hcoff.data" ;
print OUT "\n" ;

# catchall for any missing amcro - assumes they are 10 x 10
set_cell_size_default (-use_square) ;

set_rc_default_estimated ;
set_xy_default -centroid ;

print "All the def/region files loaded.\n" ;
close OUT ;

END
