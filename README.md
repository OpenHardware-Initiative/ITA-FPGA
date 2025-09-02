# AMD Open Hardware Competition Team AOHW25_216
AI Compilers Meet FPGAs: A HW/SW Codesign Approach for Vision Transformers

# Link to our 2 minute video: 
https://www.youtube.com/watch?v=RXjw670piBA

---

### Table of Contents
- [Fork Notice](#note)
- [Summary of Changes](#summary-of-changes)
- [FPGA System Architecture](#fpga-system-architecture)
- [Getting Started: Running the Full FPGA System](#getting-started-running-the-full-fpga-system)
  - [Requirements](#requirements)
  - [Vivado Project Setup](#vivado-project-setup)
  - [New Testbenches](#new-testbenches)
- [Original README Content](#original-readme-content)
  - [Simulating the Standalone ITA Core](#simulating-the-standalone-ita-core)
  - [Test Vector Generation](#test-vector-generation)
- [Contributors](#contributors)
- [License](#license)
- [References](#references)

---

# Note
This project is a fork of the excellent [ITA](https://github.com/pulp-platform/ita) by Gamze İslamoğlu (gislamoglu@iis.ee.ethz.ch) and Philip Wiese (wiesep@iis.ee.ethz.ch). We have ported the original ASIC-targeted accelerator core to an FPGA platform, building a custom memory subsystem and the necessary control logic to manage the full inference dataflow. Our sincere thanks go to the original creators for their foundational work.

### Summary of Changes

This fork adapts the original accelerator, which was designed for an ASIC, to a fully functional FPGA implementation. Our primary contributions were to refactor the core for FPGA synthesis and build the entire surrounding memory and control infrastructure required to run a complete inference pipeline.

The key architectural changes are:

*   **Core Refactoring for FPGA Synthesis**
    *   The original ASIC-optimized ITA core was modified to be FPGA-friendly. This involved replacing all latch-based memory elements with synthesizable flip-flops and removing the non-synthesizable clock-gating infrastructure. The core computational logic remains the same.

*   **New Memory Subsystem (ITA-URAM-DMA Adapter)**
    *   We replaced the original design's dependency on a 32-port Tightly-Coupled Data Memory (TCDM) with a custom memory controller built for FPGAs. This new adapter is the central hub of the memory system and is responsible for:
        *   **Emulating the TCDM:** It uses 32 parallel on-chip URAM banks to provide the high-bandwidth memory access required by the ITA core.
        *   **Memory Interleaving:** It maps sequential addresses across the URAM banks, allowing a single wide request from the ITA to be serviced in parallel.
        *   **Adding a DMA Interface:** It introduces a streaming interface for efficient, bulk data transfers to and from external memory (e.g., DDR), which is essential for loading model weights and input data.
        *   **Arbitration:** It manages access to the URAMs, granting control to either the ITA core during computation or the DMA during data transfers.

*   **Holistic Control and Dataflow Logic**
    *   A multi-level control system was created from scratch to manage the entire end-to-end inference process.
        *   **Top-Level FSM:** Orchestrates the high-level sequence: initiating DMA transfers to load data, triggering the ITA core for computation, and initiating DMA transfers to write back results.
        *   **Sequencer Module:** Acts as a low-level driver for the ITA core. It translates high-level commands (e.g., "compute Q matrix") into the series of precise register writes needed to process each data tile.
        *   **DMA Address Generator:** A dedicated helper module that generates the correct address streams for the memory controller during bulk DMA transfers.

---

## FPGA System Architecture

Below are diagrams of the top-level system and the memory controller we designed.

**Overall System Architecture**
![Overall System Architecture Diagram](path/to/your/wrapper_figure.png)

**ITA-URAM-DMA Adapter**
![ITA-URAM-DMA Adapter Diagram](path/to/your/adapter_figure.png)

---

## Original README Content

<details>
<summary><b>Click to expand the original documentation for the standalone ITA core</b></summary>

# Integer Transformer Accelerator
The Integer Transformer Accelerator is a hardware accelerator for the Multi-Head Attention (MHA) operation in the Transformer model.
It targets  efficient inference on embedded systems by exploiting 8-bit quantization and an innovative softmax implementation that operates exclusively on integer values.
By computing on-the-fly in streaming mode, our softmax implementation minimizes data movement and energy consumption.
ITA achieves competitive energy efficiency with respect to state-of-the-art transformer accelerators with 16.9 TOPS/W, while outperforming them in area efficiency with 5.93 TOPS/mm2 in 22 nm fully-depleted silicon-on-insulator technology at 0.8 V.

This repository contains the RTL code and test generator for the ITA.

## Structure
The repository is structured as follows:

- `modelsim` contains Makefiles and scripts to run the simulation in ModelSim.
- `PyITA` contains the test generator for the ITA.
- `src` contains the RTL code.
    * `tb` contains the testbenches for the ITA modules.

## Vivado setup

1. Source your Vivado License (in our case we used 2023.1)
2. Clone ITA
3. Get all the files and checkouts using Bender.
4. Get the python test files using the PyITA as intended by the original authors. Make sure to specify ITA_N parameter while generating the data.
5. Adjust the value of the ITA_N parameter accordingly inside setup_vivado.tcl
6. Run the following command to setup the project:
```bash
vivado -mode batch -source setup_vivado.tcl
```
6. Run simulation.

## RTL Simulation
We use [Bender](https://github.com/pulp-platform/bender) to generate our simulation scripts. Make sure you have Bender installed, or install it in the ITA repository with:
```bash
$> make bender
```

To run the RTL simulation, execute the following command:
```sh
$> make sim
$> s=64 e=128 p=192 make sim # To use different dimensions
$> target=sim_ita_hwpe_tb make sim # To run ITA with HWPE wrapper
```

## Vivado Synthesis
While running synthesis, add the following flag to synthesis settings:
```sh
$> -mode out_of_context
```

## Test Vector Generation
The test generator creates ONNX graphs and in case of MHA (Multi-Head Attention), additional test vectors for RTL simulations. The relevant files for ITA are located in the `PyITA` directory.

## Tests
In `tests` directory, several tests are available to verify the correctness of the ITA. To run the example test, execute the following command:
```sh
$> ./tests/run.sh
```

To run a series of tests, execute the following command:
```sh
$> ./tests/run_loop.sh
```

Test granularity and stalling can be set with the following commands before running the script:
```sh
$> export granularity=64
$> export no_stalls=1
```

#### Requirements
To install the required Python packages, create a virtual environment. Make sure to first deactivate any existing virtual environment or conda/mamba environment. Then, create a new virtual environment and install the required packages:

```sh
$> python -m venv venv
$> source venv/bin/activate
$> pip install -r requirements.txt
```

If you want to enable pre-commit hooks, which perform code formatting and linting, run the following command:
```sh
$> pre-commit install
```

In case you want to compare the softmax implementation with the QuantLib implementation, you need to install the QuantLib library and additional dependencies. To do so, create a virtual environment:

```sh
$> pip install torch torchvision scipy pandas
```
and install QuantLib from [GitHub](https://github.com/pulp-platform/quantlib).

```sh
$> git clone git@github.com:pulp-platform/quantlib.git
```

#### ITA Multi-Head Attention
To get an overview of possible options run:
```sh
$> python testGenerator.py -h
```

To generate a ONNX graph and test vectors for RTL simulations for a MHA operation run:
```sh
$> python testGenerator.py -H 1 -S 64 -E 128 -P 192 -F 256 --no-bias --activation=identity
```

To visualize the ONNX graph after generation, run:
```sh
$> netron simvectors/data_S64_E128_P192_H1_B1/network.onnx
```

## Contributors
- **Gamze İslamoğlu** ([gislamoglu@iis.ee.ethz.ch](mailto:gislamoglu@iis.ee.ethz.ch))
- **Philip Wiese** ([wiesep@iis.ee.ethz.ch](mailto:wiesep@iis.ee.ethz.ch))

## License
This repository makes use of two licenses:
- for all *software*: Apache License Version 2.0
- for all *hardware*: Solderpad Hardware License Version 0.51

For further information have a look at the license files: `LICENSE.hw`, `LICENSE.sw`

## References
<details>
<summary><i>ITA: An Energy-Efficient Attention and Softmax Accelerator for Quantized Transformers</i></summary>
<p>

```
@INPROCEEDINGS{10244348,
  author={Islamoglu, Gamze and Scherer, Moritz and Paulin, Gianna and Fischer, Tim and Jung, Victor J.B. and Garofalo, Angelo and Benini, Luca},
  booktitle={2023 IEEE/ACM International Symposium on Low Power Electronics and Design (ISLPED)},
  title={ITA: An Energy-Efficient Attention and Softmax Accelerator for Quantized Transformers},
  year={2023},
  volume={},
  number={},
  pages={1-6},
  keywords={Quantization (signal);Embedded systems;Power demand;Computational modeling;Silicon-on-insulator;Parallel processing;Transformers;neural network accelerators;transformers;attention;softmax},
  doi={10.1109/ISLPED58423.2023.10244348}}
```
This paper was published on [IEEE Xplore](https://ieeexplore.ieee.org/document/10244348) and is also available on [arXiv:2307.03493 [cs.AR]](https://arxiv.org/abs/2307.03493).

</p>
</details>
