use std/assert

const default_pattern = '**/{*[\-_]test,test[\-_]*}.nu'

# Also see the filtering in runner.nu
const supported_types = [
    test
    ignore
    before-all
    after-all
    before-each
    after-each
    strategy
]

export def suite-files [
    --glob: string = $default_pattern
    --matcher: string = ".*"
]: string -> list<string> {

    let path = $in
    $path
        | list-files $glob
        | where ($it | path parse | get stem) =~ $matcher
}

def list-files [ pattern: path]: string -> list<string> {
    let path = $in
    if ($path | path type) == file {
        [$path]
    } else {
        cd $path
        glob $pattern
    }
}

export def test-suites [
    --matcher: string = ".*"
]: list<string> -> table<name: string, path: string, tests:table<name: string, type: string>> {

    let suite_files = $in
    let result = $suite_files
        | reduce --fold [] {|file, acc|
            $acc | append (discover-suite $file)
        }
        | filter-tests $matcher

    # The following manifests the data to avoid laziness causing errors to be thrown in the wrong context
    # Some parser errors might be a `list<error>`, collecting will cause it to be thrown here
    $result | collect
    # Others are only apparent collecting the tests table
    $result | each {|suite| $suite.tests | collect }

    $result
}

def discover-suite [test_file: string]: nothing -> record<name: string, path: string, tests: table<name: string, type: string>> {
    let tests = parse-file-direct $test_file
    let suite = parse-suite $test_file $tests

    # Debug: Log suite with high test count
    if ($suite.tests | length) > 20 {
        error make {msg: $"DEBUG: Suite ($test_file) has ($suite.tests | length) tests"}
    }

    $suite
}

# Parse test file directly without spawning subshells
# This is much more memory-efficient for discovering tests
def parse-file-direct [file: path]: nothing -> list<record<name: string, attributes: list<string>, description: string>> {
    let content = open $file
    let lines = $content | lines
    mut results = []

    # Parse function definitions with attributes
    # Pattern: @attribute def name [...] OR @[attribute] def name [...]
    mut i = 0

    # Track multi-line string boundaries
    # Multi-line strings are used in integration tests to create temporary test files
    mut in_string = false
    mut quote_char = ""  # Track which quote character started the string

    # Debug: Track processing
    debug_count = 0

    while $i < ($lines | length) {
        let line = $lines | get --optional $i
        let trimmed = $line | str trim

        # Check for multi-line string start/end
        # Start: line that is just a quote (single or double) - must be ONLY a quote
        # End: line that contains quote | save or is just quote
        if $in_string {
            # Still in string, look for end
            # Check for both single and double quotes
            # Pattern: line starts with quote followed by " | save"
            if ($trimmed == $quote_char) or ($trimmed =~ $'^\s*($quote_char)\s*\|\s*save') {
                $in_string = false
                $quote_char = ""
            }
            $i += 1
            continue
        } else {
            # Not in string, check for start
            # Only treat as string start if the line is EXACTLY just a quote
            # Lines with content before the quote (like comments) are NOT string starts
            if $trimmed == '"' {
                $in_string = true
                $quote_char = '"'
                $i += 1
                continue
            } else if $trimmed == "'" {
                $in_string = true
                $quote_char = "'"
                $i += 1
                continue
            }
        }

        # Check if line starts with @attribute (with or without brackets)
        if ($line | is-not-empty) and ($line =~ '^\s*@') {
            # Try to extract attribute name with brackets @[test]
            let attr_match_brackets = $line | parse --regex '^\s*@\[([a-zA-Z_-]+)\]'
            if ($attr_match_brackets | is-not-empty) {
                let attr = $attr_match_brackets.capture0.0

                # Look for the function definition on the next line(s)
                let func_line = $lines | get --optional ($i + 1)
                if ($func_line | is-not-empty) and ($func_line =~ '^\s*def\s+') {
                    let func_match = $func_line | parse --regex '^\s*def\s+([a-zA-Z_][a-zA-Z0-9_-]*|"[^"]+")'
                    if ($func_match | is-not-empty) {
                        let func_name = $func_match.capture0.0

                        # Check for description tag in comments
                        let desc = extract-description $lines $i

                        $results ++= [{
                            name: $func_name
                            attributes: [$attr]
                            description: $desc
                        }]
                    }
                }
            } else {
                # Try to extract attribute name without brackets @test
                let attr_match = $line | parse --regex '^\s*@([a-zA-Z_-]+)'
                if ($attr_match | is-not-empty) {
                    let attr = $attr_match.capture0.0

                    # Look for the function definition on the next line(s)
                    let func_line = $lines | get --optional ($i + 1)
                    if ($func_line | is-not-empty) and ($func_line =~ '^\s*def\s+') {
                        let func_match = $func_line | parse --regex '^\s*def\s+([a-zA-Z_][a-zA-Z0-9_-]*|"[^"]+")'
                        if ($func_match | is-not-empty) {
                            let func_name = $func_match.capture0.0

                            # Check for description tag in comments
                            let desc = extract-description $lines $i

                            $results ++= [{
                                name: $func_name
                                attributes: [$attr]
                                description: $desc
                            }]
                        }
                    }
                }
            }
        } else if ($line | is-not-empty) and ($line =~ '^\s*def\s+') {
            # Check for description tag in comments without @attribute
            let func_match = $line | parse --regex '^\s*def\s+([a-zA-Z_][a-zA-Z0-9_-]*|"[^"]+")'
            if ($func_match | is-not-empty) {
                let func_name = $func_match.capture0.0
                let desc = extract-description $lines $i

                # Only include if it has a description tag
                if ($desc | is-not-empty) and ($desc =~ '\[[a-z-]+\]') {
                    $results ++= [{
                        name: $func_name
                        attributes: []
                        description: $desc
                    }]
                }
            }
        }

        $i += 1
    }

    # Debug output
    if ($results | length) > 50 {
        error make {
    msg: $"WARNING: parse-file-direct found ($results | length) results in ($file)"
}
    }

    $results
}

