import numpy as np

# --- 1. Configuration Parameters ---
# These must match your hardware configuration exactly.
N = 8
M = 64
WI = 8  # Bit-width of each element

# --- 2. Generate "Natural" Input Data ---
# Let's create two matrices, inp1 and inp2, with random 8-bit signed integers.
# In a real project, this data would come from your ML model's weights and activations.
# Shape is (N, M), so we have N vectors, each M elements long.
inp1_matrix = np.random.randint(-128, 127, size=(N, M), dtype=np.int8)
inp2_matrix = np.random.randint(-128, 127, size=(N, M), dtype=np.int8)

print("--- Original Data Shape ---")
print(f"inp1_matrix shape: {inp1_matrix.shape}")
print(f"First vector of inp1 (first 8 elements): {inp1_matrix[0, :8]}")
print(f"Second vector of inp1 (first 8 elements): {inp1_matrix[1, :8]}")
print("-" * 20)


# --- 3. Open the Output File ---
with open("../simvectors/data_S64_E128_P192_F256_H1_B0_Identity/HWPE/mem.txt", "w") as f:

    # --- 4. The Core Logic: Interleave and Pack ---
    # The outer loop iterates M times, once for each clock cycle of the computation.
    for j in range(M):  # j represents the cycle index (from 0 to 63)

        # For each cycle, we need to gather a "slice" of data.
        # This slice consists of the j-th element from all N vectors.
        
        # Gather the N elements for inp1 needed for this cycle
        inp1_slice = inp1_matrix[:, j]  # This is a powerful numpy slicing feature!

        # Gather the N elements for inp2 needed for this cycle
        inp2_slice = inp2_matrix[:, j]

        # Combine them into one list of 16 bytes for this cycle's transaction
        cycle_data_bytes = list(inp1_slice) + list(inp2_slice)

        # Now, pack these 16 bytes into four 32-bit (4-byte) words
        # and write them to the file.
        for i in range(0, len(cycle_data_bytes), 4):
            # Get a 4-byte chunk
            chunk = cycle_data_bytes[i : i+4]

            # Pack the 4 bytes into a single 32-bit integer (little-endian)
            # We use `& 0xFF` to treat signed bytes as unsigned values for packing.
            b0 = int(chunk[0]) & 0xFF
            b1 = int(chunk[1]) & 0xFF
            b2 = int(chunk[2]) & 0xFF
            b3 = int(chunk[3]) & 0xFF
            
            word32 = (b3 << 24) | (b2 << 16) | (b1 << 8) | b0

            # Write the 32-bit word to the file as an 8-digit hex string
            f.write(f"{word32:08x}\n")

print("--- Generated mem.txt Layout Example ---")
print(f"Data for Cycle 0:")
print(f"  inp1 elements: {inp1_matrix[:, 0]}")
print(f"  inp2 elements: {inp2_matrix[:, 0]}")
print("This will be packed into the first 4 lines of mem.txt")
print("\nmem.txt has been generated successfully.")