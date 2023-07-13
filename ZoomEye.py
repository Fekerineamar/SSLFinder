import argparse
import sys
from zoomeye.sdk import ZoomEye
 

def save_api_token(api_token):
    with open('.env', 'w') as file:
        file.write(api_token)


def load_api_token():
    try:
        with open('.env', 'r') as file:
            return file.read().strip()
    except FileNotFoundError:
        return None


def init_api_token(api_token):
    save_api_token(api_token)


def is_valid_api_key(api_token):
    zoomeye = ZoomEye(api_key=api_token)
    try:
        zoomeye.host_search('example.com')  # Perform a test request
        return True
    except Exception:
        return False


def clear_api_key():
    save_api_token('')


def search_ssl_info(domain, port, output_file):
    api_token = load_api_token()
    if not api_token:
        print("No ZoomEye API token found. Please set your ZoomEye API token by running the script with the --init option.")
        return

    zoomeye = ZoomEye(api_key=api_token)
    if port is not None:
        query = f"hostname:{domain} port:{port}"
    else:
        query = f"hostname:{domain}"
    page = 1
    all_ips = []
    try:
        while True:
            try:
                data = zoomeye.dork_search(query, page=page)
                if not data:
                    break
                for result in data:
                    ip = result.get('ip')
                    portinfo = result.get('portinfo')
                    if ip and portinfo:
                        port_number = portinfo.get('port')
                        service = portinfo.get('service')
                        if port is None or port == port_number:
                            ip_port = f"{ip}:{port_number}"
                            all_ips.append(ip_port)
                            if service == 'http':
                                print(f"\033[36m[IP Found] {ip}:{port_number} - [HTTP] service detected\033[0m")
                            elif service == 'https':
                                print(f"\033[36m[IP Found] {ip}:{port_number} - [HTTPS] service detected\033[0m")
                            elif service == 'dns':
                                print(f"\033[91m[IP Found] {ip}:{port_number} - [DNS] service detected\033[0m")
                            elif service == 'ssh':
                                print(f"\033[93m[IP Found] {ip}:{port_number} - [SSH] service detected\033[0m")
                            elif service == 'ftp':
                                print(f"\033[91m[IP Found] {ip}:{port_number} - [FTP] service detected\033[0m")
                            elif service == 'smtp':
                                print(f"\033[96m[IP Found] {ip}:{port_number} - [SMTP] service detected\033[0m")
                            elif service == 'pop3':
                                print(f"\033[96m[IP Found] {ip}:{port_number} - [POP3] service detected\033[0m")
                            elif service == 'imap':
                                print(f"\033[96m[IP Found] {ip}:{port_number} - [IMAP] service detected\033[0m")
                            elif service == 'dhcp':
                                print(f"\033[96m[IP Found] {ip}:{port_number} - [DHCP] service detected\033[0m")
                            elif service == 'rdp':
                                print(f"\033[95m[IP Found] {ip}:{port_number} - [RDP] service detected\033[0m")
                            elif service == 'vpn':
                                print(f"\033[96m[IP Found] {ip}:{port_number} - [VPN] service detected\033[0m")


                            else:
                                print(f"\033[90m[IP Found] [{service}] {ip}:{port_number}\033[0m")

                            if output_file:
                                with open(output_file, 'a') as file:
                                    file.write(f"{ip_port}\n")
                page += 1
            except requests.exceptions.SSLError as ssl_error:
                print(f"An SSL-related error occurred: {str(ssl_error)}")
                break
    except ValueError as e:
        print(f"An error occurred: {str(e)}")
    if not all_ips:
        print("No SSL information found for the specified domain.")
    return all_ips




def print_help():
    print("Usage: python zoomeye_search.py [OPTIONS]")
    print("Search SSL information using the ZoomEye API")
    print()
    print("Options:")
    print("  -d, --domain <domain>     Search SSL information for a single domain")
    print("  -l, --list <file>         Search SSL information for a list of domains")
    print("  -o, --output <file>       Save the results to the specified output file")
    print("  --init <api_token>        Initialize the ZoomEye API token")
    print("  --clear                   Clear the ZoomEye API token")
    print("  -p, --port <port>         Custom port number for SSL search")
    print()
    print("Example:")
    print("  python zoomeye_search.py -d example.com")
    print("  python zoomeye_search.py -l listDomain.txt")
    print("  cat listDomain.txt | python zoomeye_search.py")
    print()
    sys.exit(0)


def main():
    # Parse command-line arguments
    parser = argparse.ArgumentParser(description='Search SSL information using the ZoomEye API')
    group = parser.add_mutually_exclusive_group()
    group.add_argument('-d', '--domain', help='Single domain to search SSL information for')
    group.add_argument('-l', '--list', help='File containing a list of domains')
    parser.add_argument('-o', '--output', help='Output file to save the results')
    parser.add_argument('--init', metavar='API_TOKEN', help='Initialize the ZoomEye API token')
    parser.add_argument('--clear', action='store_true', help='Clear the ZoomEye API token')
    parser.add_argument('-p', '--port', type=int, help='Custom port number for SSL search')

    args = parser.parse_args()


    if args.init:
        api_token = args.init
        init_api_token(api_token)
        print('API token has been initialized and saved.')
        print('To search SSL information, use the following command:')
        print('python zoomeye_search.py -d <domain>')
        sys.exit(0)

    if args.clear:
        clear_api_key()
        print('API token has been cleared.')
        sys.exit(0)


    if args.domain:
        search_ssl_info(args.domain, args.port, args.output)
    elif args.list:
        domains = []
        if sys.stdin.isatty():
            with open(args.list, 'r') as file:
                domains = file.read().splitlines()
        else:
            domains = [line.strip() for line in sys.stdin]
        for domain in domains:
            search_ssl_info(domain, args.port, args.output)
    else:
        if args.domain is None and args.list is None and not sys.stdin.isatty():
            for line in sys.stdin:
                domain = line.strip()
                search_ssl_info(domain, args.port, args.output)
        else:
            parser.print_help()

if __name__ == '__main__':
    main()

