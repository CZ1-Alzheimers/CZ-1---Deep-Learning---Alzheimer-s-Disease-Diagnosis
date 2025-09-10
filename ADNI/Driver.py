import pandas as pd
from sklearn.model_selection import train_test_split
import os
from sklearn.linear_model import LinearRegression
from sklearn.model_selection import train_test_split

main_folder = 'C:\\Users\\cjohn\\Documents\\CS4850\\ADNI\\'

def getAllAtlasFiles(root_folder) :

    found_files = []

    # os.walk() generates the file names in a directory tree
    for dirpath, dirnames, filenames in os.walk(root_folder):

        # Get the name of the immediate parent folder (the "root folder" of the current set)
        current_root_name = os.path.basename(dirpath)
        if dirpath.__contains__("IGNORE"):
            continue

        # Construct the specific filename to search for
        target_filename_fragment = f"{current_root_name}_allAtlases.csv"

        # Iterate through the files found in the current directory
        for filename in filenames:

            # Check if the filename contains the target phrase
            if target_filename_fragment in filename:
                # Construct the full path to the file
                full_file_path = os.path.join(dirpath, filename)

                # Add the full file path to the list
                print(f"Adding file {full_file_path}...")
                found_files.append(full_file_path)

    return found_files

def mergeData(fileList):
    cvsList = []

    for file_path in fileList:
        cvs = pd.read_csv(file_path)
        cvsList.append(cvs)

    mergedCVS = pd.concat(cvsList, ignore_index=True)

    fileName = os.path.join(main_folder, 'ADNI_allAtlases.csv')
    mergedCVS.to_csv(fileName, index=False)

    return fileName

def splitData(dataset):
    data = pd.read_csv(dataset)

    # get the locations
    X = data.iloc[:, :-1]
    y = data.iloc[:, -1]

    # split the dataset
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.05, random_state=0)

    return X_train, X_test, y_train, y_test


startFolder = os.path.join(main_folder, 'results_multiatlas')

if __name__ == "__main__":

    if os.path.exists(startFolder):
        print("Finding allAtlases.csv files...")
        allFilePaths = getAllAtlasFiles(startFolder)

        print("Merging allAtlases.csv files...")
        dataset = mergeData(allFilePaths)

        print("Splitting dataset...")
        X_train, X_test, y_train, y_test = splitData(dataset)



    else:
        print(f"The specified directory '{startFolder}' does not exist.")

