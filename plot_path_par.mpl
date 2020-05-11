my $input_file = "/home/junw/jtag.txt" ; 
open IN, $input_file ;
my $pre_block = "" ;
my $block = "" ;
while (<IN>) {
  if (/^\s+(.0_.\/gtb.*?)\/\S+ \(GTB/) {
     #print "$1\n" ;
     $block = $1 ;
     if ($pre_block eq "") {
       $pre_block = $block ;
       next ;
     }elsif ($block eq $pre_block) {
       next ;
     }else {
       print "$pre_block => $block\n" ;
       my $xy   = attr_of_cell ('phys_centroid_point' => $block) ;
       my $xpyp = attr_of_cell ('phys_centroid_point' => $pre_block) ;
       my $x = $xy->[0] ;
       my $y = $xy->[1] ;
       my $xp = $xpyp->[0] ;
       my $yp = $xpyp->[1] ;
       plot_line(-arrow=>"last", -name => "jtag_path_order", $xp, $yp, $x, $y, -color => "red");
       $pre_block = $block ;  
       next ;
     }
  }else{
    next ;
  }
  #l0_0/gtbl0lnk0/wsc_inpd[1] (GTBL0LNK0))
}

close IN ;
