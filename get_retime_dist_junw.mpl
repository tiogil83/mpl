Tsub __get_feedthr_partitions => << 'END' ;
    DESC {
        internal function, to get all the feedthrough partitions ;
    }
    ARGS {
        -start:$s_par ,
        -end:$e_par ,
    }

    my %pars = () ;
    push @{$pars{0}}, $s_par ;

    my @n_pars = __get_neighbor_partitions $s_par ;
    if (grep ($_ eq $e_par, @n_pars)) {
        push @{$pars{0}}, $e_par ;  
        return @{$pars{0}} ;
    } else {
        my $i = 0 ;
        foreach my $par (@n_pars) {
            my @nn_pars = __get_neighbor_partitions $par ;
            if (grep ($_ eq $e_par, @n_pars)) {
        }
    }



END

Tsub __get_neighbor_partitions => << 'END' ;
    DESC {
        internal funcion, to get all the neighor partitions ;
    }
    ARGS {
        $par_inst ,
    }

    my $top = get_top ;
    chomp $top ;
    set_chip_top $top ;
    set_tl_hier_abutment 1 ;

    my %par_bound     = () ;
    my @neighbor_pars = () ;
    my @all_n_pars    = tl_get_abutments $par_inst ; 

    foreach my $par_info (@all_n_pars) {
        my $par_name   = $par_info->[0] ;
        my @sp_coor    = ($par_info->[2], $par_info->[3]) ;
        my @ep_coor    = ($par_info->[4], $par_info->[5]) ;
        my $bound_dist = get_dist (@sp_coor, @ep_coor) ; 
        if (exists $par_bound{$par_name}) {
            $par_bound{$par_name} = $par_bound{$par_name} + $bound_dist ;
        } else {
            $par_bound{$par_name} = $bound_dist ;
        }
    }
    
    foreach my $par (sort keys %par_bound) {
        if ($par_bound{$par} > 200) {
            push @neighbor_pars, $par ;
        } else {
            # print "short bound : $par $par_inst $par_bound{$par}\n" ;
        }
    }

    return @neighbor_pars ;

END
