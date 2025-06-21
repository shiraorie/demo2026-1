#!/bin/bash

# Path to the CSV file
CSV_FILE="/opt/Users.csv"

# Check if the CSV file exists
if [ ! -f "$CSV_FILE" ]; then
    echo "File $CSV_FILE not found."
    exit 1
fi

# Read the CSV file
while IFS=';' read -r fname lname role phone ou street zip city country password; do
    # Skip the header
    if [[ "$fname" == "First Name" ]]; then
        continue
    fi

    # Generate username
    username=$(echo "${fname:0:1}${lname}" | tr '[:upper:]' '[:lower:]')

    # Create OU if it doesn't exist
    sudo samba-tool ou create "OU=${ou},DC=AU-TEAM,DC=IRPO" --description="${ou} department"

    # Add user
    echo "Adding user: $username in OU=$ou"
    sudo samba-tool user add "$username" "$password" --given-name="$fname" --surname="$lname" \
      --job-title="$role" --telephone-number="$phone" \
      --userou="OU=$ou"
done < "$CSV_FILE"

echo "✅ All users added!"