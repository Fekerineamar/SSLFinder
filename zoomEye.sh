#!/bin/bash

echo -e "\e[32m"
cat << "EOF"
       __________ __    _______           __         
      / ___/ ___// /   / ____(_)___  ____/ /__  _____
      \__ \\__ \/ /   / /_  / / __ \/ __  / _ \/ ___/
     ___/ /__/ / /___/ __/ / / / / / /_/ /  __/ /    
    /____/____/_____/_/   /_/_/ /_/\__,_/\___/_/     

                     Made with ♥ By Cody4code
                                                     
EOF
echo -e "\e[0m"


ZOOM_EYE_API_ENDPOINT="https://api.zoomeye.org/"

save_api_token() {
    echo "$1" > .env
}

load_api_token() {
    if [ -f ".env" ]; then
        cat .env
    fi
}

init_api_token() {
    save_api_token "$1"
}

is_valid_api_key() {
    local api_token=$1
    local response=$(curl -sSL -X GET "${ZOOM_EYE_API_ENDPOINT}resources-info" -H "API-KEY:$api_token")
    local code=$(echo "$response" | jq -r '.code')
    if [ "$code" == "login_required" ]; then
        echo "Invalid ZoomEye API token. Please use a valid ZoomEye API token for access."
    else
        local error_message=$(echo "$response" | jq -r '.message')
        echo "Error: $error_message"
    fi
    return 1

}

clear_api_key() {
    save_api_token ""
}

search_ssl_info() {
    local domain=$1
    local port=$2
    local output_file=$3

    local api_token=$(load_api_token)
    if [ -z "$api_token" ]; then
        echo "No ZoomEye API token found. Please set your ZoomEye API token by running the script with the --init option."
        return
    fi

    local query="hostname:${domain}"
    if [ ! -z "$port" ]; then
        query="${query} port:${port}"
    fi

    local params="query=${query}&page="

    local page=1
    declare -A ip_ports  # Associative array to store unique IP:port combinations

    while true; do
        local response=$(curl -sSL -X GET "${ZOOM_EYE_API_ENDPOINT}host/search?${params}${page}" -H "API-KEY:${api_token}")
        local code=$(echo "$response" | jq -r '.code')

        if [ "$code" == "login_required" ]; then
            echo "Invalid ZoomEye API token. Please use a valid ZoomEye API token for access."
            return
        elif [[ ! "$code" =~ ^[0-9]+$ ]]; then
            local error_message=$(echo "$response" | jq -r '.message')
            echo "Error: $error_message"
            return
        else
            local matches=$(echo "$response" | jq -r '.matches[] | .ip + ":" + (.portinfo.port | tostring)')

            if [ -n "$matches" ]; then  # Check if matches is not null or empty
                while read -r match; do
                    ip_ports["$match"]=1  # Add IP:port to the associative array
                    echo "$match"  # Print IP:port combination as it is processed
                done <<< "$matches"
            fi

            local total_pages=$(echo "$response" | jq -r '.total')
            if [ "$page" -lt "$total_pages" ]; then
                page=$((page + 1))
            else
                break
            fi
        fi
    done

    # Save unique IP:port combinations to output file
    if [ ! -z "$output_file" ]; then
        for ip_port in "${!ip_ports[@]}"; do
            echo "$ip_port" >> "$output_file"
        done
    fi
}




# Print help message
print_help() {
    echo "Usage: ./zoomeye.sh [OPTIONS]"
    echo "Search SSL information using the ZoomEye API"
    echo
    echo "Options:"
    echo "  -d, --domain <domain>     Search SSL information for a single domain"
    echo "  -l, --list <file>         Search SSL information for a list of domains"
    echo "  -o, --output <file>       Save the results to the specified output file"
    echo "  --init <api_token>        Initialize the ZoomEye API token"
    echo "  --clear                   Clear the ZoomEye API token"
    echo "  -p, --port <port>         Custom port number for SSL search"
    echo
    echo "Example:"
    echo "  ./zoomeye.sh -d example.com"
    echo "  ./zoomeye.sh -l listDomain.txt"
    echo "  cat listDomain.txt | ./zoomeye.sh"
    echo
}

# Parse command-line arguments
while (( "$#" )); do
    case $1 in
        -d|--domain)
            if [ -z "$2" ]; then
                echo "Please provide a domain after the -d or --domain option."
                print_help
                exit 1
            fi
            domain=$2
            shift 2
            ;;
        -l|--list)
            if [ -z "$2" ]; then
                echo "Please provide a list file after the -l or --list option."
                print_help
                exit 1
            fi
            list_file=$2
            shift 2
            ;;
        -o|--output)
            if [ -z "$2" ]; then
                echo "Please provide an output file after the -o or --output option."
                print_help
                exit 1
            fi
            output_file=$2
            shift 2
            ;;
        --init)
            init_key=$2
            shift 2
            ;;
        --clear)
            clear_key=true
            shift
            ;;
        -p|--port)
            if [ -z "$2" ]; then
                echo "Please provide a custom port number after the -p or --port option."
                print_help
                exit 1
            fi
            port=$2
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done


# Check if help message should be displayed
if [ -z "$domain" ] && [ -z "$list_file" ] && [ -z "$init_key" ] && [ -z "$clear_key" ]; then
    print_help
    exit 0
fi

# Initialize API token if requested
if [ ! -z "$init_key" ]; then
    init_api_token "$init_key"
    echo "API token has been initialized and saved."
    echo "To search SSL information, use the following command:"
    echo "./zoomeye.sh -d <domain>"
    exit 0
fi

# Clear API token if requested
if [ ! -z "$clear_key" ]; then
    clear_api_key
    echo "API token has been cleared."
    exit 0
fi

# Search SSL information
if [ ! -z "$domain" ]; then
    search_ssl_info "$domain" "$port" "$output_file"
elif [ ! -z "$list_file" ]; then
    while read -r domain; do
        search_ssl_info "$domain" "$port" "$output_file"
    done < "$list_file"
elif ! tty -s && [ -p /dev/stdin ]; then
    while read -r domain; do
        search_ssl_info "$domain" "$port" "$output_file"
    done < /dev/stdin
else
    echo "Invalid option. Please run './zoomeye.sh' without any arguments for help."
    exit 1
fi

