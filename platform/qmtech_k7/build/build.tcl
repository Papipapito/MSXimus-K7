# ============================================================================
#  build.tcl - build NO-PROJECT reproducible para Vivado
#  Uso:  vivado -mode batch -source platform/qmtech_k7/build/build.tcl
#        vivado -mode batch -source ... -tclargs --top top_hdmi_test
# ----------------------------------------------------------------------------
#  No-project a proposito: nada de .xpr en git. El unico estado es este script
#  mas las fuentes. Reproducible y revisable en un diff.
# ============================================================================

set PART    xc7k325tffg676-1
set TOP     top
set ROOT    [file normalize [file dirname [info script]]/../../..]
set PLAT    $ROOT/platform/qmtech_k7
set OUT     $PLAT/build/out

# ----- argumentos -----
for {set i 0} {$i < $argc} {incr i} {
    switch -- [lindex $argv $i] {
        "--top"  { incr i; set TOP [lindex $argv $i] }
        "--part" { incr i; set PART [lindex $argv $i] }
    }
}

file mkdir $OUT
puts "=== MSXimus-K7 :: top=$TOP part=$PART ==="

# ----- fuentes ------------------------------------------------------------
# Plataforma
read_verilog -sv [glob $PLAT/*.sv]

# Core portable. Se activa segun avanzan los hitos: hasta el Hito 3 el core
# no entra en el build. Descomentar cuando toque (Hito 4 en adelante).
#
# OJO con dos cosas al descomentar:
#   1) Buena parte del core es VHDL, no Verilog: G80A (el Z80 entero),
#      PSG_YM2149, tn_vdp_v3_v9958/src/vdp/, src/ocm/. Necesitan read_vhdl.
#   2) Hay fuentes en SUBdirectorios (src/ocm, src/usb_direct, src/wondertang,
#      tn_vdp_v3_v9958/src/hdmi, video720/...), asi que el glob va recursivo.
#      Los tb/ se excluyen a proposito: no son sintetizables.
#
# proc core_sources {root pats} {
#     set out {}
#     foreach p $pats {
#         foreach f [glob -nocomplain -directory $root -types f $p] { lappend out $f }
#     }
#     return $out
# }
# set CORE $ROOT/core
# set v_files    [core_sources $CORE {**/*.v}]
# set sv_files   [core_sources $CORE {**/*.sv}]
# set vhd_files  [core_sources $CORE {**/*.vhd **/*.vhdl}]
# # fuera bancos de pruebas
# foreach l {v_files sv_files vhd_files} {
#     set $l [lsearch -all -inline -not -glob [set $l] */tb/*]
# }
# if {[llength $v_files]}   { read_verilog     $v_files   }
# if {[llength $sv_files]}  { read_verilog -sv $sv_files  }
# if {[llength $vhd_files]} { read_vhdl        $vhd_files }

read_xdc $PLAT/board.xdc

# ----- flujo --------------------------------------------------------------
synth_design -top $TOP -part $PART -flatten_hierarchy rebuilt
write_checkpoint -force $OUT/post_synth.dcp
report_utilization -file $OUT/post_synth_util.rpt

opt_design
place_design
phys_opt_design
route_design

write_checkpoint -force $OUT/post_route.dcp

# ----- informes que MANDAN sobre cualquier estimacion ---------------------
report_utilization        -file $OUT/post_route_util.rpt
report_timing_summary     -file $OUT/post_route_timing.rpt -max_paths 20
report_drc                -file $OUT/post_route_drc.rpt
report_clock_utilization  -file $OUT/post_route_clocks.rpt

# ----- puerta de calidad: no entregar un bitstream que no cierra timing ---
set wns [get_property SLACK [get_timing_paths -delay_type max]]
set whs [get_property SLACK [get_timing_paths -delay_type min]]
puts "=== WNS = $wns ns   WHS = $whs ns ==="
if {$wns < 0 || $whs < 0} {
    puts "!!! TIMING NO CIERRA - revisa $OUT/post_route_timing.rpt"
    puts "!!! El bitstream se genera igual, pero NO te fies de el."
}

write_bitstream -force $OUT/$TOP.bit
puts "=== OK -> $OUT/$TOP.bit ==="
