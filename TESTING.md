# Testing

There are two flavors of test. Both run inside nvim.

## Unit tests

These mostly just test lua stuff, but might still require some vim specifics
like vim apis and editor variables.

Run using `run_tests.sh`.

## Functional tests

These test more high level things and assert on things like buffer contents.
These assume you have a `nvim.test` set up in the normal config location.

Run using `run_functional_tests.sh`.

TODO: Document the expected setup, basically just a config that uses the `vc*` plugins via lazy or whatever.
