import json
import sys
import os
from collections import defaultdict

def analyze_failures(report_path):
    if not os.path.exists(report_path):
        print(f"Error: Report file not found at {report_path}")
        return

    # Map seq -> case data
    cases = {}
    failures = defaultdict(list)
    total_failed = 0

    with open(report_path, "r") as f:
        for line in f:
            data = json.loads(line.strip())
            
            # Skip metadata line
            if "implementations" in data:
                continue
                
            seq = data.get("seq")
            if seq is None:
                continue
                
            # Pass 1: Case definitions
            if "case" in data:
                cases[seq] = data["case"]
                continue
                
            # Pass 2: Result lines
            if "results" in data:
                test_case = cases.get(seq)
                if not test_case:
                    continue
                    
                expected = data.get("expected", [])
                results = data.get("results", [])
                schema = test_case.get("schema", {})
                tests = test_case.get("tests", [])
                case_desc = test_case.get("description", "Unknown Case")
                
                # Determine the primary keywords in the schema
                if isinstance(schema, bool):
                    schema_keys = {"boolean-schema"}
                else:
                    schema_keys = set(schema.keys()) - {"$schema", "$id", "description", "title", "$defs", "definitions"}
                    if not schema_keys:
                        schema_keys = {"empty-schema"}
                    
                for idx, (exp, res) in enumerate(zip(expected, results)):
                    got_valid = res.get("valid", False)
                    if got_valid != exp:
                        total_failed += 1
                        test_desc = tests[idx].get("description", "Unknown Test")
                        instance = tests[idx].get("instance", None)
                        
                        # Group by primary schema keyword
                        for key in schema_keys:
                            failures[key].append({
                                "case": case_desc,
                                "test": test_desc,
                                "schema": schema,
                                "instance": instance,
                                "expected": exp,
                                "got": got_valid
                            })

    print("# Bowtie Draft 2020-12 Failure Analysis")
    print(f"Total Failed Assertions: {total_failed}\n")
    print("## Failures Grouped by JSON Schema Keyword\n")
    
    # Sort keywords by number of failures descending
    for key in sorted(failures.keys(), key=lambda k: len(failures[k]), reverse=True):
        count = len(failures[key])
        print(f"### `{key}` ({count} failures)")
        print("| Case Description | Test Description | Expected | Got |")
        print("| :--- | :--- | :---: | :---: |")
        # Print top 5 unique cases to keep it readable
        seen_cases = set()
        printed_count = 0
        for fail in failures[key]:
            case_key = f"{fail['case']} - {fail['test']}"
            if case_key not in seen_cases:
                seen_cases.add(case_key)
                print(f"| {fail['case']} | {fail['test']} | {fail['expected']} | {fail['got']} |")
                printed_count += 1
                if printed_count >= 5:
                    break
        if count > 5:
            print(f"| ... and {count - 5} more failures | | | |")
        print()

if __name__ == "__main__":
    report_file = "/Users/piebie/Documents/GitHub/a2ui/renderers/swift_core/Tools/A2UIJSONBowtie/report.jsonl"
    if len(sys.argv) > 1:
        report_file = sys.argv[1]
    analyze_failures(report_file)

