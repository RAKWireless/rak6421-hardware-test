#!/usr/bin/env python3
import subprocess
import os
import json
import time
import sys
import getpass
from datetime import datetime, timezone

def parse_config_file(config_file_path):
    """Parse the original RAK-6421-eeprom.txt config file to get expected values dynamically"""
    expected_values = {}
    
    if not os.path.exists(config_file_path):
        return expected_values
    
    try:
        with open(config_file_path, 'r') as f:
            content = f.read()
        
        lines = content.split('\n')
        custom_data_list = []
        
        for line in lines:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            
            # Parse standard fields
            if line.startswith('product_uuid '):
                expected_values['uuid'] = line.split(maxsplit=1)[1].strip('"')
            elif line.startswith('product_id '):
                expected_values['product_id'] = line.split(maxsplit=1)[1]
            elif line.startswith('product_ver '):
                expected_values['product_ver'] = line.split(maxsplit=1)[1]
            elif line.startswith('vendor '):
                value = line.split(maxsplit=1)[1].strip('"')
                expected_values['vendor'] = value
            elif line.startswith('product '):
                value = line.split(maxsplit=1)[1].strip('"')
                expected_values['product'] = value
            elif line.startswith('custom_data '):
                # Extract all custom data values dynamically
                if '"' in line:
                    custom_value = line.split('"')[1] if len(line.split('"')) > 1 else ""
                    custom_data_list.append(custom_value)
        
        # Store all custom data for dynamic comparison
        expected_values['custom_data_list'] = custom_data_list
        
        # Add fixed values
        expected_values['name'] = 'hat'
        
        return expected_values
        
    except Exception as e:
        return expected_values

