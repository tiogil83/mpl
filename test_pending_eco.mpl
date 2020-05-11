#! /home/gnu/bin/perl -w
use strict ;

my $ltot = "/home/scratch.junw_t114/T114/t35/timing" ;
#system "p4 sync $ltot/t35/eco/..." ;
system "touch $ltot/pending_eco.txt" ;
#system "rm -vf ltot/pending_eco.txt" ;
unlink "$ltot/pending_eco.txt" ;
unlink "$ltot/temp" ;

chdir $ltot ;
open TEMPOUT, ">> $ltot/temp" ;
print TEMPOUT "# -----------------------------------\n" ;

#my @macros = qw / NV_CAR_GR_gcg2_mc_gr_dis_wclk NV_CAR_GR_gcg2_mc_gr_disb_wclk NV_CAR_GR_gcg2_mc_gr_me_wclk NV_CAR_GR_gcg2_mc_gr_vd_wclk NV_CAR_GR_trim_grouped NV_CAR_MS_trim_grouped NV_CAR_TDE_gcg2_soc_therm_pipe1_clk NV_CAR_TDE_trim_grouped NV_CAR_TDF_gcg2_csite_pipe_tdf_atclk NV_CAR_TDF_gcg2_csite_pipe_tdf_pclk NV_CAR_TDF_gcg2_mc0_tdf_tdf_rclk NV_CAR_TDF_gcg2_mc1_tdf_tdf_rclk NV_CAR_TDF_gcg2_mc_tdf_ahb_wclk NV_CAR_TDF_gcg2_mc_tdf_apb_wclk NV_CAR_TDF_gcg2_mc_tdf_avp_wclk NV_CAR_TDF_gcg2_mc_tdf_xusbc_wclk NV_CAR_TDF_trim_grouped NV_CLK_div1234_serdes_core NV_CORESIGHT_apbpipemacro NV_CORESIGHT_csbridgesync1t1 NV_ENTROPY_ro NV_ISM_MINI_1CLK_core NV_ISM_MINI_2CLK_core NV_MC_PIPE_data_macro NV_MC_PIPE_req_macro NV_OBS2_finalmux_tde NV_OBS2_finalmux_tdf NV_host1x_masterint_pipe NV_ppsb_pipemacro NV_APC_TO_ARM7_width8_pipemacro NV_CAR_TDC_gcg2_gr3d_gpu_fs_clk NV_CAR_TDC_gcg2_host1x2emc1_tdc_clk NV_CAR_TDC_gcg2_host1x2emc_tdc_clk NV_CAR_TDC_gcg2_host1x2mc1_tdc_clk NV_CAR_TDC_gcg2_host1x2mc_tdc_clk NV_CAR_TDC_gcg2_mc0_tdc_tdc_rclk NV_CAR_TDC_gcg2_mc1_tdc_tdc_rclk NV_CAR_TDC_gcg2_mc_tdc_tda_wclk NV_CAR_TDC_trim_grouped NV_CAR_TDD_gcg2_soc_therm_pipe2_clk NV_CAR_TDD_trim_grouped NV_OBS2_finalmux_tdc NV_OBS2_finalmux_tdd NV_SOC_THERM_pipemacro NV_soc_therm_tsosc / ;
my @macros = qw /NV_CAR_GR_gcg2_mc_gr_dis_wclk NV_CAR_GR_gcg2_mc_gr_disb_wclk NV_CAR_GR_gcg2_mc_gr_me_wclk/ ;
foreach my $macro(@macros){
   print TEMPOUT "# $macro\n" ;
   system "/home/nvtools/service/t35_tm/nvtools/timing/scripts/findEcoStatus.pl -p t35 -b $macro >> $ltot/temp" ;
 }
print TEMPOUT "# -----------------------------------\n" ;
close TEMPOUT ;

open OUT, "> $ltot/pending_eco.txt" ;
open IN, "$ltot/temp" ;
while(<IN>){
  s/^find.*$//gsi ;
  s/ACTION REQUIRED eco //g ;
  s/ is not applied yet//g ;
  print OUT $_ ;
}

#unlink "$ltot/temp" ;
