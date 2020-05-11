sub get_common_cells {
	lprint "Get all cells from $_[0] to $_[1]...\n";
	my $in_pin = pin_of_name($_[0]);
	my $o_pin = pin_of_name ($_[1]);

	my @in_cells  = remove_duplicates (map(name_of_cell(cell_of_pin($_)), fanin_pins_of_pins($o_pin)));
	my @out_cells = remove_duplicates (map(name_of_cell(cell_of_pin($_)), fanout_pins_of_pins($in_pin)));
	#lprint "xx in_cells=@in_cells\n";
	#lprint "xx out_cells=@out_cells\n";

	return get_intersection(@in_cells, @out_cells);
}

sub get_common_in_cells {
    lprint "Get all cells to $_[0] and $_[1]...\n";
    my $in_pin = pin_of_name($_[0]);
    my $o_pin = pin_of_name ($_[1]);

    my @in_cells  = remove_duplicates (map(name_of_cell(cell_of_pin($_)), fanin_pins_of_pins($o_pin)));
    my @out_cells = remove_duplicates (map(name_of_cell(cell_of_pin($_)), fanin_pins_of_pins($in_pin)));
    #lprint "xx in_cells=@in_cells\n";
    #lprint "xx out_cells=@out_cells\n";

    return get_intersection(@in_cells, @out_cells);
}