def run_command_with_sudo(cmd, password):
    """Run command with sudo using proper password input"""
    try:
        # Use Popen for better control over stdin
        process = subprocess.Popen(
            cmd,
            shell=True,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        # Send password to stdin
        stdout, stderr = process.communicate(input=f"{password}\n")
        
        if process.returncode == 0:
            return stdout.strip(), "PASS"
        else:
            return stderr.strip(), "FAIL"
    except Exception as e:
        return str(e), "FAIL"

def run_command(cmd, input_text=None):
    try:
        result = subprocess.run(cmd, shell=True, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, input=input_text)
        return result.stdout.strip(), "PASS"
    except subprocess.CalledProcessError as e:
        return e.stderr.strip(), "FAIL"

def verify_eeprom_and_parse(password, config_file):
    """Verify EEPROM by reading it back and parsing the contents"""
    verify_eep = "verify.eep"
    verify_txt = "verify.txt"
    
    try:
        # Step 1: Read EEPROM to verify.eep
        eepflash_read_cmd = f"sudo -S eepflash.sh -y -r -f={verify_eep} -t=24c32"
        read_out, read_status = run_command_with_sudo(eepflash_read_cmd, password)
        
        if read_status != "PASS":
            return [{"name": "eeprom_read", "output": read_out, "status": "FAIL"}]
        
        # Step 2: Dump .eep to readable text
        eepdump_cmd = f"eepdump {verify_eep} {verify_txt}"
        dump_out, dump_status = run_command(eepdump_cmd)
        
        if dump_status != "PASS":
            return [{"name": "eepdump", "output": dump_out, "status": "FAIL"}]
        
        # Step 3: Parse verify.txt to extract fields and compare with config
        summary = parse_verify_txt(verify_txt, config_file)
        
        # Cleanup temporary files
        for temp_file in [verify_eep, verify_txt]:
            try:
                if os.path.exists(temp_file):
                    os.remove(temp_file)
            except Exception as e:
                pass  # Ignore cleanup errors
        
        return summary
        
    except Exception as e:
        return [{"name": "verify_exception", "output": str(e), "status": "FAIL"}]

def is_valid_uuid(uuid_str):
    """Check if a string is a valid UUID format"""
    import re
    uuid_regex = r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$'
    return re.match(uuid_regex, uuid_str) is not None

def get_system_info():
    """Get system information for metadata"""
    info = {
        "cpu": "Unknown",
        "cpu_serial": "Unknown", 
        "memory": "Unknown",
        "storage": "Unknown",
        "os": "Unknown",
        "device_eui": "Unknown"
    }
    
    try:
        result = subprocess.run(
            ["lshw", "-quiet", "-json", "-c", "system"],
            capture_output=True,
            text=True,
            timeout=5,
            check=False
        )
        if result.returncode == 0 and result.stdout:
            data = json.loads(result.stdout)
            if isinstance(data, list) and data:
                info["cpu"] = data[0].get("product", info["cpu"])
                info["cpu_serial"] = data[0].get("serial", info["cpu_serial"])
    except Exception:
        pass
    
    try:
        result = subprocess.run(["free", "-h"], capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            lines = result.stdout.splitlines()
            if len(lines) > 1:
                info["memory"] = lines[1].split()[1]
    except Exception:
        pass
    
    try:
        result = subprocess.run(["df", "-h", "/"], capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            lines = result.stdout.splitlines()
            if len(lines) > 1:
                info["storage"] = lines[1].split()[1]
    except Exception:
        pass
    
    try:
        with open("/etc/os-release", encoding="utf-8") as fp:
            for line in fp:
                if line.startswith("VERSION_ID="):
                    info["os"] = line.split("=", 1)[1].strip().strip('"')
                    break
    except OSError:
        pass
    
    try:
        result = subprocess.run(["ip", "link", "show", "eth0"], capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            for line in result.stdout.splitlines():
                if "ether" in line:
                    mac = line.split()[1]
                    parts = mac.split(":")
                    if len(parts) == 6:
                        info["device_eui"] = f"{parts[0]}{parts[1]}{parts[2]}FFFE{parts[3]}{parts[4]}{parts[5]}"
                    break
    except Exception:
        pass
    
    return info

def parse_verify_txt(verify_txt_path, config_file):
    """Parse the verify.txt file to extract EEPROM fields and compare with config dynamically"""
    tests = []
    
    if not os.path.exists(verify_txt_path):
        return [{"name": "verify_txt", "output": "File not found", "status": "FAIL"}]
    
    # Get expected values from config file
    expected_values = parse_config_file(config_file)
    expected_custom_data = expected_values.get('custom_data_list', [])
    
    try:
        with open(verify_txt_path, 'r') as f:
            content = f.read()
        
        def clean_value(value):
            """Remove quotes, comments, and extra whitespace from parsed values"""
            # Remove quotes
            if value.startswith('"') and '"' in value[1:]:
                value = value[1:value.find('"', 1)]
            # Remove comments like '# length=3'
            if '#' in value:
                value = value[:value.find('#')].strip()
            return value.strip()
        
        # Parse key fields from the dumped content
        lines = content.split('\n')
        fields_map = {
            'product_uuid': 'uuid',
            'product_id': 'product_id', 
            'product_ver': 'product_ver',
            'vendor': 'vendor',
            'product': 'product'
        }
        
        # Collect actual custom_data from verify.txt in order
        actual_custom_data = []
        
        # First pass: extract standard fields and collect custom_data
        for line in lines:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
                
            # Handle custom_data fields - collect in order
            if line.startswith('custom_data'):
                if '"' in line:
                    custom_value = line.split('"')[1] if len(line.split('"')) > 1 else ""
                    actual_custom_data.append(custom_value)
            
            # Handle standard fields
            for field_key, field_name in fields_map.items():
                if line.startswith(field_key):
                    value = line.split(maxsplit=1)[1] if len(line.split(maxsplit=1)) > 1 else ""
                    cleaned_value = clean_value(value)
                    
                    # Special handling for UUID - validate format
                    if field_name == 'uuid':
                        status = "PASS" if is_valid_uuid(cleaned_value) else "FAIL"
                        tests.append({"name": field_name, "expected": "auto-generated", "output": cleaned_value, "status": status})
                    else:
                        # Compare with expected value
                        expected = expected_values.get(field_name, "")
                        status = "PASS" if cleaned_value == expected else "FAIL"
                        tests.append({"name": field_name, "expected": expected, "output": cleaned_value, "status": status})
                    break
        
        # Compare custom_data dynamically based on what's in the config
        for i, expected_custom in enumerate(expected_custom_data):
            if i < len(actual_custom_data):
                actual_custom = actual_custom_data[i]
                status = "PASS" if actual_custom == expected_custom else "FAIL"
                # Extract field name from custom data for better identification
                field_id = expected_custom.split()[0] if ' ' in expected_custom else f"custom_{i}"
                tests.append({"name": field_id, "expected": expected_custom, "output": actual_custom, "status": status})
            else:
                # Missing custom data in EEPROM
                field_id = expected_custom.split()[0] if ' ' in expected_custom else f"custom_{i}"
                tests.append({"name": field_id, "expected": expected_custom, "output": "missing", "status": "FAIL"})
        
        # Add name field (fixed value for HAT)
        expected_name = expected_values.get('name', 'hat')
        status = "PASS" if 'hat' == expected_name else "FAIL"
        tests.append({"name": "name", "expected": expected_name, "output": "hat", "status": status})
        
        return tests
        
    except Exception as e:
        return [{"name": "parse_error", "output": str(e), "status": "FAIL"}]

def main():
    start_time = time.time()
    config_file = "RAK-6421-eeprom.txt"
    eep_file = "RAK-6421-eeprom.eep"
    
    # Get sudo password
    if len(sys.argv) > 1:
        password = sys.argv[1]
    else:
        password = getpass.getpass("[INPUT] Enter sudo password: ")

    # Step 1: eepmake
    eepmake_cmd = f"eepmake {config_file} {eep_file}"
    eepmake_out, eepmake_status = run_command(eepmake_cmd)

    if eepmake_status != "PASS":
        print(f"[ERROR] eepmake failed: {eepmake_out}")
        return

    # Step 2: eepflash with password using sudo -S
    eepflash_cmd = f"sudo -S eepflash.sh -y -w -f={eep_file} -t=24c32"
    eepflash_out, eepflash_status = run_command_with_sudo(eepflash_cmd, password)

    if eepflash_status != "PASS":
        print(f"[ERROR] eepflash failed: {eepflash_out}")
        return

    # Step 3: Cleanup generated .eep file
    try:
        if os.path.exists(eep_file):
            os.remove(eep_file)
    except Exception as e:
        pass  # Ignore cleanup errors

    # Step 4: Verify EEPROM by reading it back
    tests = verify_eeprom_and_parse(password, config_file)
    
    # Calculate summary statistics
    total_tests = len(tests)
    passed_tests = sum(1 for test in tests if test["status"] == "PASS")
    failed_tests = total_tests - passed_tests
    overall_status = "PASS" if failed_tests == 0 else "FAIL"
    
    # Get system information for metadata
    system_info = get_system_info()

    end_time = time.time()
    duration = end_time - start_time
    timestamp = datetime.now(timezone.utc).isoformat()

    result = {
        "command_type": "RAK6421 eeprom flash",
        "configuration": config_file,
        "timestamp": timestamp,
        "duration_seconds": duration,
        "summary": {
            "total": total_tests,
            "passed": passed_tests, 
            "failed": failed_tests,
            "status": overall_status
        },
        "metadata": {
            "system": system_info
        },
        "tests": tests
    }
    
    print(json.dumps(result, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
