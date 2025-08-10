# PowerShell WPF CSV Viewer

## Overview
The PowerShell WPF CSV Viewer is a PowerShell application that provides a graphical user interface (GUI) for viewing and interacting with CSV data. Users can search for specific entries, select multiple rows, and output the selected data in either nested CSV format or JSON format.

## Project Structure
```
PowerShell-WPF-CSV-Viewer
├── src
│   ├── Main.ps1          # Entry point of the application
│   ├── UI.xaml           # WPF user interface layout
│   └── modules
│       └── CsvHandler.psm1 # Module for handling CSV data
├── assets
│   └── sample-data.csv   # Sample CSV data for testing
├── README.md             # Documentation for the project
└── .gitignore            # Files to ignore in version control
```

## Setup Instructions
1. **Clone the repository**:
   ```
   git clone <repository-url>
   cd PowerShell-WPF-CSV-Viewer
   ```

2. **Open PowerShell** and navigate to the project directory.

3. **Run the application**:
   ```
   .\src\Main.ps1
   ```

## Usage
- Upon launching the application, the CSV data will be loaded and displayed in a grid format.
- Use the search box to filter the displayed rows based on any of the columns (Name, Description, NickName, OwnerUPN).
- To select or deselect rows, hold the `Control` key and click on the desired rows.
- Click the **Submit** button to output the selected rows in the desired format (nested CSV or JSON).

## Functionality
- **Search**: Filter rows based on user input across all columns.
- **Select/Deselect Rows**: Use Control + Mouse Click to manage row selection.
- **Output Selected Rows**: Display selected rows in nested CSV or JSON format upon submission.

## Sample Data
The `assets/sample-data.csv` file contains sample data with the following columns:
- Name
- Description
- NickName
- OwnerUPN

## Contributing
Contributions are welcome! Please submit a pull request or open an issue for any suggestions or improvements.

## License
This project is licensed under the MIT License. See the LICENSE file for more details.