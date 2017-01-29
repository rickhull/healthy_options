# Notes

*subject to revision; just capturing some notes for now; pay no heed*

# arg styles

* flags always start with dash
* could be double-dash long-form e.g. --long-flag
* could be single-dash short-form e.g. -l
* could be single-dash long-form e.g. -lf

# Values

* space, e.g. --long-flag value
* equals, e.g. --long-flag=value
* smash, e.g. -lvalue

# Smash flags

* e.g. ps aux


cases:

`-lf -lr`

1. is this flag=l value=f or flag=lf
2. check flag=lf first, noting whether we have a value for it
3. we don't have a value for flag=lf: no equals, and the next arg is a flag


let's consider the following flags:

--name,      -n, requires a value
--enable,    -e, no value accepted
--net-read, -nr, requires a value

`-nr -e`

This can't be --net-read because we don't have a value.  It must be name=r.

--name,      -n, requires a value
--enable,    -e, no value accepted
--net-read, -nr, no value accepted

`-nr -e`

This could be --net-read or name=r, but we'll take --net-read because it was
specific.

Recommendation:

1. don't support -nr (one dash for short options, two for long)
2. don't support smashing for long options, ever
3. support smashing for short options, both flags and any final value
4. always handle an = immediately after a recognized flag (which takes a value) as a value assignment


2 primary distinctions:

* short option or long option
* takes a value or not

if it's a long option, it's easy:
1. read 2 dashes
2. read until [space] or [equals]
3. match flag or fail
4. does match take an arg?
 yes.1 if we have [equals] [value], done.
 yes.2 if the next arg is not a flag, done.
 yes.3 otherwise fail
 no.1 if we have equals, fail
 no.2 if the next arg is a flag, done
 no.3 if there are no more args, done
 no.4 if there are no more flags, done (leave non-flag args alone)
 no.5 otherwise we have an arg, fail


if it's a short option, we have to consider smashing
1. read a single dash followed by alphanum
2. confirm the flag and whether it takes a value
3. if the next character is a space, look for value match
 2.a if no value wanted, done
 2.b if value wanted, fail if no args or next arg is a flag. otherwise done
3. if the next character is equals, look for a value match
 3.a if no value wanted, fail
 3.b if value wanted, take the right side of the equals, done
4. if the next character is an alphanum, then we have either a smashed flag or a smashed value, depending on #2.
 3.a if no value wanted, then parse next char as a short flag
 3.b if value wanted, read the rest of the word as a value, done


1. given a string of alphanum, punctuation, and whitespace
2. split on whitespace into args consisting of alphanum and punctuation
3. an arg is either an option-flag, an option-value,
   a combination of these 2, or a non-option
4. the combinations consist of short-option smashing or flag=value
5. options come before non-options
6. args flatten to FLAG VALUE NONOPT [[DOUBLEDASH] ANY]
7. FLAG can be followed by FLAG or !FLAG
8. VALUE must be preceded by FLAG (otherwise it's a NONOPT)
9. every arg after a NONOPT must be a NONOPT
10. any NONOPT that looks like a flag is forbidden
11. unless it's the special DOUBLEDASH


So, split on whitespace.  That's handled for us with ARGV.

Next, look for dashes in the first arg.