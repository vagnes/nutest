use std/assert

const default_pattern = '**/{*[\-_]test,test[\-_]*}.nu'

# Also see the filtering in runner.nu
const supported_types = [
    "test",
    "ignore",
    "before-all",
    "after-all",
    "before-each",
    "after-each",
    "strategy"
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

def list-files [ pattern: string ]: string -> list<string> {
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
        | reduce --fold [] { |file, acc|
            $acc | append (discover-suite $file)
        }
        | filter-tests $matcher

    # The following manifests the data to avoid laziness causing errors to be thrown in the wrong context
    # Some parser errors might be a `list<error>`, collecting will cause it to be thrown here
    $result | collect
    # Others are only apparent collecting the tests table
    $result | each { |suite| $suite.tests | collect }

    $result
}

def discover-suite [test_file: string]: nothing -> record<name: string, path: string, tests: table<name: string, type: string>> {
    let tests = parse-file-direct $test_file
    parse-suite $test_file $tests
}

# Parse test file directly without spawning subshells
# This is much more memory-efficient for discovering tests
def parse-file-direct [file: string]: nothing -> list<record<name: string, attributes: list<string>, description: string>> {
    let content = open $file
    let lines = $content | lines
    mut results = []
    
    # Parse function definitions with attributes
    # Pattern: @attribute def name [...] OR @[attribute] def name [...]
    mut i = 0
    
    while $i < ($lines | length) {
        let line = $lines | get $i
        
        # Check if line starts with @attribute (with or without brackets)
        if ($line | is-not-empty) and ($line =~ '^\s*@') {
            # Try to extract attribute name with brackets @[test]
            let attr_match_brackets = $line | parse --regex '^\s*@\[([a-zA-Z_-]+)\]'
            if ($attr_match_brackets | is-not-empty) {
                let attr = $attr_match_brackets.capture0.0
                
                # Look for the function definition on the next line(s)
                let func_line = $lines | get ($i + 1)
                if ($func_line | is-not-empty) and ($func_line =~ '^\s*def\s+') {
                    let func_match = $func_line | parse --regex '^\s*def\s+([a-zA-Z_][a-zA-Z0-9_-]*)'
                    if ($func_match | is-not-empty) {
                        let func_name = $func_match.capture0.0
                        
                        # Check for description tag in comments
                        let desc = extract-description $lines $i
                        
                        $results = ($results | append {
                            name: $func_name
                            attributes: [$attr]
                            description: $desc
                        })
                    }
                }
            } else {
                # Try to extract attribute name without brackets @test
                let attr_match = $line | parse --regex '^\s*@([a-zA-Z_-]+)'
                if ($attr_match | is-not-empty) {
                    let attr = $attr_match.capture0.0
                    
                    # Look for the function definition on the next line(s)
                    let func_line = $lines | get ($i + 1)
                    if ($func_line | is-not-empty) and ($func_line =~ '^\s*def\s+') {
                        let func_match = $func_line | parse --regex '^\s*def\s+([a-zA-Z_][a-zA-Z0-9_-]*)'
                        if ($func_match | is-not-empty) {
                            let func_name = $func_match.capture0.0
                            
                            # Check for description tag in comments
                            let desc = extract-description $lines $i
                            
                            $results = ($results | append {
                                name: $func_name
                                attributes: [$attr]
                                description: $desc
                            })
                        }
                    }
                }
            }
        } else if ($line | is-not-empty) and ($line =~ '^\s*def\s+') {
            # Check for description tag in comments without @attribute
            let func_match = $line | parse --regex '^\s*def\s+([a-zA-Z_][a-zA-Z0-9_-]*)'
            if ($func_match | is-not-empty) {
                let func_name = $func_match.capture0.0
                let desc = extract-description $lines $i
                
                # Only include if it has a description tag
                if ($desc | is-not-empty) and ($desc =~ '\[[a-z-]+\]') {
                    $results = ($results | append {
                        name: $func_name
                        attributes: []
                        description: $desc
                    })
                }
            }
        }
        
        $i = $i + 1
    }
    
    $results
}

# Extract description from comments before a function
def extract-description [lines: list<string>, line_num: int]: nothing -> string {
    mut desc_lines = []
    mut i = $line_num - 1
    
    # Look backwards for comments
    while $i >= 0 and ($lines | get $i | default '' | str trim | str starts-with '#') {
        let line = $lines | get $i
        $desc_lines = ($desc_lines | prepend ($line | str replace '^#\s*' ''))
        $i = $i - 1
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
        | default "unsupported"
}

def description-attributes []: string -> list<string> {
    $in | parse --regex '.*\[([a-z-]+)\].*' | get capture0
}

def filter-tests [
    matcher: string
]: table<name: string, path: string, tests:table<name: string, type: string>> -> table<name: string, path: string, tests: table<name: string, type: string>> {

    let tests = $in
    $tests
        | each { |suite|
            {
                name: $suite.name
                path: $suite.path
                tests: ( $suite.tests
                    # Filter out unsupported types
                    | where $it.type in $supported_types
                    # Filter only 'test' and 'ignore' by pattern
                    | where ($it.type != "test" and $it.type != "ignore") or $it.name =~ $matcher
                )
            }
        }
        # Remove suites that have no actual tests to run
        | where ($it.tests | where type in ["test", "ignore"] | is-not-empty)
}
