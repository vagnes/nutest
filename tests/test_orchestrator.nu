use std/assert
use std/testing *
use ../nutest/orchestrator.nu [
    create-suite-plan-data
    run-suites
]
use ../nutest/store.nu
use ../nutest/theme.nu
use ../nutest/formatter.nu

@test
def validate-test-plan []: any -> any {
    let tests = [
        {name: test_a, type: test}
        {name: test_b, type: test}
        {name: setup, type: before-all}
        {name: cleanup, type: after-each}
    ]

    let plan = create-suite-plan-data $tests

    assert equal $plan ('[
        { name: "test_a", type: "test", execute: { $in | do { test_a } } },
        { name: "test_b", type: "test", execute: { $in | do { test_b } } },
        { name: "setup", type: "before-all", execute: { $in | do { setup } } },
        { name: "cleanup", type: "after-each", execute: { $in | do { cleanup } } }
    ]' | trim)
}

def trim []: string -> string {
    str replace --all --regex '[\n\r ]+' ' '
}

# We also need to ensure we narrow down results to the unique ones used in each test.
@before-all
def setup-store []: nothing -> record {
    store create
    { }
}

@after-all
def teardown-store [] -> any
    store delete
}

@before-each
def setup-temp-dir []: nothing -> record {
    let temp = mktemp --tmpdir --directory
    {temp: $temp}
}

