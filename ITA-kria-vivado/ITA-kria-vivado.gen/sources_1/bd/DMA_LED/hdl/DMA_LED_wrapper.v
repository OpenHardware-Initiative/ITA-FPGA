//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2024.1 (lin64) Build 5076996 Wed May 22 18:36:09 MDT 2024
//Date        : Sat Aug 30 15:55:31 2025
//Host        : coppholl running 64-bit Ubuntu 20.04.6 LTS
//Command     : generate_target DMA_LED_wrapper.bd
//Design      : DMA_LED_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module DMA_LED_wrapper
   (fan_en_b);
  output [0:0]fan_en_b;

  wire [0:0]fan_en_b;

  DMA_LED DMA_LED_i
       (.fan_en_b(fan_en_b));
endmodule
