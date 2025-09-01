# Project Update & Handoff Notes (Aug 26)

Hey team,

Here’s a quick summary of the changes I pushed tonight for the FPGA wrapper and sequencer. The goal was to fix the data loading and get the core to run past the first 'Q' step.

---
## Change 1: Corrected DMA Loading in the Top Wrapper

* **File Changed**: `ITA_FPGA_WRAPPER.sv`
* **Problem**: The old FSM used a single DMA transfer (`WB_LOAD_WORDS`) for all weights & biases. This was incorrect.
* **Reasoning**: The `BASE_PTR` logic proves that the **Attention and FFN parameters are NOT stored contiguously** in the URAM. There's a gap between them for intermediate results (the FFN's input tensor). A single, contiguous DMA write would corrupt this memory region.
* **Solution**:
    1.  I replaced the single `start_wb_i` path with two distinct loading paths triggered by new inputs: `start_load_attn_wb_i` and `start_load_ffn_wb_i`.
    2.  Each path now uses the correct, specific transfer length (`ATTN_WB_LOAD_WORDS` and `FFN_WB_LOAD_WORDS`).
    3.  The FSM now internally selects the correct logical `BASE_PTR` for each DMA operation, ensuring data is written to the correct (non-contiguous) locations.

---
## Change 2: Fixed Sequencer Deadlock

* **File Changed**: `ita_sequencer.sv`
* **Problem**: The sequencer would hang after processing the first tile of the 'Q' step. The `hwpe_busy_i` signal would never go low again.
* **Reasoning**: The FSM's control flow was **`PROGRAM -> TRIGGER -> WAIT`**. The working testbench's flow is **`WAIT -> PROGRAM -> TRIGGER`**. The sequencer was illegally reprogramming the HWPE for the next tile *while* it was still busy with the current one, causing a deadlock.
* **Solution**: I restructured the FSM to be a cycle-accurate mimic of the testbench. The main fix is a new `S_CHECK_BUSY` state at the **beginning** of each tile's processing loop. This state waits for `hwpe_busy_i` to be low *before* continuing, ensuring the previous operation is complete.

---
## Change 3: Added Critical Stability Delays to Sequencer

* **File Changed**: `ita_sequencer.sv`
* **Problem**: While functionally correct, the sequencer was missing two subtle delays that the testbench author explicitly commented were for **"stability"**. Ignoring these is risky.
* **Reasoning**: These delays are likely required by the HWPE's internal pipeline to settle before receiving new commands.
* **Solution**: I added two new states to the FSM to perfectly mimic the testbench's timing:
    1.  **5-Cycle Delay**: Added `S_POST_BUSY_DELAY` to wait 5 cycles after `busy` goes low but *before* programming the next tile. This mimics the `repeat(5)` in the testbench.
    2.  **1-Cycle Delay**: Added `S_POST_PROGRAM_DELAY` to wait 1 cycle after the last register is written but *before* the trigger is sent. This mimics the `@(posedge clk_i)` in the testbench.

With these fixes, the wrapper has a correct data loading strategy, and the sequencer should be a fully cycle-accurate and robust replacement for the testbench's control logic.

Let me know if anything is unclear. Good luck!