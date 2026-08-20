// ============================================================================
// opl4_est_top.v — HARNESS DE ESTIMACION DE RECURSOS (NO es un diseño real)
//
// Objetivo: medir el coste en LUT/CLS/DSP/BSRAM del bloque OPL4 completo
// (FM OPL3 + motor PCM wavetable + shim de memoria de ondas) sintetizado
// SOLO, contra la GW2AR-18C de la Tang Nano 20K, para decidir si cabe en
// un cartucho WonderTANG.
//
// Truco anti-optimizacion y anti-desborde-de-pines:
//  - TODAS las entradas de los modulos se alimentan de UN shift register
//    de 256 bits movido por un unico pin serie `sin`. Asi el sintetizador
//    ve cada entrada conducida por FFs reales (no constant-folding) y el
//    diseño tiene 6 pines en vez de ~150 (el QN88 no daria).
//  - TODAS las salidas se concatenan y se reducen por XOR a un unico pin
//    `sout` (registrado). Nada se puede podar: todo alimenta la salida.
//
// El numero que importa es la seccion "Resource Usage Summary" del
// project.rpt.txt tras `run pnr`. El timing aqui NO es representativo
// (sin .sdc, relojes sin restringir) — es un censo de recursos.
// ============================================================================

module opl4_est_top (
    input  wire clk_host,     // 54 MHz (dominio bus)
    input  wire clk_opl3,     // 33.75 MHz (FM)
    input  wire clk_eng,      // 37.125 MHz (motor PCM)
    input  wire clk_108m,     // 108 MHz (arbitraje SDRAM)
    input  wire rst_n,
    input  wire sin,          // serie -> alimenta todas las entradas
    output wire sout          // XOR de todas las salidas
);

    // ------------------------------------------------------------------
    // shift register de entrada (256b) — cada bit conduce una entrada
    // ------------------------------------------------------------------
    reg [255:0] ish;
    always @(posedge clk_host) ish <= {ish[254:0], sin};

    // --- bus MSX comun a opl4fm y opl4_pcm ---
    wire        iorq_n = ish[0];
    wire        rd_n   = ish[1];
    wire        wr_n   = ish[2];
    wire        m1_n   = ish[3];
    wire [7:0]  addr   = ish[11:4];
    wire [7:0]  din    = ish[19:12];
    // --- puerto HOST/loader del wave_sdram (carga YRW801 desde SD) ---
    wire        wl_req_toggle = ish[20];
    wire        wl_we         = ish[21];
    wire [21:0] wl_addr       = ish[43:22];
    wire [7:0]  wl_wdata      = ish[51:44];
    // --- retorno del controlador SDRAM (puerto wv_*) ---
    wire [15:0] wv_dout = ish[67:52];
    wire        wv_done = ish[68];

    // ==================================================================
    // 1) FM OPL3  (opl4fm)
    // ==================================================================
    wire        uf_fm_rd, uf_wave_rd, uf_int_n;
    wire [7:0]  uf_dout, uf_wave_dout;
    wire signed [15:0] uf_pcm_out;
    wire [1:0]  up_wave_status;   // viene del motor PCM

    opl4fm uf (
        .rst_n       (rst_n),
        .clk_host    (clk_host),
        .clk_opl3    (clk_opl3),
        .iorq_n      (iorq_n),
        .rd_n        (rd_n),
        .wr_n        (wr_n),
        .m1_n        (m1_n),
        .addr        (addr),
        .din         (din),
        .wave_status (up_wave_status),
        .fm_rd       (uf_fm_rd),
        .wave_rd     (uf_wave_rd),
        .dout        (uf_dout),
        .wave_dout   (uf_wave_dout),
        .pcm_out     (uf_pcm_out),
        .int_n       (uf_int_n)
    );

    // ==================================================================
    // 2) motor PCM wavetable  (opl4_pcm)  <->  shim de memoria (wave_sdram)
    // ==================================================================
    wire        up_wave_rd, up_wave_wait_n, up_dbg_tx;
    wire [7:0]  up_wave_dout, up_diag;
    wire [5:0]  up_mix_fm;
    wire signed [15:0] up_pcm_l, up_pcm_r;
    // puerto de memoria del motor
    wire        up_mem_req, up_mem_we;
    wire [21:0] up_mem_addr;
    wire [7:0]  up_mem_wdata;
    // vuelta desde el shim
    wire [7:0]  uw_eng_rdata;
    wire [15:0] uw_eng_rword;
    wire        uw_eng_done_t;

    opl4_pcm up (
        .rst_n       (rst_n),
        .clk_host    (clk_host),
        .iorq_n      (iorq_n),
        .rd_n        (rd_n),
        .wr_n        (wr_n),
        .m1_n        (m1_n),
        .addr        (addr),
        .din         (din),
        .wave_rd     (up_wave_rd),
        .wave_dout   (up_wave_dout),
        .wave_wait_n (up_wave_wait_n),
        .wave_status (up_wave_status),
        .mix_fm      (up_mix_fm),
        .pcm_l       (up_pcm_l),
        .pcm_r       (up_pcm_r),
        .clk_eng     (clk_eng),
        .eng_rst_n   (rst_n),
        .mem_req     (up_mem_req),
        .mem_we      (up_mem_we),
        .mem_addr    (up_mem_addr),
        .mem_wdata   (up_mem_wdata),
        .mem_rdata   (uw_eng_rdata),
        .mem_rword   (uw_eng_rword),
        .mem_done_t  (uw_eng_done_t),
        .diag        (up_diag),
        .dbg_tx      (up_dbg_tx)
    );

    // shim de memoria de ondas (host loader + motor + puerto wv_* a SDRAM)
    wire [7:0]  uw_rdata, uw_diag;
    wire        uw_done_toggle, uw_ready;
    wire        uw_wv_req, uw_wv_we;
    wire [21:0] uw_wv_addr;
    wire [7:0]  uw_wv_wdata;

    wave_sdram uw (
        .clk_host    (clk_host),
        .rst_n       (rst_n),
        .req_toggle  (wl_req_toggle),
        .we          (wl_we),
        .addr        (wl_addr),
        .wdata       (wl_wdata),
        .rdata       (uw_rdata),
        .done_toggle (uw_done_toggle),
        .ready       (uw_ready),
        .clk_eng     (clk_eng),
        .eng_req     (up_mem_req),
        .eng_we      (up_mem_we),
        .eng_addr    (up_mem_addr),
        .eng_wdata   (up_mem_wdata),
        .eng_rdata   (uw_eng_rdata),
        .eng_rword   (uw_eng_rword),
        .eng_done_t  (uw_eng_done_t),
        .diag        (uw_diag),
        .clk_108m    (clk_108m),
        .wv_req      (uw_wv_req),
        .wv_we       (uw_wv_we),
        .wv_addr     (uw_wv_addr),
        .wv_wdata    (uw_wv_wdata),
        .wv_dout     (wv_dout),
        .wv_done     (wv_done)
    );

    // ------------------------------------------------------------------
    // censo: concatenar TODAS las salidas y reducir por XOR a 1 pin
    // ------------------------------------------------------------------
    wire [255:0] allout = {
        // opl4fm
        uf_fm_rd, uf_wave_rd, uf_int_n, uf_dout, uf_wave_dout, uf_pcm_out,
        // opl4_pcm
        up_wave_rd, up_wave_wait_n, up_dbg_tx, up_wave_dout, up_diag,
        up_mix_fm, up_pcm_l, up_pcm_r, up_wave_status,
        up_mem_req, up_mem_we, up_mem_addr, up_mem_wdata,
        // wave_sdram
        uw_rdata, uw_diag, uw_done_toggle, uw_ready,
        uw_eng_rdata, uw_eng_rword, uw_eng_done_t,
        uw_wv_req, uw_wv_we, uw_wv_addr, uw_wv_wdata,
        1'b0 // padding
    };

    reg sout_r;
    always @(posedge clk_host or negedge rst_n) begin
        if (!rst_n) sout_r <= 1'b0;
        else        sout_r <= ^allout;
    end
    assign sout = sout_r;

endmodule
