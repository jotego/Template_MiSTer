module vga_top(
    input         clk_hdmi,
    input         clk_vid,

    // Configuration
    input         ypbpr_en,
    input         csync_en,
    input         vga_fb,
    input         vga_scaler,
    input         oen_b,        // output enable (active low)

    // Scaler version
    input         hdmi_hs_osd,
    input         hdmi_vs_osd,
    input         hdmi_cs_osd,
    input         hdmi_de_osd,
    input  [23:0] hdmi_data_osd,

    // Regular version
    input         vga_hs_osd,
    input         vga_vs_osd,
    input         vga_cs_osd,
    input  [23:0] vga_data_osd,

    // FPGA pins
    input         VGA_ENB,
    output  [5:0] VGA_R,
    output  [5:0] VGA_G,
    output  [5:0] VGA_B,
    inout         VGA_HS,  // VGA_HS is secondary SD card detect when VGA_ENB = 1 (inactive)
    output        VGA_VS
);

    wire [23:0] vgas_o;
    wire vgas_hs, vgas_vs, vgas_cs;
    vga_out vga_scaler_out
    (
        .clk(clk_hdmi),
        .ypbpr_en(ypbpr_en),
        .hsync(hdmi_hs_osd),
        .vsync(hdmi_vs_osd),
        .csync(hdmi_cs_osd),
        .dout(vgas_o),
        .din({24{hdmi_de_osd}} & hdmi_data_osd),
        .hsync_o(vgas_hs),
        .vsync_o(vgas_vs),
        .csync_o(vgas_cs)
    );

    wire [23:0] vga_o;
    wire vga_hs, vga_vs, vga_cs;
    vga_out vga_out
    (
        .clk(clk_vid),
        .ypbpr_en(ypbpr_en),
        .hsync(vga_hs_osd),
        .vsync(vga_vs_osd),
        .csync(vga_cs_osd),
        .dout(vga_o),
        .din(vga_data_osd),
        .hsync_o(vga_hs),
        .vsync_o(vga_vs),
        .csync_o(vga_cs)
    );

    wire cs1 = (vga_fb | vga_scaler) ? vgas_cs : vga_cs;

    assign VGA_VS = (VGA_ENB | oen_b) ? 1'bZ      : ((vga_fb | vga_scaler) ? ~vgas_vs : ~vga_vs) | csync_en;
    assign VGA_HS = (VGA_ENB | oen_b) ? 1'bZ      :  (vga_fb | vga_scaler) ? (csync_en ? ~vgas_cs : ~vgas_hs) : (csync_en ? ~vga_cs : ~vga_hs);
    assign VGA_R  = (VGA_ENB | oen_b) ? 6'bZZZZZZ :  (vga_fb | vga_scaler) ? vgas_o[23:18] : vga_o[23:18];
    assign VGA_G  = (VGA_ENB | oen_b) ? 6'bZZZZZZ :  (vga_fb | vga_scaler) ? vgas_o[15:10] : vga_o[15:10];
    assign VGA_B  = (VGA_ENB | oen_b) ? 6'bZZZZZZ :  (vga_fb | vga_scaler) ? vgas_o[7:2]   : vga_o[7:2]  ;
endmodule