Tsub get_top_nets => << 'END';
    DESC {
         get_top_nets -i <in_file> -o <out_file>
    }
    ARGS {
        -i:$in_file   # to specify the input file
        -o:$out_file   # to specify the output file
    }

open IN, "$in_file" ;
open OUT, "> $out_file" ;

while (<IN>) {
  chomp ;
  $top_net = get_top_net $_ ;
  print OUT "$top_net\n" ;
}

close IN ;
close OUT ;


END
