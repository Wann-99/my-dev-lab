import os
import sys
import re
import argparse
from datetime import datetime
import getpass
import telnetlib
import ftplib
import time

def parse_date(date_str):
    return datetime.strptime(date_str, "%Y-%m-%d").date()

def connect_telnet(ip, user, password, port=23, timeout=10):
    print(f"\nConnecting to {ip}:{port} via Telnet...")
    tn = telnetlib.Telnet(ip, port, timeout)
    
    # Wait for login prompt
    tn.read_until(b"login: ", timeout=5)
    tn.write(user.encode('ascii') + b"\n")
    
    if password:
        tn.read_until(b"Password: ", timeout=5)
        tn.write(password.encode('ascii') + b"\n")
    
    # Wait for shell prompt (QNX usually ends with # or $)
    # Adjust this based on actual QNX prompt if needed
    tn.read_until(b"# ", timeout=5)
    print("Telnet login successful.")
    return tn

def main():
    parser = argparse.ArgumentParser(description="Fetch remote log files by date range via Telnet/FTP.")
    parser.add_argument("ip", help="Remote device IP address")
    parser.add_argument("--start", required=True, help="Start date (YYYY-MM-DD), e.g., 2026-04-20")
    parser.add_argument("--end", required=True, help="End date (YYYY-MM-DD), e.g., 2026-04-24")
    parser.add_argument("--user", default="root", help="Username for Telnet (default: root)")
    parser.add_argument("--password", help="Password for Telnet (will prompt if not provided)")
    parser.add_argument("--ftp-user", help="Username for FTP (defaults to --user if not provided)")
    parser.add_argument("--ftp-password", help="Password for FTP (defaults to --password if not provided)")
    parser.add_argument("--remote-dir", default="/root/mnt/programs/log", help="Remote log directory path for Telnet")
    parser.add_argument("--ftp-dir", help="Remote log directory path for FTP (defaults to --remote-dir if not provided)")
    parser.add_argument("--local-dir", default="./logs", help="Local directory to save logs (default: ./logs)")
    parser.add_argument("--keyword", default="", help="Keyword to fuzzy match filenames (optional)")
    parser.add_argument("--method", choices=["ftp", "telnet"], default="ftp", 
                        help="Transfer method to use (default: ftp, fallback to telnet if ftp is unavailable)")

    args = parser.parse_args()

    # Parse dates
    try:
        start_date = parse_date(args.start)
        end_date = parse_date(args.end)
    except ValueError:
        print("Error: Invalid date format. Please use YYYY-MM-DD (e.g., 2026-04-20).")
        return

    if start_date > end_date:
        print("Error: Start date must be before or equal to end date.")
        return

    # In GUI mode, we should not block on getpass if passwords are not provided, 
    # as the GUI subprocess pipe cannot interactively answer.
    password = args.password
    if not password and sys.stdin.isatty():
        password = getpass.getpass(f"Enter password for {args.user}@{args.ip}: ")
    elif not password:
        password = "" # Allow empty password if not in terminal and not provided

    ftp_user = args.ftp_user if args.ftp_user else args.user
    ftp_password = args.ftp_password if args.ftp_password else password
    ftp_dir = args.ftp_dir if args.ftp_dir else args.remote_dir

    os.makedirs(args.local_dir, exist_ok=True)
    matched_files = []

    # Method 1: Try FTP first (More reliable for file transfer)
    if args.method == "ftp":
        try:
            print(f"\nAttempting FTP connection to {args.ip} as user '{ftp_user}'...")
            ftp = ftplib.FTP(args.ip, timeout=10)
            ftp.login(user=ftp_user, passwd=ftp_password)
            print("FTP login successful.")
            
            ftp.cwd(ftp_dir)
            files = ftp.nlst()
            
            for f in files:
                # Fuzzy match on the user-provided keyword
                if args.keyword and args.keyword not in f:
                    continue
                
                # Extract any YYYY-MM-DD date from the filename to check against range
                match = re.search(r'(\d{4}-\d{2}-\d{2})', f)
                if match:
                    try:
                        file_date = parse_date(match.group(1))
                        if start_date <= file_date <= end_date:
                            matched_files.append(f)
                    except ValueError:
                        continue
            
            if not matched_files:
                print(f"No log files found between {args.start} and {args.end}.")
                ftp.quit()
                return
                
            print(f"Found {len(matched_files)} files matching the date range.")
            
            for f in sorted(matched_files):
                local_path = os.path.join(args.local_dir, f)
                print(f"Downloading {f} -> {local_path} ...", end=" ", flush=True)
                with open(local_path, 'wb') as local_file:
                    ftp.retrbinary(f"RETR {f}", local_file.write)
                print("Done.")
                
            ftp.quit()
            print("\nAll files downloaded successfully via FTP.")
            return
            
        except ftplib.error_perm as e:
            if "530" in str(e) and "root" in args.user:
                print(f"FTP failed: {e}")
                print("Note: Many QNX systems disable FTP for the 'root' user by default for security reasons.")
                print("Please use a different user or select Telnet method.")
            else:
                print(f"FTP failed: {e}. Please check credentials or permissions.")
        except Exception as e:
            print(f"FTP failed: {e}. Please check FTP service or network.")
    # Method 2: Telnet
    if args.method == "telnet":
        try:
            tn = connect_telnet(args.ip, args.user, password)
            
            # Send a simple command to figure out the exact prompt
            tn.write(b"\n")
            time.sleep(1)
            prompt_output = tn.read_very_eager()
            
            # Try to extract the prompt from the last non-empty line
            lines = prompt_output.decode('ascii', errors='ignore').split('\n')
            last_line = ""
            for line in reversed(lines):
                if line.strip():
                    last_line = line.strip()
                    break
            
            # We assume the prompt might be `#`, `$`, or end with them
            # Let's just use a more generic read approach instead of relying on exact prompt match
            prompt_char = b"#" if b"#" in prompt_output else b"$"
            
            # List files in the directory
            print(f"Reading directory: {args.remote_dir}")
            command = f"ls -1 {args.remote_dir}\n"
            tn.write(command.encode('ascii'))
            
            # Read command output
            time.sleep(1) # Give it a moment to execute
            output = tn.read_very_eager().decode('ascii', errors='ignore')
            
            # Parse the output
            lines = output.replace('\r', '').split('\n')
            files = [line.strip() for line in lines if line.strip() and not line.startswith('ls')]
            
            for f in files:
                # Sometimes QNX ls might return full paths depending on how it's called, strip if necessary
                basename = os.path.basename(f)
                
                if args.keyword and args.keyword not in basename:
                    continue
                
                match = re.search(r'(\d{4}-\d{2}-\d{2})', basename)
                if match:
                    try:
                        file_date = parse_date(match.group(1))
                        if start_date <= file_date <= end_date:
                            matched_files.append(basename)
                    except ValueError:
                        continue

            if not matched_files:
                print(f"No log files found between {args.start} and {args.end}.")
                tn.write(b"exit\n")
                tn.close()
                return

            print(f"Found {len(matched_files)} files matching the date range.")
            print("\nWARNING: Transferring files via Telnet output capture is slow and can be corrupted.")
            print("If the device supports FTP, please ensure it's enabled and use --method ftp.")
            
            for f in sorted(matched_files):
                remote_path = f"{args.remote_dir}/{f}"
                local_path = os.path.join(args.local_dir, f)
                print(f"Downloading {f} -> {local_path} ...", end=" ", flush=True)
                
                # Using cat to dump file content. 
                # To make it more reliable, we'll add start and end markers
                start_marker = "---START_FILE_DUMP---"
                end_marker = "---END_FILE_DUMP---"
                
                # Clear buffer
                tn.read_very_eager()
                
                # Send command with markers
                # To prevent the Telnet command echo from matching our markers and prematurely stopping `read_until`,
                # we split the marker strings in the shell command using quotes (e.g. '---START_''FILE_DUMP---').
                # The shell will concatenate them and output the exact marker, but the echoed command text won't contain the exact marker.
                tn.write(f"echo '---START_''FILE_DUMP---'; cat {remote_path}; echo '---END_''FILE_DUMP---'\n".encode('ascii'))
                
                # Wait a bit for the command to echo back before we start looking for the REAL marker
                time.sleep(0.5)
                
                # Read until the end marker
                file_content = tn.read_until(end_marker.encode('ascii'), timeout=60)
                
                try:
                    content_str = file_content.decode('utf-8', errors='ignore')
                    
                    # Now we can just find the start marker directly, because the command echo doesn't contain it!
                    start_idx = content_str.find(start_marker)
                    
                    if start_idx != -1:
                        # Add length of start marker
                        content_start = start_idx + len(start_marker)
                        # We might have \r\n or \n after the start marker
                        if content_str[content_start:content_start+2] == '\r\n':
                            content_start += 2
                        elif content_str[content_start] == '\n':
                            content_start += 1
                            
                        # The end index is where the end marker begins
                        end_idx = content_str.rfind(end_marker)
                        
                        if end_idx != -1 and end_idx > content_start:
                            # Extract the clean content
                            clean_content = content_str[content_start:end_idx]
                            
                            # Remove the trailing newline before the end marker if it exists
                            if clean_content.endswith('\r\n'):
                                clean_content = clean_content[:-2]
                            elif clean_content.endswith('\n'):
                                clean_content = clean_content[:-1]
                                
                            with open(local_path, 'w', encoding='utf-8') as local_file:
                                local_file.write(clean_content)
                            print("Done.")
                        else:
                            print("Failed to find end of content.")
                    else:
                        print("Failed to parse file content cleanly (markers not found).")
                        # Fallback: just dump everything we got
                        with open(local_path, 'w', encoding='utf-8') as local_file:
                            local_file.write(content_str)
                        print("Done (with possible extra characters).")
                        
                except Exception as e:
                    print(f"Error saving file: {e}")

            tn.write(b"exit\n")
            tn.close()
            print("\nTelnet download process completed.")

        except Exception as e:
            print(f"\nTelnet Error: {e}")
            print("Please ensure Telnet service is running on the device.")

if __name__ == "__main__":
    main()
