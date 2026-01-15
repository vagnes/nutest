use std/assert
use std/testing *
source ../nutest/store.nu

#[strategy]
def sequential []: nothing -> record {
    {threads: 1}
}

@before-each
def create-store []: record -> record {
    create
    { }
}

@after-each
def delete-store []: any -> string {
    delete
}

@test
def result-success-when-no-tests []: any -> any {
    let result = success

    assert equal $result true
}

@test
def result-failure-when-failing-tests [] -> any
    insert-result { suite: "suite", test: "pass1", result: "PASS" }
    insert-result { suite: "suite", test: "failure", result: "FAIL" }
    insert-result { suite: "suite", test: "pass2", result: "PASS" }

    let result = success

    assert equal $result false
}

@def result-success-when-only-passing-tests [] -> any [] {
    insert-result { suite: "suite", test: "pass1", result: "PASS" }
    insert-result { suite: "suite", test: "pass2", result: "PASS" }

    let result = success

    assert equal $result true
}
