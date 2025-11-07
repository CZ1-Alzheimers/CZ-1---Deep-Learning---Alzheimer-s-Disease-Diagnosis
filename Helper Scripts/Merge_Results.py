import pandas as pd
import os

# Get the current directory
current_dir = os.path.dirname(os.path.abspath(__file__))

# Define the paths to the CSV files
file1_path = os.path.join(current_dir, '..','Results', 'ADNI-Oasis', 'PCA - 50', 'model_comparison_summary_50_dimensions.csv')
file2_path = os.path.join(current_dir, '..','Results', 'ADNI-Oasis', 'PCA - 75', 'model_comparison_summary_75_dimensions.csv')
file3_path = os.path.join(current_dir, '..','Results', 'ADNI-Oasis', 'PCA - 100', 'model_comparison_summary_100_dimensions.csv')

# Define the output file path
output_file_path = os.path.join(current_dir, '..','Results', 'ADNI-Oasis',  'ADNI-Oasis_Results.csv')

try:
    # Read all three CSV files
    df1 = pd.read_csv(file1_path)
    df2 = pd.read_csv(file2_path)
    df3 = pd.read_csv(file3_path)

    # Concatenate the DataFrames
    merged_df = pd.concat([df1, df2, df3], ignore_index=True)

    # Save to CSV
    merged_df.to_csv(output_file_path, index=False)

    print(f"Successfully merged 3 CSV files into '{output_file_path}'")

except FileNotFoundError as e:
    print(f"Error: File not found — {e.filename}")
except Exception as e:
    print(f"An error occurred: {e}")
