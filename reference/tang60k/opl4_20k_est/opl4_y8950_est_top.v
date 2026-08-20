// ============================================================================
// opl4_y8950_est_top.v — HARNESS DE ESTIMACION v2 (NO es diseño real)
//
// Mide el coste de OPL4 (FM OPL3 + wavetable) + Y8950 MSX-Audio (FM jtopl2 +
// ADPCM-B jt10 con su RAM de 32KB en BSRAM) juntos, en la GW2AR-18C de la
// Tang Nano 20K, para ver si un cartucho WonderTANG "MoonSound + MSX-Audio"
// cabe. Mismo truco anti-poda que el harness v1: entradas serializadas por
// 1 pin, salidas XOR a 1 pin.
//
// OJO terminologia: el OPL3 (YMF262) YA esta dentro del OPL4 (opl4fm). Lo que
// añade "ADPCM" es el Y8950 = FM tipo OPL (jtopl2) + ADPCM-B. Aqui se suma el
// Y8950 ENTERO sobre el bloque OPL4 ya medido.
// ============================================================================

module opl4_y8950_est_top (
    input  wire clk_host,     // 54 MHz
    input  wire clk_opl3,     // 33.75 MHz
    input  wire clk_eng,      // 37.125 MHz
    input  wire clk_108m,     // 108 MHz
    input  wire rst_n,
    input  wire sin,
    output wire sout
);
    reg [255:0] ish;
    always @(posedge clk_host) ish <= {ish[254:0], sin};

    // --- bus MSX comun ---
    wire        iorq_n = ish[0];
    wire        rd_n   = ish[1];
    wire        wr_n   = ish[2];
    wire        m1_n   = ish[3];
    wire [7:0]  addr   = ish[11:4];
    wire [7:0]  din    = ish[19:12];
    wire        wl_req_toggle = ish[20];
    wire        wl_we         = ish[21];
    wire [21:0] wl_addr       = ish[43:22];
    wire [7:0]  wl_wdata      = ish[51:44];
    wire [15:0] wv_dout = ish[67:52];
    wire        wv_done = ish[68];
    // --- extra para Y8950 ---
    wire        cen3m6 = ish[69];
    wire        y_addr = ish[70];
    wire        y_cs_n = ish[71];
    wire        wr_c0  = ish[72];
    wire        wr_c1  = ish[73];
    wire        rd_c1  = ish[74];

    // ================= OPL4 FM (opl4fm) =================
    wire        uf_fm_rd, uf_wave_rd, uf_int_n;
    wire [7:0]  uf_dout, uf_wave_dout;
    wire signed [15:0] uf_pcm_out;
    wire [1:0]  up_wave_status;

    opl4fm uf (
        .rst_n(rst_n), .clk_host(clk_host), .clk_opl3(clk_opl3),
        .iorq_n(iorq_n), .rd_n(rd_n), .wr_n(wr_n), .m1_n(m1_n),
        .addr(addr), .din(din), .wave_status(up_wave_status),
        .fm_rd(uf_fm_rd), .wave_rd(uf_wave_rd), .dout(uf_dout),
        .wave_dout(uf_wave_dout), .pcm_out(uf_pcm_out), .int_n(uf_int_n)
    );

    // ============ OPL4 PCM (opl4_pcm) <-> wave_sdram ============
    wire        up_wave_rd, up_wave_wait_n, up_dbg_tx;
    wire [7:0]  up_wave_dout, up_diag;
    wire [5:0]  up_mix_fm;
    wire signed [15:0] up_pcm_l, up_pcm_r;
    wire        up_mem_req, up_mem_we;
    wire [21:0] up_mem_addr;
    wire [7:0]  up_mem_wdata;
    wire [7:0]  uw_eng_rdata;
    wire [15:0] uw_eng_rword;
    wire        uw_eng_done_t;

    opl4_pcm up (
        .rst_n(rst_n), .clk_host(clk_host),
        .iorq_n(iorq_n), .rd_n(rd_n), .wr_n(wr_n), .m1_n(m1_n),
        .addr(addr), .din(din),
        .wave_rd(up_wave_rd), .wave_dout(up_wave_dout),
        .wave_wait_n(up_wave_wait_n), .wave_status(up_wave_status),
        .mix_fm(up_mix_fm), .pcm_l(up_pcm_l), .pcm_r(up_pcm_r),
        .clk_eng(clk_eng), .eng_rst_n(rst_n),
        .mem_req(up_mem_req), .mem_we(up_mem_we), .mem_addr(up_mem_addr),
        .mem_wdata(up_mem_wdata), .mem_rdata(uw_eng_rdata),
        .mem_rword(uw_eng_rword), .mem_done_t(uw_eng_done_t),
        .diag(up_diag), .dbg_tx(up_dbg_tx)
    );

    wire [7:0]  uw_rdata, uw_diag;
    wire        uw_done_toggle, uw_ready;
    wire        uw_wv_req, uw_wv_we;
    wire [21:0] uw_wv_addr;
    wire [7:0]  uw_wv_wdata;

    wave_sdram uw (
        .clk_host(clk_host), .rst_n(rst_n),
        .req_toggle(wl_req_toggle), .we(wl_we), .addr(wl_addr), .wdata(wl_wdata),
        .rdata(uw_rdata), .done_toggle(uw_done_toggle), .ready(uw_ready),
        .clk_eng(clk_eng), .eng_req(up_mem_req), .eng_we(up_mem_we),
        .eng_addr(up_mem_addr), .eng_wdata(up_mem_wdata),
        .eng_rdata(uw_eng_rdata), .eng_rword(uw_eng_rword),
        .eng_done_t(uw_eng_done_t), .diag(uw_diag),
        .clk_108m(clk_108m), .wv_req(uw_wv_req), .wv_we(uw_wv_we),
        .wv_addr(uw_wv_addr), .wv_wdata(uw_wv_wdata),
        .wv_dout(wv_dout), .wv_done(wv_done)
    );

    // ================= Y8950 FM (jtopl2) =================
    wire [7:0]  y_dout;
    wire        y_irq_n, y_sample;
    wire signed [15:0] y_snd;

    jtopl2 y8950 (
        .rst(~rst_n), .clk(clk_host), .cen(cen3m6),
        .din(din), .addr(y_addr), .cs_n(y_cs_n), .wr_n(wr_n),
        .dout(y_dout), .irq_n(y_irq_n), .snd(y_snd), .sample(y_sample)
    );

    // ================= Y8950 ADPCM-B (y8950_adpcm + jt10) =================
    wire [7:0]  a_status;
    wire [7:0]  a_data_dout;
    wire        a_irq;
    wire signed [15:0] a_pcm_out;

    y8950_adpcm uadpcm (
        .clk(clk_host), .cen3m6(cen3m6), .rst_n(rst_n),
        .wr_c0(wr_c0), .wr_c1(wr_c1), .rd_c1(rd_c1), .din(din),
        .ft1(y_dout[6]), .ft2(y_dout[5]),
        .status(a_status), .data_dout(a_data_dout),
        .irq(a_irq), .pcm_out(a_pcm_out)
    );

    // ---------------- censo XOR ----------------
    wire [255:0] allout = {
        uf_fm_rd, uf_wave_rd, uf_int_n, uf_dout, uf_wave_dout, uf_pcm_out,
        up_wave_rd, up_wave_wait_n, up_dbg_tx, up_wave_dout, up_diag,
        up_mix_fm, up_pcm_l, up_pcm_r, up_wave_status,
        up_mem_req, up_mem_we, up_mem_addr, up_mem_wdata,
        uw_rdata, uw_diag, uw_done_toggle, uw_ready,
        uw_eng_rdata, uw_eng_rword, uw_eng_done_t,
        uw_wv_req, uw_wv_we, uw_wv_addr, uw_wv_wdata,
        y_dout, y_irq_n, y_sample, y_snd,
        a_status, a_data_dout, a_irq, a_pcm_out,
        1'b0
    };

    reg sout_r;
    always @(posedge clk_host or negedge rst_n)
        if (!rst_n) sout_r <= 1'b0; else sout_r <= ^allout;
    assign sout = sout_r;

endmodule
