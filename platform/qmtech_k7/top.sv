// ============================================================================
//  top.sv - QMTECH XC7K325T - HITO 1 "Vida"
// ----------------------------------------------------------------------------
//  Objetivo del hito: demostrar que el reloj entra, que el MMCM engancha y
//  que el bitstream se carga. NADA de MSX todavia.
//
//  Criterio de salida: parpadeo a ritmo MEDIDO (1 Hz exacto, no "parece que
//  parpadea"), JTAG programa, DONE sube.
//
//  Por que se parpadea en un PMOD y no en un LED de placa: los pines de los
//  LEDs NO estan verificados (ver board.xdc). Los de PMOD si. Pincha un LED
//  con su resistencia entre pmod1[0] (J11 pin 1) y GND (J11 pin 5), o mide
//  con el polimetro en continua: debe oscilar entre ~0 y ~3,3 V.
//
//  El MMCM instanciado es el "REF" del plan de relojes:
//     50 MHz -> D=1, M=13,500 -> VCO 675 MHz -> /25 -> 27,000 MHz EXACTOS
//  Es el primer escalon de la cascada; los MMCM SYS y VID cuelgan de el.
// ============================================================================
`default_nettype none

module top (
    input  wire        clk_50m,
    inout  wire [7:0]  pmod1,
    inout  wire [7:0]  pmod2,
    inout  wire [7:0]  pmod3
);

    // ------------------------------------------------------ MMCM REF ------
    wire clk_fb, clk_27_raw, mmcm_locked;

    MMCME2_BASE #(
        .BANDWIDTH          ("OPTIMIZED"),
        .CLKIN1_PERIOD      (20.000),   // 50 MHz
        .DIVCLK_DIVIDE      (1),        // D
        .CLKFBOUT_MULT_F    (13.500),   // M  -> VCO = 50 * 13,5 = 675 MHz
        .CLKOUT0_DIVIDE_F   (25.000),   // 675 / 25 = 27,000 MHz exactos
        .CLKOUT0_DUTY_CYCLE (0.500),
        .STARTUP_WAIT       ("FALSE")
    ) u_mmcm_ref (
        .CLKIN1   (clk_50m),
        .CLKFBIN  (clk_fb),
        .CLKFBOUT (clk_fb),
        .CLKOUT0  (clk_27_raw),
        .LOCKED   (mmcm_locked),
        .PWRDWN   (1'b0),
        .RST      (1'b0)
    );

    wire clk_27;
    BUFG u_bufg_27 (.I(clk_27_raw), .O(clk_27));

    // ------------------------------------------- reset sincrono al lock ---
    (* ASYNC_REG = "TRUE" *) reg [2:0] lock_sync = 3'b000;
    always_ff @(posedge clk_27) lock_sync <= {lock_sync[1:0], mmcm_locked};
    wire rst_n = lock_sync[2];

    // --------------------------------------- divisor a 1 Hz exacto -------
    // 27.000.000 ciclos = 1 s. Semiperiodo 13.500.000 -> onda de 1 Hz.
    localparam int HALF = 13_500_000;
    reg [23:0] cnt  = 24'd0;
    reg        beat = 1'b0;

    always_ff @(posedge clk_27) begin
        if (!rst_n) begin
            cnt  <= 24'd0;
            beat <= 1'b0;
        end else if (cnt == HALF - 1) begin
            cnt  <= 24'd0;
            beat <= ~beat;
        end else begin
            cnt <= cnt + 24'd1;
        end
    end

    // ---------------------------------------------------- salidas --------
    // pmod1[0] = J11 pin 1 -> el parpadeo de 1 Hz
    // pmod1[1] = J11 pin 2 -> lock del MMCM (fijo alto = enganchado)
    // El resto en alta impedancia: nada conectado todavia.
    assign pmod1[0] = beat;
    assign pmod1[1] = mmcm_locked;
    assign pmod1[7:2] = 6'bzzzzzz;
    assign pmod2 = 8'bzzzzzzzz;
    assign pmod3 = 8'bzzzzzzzz;

endmodule

`default_nettype wire
