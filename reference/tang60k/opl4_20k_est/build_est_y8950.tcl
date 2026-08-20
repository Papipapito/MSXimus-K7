# ============================================================================
#  build_est_y8950.tcl — ESTIMACION v2: OPL4 + Y8950(FM+ADPCM) en Tang Nano 20K
#  Device GW2AR-18C. Uso: gw_sh.exe build_est_y8950.tcl (desde opl4_20k_est/)
# ============================================================================
set_device -name GW2AR-18C GW2AR-LV18QN88C8/I7

set SRC C:/Users/alber/proyectosAI/msx/MSX_up/fpga

# ---- OPL4 FM (core OPL3) ----
add_file $SRC/opl3/opl3_pkg.sv
add_file $SRC/opl3/afifo.v
add_file $SRC/opl3/calc_envelope_shift.sv
add_file $SRC/opl3/calc_phase_inc.sv
add_file $SRC/opl3/calc_rhythm_phase.sv
add_file $SRC/opl3/channels.sv
add_file $SRC/opl3/clk_div.sv
add_file $SRC/opl3/control_operators.sv
add_file $SRC/opl3/dac_prep.sv
add_file $SRC/opl3/edge_detector.sv
add_file $SRC/opl3/envelope_generator.sv
add_file $SRC/opl3/host_if.sv
add_file $SRC/opl3/ksl_add_rom.sv
add_file $SRC/opl3/leds.sv
add_file $SRC/opl3/mem_multi_bank.sv
add_file $SRC/opl3/mem_multi_bank_reset.sv
add_file $SRC/opl3/mem_simple_dual_port.sv
add_file $SRC/opl3/mem_simple_dual_port_async_read.sv
add_file $SRC/opl3/operator.sv
add_file $SRC/opl3/opl3.sv
add_file $SRC/opl3/opl3_exp_lut.sv
add_file $SRC/opl3/opl3_log_sine_lut.sv
add_file $SRC/opl3/phase_generator.sv
add_file $SRC/opl3/pipeline_sr.sv
add_file $SRC/opl3/reset_sync.sv
add_file $SRC/opl3/synchronizer.sv
add_file $SRC/opl3/timer.sv
add_file $SRC/opl3/timers.sv
add_file $SRC/opl3/tremolo.sv
add_file $SRC/opl3/trick_sw_detection.sv
add_file $SRC/opl3/vibrato.sv
add_file $SRC/src/opl4fm.v

# ---- OPL4 PCM wavetable + shim SDRAM ----
add_file $SRC/opl4wave/ymf278b_gowin.v
add_file $SRC/src/opl4_pcm.v
add_file $SRC/src/wave_sdram.v

# ---- Y8950 FM (jtopl2, OPL_TYPE=2) ----
add_file $SRC/jtopl/jtopl2.v
add_file $SRC/jtopl/jtopl.v
add_file $SRC/jtopl/jtopl_acc.v
add_file $SRC/jtopl/jtopl_csr.v
add_file $SRC/jtopl/jtopl_div.v
add_file $SRC/jtopl/jtopl_eg.v
add_file $SRC/jtopl/jtopl_eg_cnt.v
add_file $SRC/jtopl/jtopl_eg_comb.v
add_file $SRC/jtopl/jtopl_eg_ctrl.v
add_file $SRC/jtopl/jtopl_eg_final.v
add_file $SRC/jtopl/jtopl_eg_pure.v
add_file $SRC/jtopl/jtopl_eg_step.v
add_file $SRC/jtopl/jtopl_exprom.v
add_file $SRC/jtopl/jtopl_lfo.v
add_file $SRC/jtopl/jtopl_logsin.v
add_file $SRC/jtopl/jtopl_mmr.v
add_file $SRC/jtopl/jtopl_noise.v
add_file $SRC/jtopl/jtopl_op.v
add_file $SRC/jtopl/jtopl_pg.v
add_file $SRC/jtopl/jtopl_pg_comb.v
add_file $SRC/jtopl/jtopl_pg_inc.v
add_file $SRC/jtopl/jtopl_pg_rhy.v
add_file $SRC/jtopl/jtopl_pg_sum.v
add_file $SRC/jtopl/jtopl_pm.v
add_file $SRC/jtopl/jtopl_reg.v
add_file $SRC/jtopl/jtopl_reg_ch.v
add_file $SRC/jtopl/jtopl_sh.v
add_file $SRC/jtopl/jtopl_sh_rst.v
add_file $SRC/jtopl/jtopl_single_acc.v
add_file $SRC/jtopl/jtopl_slot_cnt.v
add_file $SRC/jtopl/jtopl_timers.v

# ---- Y8950 ADPCM-B (jt10 decoder + glue con RAM 32KB BSRAM) ----
add_file $SRC/jt10/jt10_adpcmb.v
add_file $SRC/jt10/jt10_adpcmb_interpol.v
add_file $SRC/jt10/jt10_adpcm_div.v
add_file $SRC/src/y8950_adpcm.v

# ---- harness ----
add_file C:/Users/alber/proyectosAI/msx/MSX_up/fpga/opl4_20k_est/opl4_y8950_est_top.v

set_option -top_module opl4_y8950_est_top -verilog_std sysv2017 -include_path $SRC/src
set_option -place_option 2
set_option -route_option 1

run syn
run pnr
