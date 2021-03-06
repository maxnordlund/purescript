## 0.5.0 Changes

## Breaking Changes

- Support for blocks has been removed. (paf31)
- Type class instances must now be named (paf31)

        instance showNumber :: Show Number where
          ...

### New Features

- `let ... in` syntax for bindings (paf31)
- Multi parameter typeclasses (paf31)
- Empty data declarations and empty type classes are now supported (paf31)

### Enhancements

- Pretty printing for row types was improved (garyb)
- Module names can now contain `.` (garyb)
- Prelude modules now follow a naming scheme similar to haskell (e.g. `Data.Maybe`, `Control.Monad`) (garyb)
- New optimizer rules have been added for code in the ST monad, to reproduce the functionality of the blocks feature, which has been removed (paf31)
- Pattern binders are now usable in lambda expression arguments (paf31)
- PSCI now has a `:t` command for checking the type of a value (paf31)
- Array pretty printing via `show` has been improved (joneshf)
- PSCI completions are sorted (joneshf)
- PSCI now has help commands (joneshf)
- PSCI history is in XDG config (joneshf)
- PSCI allows loading of modules from ~ paths (joneshf)
- PSCI can accept a list of modules to load on start from the command line (paf31)
- Type class instances are now named, to enable easier interop with Javascript (paf31)
- Class names no longer need to be qualified in instance declarations (garyb)
- Module exports can now be specified explicitly (garyb)
- Let bindings can now define functions with binders (paf31)
- Case statements and functions which do not pattern match on their arguments now generate smaller code (paf31)

### Bug Fixes

- The subsumes relation has been fixed for object types (paf31)
- `sort` no longer mutates arrays (joneshf)
- PSCI now evaluates expressions (joneshf)
- Overlapping variables in typeclass instances are rejected (paf31)
- A bug in the optimizer related to inlining was fixed (paf31)

### Libraries

- The [purescript-date](https://github.com/purescript/purescript-date) library provides basic date/time functions
- The [purescript-reactive](https://github.com/purescript/purescript-reactive) and [purescript-reactive-jquery]() libraries provide reactive variables, and bindings to jQuery properties.
- The [purescript-generics](https://github.com/purescript/purescript-generics) library provides generic programming capabilities.

### Documentation

- 
