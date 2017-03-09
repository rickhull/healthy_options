# Notes

*subject to revision; just capturing some notes for now; pay no heed*

## Background

Thinking about parsing command line options...  What are the most
prevalent styles out there?  Could we possibly support 80-90% of the
most prevalent styles with a single option spec and parser?

### Terminology

First, some terminology, as used below:

* **arg** - _A single term from a command line invocation as would
            be parsed and available in C's `ARGV` struct;
            i.e. whitespace delimited_
* **option** - _an **arg** or combination of args that "belongs to"
               (and presumably controls) the calling program;
               options are denoted by leading **flags**_
* **flag** - _an **arg** or part of an arg that begins an **option**;
             flags typically start with a dash though this can be
             omitted in certain cases;
             a flag may be the entirety of an option_
* **value** - _when an **option** is not a simple **flag**, the
              option may have a value;
              this is always preceded by the flag;
              an option that takes a value may span two args_

## Prevalent command line options styles

* flags always start with dash
* could be double-dash long-form: `--long-flag`
* could be single-dash short-form: `-l`
* could be single-dash long-form: `-lf`
* and ?

### Values

* space, e.g. `--long-flag value`
* equals, e.g. `--long-flag=value`
* smash, e.g. `-lvalue`

### Smash Flags

* e.g. `ps aux` or `ps -ef`

## Cases

`-lf -lr`

1. is this `flag=l value=f` or `flag=lf`?
2. check `flag=lf` first, noting whether we have a value for it
3. we don't have a value for `flag=lf`: no equals, and the next arg
   is a flag
4. we need to look up the options definition to see if `flag=lf` or
   `flag=l value=f` makes more sense

let's consider the following flags:

```
--name,      -n, requires a value
--enable,    -e, no value accepted
--net-read, -nr, requires a value
```

`-nr -e`

This can't be `--net-read` because we don't have a value.
It must be `name=r`.

What if `--net-read` doesn't take a value?

```
--name,      -n, requires a value
--enable,    -e, no value accepted
--net-read, -nr, no value accepted
```

`-nr -e`

This could be `--net-read` or `name=r`, but we'll take `--net-read`
because it was specific -- it didn't depend on a user-supplied value
to match the spec.

# Recommendation

1. don't support `-nr` (instead: one dash for short, single char
   options, two dashes for long options)
2. don't support smashing for long options, ever
3. support smashing for short options, both flags and any final value
4. always handle an `=` immediately after a recognized flag
   (which takes a value) as a value assignment


## 2 primary distinctions

* short option or long option
* takes a value or not

if it's a long option, it's easy:

```
1. read 2 dashes
2. read until [space] or [equals]
3. match flag or fail
4. does match take an arg?
 yes.1 if we have [equals] [value], done.
 yes.2 if the next arg is not a flag, done.
 yes.3 otherwise fail
 no.1 if we have equals, fail
 no.2 otherwise done
```

if it's a short option, we have to consider smashing

```
1. read a single dash followed by alphanum
2. confirm the flag and whether it takes a value
3. if the next character is a space, look for value match
 2.a if no value wanted, done
 2.b if value wanted, fail if no args or next arg is a flag.
     otherwise done
3. if the next character is equals, look for a value match
 3.a if no value wanted, fail
 3.b if value wanted, take the right side of the equals, done
4. if the next character is an alphanum, then we have either a
   smashed flag or a smashed value, depending on #2.
 3.a if no value wanted, then parse next char as a short flag
 3.b if value wanted, read the rest of the word as a value, done
```

Overall strategy, from the top:

1. given a string of alphanum, punctuation, and whitespace
2. split on whitespace into args consisting of alphanum and
   punctuation (i.e. `ARGV`)
3. an `arg` is either an `option-flag`, an `option-value`,
   a combination of these 2, or a `non-option`
4. the combinations (options which take a value in a single arg)
   consist of short-option smashing or `flag=value` forms
5. an option which takes a value can span 2 args when not using the
   `flag=value` form

... to be continued ...