# Extract description from comments before a function
def extract-description [lines: list<string>, line_num: int]: nothing -> string {
    mut desc_lines = []
    mut i = $line_num - 1

    # Look backwards for comments
    while $i >= 0 and ($lines | get --optional $i | default '' | str trim | str starts-with '#') {
        let line = $lines | get --optional $i
        $desc_lines = ($desc_lines | prepend ($line | str replace '^#\s*' ''))
        $i -= 1
    }

    # Look for description tag pattern [tag]
    $desc_lines
        | str join ' '
        | default ''
}

def parse-suite [
    test_file: string
    tests: list<record<name: string, attributes: list<string>, description: string>>
]: nothing -> record<name: string, path: string, tests: table<name: string, type: string>> {

    {
        name: ($test_file | path parse | get stem)
        path: $test_file
        tests: ($tests | each { parse-test $in })
    }
}

def parse-test [
    test: record<name: string, attributes: list<string>, description: string>
]: nothing -> record<name: string, type: string> {

    {
        name: $test.name
        type: ($test | parse-type)
    }
}

def parse-type []: record<attributes: list<string>, description: string> -> string {
    let metadata = $in

    $metadata.attributes
        | append ($metadata.description | description-attributes)
        | where $it in $supported_types
        | get 0 --optional
        | default unsupported
}

def description-attributes []: string -> list<string> {
    parse --regex '.*\[([a-z-]+)\].*' | get capture0
}

def filter-tests [
    matcher: string
]: table<name: string, path: string, tests:table<name: string, type: string>> -> table<name: string, path: string, tests: table<name: string, type: string>> {

    let tests = $in
    $tests
        | each {|suite|
            {
                name: $suite.name
                path: $suite.path
                tests: ( $suite.tests
                    # Filter out unsupported types
                    | where type in $supported_types
                    # Filter only 'test' and 'ignore' by pattern
                    # Strategy functions are not filtered here - they are included for runner configuration
                    # but are not executed as tests (see runner.nu line 57)
                    | where (type != test and $it.type != ignore) or name =~ $matcher
                )
            }
        }
        # Remove suites that have no actual tests to run (only count test and ignore types, not strategy)
        | where ($it.tests | where type in [test ignore] | is-not-empty)
}
