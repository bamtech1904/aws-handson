# Update Handson List

This command updates the handson list in README.md based on the handson directory structure.

## What it does

1. Scans the `handson/` directory for subdirectories
2. Reads the title from each README.md file in those directories  
3. Extracts the service name from the directory name
4. Updates the README.md with a markdown table containing:
   - Service name
   - Title from the README.md
   - Link to the handson directory

## Instructions

Update the handson list table in README.md by:

1. Scanning all subdirectories in the `handson/` directory
2. For each subdirectory, read the first line starting with `# ` from its README.md file as the title
3. Extract the service name from the directory name by:
   - Removing numeric prefix and underscore (e.g., `001_` → ``)
   - Removing `-handson` suffix
   - Removing `-notification` suffix
   - Converting to uppercase
   - Special cases: directories containing "ebs" → "EBS", "billing" → "Billing"
4. Replace the existing table in README.md (from "## ハンズオン一覧" section) with a new table containing:
   - Service name
   - Title from README.md
   - Link to handson directory in format `[📁 資料](handson/directory_name/)`

The table should use this header:
```
| サービス | 題名               | 資料                                         |
| -------- | ------------------ | -------------------------------------------- |
```

## Service Name Extraction Rules

- Removes numeric prefix and underscore (e.g., `001_` → ``)
- Removes `-handson` suffix
- Removes `-notification` suffix  
- Converts to uppercase
- Special cases:
  - Directory names containing "ebs" → "EBS"
  - Directory names containing "billing" → "Billing"