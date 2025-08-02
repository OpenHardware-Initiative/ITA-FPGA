#!/bin/bash

# Copyright 2023 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

echo "Testing ITA ..."

source venv/bin/activate

export buildpath=build
export SIM_PATH=modelsim/$buildpath

# Set to -gui to use the GUI of QuestaSim
export vsim_flags=-c

export target=ita_tb
export no_stalls=0
export s=64
export e=128
export p=192
export f=256
export bias=0
export activation=identity

# Create test vectors if don't exist
if [ ! -d simvectors/data_S${s}_E${e}_P${p}_F${f}_H1_B${bias}_${activation^} ]
then
    if [ $bias -eq 1 ]
    then
        python testGenerator.py -H 1 -S $s -P $p -E $e -F $f --activation $activation
    else
        python testGenerator.py -H 1 -S 64 -E 128 -P 192 -F 256 --no-bias --activation=identity --debug-pattern asymmetric -v  --skip-vector-validation
    fi
fi

# Run the test
make sim VSIM_FLAGS=$vsim_flags DEBUG=OFF target=sim_$target no_stalls=$no_stalls s=$s e=$e p=$p f=$f bias=$bias activation=$activation
./modelsim/return_status.sh ${SIM_PATH}/transcript $s $e $p $f $target
