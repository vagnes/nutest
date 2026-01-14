use std/assert
use std/testing *
use harness.nu

# This suite tests use of external tools that would send output to stdout or stderr
# directly rather than what would otherwise be captured by runner aliasing of `print`.

@before-all
def setup-tests []: record -> record {
    harness setup-tests
}

@after-all
def cleanup-tests []: record -> nothing {
    harness cleanup-tests
}

@before-each
def setup-test []: record -> record {
    harness setup-test
}

@after-each
def cleanup-test []: record -> nothing {
    harness cleanup-test
}

@test
def non-captured-output-is-ignored []: any -> any {
    let code = {
        ^$nu.current-exe --version # This will print direct to stdout
        print "Only this text"
    }

    let result = $in | harness run $code

    assert equal ($result | reject suite test) {
        result: PASS
        output: ["Only this text"]
    }
}
