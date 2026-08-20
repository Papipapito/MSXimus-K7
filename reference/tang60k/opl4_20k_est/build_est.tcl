# ============================================================================
#  build_est.tcl — SINTESIS DE ESTIMACION: bloque OPL4 solo en Tang Nano 20K
#  Device GW2AR-18C (GW2AR-LV18QN88C8/I7). Uso: gw_sh.exe build_est.tcl
#  (ejecutar desde la carpeta opl4_20k_est/ — impl/ se genera aqui)
# ============================================================================
set_device -name GW2AR-18C GW2AR-LV18QN88C8/I7

set SRC C:/Users/alber/proyectosAI/msx/MSX_up/fpga

# ----- core FM OPL3 (gtaylormb / mangOPL4) — paquete primero -----
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

# ----- motor PCM wavetable (srg320 YMF278B via sv2v) + shim memoria -----
add_file $SRC/opl4wave/ymf278b_gowin.v
add_file $SRC/src/opl4_pcm.v
add_file $SRC/src/wave_sdram.v

# ----- harness de estimacion -----
add_file C:/Users/alber/proyectosAI/msx/MSX_up/fpga/opl4_20k_est/opl4_est_top.v

set_option -top_module opl4_est_top -verilog_std sysv2017 -include_path $SRC/src
set_option -place_option 2
set_option -route_option 1

run syn
run pnr
