library ieee;
use ieee.std_logic_1164.all;

use work.NOC_3D_PACKAGE.vhd

entity s_axi_noc is
    generic (
        router_num         : Integer := 4;
        C_S_AXI_ADDR_WIDTH : Integer := 32;
        C_S_AXI_DATA_WIDTH : Integer := 32
    );
    port (
        s_axi_aclk    : in Std_logic;
        s_axi_aresetn : in Std_logic;
        s_axi_awaddr  : in Std_logic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0); -- this indicates which vc will be used
        s_axi_awprot  : in Std_logic_vector(2 downto 0);
        s_axi_awvalid : in Std_logic; -- required
        s_axi_awready : out Std_logic;
        s_axi_wdata   : in Std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0); -- flit
        s_axi_wstrb   : in Std_logic_vector((C_S_AXI_DATA_WIDTH/8) - 1 downto 0);
        s_axi_wvalid  : in Std_logic; -- required
        s_axi_wready  : out Std_logic;
        s_axi_bresp   : out Std_logic_vector(1 downto 0);
        s_axi_bvalid  : out Std_logic;
        s_axi_bready  : in Std_logic;
        s_axi_araddr  : in Std_logic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0);
        s_axi_arprot  : in Std_logic_vector(2 downto 0);
        s_axi_arvalid : in Std_logic;
        s_axi_arready : out Std_logic;
        s_axi_rdata   : out Std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
        s_axi_rresp   : out Std_logic_vector(1 downto 0);
        s_axi_rvalid  : out Std_logic;
        s_axi_rready  : in Std_logic;

        clk_noc : in Std_logic;
        rst_noc : in Std_logic
    );
end entity s_axi_noc;
architecture structural of s_axi_noc is
    signal local_rx          : flit_vector(4 - 1 downto 0);
    signal local_vc_write_rx : Std_logic_vector(8 - 1 downto 0);
    signal local_incr_rx_vec : Std_logic_vector(8 - 1 downto 0);
    signal local_tx          : flit_vector(4 - 1 downto 0);
    signal local_vc_write_tx : Std_logic_vector(8 - 1 downto 0);
    signal local_incr_tx_vec : Std_logic_vector(8 - 1 downto 0)
begin

    local_rx(0) <= s_axi_wdata;

    -- inst : entity work.full_noc
    --     port map(
    --         clk               => clk_noc,
    --         rst               => rst_noc,
    --         local_rx          => local_rx,
    --         local_vc_write_rx => local_vc_write_rx,
    --         local_incr_rx_vec => local_incr_rx_vec,
    --         local_tx          => local_tx,
    --         local_vc_write_tx => local_vc_write_tx,
    --         local_incr_tx_vec => local_incr_tx_vec
    --     );

end architecture structural;
-- -- Global Clock Signal
-- S_AXI_ACLK : in Std_logic;
-- -- Global Reset Signal. This Signal is Active LOW
-- S_AXI_ARESETN : in Std_logic;
-- -- Write address (issued by master, acceped by Slave)
-- S_AXI_AWADDR : in Std_logic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0);
-- -- Write channel Protection type. This signal indicates the
-- -- privilege and security level of the transaction, and whether
-- -- the transaction is a data access or an instruction access.
-- S_AXI_AWPROT : in Std_logic_vector(2 downto 0);
-- -- Write address valid. This signal indicates that the master signaling
-- -- valid write address and control information.
-- S_AXI_AWVALID : in Std_logic;
-- -- Write address ready. This signal indicates that the slave is ready
-- -- to accept an address and associated control signals.
-- S_AXI_AWREADY : out Std_logic;
-- -- Write data (issued by master, acceped by Slave)
-- S_AXI_WDATA : in Std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
-- -- Write strobes. This signal indicates which byte lanes hold
-- -- valid data. There is one write strobe bit for each eight
-- -- bits of the write data bus.
-- S_AXI_WSTRB : in Std_logic_vector((C_S_AXI_DATA_WIDTH/8) - 1 downto 0);
-- -- Write valid. This signal indicates that valid write
-- -- data and strobes are available.
-- S_AXI_WVALID : in Std_logic;
-- -- Write ready. This signal indicates that the slave
-- -- can accept the write data.
-- S_AXI_WREADY : out Std_logic;
-- -- Write response. This signal indicates the status
-- -- of the write transaction.
-- S_AXI_BRESP : out Std_logic_vector(1 downto 0);
-- -- Write response valid. This signal indicates that the channel
-- -- is signaling a valid write response.
-- S_AXI_BVALID : out Std_logic;
-- -- Response ready. This signal indicates that the master
-- -- can accept a write response.
-- S_AXI_BREADY : in Std_logic;
-- -- Read address (issued by master, acceped by Slave)
-- S_AXI_ARADDR : in Std_logic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0);
-- -- Protection type. This signal indicates the privilege
-- -- and security level of the transaction, and whether the
-- -- transaction is a data access or an instruction access.
-- S_AXI_ARPROT : in Std_logic_vector(2 downto 0);
-- -- Read address valid. This signal indicates that the channel
-- -- is signaling valid read address and control information.
-- S_AXI_ARVALID : in Std_logic;
-- -- Read address ready. This signal indicates that the slave is
-- -- ready to accept an address and associated control signals.
-- S_AXI_ARREADY : out Std_logic;
-- -- Read data (issued by slave)
-- S_AXI_RDATA : out Std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
-- -- Read response. This signal indicates the status of the
-- -- read transfer.
-- S_AXI_RRESP : out Std_logic_vector(1 downto 0);
-- -- Read valid. This signal indicates that the channel is
-- -- signaling the required read data.
-- S_AXI_RVALID : out Std_logic;
-- -- Read ready. This signal indicates that the master can
-- -- accept the read data and response information.
-- S_AXI_RREADY : in Std_logic