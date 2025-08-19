import os
import sys

# --- Configuration ---
# Your number of memory banks (MP value in Verilog)
NUM_BANKS = 32
# The name of your single, large, interleaved input memory file
INPUT_FILE = "simvectors/data_S64_E128_P192_F256_H1_B0_Identity/hwpe/mem.txt"
# The name of the directory where the new bank files will be created
OUTPUT_DIR = "ita_kria_wrapper/memory_banks"
# --- End of Configuration ---


def deinterleave_memory():
    """
    Reads a single interleaved memory file and splits it into
    a specified number of de-interleaved bank files, one for each memory bank.
    """
    

    print(f"Starting de-interleaving process...")
    print(f"Source file:      {os.path.abspath(INPUT_FILE)}")
    print(f"Number of banks:  {NUM_BANKS}")

    # Create the output directory if it doesn't exist
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        print(f"Created output directory: {os.path.abspath(OUTPUT_DIR)}")
    else:
        print(f"Output directory:   {os.path.abspath(OUTPUT_DIR)}")


    try:
        # Open the source file and read all lines into a list
        with open(INPUT_FILE, 'r') as f_in:
            lines = f_in.readlines()
        print(f"Successfully read {len(lines)} lines.")
    except Exception as e:
        print(f"--- ERROR ---")
        print(f"Could not read the input file. Error: {e}")
        sys.exit(1)

    # Create and open all bank files in write mode
    output_files = []
    for i in range(NUM_BANKS):
        file_path = os.path.join(OUTPUT_DIR, f"bank{i}.mem")
        try:
            output_files.append(open(file_path, 'w'))
        except Exception as e:
            print(f"--- ERROR ---")
            print(f"Could not create output file {file_path}. Error: {e}")
            # Clean up any already opened files
            for f in output_files:
                f.close()
            sys.exit(1)

    print(f"\nWriting to {NUM_BANKS} bank files...")

    # Iterate through the lines with an index, "dealing" each line
    # to the appropriate bank file using the modulo operator.
    line_count = 0
    for i, line in enumerate(lines):
        # The line index (i) determines the bank index
        bank_index = i % NUM_BANKS

        # Write the line (including its newline character) to the correct file
        output_files[bank_index].write(line)
        line_count += 1

    # Close all the output files to ensure data is saved
    for f in output_files:
        f.close()

    print(f"\n--- SUCCESS ---")
    print(f"Processed {line_count} lines.")
    print(f"Your {NUM_BANKS} memory bank files are ready in the '{OUTPUT_DIR}' directory.")
    # Calculate and print per-bank stats
    if line_count > 0 and NUM_BANKS > 0:
        lines_per_bank = (line_count + NUM_BANKS - 1) // NUM_BANKS
        print(f"Each bank file should contain approximately {lines_per_bank} lines.")


if __name__ == "__main__":
    deinterleave_memory()