@pars = get_cells (gp?pad0*0) ; 

open_log x ;
lprint "PARTITION(\t\t)INST_CNT\t\tCKBD12_CNT\t\tCKND8_CNT\t\tMUX2D2_CNT\t\tLND4_CNT\n" ;
#                CKBD12_S    => { fix_wire => 10000,}, 
#                CKND8_S     => { fix_wire => 10000,}, 
#                MUX2D2_S    => { fix_wire => 2000,}, 
#                LND4_S      => { fix_wire => 500,}, 


foreach $par (@pars) {
  $par = uc $par ;
  set_top $par ;
  #@insts = get_cells (*) ;
  #$inst_cnt = $#insts + 1 ;
  @use_refs = grep ($_ !~ /(^FILL|^AFILL|^decap|^DECAP|^TAP|^EDGE|_S$)/, sort( get_all_refs("*") ) );
  @all_insts = ();
  foreach $r (@use_refs) { push ( @all_insts, find_insts('*', -quiet, -ref => $r) ); }
  $inst_cnt = @all_insts;
  @ckbd12 = find_insts ('*', -quiet, -ref => CKBD12_S) ;
  $ckbd12_cnt = $#ckbd12 + 1 ;
  @cknd8 = find_insts ('*', -quiet, -ref => CKND8_S) ;
  $cknd8_cnt = $#cknd8 + 1 ;
  @mux2d2 = find_insts ('*', -quiet, -ref => MUX2D2_S) ;
  $mux2d2_cnt = $#mux2d2 + 1 ;
  @lnd4 = find_insts ('*', -quiet, -ref => LND4_S) ;
  $lnd4_cnt = $#lnd4 + 1 ;
  lprint "$par\t\t\t$inst_cnt\t\t\t$ckbd12_cnt\t\t\t$cknd8_cnt\t\t\t$mux2d2_cnt\t\t\t$lnd4_cnt\n" ;
}

close_log ;
