# PROGRAM_ITA Task Implementation with Complete Testbench Logic
# Based on the SystemVerilog testbench ita_hwpe_tb

# Define ITA register offsets (from testbench)
ITA_REG_INPUT_PTR = 0x00
ITA_REG_WEIGHT_PTR0 = 0x01
ITA_REG_WEIGHT_PTR1 = 0x02
ITA_REG_BIAS_PTR = 0x03
ITA_REG_OUTPUT_PTR = 0x04
ITA_REG_TILES = 0x05
ITA_REG_EPS_MULT0 = 0x06
ITA_REG_EPS_MULT1 = 0x07
ITA_REG_RIGHT_SHIFT0 = 0x08
ITA_REG_RIGHT_SHIFT1 = 0x09
ITA_REG_ADD0 = 0x0A
ITA_REG_ADD1 = 0x0B
ITA_REG_GELU_B_C = 0x0C
ITA_REG_ACTIVATION_REQUANT = 0x0D
ITA_REG_CTRL_ENGINE = 0x0E
ITA_REG_CTRL_STREAM = 0x0F

# Base offset for ITA registers (from testbench)
ITA_REG_OFFSET = 0x20

# Operation indices (step_e enum)
Q = 0
K = 1
V = 2
QK = 3
AV = 4
OW = 5
F1 = 6
F2 = 7

# Activation types
Identity = 0
GELU = 1
ReLU = 2

# Layer types
Linear = 0
Attention = 1
SingleAttention = 2
Feedforward = 3

def periph_write_info(reg_name, reg_offset, value, tile_info=""):
    """Calculate and print PERIPH_WRITE address and value information"""
    address = 4 * reg_offset + ITA_REG_OFFSET
    print(f"PERIPH_WRITE: {reg_name:20s} | Address=0x{address:08X} | Value=0x{value:08X} ({value:10d}) | {tile_info}")
    return address, value

def ita_ptrs_compute(input_base_ptr, weight_base_ptr0, weight_base_ptr1, bias_base_ptr, output_base_ptr, 
                     step, tile, tile_x, tile_y, tile_inner, n_tiles_outer_x, n_tiles_inner_dim, 
                     n_elements_per_tile, m_tile_len, total_tiles):
    """
    Compute pointers exactly as in the testbench ita_ptrs_compute task
    """
    # Input pointer calculation
    input_ptr = input_base_ptr + (tile_y * n_tiles_inner_dim + tile_inner) * n_elements_per_tile
    
    # Output pointer calculation
    output_ptr = output_base_ptr + (tile_y * n_tiles_outer_x + tile_x) * n_elements_per_tile
    
    # Bias pointer calculation
    if step == V:  # V step uses tile_y
        bias_ptr = bias_base_ptr + tile_y * m_tile_len * 3
    else:  # All other steps use tile_x
        bias_ptr = bias_base_ptr + tile_x * m_tile_len * 3
    
    # Weight pointer 0 calculation
    weight_ptr0 = weight_base_ptr0 + (tile % (n_tiles_outer_x * n_tiles_inner_dim)) * n_elements_per_tile
    
    # Weight pointer 1 calculation
    if tile == (total_tiles - 1):  # Last tile
        weight_ptr1 = weight_base_ptr1
        is_last_tile = True
    else:  # Next tile
        weight_ptr1 = weight_base_ptr0 + ((tile + 1) % (n_tiles_outer_x * n_tiles_inner_dim)) * n_elements_per_tile
        is_last_tile = False
    
    return input_ptr, weight_ptr0, weight_ptr1, bias_ptr, output_ptr, is_last_tile

