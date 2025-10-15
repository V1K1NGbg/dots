#!/bin/bash

# Check if qalc is installed
if ! command -v qalc &> /dev/null; then
    echo "qalc is not installed. Please install qalculate-gtk or libqalculate"
    exit 1
fi



# Function to calculate using qalc
calculate() {
    local expression="$1"
    
    # Remove any leading/trailing whitespace
    expression=$(echo "$expression" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Skip empty expressions
    if [[ -z "$expression" ]]; then
        return
    fi
    
    # Skip if it's just a result from history (contains =)
    if [[ "$expression" == *"="* ]]; then
        # Extract just the result part for copying
        echo "${expression##*= }"
        return
    fi
    
    # Calculate using qalc with no interactive prompts and clean output
    local result
    result=$(echo "$expression" | qalc -t -c -f - 2>/dev/null)
    
    if [[ $? -eq 0 && -n "$result" ]]; then
        # Remove ANSI color codes and control characters
        result=$(echo "$result" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/[[:cntrl:]]//g')
        
        # Remove qalc prompts and input echoing
        result=$(echo "$result" | sed 's/^>.*$//' | sed '/^$/d' | tail -n 1)
        
        # Clean up whitespace
        result=$(echo "$result" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Remove trailing zeros and unnecessary decimal points
        result=$(echo "$result" | sed 's/\.0*$//;s/\.\([0-9]*[1-9]\)0*$/.\1/')
        
        echo "$result"
    else
        echo "Error: Invalid expression"
    fi
}
# Calculate the expression if provided
if [[ $# -gt 0 ]]; then
    expression="$1"
    result=$(calculate "$expression")

    # Show only the result
    echo "$expression = $result"
fi