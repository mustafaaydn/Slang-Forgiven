## Slang::Forgiven
When a for loop meets a given statement

```raku
use Slang::Forgiven;

# `$num` as well as `$_` are available in the loop body
forgiven [2, -3, 4, -5] -> $num {
    # `$_` is aliased to `$num`, so `when` will know
    when * > 0 { put "$num is positive" }
    when * < 0 { put "$num is negative" }
    default    { put "neutral" }
}
```

### What
A for loop with a parametrized block lets you iterate over things with names, and a given statement allows for topicalization. The "forgiven" statement does both: you have the usual looping but also have `$_` available.

That is,
```raku
for @values -> $val {
    given $val {
        when * > 0 { "$val is positive" }
        ...
    }
}
```
is possible as
```raku
forgiven @values -> $val {
    when * > 0 { "$val is positive" }
    ...
}
```
i.e., it's as if `$_ := $val` is placed immediately after the opening curly bracket. Arrays, Hashes, their destructuring, optional and/or typed parameters are possible, too; examples for them can be found in the "t/" directory.

### Why
"For fun" should be enough but this also came up in at least 2 places:
- "habere-et-disper" (~"tire") [on IRC](https://irclogs.raku.org/raku-beginner/2022-11-10.html#10:26) mentions the "-Ofun idea of `forgiven`"
- "VZ." asks about an "elegant way to write when inside a for loop" [on StackOverflow](https://stackoverflow.com/questions/75186531)

I thank "habere-et-dispertire" for the idea; this arose from their message(s). I also thank Damian Conway for their [for-else](https://blogs.perl.org/users/damian_conway/2019/09/itchscratch.html) writing (as well as numerous presentations online that leave me amazed).

### How
Grammar follows that of the "for" loop. Actions first gather the parameter names of the block of the loop, and then unshift the `$_ := ...`  statement (a "bind" QAST::Op) to the AST of the statement list of the block.

#### Installation
Using [pakku](https://github.com/hythm7/Pakku):
```sh
git clone https://github.com/mustafaaydn/Slang-Forgiven.git && cd "$(basename "$_" .git)"
pakku add . && cd .. && rm -rf Slang-Forgiven
```