def ctrl_val_compute(step, tile, n_tiles_outer_x, n_tiles_outer_y, n_tiles_inner_dim, 
                     single_attention=0, activation=Identity):
    """
    Compute control values exactly as in the testbench ctrl_val_compute task
    """
    # Initialize values
    ctrl_stream_val = 0
    reg_weight_en = False
    reg_bias_en = False
    
    # Determine layer type
    if single_attention == 1:
        layer_type = Linear
    else:
        layer_type = Attention
    
    # Default activation
    activation_function = Identity
    ctrl_engine_val = layer_type | (activation_function << 2)
    
    # Calculate total tiles for this step
    total_tiles = n_tiles_outer_x * n_tiles_outer_y * n_tiles_inner_dim
    
    # Step-specific logic
    if step == Q:
        if tile == 0:
            ctrl_stream_val = 0b0011  # 4'b0011
        else:
            ctrl_stream_val = 0b0010  # 4'b0010
        reg_weight_en = True
        reg_bias_en = True
        
    elif step == K:
        ctrl_stream_val = 0b0010  # 4'b0010
        reg_weight_en = True
        reg_bias_en = True
        
    elif step == V:
        ctrl_stream_val = 0b1010  # 4'b1010
        reg_weight_en = True
        reg_bias_en = True
        
    elif step == QK:
        if single_attention == 1:
            ctrl_engine_val = SingleAttention | (Identity << 2)
        ctrl_stream_val = 0b0110  # 4'b0110
        reg_weight_en = True
        reg_bias_en = False
        
    elif step == AV:
        if single_attention == 1:
            ctrl_engine_val = SingleAttention | (Identity << 2)
        ctrl_stream_val = 0b0110  # 4'b0110
        reg_weight_en = True
        reg_bias_en = False
        
    elif step == OW:
        if tile == (total_tiles - 1):  # Last tile
            ctrl_stream_val = 0b0000  # 4'b0000
            reg_weight_en = False
        else:
            ctrl_stream_val = 0b0010  # 4'b0010
            reg_weight_en = True
        reg_bias_en = True
        
    elif step == F1:
        if single_attention == 1:
            ctrl_engine_val = Linear | (activation << 2)
        else:
            ctrl_engine_val = Feedforward | (activation << 2)
        if tile == 0:
            ctrl_stream_val = 0b0011  # 4'b0011
        else:
            ctrl_stream_val = 0b0010  # 4'b0010
        reg_weight_en = True
        reg_bias_en = True
        
    elif step == F2:
        if single_attention == 1:
            ctrl_engine_val = Linear | (Identity << 2)
        else:
            ctrl_engine_val = Feedforward | (Identity << 2)
        if tile == (total_tiles - 1):  # Last tile
            ctrl_stream_val = 0b0000  # 4'b0000
            reg_weight_en = False
        else:
            ctrl_stream_val = 0b0010  # 4'b0010
            reg_weight_en = True
        reg_bias_en = True
    
    # Set bit 4 based on inner dimension logic
    if ((tile + 1) % n_tiles_inner_dim) == 0:
        # Last inner tile - clear bit 4
        pass  # bit 4 remains 0
    else:
        # Not last inner tile - set bit 4
        ctrl_stream_val |= (1 << 4)
    
    return ctrl_engine_val, ctrl_stream_val, reg_weight_en, reg_bias_en

