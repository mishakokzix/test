#!/bin/bash

# Initialize variables
LOOP_COUNT=0
TOKEN_DIR="token-setup"
BINARY_FILE="./token-collector"
TOKEN_DB="tokens.sqlite"

# Function to run setup
run_setup() {
    echo "Running setup..."
    mkdir -p "$TOKEN_DIR"
    if [ -f "$BINARY_FILE" ]; then
        mv "$BINARY_FILE" "$TOKEN_DIR/"
        echo "Moved token-collector to $TOKEN_DIR/"
    else
        echo "Warning: $BINARY_FILE not found"
    fi
}

# Function to determine token number based on loop count
get_token_number() {
    if [ $((LOOP_COUNT % 2)) -eq 0 ]; then
        echo "0"
    else
        echo "1"
    fi
}

# Function to run the binary file
run_binary() {
    echo "Running binary file..."
    # Change to the token directory
    cd "$TOKEN_DIR" || { echo "Failed to cd to $TOKEN_DIR"; return 1; }
    
    # Run the binary
    ./token-collector --no-tui --unsafe --tokens 850 --batch 3 --parallel 3
    
    # Capture the exit code
    local exit_code=$?
    
    # Return to the original directory
    cd - > /dev/null || { echo "Failed to return to original directory"; return 1; }
    
    # Check if the binary exited with code 0
    if [ $exit_code -eq 0 ]; then
        echo "Binary completed successfully"
        return 0
    else
        echo "Binary failed with exit code $exit_code"
        return 1
    fi
}

# Function to move the SQLite file
move_sqlite() {
    local token_num=$(get_token_number)
    local new_name="tokens_${token_num}.sqlite"
    local source_path="$TOKEN_DIR/$TOKEN_DB"
    local dest_path="$TOKEN_DIR/$new_name"
    
    echo "Moving $source_path to $dest_path..."
    
    if [ -f "$source_path" ]; then
        mv "$source_path" "$dest_path"
        echo "Moved $source_path to $dest_path"
        return 0
    else
        echo "Error: $source_path not found"
        return 1
    fi
}

# Function to send curl request
send_curl() {
    local token_num=$(get_token_number)
    local db_path="$TOKEN_DIR/tokens_${token_num}.sqlite"
    local db_path_real=$(realpath "$db_path" 2>/dev/null || echo "$db_path")
    
    echo "Sending curl request for $db_path..."
    
    curl -X POST http://localhost:3001/sqlite \
        -H "Authorization: Bearer Waguri" \
        -H "Content-Type: application/json" \
        -d "{\"db_path\": \"$db_path_real\"}"
    
    echo "" # Add newline after curl output
}

# Main loop
while true; do
    echo "=== Loop iteration: $LOOP_COUNT ==="
    
    # Run setup (only on first iteration or when needed)
    if [ $LOOP_COUNT -eq 0 ]; then
        run_setup
    fi
    
    # Wait 30 minutes
    echo "Waiting 30 minutes..."
    sleep 1800  # 30 minutes = 1800 seconds
    
    # Run the binary file (it will handle its own directory changes)
    echo "Starting binary execution..."
    
    if run_binary; then
        # Binary completed successfully, move the SQLite file
        if move_sqlite; then
            # Send curl request
            send_curl
        else
            echo "Failed to move SQLite file"
        fi
    else
        echo "Binary failed, skipping move and curl"
    fi
    
    # Increment loop counter
    LOOP_COUNT=$((LOOP_COUNT + 1))
    
    # Wait 30 minutes before next iteration
    echo "Waiting 30 minutes before next iteration..."
    sleep 1800  # 30 minutes = 1800 seconds
done