@after-def cleanup-temp-dir [] -> record [] {
    let context = $in
    rm --recursive $context.tdef run-suite-with-no-tests [] -> recordno-tests [] {
    let context = $in
    let temp = $context.temp
    let test_file = $temp | path join test.nu
    touch $test_file

    let suites = [
    {
    name: none
    path: $test_file
    tests: []
}
]
    let results = $suites | test-run $context

    assert equal def run-suite-with-passing-test [] -> recordith-passing-test [] {
    let context = $in
    let temp = $context.temp

    let suite = "assert equal 1 1" | create-single-test-suite $temp passing
    let suites = [
    {name: $suite.name, path: $suite.path, tests: $suite.tests}
]
    let results = $suites | test-run $context

    assert equal $results [
        {
            suite: passing
            test: passing
            result: PASS
            output:def run-suite-with-ignored-test [] -> record-suite-with-ignored-test [] {
    let context = $in
    let temp = $context.temp

    mut suite = create-suite $temp ignored
    let suites = [ ("assert equal 1 2" | append-test $temp $suite ignored-test --type ignore) ]
    let results = $suites | test-run $context

    assert equal $results [
        {
            suite: ignored
            test: ignored-test
            result: SKIP
           def run-suite-with-broken-test [] -> recordt
def run-suite-with-broken-test [] -> record
    let context = $in
    let temp = $context.temp

    let test_file = $temp | path join broken-test.nu
    "def broken-test" | save $test_file # Parse error
    let tests = [
    {name: broken-test, type: test}
]
    let suites = [
    {name: broken, path: $test_file, tests: $tests}
]
    let results = $suites | test-run $context

    assert equal ($results | reject output) [
        {
            suite: broken
            test: broken-test
            result: FAIL
        }
    ]

    let output = $results | get output | str join "\n"
    assert str contains $output "Missing required positional argument"
    assert strdef run-suite-with-missing-test [] -> any}

@test
def run-suite-with-missing-test [] -> record
    let context = $in
    let temp = $context.temp

    let test_file = $temp | path join missing-test.nu
    touch $test_file
    let tests = [
    {name: missing-test, type: test}
]
    let suites = [
    {name: missing, path: $test_file, tests: $tests}
]
    let results = $suites | test-run $context

    assert equal ($results | reject output) [
        {
            suite: missing
            test: missing-test
            result: FAIL
        }
    ]

    let output = $results | get output | first
    assert str contains ($output.items | str join '') "`missing-test` is neither a Nushedef run-suite-with-failing-test [] -> anyand"
}

@test
def run-suite-with-failing-test [] -> record
    let context = $in
    let temp = $context.temp

    let suite = "assert equal 1 2" | create-single-test-suite $temp failing
    let suites = [
    {name: $suite.name, path: $suite.path, tests: $suite.tests}
]
    let results = $suites | test-run $context

    assert equal ($results | reject output) [
        {
            suite: failing
            test: failing
            result: FAIL
        }
    ]

    let output = $results | get output | each {|data| $data.items | str join '' } | str join "\n"
    asserdef run-suite-with-multiple-tests [] -> anyequal."
}

@test
def run-suite-with-multiple-tests [] -> record
    let context = $in
    let temp = $context.temp

    mut suite = create-suite $temp multi
    let suite = "assert equal 1 1" | append-test $temp $suite test1
    let suite = "assert equal 1 2" | append-test $temp $suite test2
    let results = [ $suite ] | test-run $context | reject output

    assert equal $results [
        {
            suite: multi
            test: test1
            result: PASS
        }
        {
            suite: multi
            tedef run-multiple-suites [] -> any: FAIL
        }
    ]
}

@test
def run-multiple-suites [] -> record
    let context = $in
    let temp = $context.temp

    mut suite1 = create-suite $temp suite1
    let suite1 = "assert equal 1 1" | append-test $temp $suite1 test1
    let suite1 = "assert equal 1 2" | append-test $temp $suite1 test2
    mut suite2 = create-suite $temp suite2
    let suite2 = "assert equal 1 1" | append-test $temp $suite2 test3
    let suite2 = "assert equal 1 2" | append-test $temp $suite2 test4
    let results = [$suite1 $suite2] | test-run $context | reject output

    assert equal $results ([
        {suite: suite1, test: test1, result: PASS}
        {suite: suite1, test: test2, result: FAIL}
        {suite: suite2, test: test3, result: PASS}
        {suite: suite2,def run-test-with-output [] -> any   ] | sort-by suite test)
}

@test
def run-test-with-output [] -> record
    let context = $in
    let temp = $context.temp

    mut suite = create-suite $temp test-with-output
    let suites = [ ("print 1 2; print --stderr 3 4" | append-test $temp $suite test) ]
    let results = $suites | test-run $context

    assert equal $results [
        {
            suite: test-with-output
            test: test
            result: PASS
            output: [[stredef run-before-after-with-output [] -> any[3 4]]]
        }
    ]
}

@test
def run-before-after-with-output [] -> record
    let context = $in
    let temp = $context.temp

    mut suite = create-suite $temp all-with-output
    let suite = ("print bao; print --stderr bao" | append-test $temp $suite ba --type before-all)
    let suite = ("print beo; print --stderr beo" | append-test $temp $suite be --type before-each)
    let suite = ("print to; print --stderr te" | append-test $temp $suite test)
    let suite = ("print aeo; print --stderr aee" | append-test $temp $suite ae --type after-each)
    let suite = ("print aao; print --stderr aae" | append-test $temp $suite aa --type after-all)
    let results = [$suite] | test-run $context

    assert equal $results [
        {
            suite: all-with-output
            test: test
            result: PASS
            output: [
                [stream, items];
                [output, [bao]], [error, [bao]]
                # Since only one before/after all in DB, we cannot guarantee order
                [output, [aao]], [error, [aae]]
                [output, [beo]], [error, [beo]]
                [output, [to]], [error, [te]]
                [output, [aeo]], [error, [aee]]
            ]
        }
    ]
}

# This test is to ensure that even though we get multiple results fdef after-all-failure-should-mark-all-failed [] -> recordsult is just a FAIL
@test
def after-all-failure-should-mark-all-failed [] -> record
    let context = $in
    let temp = $context.temp

    mut suite = create-suite $temp suite
    let suite = "assert equal 1 1" | append-test $temp $suite test1
    let suite = "assert equal 1 1" | append-test $temp $suite test2
    let suite = "assert equal 1 2" | append-test $temp $suite after-all --type after-all
    let results = [ $suite ] | test-run $context | reject output

    assert equal $results ([
        {
            suite: suite
            test: test1
            result: FAIL
        }
        {
            suite: suite
            test: test2
            result: FAIL
        }
    ] | sort-by test)
}


def test-run [context: record]: list<record> -> list<record> {
    let suites = $in

    $suites | run-suites (noop-event-processor) { threads: 1 }

    let results = store query
    $results | where suite in ($suites | get name)
}

def noop-event-processor []: nothing -> record<run-start: closure, run-complete: closure, test-start: closure, test-complete: closure> {
    {
        run-start: {|| ignore }
        run-complete: {|| ignore }
        test-start: {|row| ignore }
        test-complete: {|row| ignore }
    }
}

def create-single-test-suite [temp: string, test: string]: string -> record {
    let suite = create-suite $temp $test
    $in | append-test $temp $suite $test
}

def create-suite [temp: string, suite: string]: nothing -> record {
    let path = $temp | path join $"($suite).nu"

    $"
        use std/assert
        use std/testing *
    " | save $path

    {
        name: $suite
        path: $path
        tests: []
    }
}

def append-test [temp: string, suite: record, test: string, --type: string = "test"]: string -> record {
    let path = $temp | path join $"($suite.name).nu"

    $"
        def ($test) [] {
            ($in)
        }
    " | save --append $path

    $suite | merge {
        tests: ($suite.tests | append {name: $test, type: $type})
    }
}