def program_ita_q_complete(config, 
                          single_attention=0,
                          activation=Identity,
                          ita_reg_tiles_val=0x00010001,
                          ita_reg_rqs_val=[0x1000, 0x1000, 0x8, 0x8, 0x0, 0x0],
                          ita_reg_gelu_b_c_val=0x0,
                          ita_reg_activation_rqs_val=0x1000):
    """
    Complete PROGRAM_ITA implementation for Q operation following testbench logic
    """
    
    # Get Q operation configuration
    step = Q
    n_tiles_outer_x = config['tiling']['N_TILES_OUTER_X'][Q]
    n_tiles_outer_y = config['tiling']['N_TILES_OUTER_Y'][Q]
    n_tiles_inner_dim = config['tiling']['N_TILES_INNER_DIM'][Q]
    n_elements_per_tile = config['tiling']['N_ELEMENTS_PER_TILE']
    m_tile_len = config['tiling']['M_TILE_LEN']
    
    # Base pointers
    input_base_ptr = config['memory_layout']['BASE_PTR_INPUT'][Q]
    weight_base_ptr0 = config['memory_layout']['BASE_PTR_WEIGHT0'][Q]
    weight_base_ptr1 = config['memory_layout']['BASE_PTR_WEIGHT1'][Q] if Q < len(config['memory_layout']['BASE_PTR_WEIGHT1']) else 0
    bias_base_ptr = config['memory_layout']['BASE_PTR_BIAS'][Q] if config['memory_layout']['BASE_PTR_BIAS'][Q] is not None else 0
    output_base_ptr = config['memory_layout']['BASE_PTR_OUTPUT'][Q]
    
    total_tiles = n_tiles_outer_x * n_tiles_outer_y * n_tiles_inner_dim
    
    print("="*80)
    print(f"PROGRAM_ITA for Q Operation - Complete Testbench Logic")
    print("="*80)
    print(f"Tile dimensions: {n_tiles_outer_x} x {n_tiles_outer_y} x {n_tiles_inner_dim} = {total_tiles} total tiles")
    print(f"Elements per tile: {n_elements_per_tile}")
    print("="*80)
    
    all_writes = []
    ita_reg_cnt = 0  # Counter for register enabling logic
    
    # Triple nested loop as in testbench
    for tile_y in range(n_tiles_outer_y):
        for tile_x in range(n_tiles_outer_x):
            output_tile = tile_y * n_tiles_outer_x + tile_x
            
            for tile_inner in range(n_tiles_inner_dim):
                tile = output_tile * n_tiles_inner_dim + tile_inner
                
                print(f"\n--- Programming Tile {tile} (X={tile_x}, Y={tile_y}, Inner={tile_inner}) ---")
                
                # Calculate pointers using testbench logic
                input_ptr, weight_ptr0, weight_ptr1, bias_ptr, output_ptr, is_last_tile = ita_ptrs_compute(
                    input_base_ptr, weight_base_ptr0, weight_base_ptr1, bias_base_ptr, output_base_ptr,
                    step, tile, tile_x, tile_y, tile_inner, n_tiles_outer_x, n_tiles_inner_dim,
                    n_elements_per_tile, m_tile_len, total_tiles
                )
                
                # Calculate control values using testbench logic
                ctrl_engine_val, ctrl_stream_val, weight_ptr_en, bias_ptr_en = ctrl_val_compute(
                    step, tile, n_tiles_outer_x, n_tiles_outer_y, n_tiles_inner_dim,
                    single_attention, activation
                )
                
                # ITA register enable logic (simplified)
                if single_attention == 1:
                    ita_reg_en = True
                else:
                    # Enable for first few tiles (N_CONTEXT logic would be here)
                    ita_reg_en = (ita_reg_cnt < 4)  # Assuming N_CONTEXT = 4
                    if ita_reg_en:
                        ita_reg_cnt += 1
                
                # Print pointer calculations
                print(f"  input_ptr   = 0x{input_ptr:08X}")
                print(f"  weight_ptr0 = 0x{weight_ptr0:08X}")
                print(f"  weight_ptr1 = 0x{weight_ptr1:08X}")
                print(f"  bias_ptr    = 0x{bias_ptr:08X}")
                print(f"  output_ptr  = 0x{output_ptr:08X}")
                print(f"  ctrl_engine = 0x{ctrl_engine_val:08X}")
                print(f"  ctrl_stream = 0x{ctrl_stream_val:08X}")
                print(f"  weight_en   = {weight_ptr_en}")
                print(f"  bias_en     = {bias_ptr_en}")
                print(f"  ita_reg_en  = {ita_reg_en}")
                
                # Execute PROGRAM_ITA task - Required writes (always executed)
                tile_info = f"Tile({tile_x},{tile_y},{tile_inner}) #{tile}"
                all_writes.append(periph_write_info("ITA_REG_INPUT_PTR", ITA_REG_INPUT_PTR, input_ptr, tile_info))
                all_writes.append(periph_write_info("ITA_REG_WEIGHT_PTR0", ITA_REG_WEIGHT_PTR0, weight_ptr0, tile_info))
                
                # Conditional writes
                if weight_ptr_en:
                    all_writes.append(periph_write_info("ITA_REG_WEIGHT_PTR1", ITA_REG_WEIGHT_PTR1, weight_ptr1, tile_info))
                
                if bias_ptr_en:
                    all_writes.append(periph_write_info("ITA_REG_BIAS_PTR", ITA_REG_BIAS_PTR, bias_ptr, tile_info))
                
                all_writes.append(periph_write_info("ITA_REG_OUTPUT_PTR", ITA_REG_OUTPUT_PTR, output_ptr, tile_info))
                
                # ITA register configuration (if enabled)
                if ita_reg_en:
                    all_writes.append(periph_write_info("ITA_REG_TILES", ITA_REG_TILES, ita_reg_tiles_val, tile_info))
                    all_writes.append(periph_write_info("ITA_REG_EPS_MULT0", ITA_REG_EPS_MULT0, ita_reg_rqs_val[0], tile_info))
                    all_writes.append(periph_write_info("ITA_REG_EPS_MULT1", ITA_REG_EPS_MULT1, ita_reg_rqs_val[1], tile_info))
                    all_writes.append(periph_write_info("ITA_REG_RIGHT_SHIFT0", ITA_REG_RIGHT_SHIFT0, ita_reg_rqs_val[2], tile_info))
                    all_writes.append(periph_write_info("ITA_REG_RIGHT_SHIFT1", ITA_REG_RIGHT_SHIFT1, ita_reg_rqs_val[3], tile_info))
                    all_writes.append(periph_write_info("ITA_REG_ADD0", ITA_REG_ADD0, ita_reg_rqs_val[4], tile_info))
                    all_writes.append(periph_write_info("ITA_REG_ADD1", ITA_REG_ADD1, ita_reg_rqs_val[5], tile_info))
                    all_writes.append(periph_write_info("ITA_REG_GELU_B_C", ITA_REG_GELU_B_C, ita_reg_gelu_b_c_val, tile_info))
                    all_writes.append(periph_write_info("ITA_REG_ACTIVATION_REQUANT", ITA_REG_ACTIVATION_REQUANT, ita_reg_activation_rqs_val, tile_info))
                
                # Control registers (always executed)
                all_writes.append(periph_write_info("ITA_REG_CTRL_ENGINE", ITA_REG_CTRL_ENGINE, ctrl_engine_val, tile_info))
                all_writes.append(periph_write_info("ITA_REG_CTRL_STREAM", ITA_REG_CTRL_STREAM, ctrl_stream_val, tile_info))
    
    # Summary
    print(f"\n{'='*80}")
    print(f"SUMMARY: Total PERIPH_WRITE operations: {len(all_writes)}")
    print(f"Address range: 0x{min(w[0] for w in all_writes):08X} - 0x{max(w[0] for w in all_writes):08X}")
    print(f"{'='*80}")
    
    return all_writes

