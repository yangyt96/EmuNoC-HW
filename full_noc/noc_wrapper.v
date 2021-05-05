module noc_wrapper(
    input clk,
    input rst,
    input [31:0] local_rx [3:0],
    input local_vc_write_rx[7:0],
    input local_incr_rx_vec[7:0],
    output [31:0] local_tx[3:0],
    output local_vc_write_tx[7:0],
    output local_incr_tx_vec[7:0]
);

    full_noc inst(
        .clk(clk),
        .rst(rst),
        .local_rx(loca_rx),
        .local_vc_write_rx(local_vc_write_rx),
        .local_incr_rx_vec(local_incr_rx_vec),
        .local_tx(local_tx),
        .local_vc_write_tx(local_vc_write_tx),
        .local_incr_tx_vec(local_incr_tx_vec)
    );

endmodule