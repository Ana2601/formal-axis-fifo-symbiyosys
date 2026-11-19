// Formal properties for the AXI-Stream FIFO (axis_fifo.sv).
//
// These SVA assertions prove safety invariants hold for ALL input sequences
// (bounded model checking / k-induction), not just the sampled ones.
//
// To keep the properties self-contained we instantiate the DUT here with a
// fixed depth of 4 (small enough for the solver).

`timescale 1ns/1ps

module fifo_formal_tb (
  // The clock is a top-level input: the solver steps it every formal cycle.
  // (An `always #5 clk = ~clk` generator is ignored by synthesis/formal, which
  // would leave the clock stuck and make every property vacuously true.)
  input logic clk
);

  localparam int DATA_WIDTH = 8;
  localparam int DEPTH      = 4;

  logic rst_n = 1'b0;

  // slave (input) side
  logic               s_axis_tvalid;
  logic               s_axis_tready;
  logic [DATA_WIDTH-1:0] s_axis_tdata;
  logic               s_axis_tlast;

  // master (output) side
  logic               m_axis_tvalid;
  logic               m_axis_tready;
  logic [DATA_WIDTH-1:0] m_axis_tdata;
  logic               m_axis_tlast;

  logic               fifo_full;
  logic               fifo_empty;
  logic [$clog2(DEPTH):0] fifo_count;

  axis_fifo #(
    .DATA_WIDTH(DATA_WIDTH),
    .DEPTH(DEPTH)
  ) dut (
    .clk           (clk),
    .rst_n         (rst_n),
    .s_axis_tvalid (s_axis_tvalid),
    .s_axis_tready (s_axis_tready),
    .s_axis_tdata  (s_axis_tdata),
    .s_axis_tlast  (s_axis_tlast),
    .m_axis_tvalid (m_axis_tvalid),
    .m_axis_tready (m_axis_tready),
    .m_axis_tdata  (m_axis_tdata),
    .m_axis_tlast  (m_axis_tlast),
    .fifo_full     (fifo_full),
    .fifo_empty    (fifo_empty),
    .fifo_count    (fifo_count)
  );


  // Deterministic reset for the formal model: asserted for the first clock
  // cycle, deasserted forever after. Avoids time-delay initializations that
  // don't formalize cleanly.
  initial rst_n = 1'b0;
  always @(posedge clk) rst_n <= 1'b1;

  // ===================== formal inputs (unconstrained) =====================
  // $anyseq: the solver picks a fresh value every cycle (any traffic pattern).
  // ($anyconst would freeze each input for the whole trace - a much weaker check.)
  wire f_s_axis_tvalid = $anyseq;
  wire [DATA_WIDTH-1:0] f_s_axis_tdata = $anyseq;
  wire f_s_axis_tlast = $anyseq;
  wire f_m_axis_tready = $anyseq;

  assign s_axis_tvalid = f_s_axis_tvalid;
  assign s_axis_tdata  = f_s_axis_tdata;
  assign s_axis_tlast  = f_s_axis_tlast;
  assign m_axis_tready = f_m_axis_tready;

  // ============================== properties ==============================
  // Assertions are checked on posedge clk; the `rst_n &&` guards skip them
  // while reset is asserted.

  always @(posedge clk) begin
    if (rst_n) begin
      // P1: never overflow -- count must always stay within [0, DEPTH]
      assert (fifo_count <= DEPTH);

      // P2: handshake -- a write must be dropped when the FIFO is full
      if (fifo_full && s_axis_tvalid) assert (!s_axis_tready);

      // P3: count may change by at most one per cycle (no over/underflow pulse)
      if ($past(fifo_count) >= fifo_count)
        assert ($past(fifo_count) - fifo_count <= 1);
      else
        assert (fifo_count - $past(fifo_count) <= 1);

      // P4: full and empty are mutually exclusive (for DEPTH >= 2)
      assert (!(fifo_full && fifo_empty));

      // P5: tready is combinational ~full
      assert (s_axis_tready == ~fifo_full);

      // P6 (inductive invariant): the output register only ever holds a word
      // that is still counted in the FIFO, so a pop can never underflow it
      if (m_axis_tvalid) assert (!fifo_empty);

      // P6: full means count == DEPTH
      if (fifo_full)
        assert (fifo_count == DEPTH);

      // P7: empty means count == 0
      if (fifo_empty)
        assert (fifo_count == 0);

      // P8: count == 0 implies empty
      if (fifo_count == 0)
        assert (fifo_empty);

      // P9: count == DEPTH implies full
      if (fifo_count == DEPTH)
        assert (fifo_full);
    end
  end

endmodule