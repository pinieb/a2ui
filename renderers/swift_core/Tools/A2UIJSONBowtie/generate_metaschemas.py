import os
import json

def main():
    venv_base = "/Users/piebie/Documents/GitHub/a2ui/renderers/swift_core/.venv/lib/python3.14/site-packages/jsonschema_specifications/schemas/draft202012"
    
    files = [
        ("https://json-schema.org/draft/2020-12/schema", os.path.join(venv_base, "metaschema.json")),
        ("https://json-schema.org/draft/2020-12/meta/core", os.path.join(venv_base, "vocabularies/core")),
        ("https://json-schema.org/draft/2020-12/meta/applicator", os.path.join(venv_base, "vocabularies/applicator")),
        ("https://json-schema.org/draft/2020-12/meta/unevaluated", os.path.join(venv_base, "vocabularies/unevaluated")),
        ("https://json-schema.org/draft/2020-12/meta/validation", os.path.join(venv_base, "vocabularies/validation")),
        ("https://json-schema.org/draft/2020-12/meta/meta-data", os.path.join(venv_base, "vocabularies/meta-data")),
        ("https://json-schema.org/draft/2020-12/meta/format-annotation", os.path.join(venv_base, "vocabularies/format-annotation")),
        ("https://json-schema.org/draft/2020-12/meta/format-assertion", os.path.join(venv_base, "vocabularies/format-assertion")),
        ("https://json-schema.org/draft/2020-12/meta/content", os.path.join(venv_base, "vocabularies/content"))
    ]
    
    output_lines = [
        "// Copyright 2026 Google LLC",
        "//",
        "// Licensed under the Apache License, Version 2.0 (the \"License\");",
        "// you may not use this file except in compliance with the License.",
        "// You may obtain a copy of the License at",
        "//",
        "//     https://www.apache.org/licenses/LICENSE-2.0",
        "//",
        "// Unless required by applicable law or agreed to in writing, software",
        "// distributed under the License is distributed on an \"AS IS\" BASIS,",
        "// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.",
        "// See the License for the specific language governing permissions and",
        "// limitations under the License.",
        "",
        "import Foundation",
        "",
        "extension JSONSchema {",
        "  public static let wellKnownSchemas: [URL: JSONSchema] = {",
        "    var dict: [URL: JSONSchema] = [:]",
        "    let bundled: [(String, String)] = ["
    ]
    
    for id_url, path in files:
        if not os.path.exists(path):
            print(f"Error: file not found at {path}")
            return
        with open(path, "r") as f:
            content = f.read().strip()
            # Mini-validate by parsing JSON
            json.loads(content)
            # Format as raw Swift string: #\"\"\"<content>\"\"\"#
            escaped = f'#"""\n{content}\n"""#'
            output_lines.append(f'      ("{id_url}", {escaped}),')
            
    output_lines.extend([
        "    ]",
        "    for (idStr, jsonStr) in bundled {",
        "      if let url = URL(string: idStr),",
        "         let schema = try? JSONSchemaParser.parse(jsonStr) {",
        "        dict[url] = schema",
        "      }",
        "    }",
        "    return dict",
        "  }()",
        "}",
        ""
    ])
    
    output_path = "/Users/piebie/Documents/GitHub/a2ui/renderers/swift_core/Sources/A2UIJSON/Parser/Metaschemas.swift"
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w") as f:
        f.write("\n".join(output_lines))
    print(f"Successfully generated {output_path}")

if __name__ == "__main__":
    main()
