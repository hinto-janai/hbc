# hbc
>hinto's bash compiler

## Contents
- [About](#About)
- [Development](#Development)
- [Specification](#Specification)
  - [Files](#Files)
  - [Include](#Include)
  - [Header](#Header)
  - [Safety](#Safety)
  - [Diagrams](#Diagrams)
- [Usage](#Usage)

## About
hbc is a Bash compiler based on traditional compiled language environments and C compile features.

An unfortunate consequence of creating larger scripts is that you cannot seperate codebase files like a compiled language, instead you must stuff all the logic inside one script which becomes hard to maintain.

hbc allows you to seperate your files then "compile" them together in the end to create one giant executable with all your code attached, much like the source files & compiled binary of a regular compiled language.

The end result "compiled" executable made by hbc is still a Bash script, however hbc adds some safety guarantees and can automatically add library code.

## Development
hbc uses certain functions from [stdlib](https://github.com/hinto-janaiyo/stdlib), and many hbc features benefit from having a copy of the stdlib. hbc also uses [shellcheck](https://github.com/koalaman/shellcheck) as a final lint at the end of compile, this is on by default but can be turned off.

## Specification
### Files
hbc requires only 1 file to work:
* `main.sh`

To fully utilize hbc, a project folder should have:
* a `src` directory
* the `lib` path set
* [`hbc.conf`](https://github.com/hinto-janaiyo/hbc/blob/main/hbc.conf.ref)
* [`shellcheck`](https://github.com/koalaman/shellcheck) installed

### Include
hbc uses the exact same directive as C, when including library code:
```
#include <lib/my_lib.sh>
```
Just like the C #include, hbc will look for files within the brackets (default location: `/usr/local/include`) and include them in the final output. This makes library code reuse very easy. Afterwards, hbc looks recursively in your `src` for any `.sh` files and includes them.

There are more compile-time options available available either through --flag options or through a custom [`hbc.conf`](https://github.com/hinto-janaiyo/hbc/blob/main/hbc.conf.ref).

### Header
hbc includes some useful information at the beginning of compiled scripts. This includes:
* `#git` - the name of the project + current git commit hash
* `#nix` - the time of compile in UNIX time
* `#hbc` - the version of hbc used to compile this script
* `#lib` - details on what library code was used + their git commit hash
* `#src` - details on what source code was used

### Safety
hbc aggressively wraps included library and source code within safety code to make sure IF a lib/src function is declared, it WILL be declared for the entire duration of the script and be readonly. There are many other gotchas when running a Bash script in an unknown environment, not so much a problem with your own scripts, but this becomes an issue when developing scripts other's will use. hbc takes care of this by including some, quite frankly, paranoid safety measure to make sure the GNU-core-utils and Bash builtins aren't tampered with.

Since this is all done with Bash builtins, this adds 0 runtime delay. Including many lib/src files does not slow anything down either, as function declarations are lightning fast.

### Diagrams

Diagram on how hbc takes these files as input and produces an output script:

![hbc](https://user-images.githubusercontent.com/101352116/179369380-66e13c19-d5e0-4ac0-9c29-521d52daeab0.png)

Cross-section of an output file:

![stack](https://user-images.githubusercontent.com/101352116/179369816-3527c37f-6065-4e4f-8223-3210b652dbd6.png)

## Usage
Command Usage:
```
USAGE: hbc --OPTION <ARGUMENT>

    -a | --add     <text file>          add a text file (like a license) on top of output, default: [LICENSE]
    -c | --config  <hbc config file>    specify hbc config to use, default: [$PWD/hbc.conf] or [/etc/hbc.conf]
    -d | --delete                       overwrite output file if it already exists
    -i | --ignore  <codes> or <ALL>     ignore shellcheck codes or disable shellcheck: [-i SC2154,SC2155] or [-i ALL]
    -l | --library <library directory>  specify where to look for lib code, default: [/usr/local/include]
    -m | --main    <main script name>   specify main script name, default: [main.sh]
    -h | --help                         print this help message and exit unsuccessfully
    -o | --output  <output name>        specify output filename, default: [$FOLDER_NAME.sh]
    -q | --quiet                        suppress hbc compile-time output (exit codes stay)
    -r | --run                          run output file if hbc successfully compiles
    -s | --source  <source directory>   specify where to look for src code, default: [src]
    -t | --test                         --run & --quiet the output from memory, no file made
    -v | --version                      print this hbc's time of compile and exit unsuccessfully
```

To begin compiling, enter a directory with a Bash project that looks something like:
```
main.sh
src/
├─ src_file1.sh
├─ src_file2.sh
```
and run `hbc`.

This will compile your `src` files together and append your `main.sh` at the end.

To include library code, use an `#include` directive at the top of your `main.sh`:
```
#include <stdlib/log.sh>
#include <my_lib/file.sh>
```
This will let hbc include `lib` and `src` code together before appending `main.sh`.

If all goes well, hbc will finish and you will have an output file.

Configuration can be done either with command options, or a [`hbc.conf`](https://github.com/hinto-janaiyo/hbc/blob/main/hbc.conf.ref). A different [`hbc.conf`](https://github.com/hinto-janaiyo/hbc/blob/main/hbc.conf.ref) can be used per project directory. The one included in this repo is for building `hbc` itself, `hbc.conf.ref` is an empty reference ready to use.
