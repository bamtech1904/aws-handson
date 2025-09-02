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

## Implementation

```bash
# Get the root directory
ROOT_DIR="/Users/ryo_kogakura/Work/aws-handson"
README_FILE="$ROOT_DIR/README.md"
HANDSON_DIR="$ROOT_DIR/handson"

# Check if handson directory exists
if [ ! -d "$HANDSON_DIR" ]; then
    echo "Error: handson directory not found at $HANDSON_DIR"
    exit 1
fi

# Create temporary file for new README content
TEMP_FILE=$(mktemp)

# Copy everything up to the handson list table
sed -n '1,/## ハンズオン一覧/p' "$README_FILE" > "$TEMP_FILE"

# Add table header
echo "" >> "$TEMP_FILE"
echo "| サービス | 題名               | 資料                                         |" >> "$TEMP_FILE"
echo "| -------- | ------------------ | -------------------------------------------- |" >> "$TEMP_FILE"

# Scan handson directory and extract information
for dir in "$HANDSON_DIR"/*; do
    if [ -d "$dir" ]; then
        dir_name=$(basename "$dir")
        readme_path="$dir/README.md"
        
        if [ -f "$readme_path" ]; then
            # Extract title from README.md (first line starting with #)
            title=$(grep "^# " "$readme_path" | head -1 | sed 's/^# //')
            
            # Extract service name from directory name (after first underscore)
            service=$(echo "$dir_name" | sed 's/^[0-9]*_//' | sed 's/-handson$//' | sed 's/-notification$//' | tr '[:lower:]' '[:upper:]')
            
            # Handle specific cases
            case "$dir_name" in
                *"ebs"*)
                    service="EBS"
                    ;;
                *"billing"*)
                    service="Billing"
                    ;;
            esac
            
            if [ -n "$title" ]; then
                echo "| $service | $title | [📁 資料](handson/$dir_name/) |" >> "$TEMP_FILE"
            fi
        fi
    fi
done

echo "" >> "$TEMP_FILE"

# Replace the original README.md
mv "$TEMP_FILE" "$README_FILE"

echo "✅ README.md has been updated with the latest handson list"
```

## Service Name Extraction Rules

- Removes numeric prefix and underscore (e.g., `001_` → ``)
- Removes `-handson` suffix
- Removes `-notification` suffix  
- Converts to uppercase
- Special cases:
  - Directory names containing "ebs" → "EBS"
  - Directory names containing "billing" → "Billing"