# Example usage matching testbench parameters
if __name__ == "__main__":
    # Testbench parameters
    SEQUENCE_LEN = 64
    EMBEDDING_SIZE = 128
    PROJECTION_SPACE = 192
    FEEDFORWARD_SIZE = 256
    M_TILE_LEN = 64
    
    # Calculate derived parameters as in testbench
    N_TILES_SEQUENCE_DIM = SEQUENCE_LEN // M_TILE_LEN
    N_TILES_EMBEDDING_DIM = EMBEDDING_SIZE // M_TILE_LEN
    N_TILES_PROJECTION_DIM = PROJECTION_SPACE // M_TILE_LEN
    N_TILES_FEEDFORWARD_DIM = FEEDFORWARD_SIZE // M_TILE_LEN
    N_ELEMENTS_PER_TILE = M_TILE_LEN * M_TILE_LEN
    
    # Create configuration matching testbench BASE_PTR calculations
    BASE_PTR = [0] * 23
    BASE_PTR[0] = 0
    BASE_PTR[1] = BASE_PTR[0] + SEQUENCE_LEN * EMBEDDING_SIZE
    BASE_PTR[2] = BASE_PTR[1] + SEQUENCE_LEN * EMBEDDING_SIZE
    BASE_PTR[6] = BASE_PTR[5] + PROJECTION_SPACE * EMBEDDING_SIZE
    BASE_PTR[15] = BASE_PTR[14] + EMBEDDING_SIZE * 3
    
    config = {
        'tiling': {
            'N_TILES_OUTER_X': [N_TILES_PROJECTION_DIM, 0, 0, 0, 0, 0, 0, 0],
            'N_TILES_OUTER_Y': [N_TILES_SEQUENCE_DIM, 0, 0, 0, 0, 0, 0, 0],
            'N_TILES_INNER_DIM': [N_TILES_EMBEDDING_DIM, 0, 0, 0, 0, 0, 0, 0],
            'N_ELEMENTS_PER_TILE': N_ELEMENTS_PER_TILE,
            'M_TILE_LEN': M_TILE_LEN
        },
        'memory_layout': {
            'BASE_PTR_INPUT': [BASE_PTR[0], 0, 0, 0, 0, 0, 0, 0],
            'BASE_PTR_WEIGHT0': [BASE_PTR[2], 0, 0, 0, 0, 0, 0, 0],
            'BASE_PTR_WEIGHT1': [BASE_PTR[3], 0, 0, 0, 0, 0, 0, 0],
            'BASE_PTR_BIAS': [BASE_PTR[6], 0, 0, 0, 0, 0, 0, 0],
            'BASE_PTR_OUTPUT': [BASE_PTR[15], 0, 0, 0, 0, 0, 0, 0]
        }
    }
    
    eps_mult = [108, 111, 117, 64, 67, 123, 67, 103 , 73]
    right_shift = [16, 16, 16, 15, 11, 16, 7, 16, 17]
    add = [0, 0, 0, 0, 0, 0, 0, 0 ,0 ] 
    ita_reg_rqs_val = [0]*6
    ita_reg_rqs_val[0] = eps_mult[0] | eps_mult[1] << 8 | eps_mult[2] << 16 | eps_mult[3] << 24
    ita_reg_rqs_val[1] = eps_mult[4] | eps_mult[5] << 8 | eps_mult[6] << 16 | eps_mult[7] << 24
    ita_reg_rqs_val[2] = right_shift[0] | right_shift[1] << 8 | right_shift[2] << 16 | right_shift[3] << 24
    ita_reg_rqs_val[3] = right_shift[4] | right_shift[5] << 8 | right_shift[6] << 16 | right_shift[7] << 24
    ita_reg_rqs_val[4] = add[0] | add[1] << 8 | add[2] << 16 | add[3] << 24
    ita_reg_rqs_val[5] = add[4] | add[5] << 8 | add[6] << 16 | add[7] << 24


    # Program ITA for Q operation with testbench logic
    writes = program_ita_q_complete(
        config,
        single_attention=0,
        activation=Identity,
        ita_reg_tiles_val = N_TILES_SEQUENCE_DIM | (N_TILES_EMBEDDING_DIM << 4) | (N_TILES_PROJECTION_DIM << 8) | (N_TILES_FEEDFORWARD_DIM << 12),
        ita_reg_rqs_val = ita_reg_rqs_val)