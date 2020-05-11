##! /home/gnu/bin/perl -w
#use strict ;
my $full_report = 0 ;

my $proj = get_var projname ;
chomp $proj ;

system "p4 sync ./${proj}/eco/..." ;
unlink "./pending_eco.txt" ;

my $top ;
if ($proj =~ /104/) {
  $top = "NV_gpd_t0" ;
}elsif ($proj =~ /102/) {
  $top = "NV_gpj_t0" ;
}elsif ($proj =~ /106/) {
  $top = "NV_gph_t0" ; 
}elsif ($proj =~ /107/) {
  $top = "NV_gpy_t0" ;
}elsif ($proj =~ /gv100/) {
  $top = "NV_gva_t0" ;
}else{
  die "Please double check project.\n" ; 
}

open TEMPOUT, "> ./pending_eco_macro.txt" ;
print TEMPOUT "# -----------------------------------\n" ;

my @macros = () ;
my @partitions = () ;

#@macros = get_blocks -type anno -param is_partition -block $top ;
@macros = get_blocks -type anno -param is_macro -block $top ;
#
#if ($full_report) {
#  @macros = @partitions ;
#}else{
#  push @macros, @partitions ;
#}

foreach my $macro(@macros){
   my $eco_shell = $shell->flows->{eco};
   my $vars = $eco_shell->clone_vars_with_overrides();
   $vars->sv("eco_opt_block",$macro);
   my @pending_ecos = $eco_shell->find_eco_status($vars);
   if ($#pending_ecos != -1) {
     print TEMPOUT "# $macro\n" ;
     foreach $pending_eco(@pending_ecos){
       print TEMPOUT "$pending_eco\n" ;
     }
   }
}
print TEMPOUT "# -----------------------------------\n" ;
close TEMPOUT ;
