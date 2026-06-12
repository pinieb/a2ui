import json
import sys
import os

def calculate_stats(report_path):
    if not os.path.exists(report_path):
        print(f"Error: Report file not found at {report_path}")
        return

    total_cases = 0
    total_tests = 0
    passed_tests = 0
    failed_tests = 0
    errored_tests = 0

    with open(report_path, "r") as f:
        for line in f:
            data = json.loads(line.strip())
            
            # Skip metadata line
            if "implementations" in data:
                continue
                
            # We only care about result lines, which contain 'implementation'
            if "implementation" not in data:
                continue
                
            total_cases += 1
            expected = data.get("expected", [])
            num_tests_in_case = len(expected)
            total_tests += num_tests_in_case
            
            if data.get("errored", False):
                errored_tests += num_tests_in_case
                continue
                
            results = data.get("results", [])
            for exp, res in zip(expected, results):
                got_valid = res.get("valid", False)
                if got_valid == exp:
                    passed_tests += 1
                else:
                    failed_tests += 1

    compliance_rate = (passed_tests / total_tests) * 100 if total_tests > 0 else 0.0

    print("==================================================")
    print("           BOWTIE COMPLIANCE STATISTICS           ")
    print("==================================================")
    print(f"Total Test Cases      : {total_cases}")
    print(f"Total Individual Tests: {total_tests}")
    print(f"Passed Tests          : {passed_tests} ({passed_tests/total_tests*100:.2f}%)")
    print(f"Failed Tests          : {failed_tests} ({failed_tests/total_tests*100:.2f}%)")
    print(f"Errored Tests         : {errored_tests} ({errored_tests/total_tests*100:.2f}%)")
    print("--------------------------------------------------")
    print(f"OVERALL COMPLIANCE RATE: {compliance_rate:.2f}%")
    print("==================================================")

if __name__ == "__main__":
    report_file = "/Users/piebie/Documents/GitHub/a2ui/renderers/swift_core/Tools/A2UIJSONBowtie/report.jsonl"
    if len(sys.argv) > 1:
        report_file = sys.argv[1]
    calculate_stats(report_file)
