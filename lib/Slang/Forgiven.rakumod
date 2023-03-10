use nqp;
use QAST:from("NQP");

constant NL    = $*DISTRO.is-win ?? "\r\n" !! "\n";
constant ARROW = "------> ";

role Forgiven::Grammar {
    # Add it as a yet another statement controller
    rule statement_control:sym<forgiven> {
        "forgiven"
        :my $*GOAL := "\{";
        <fg-xblock>
    }

    # This is equivalent to <xblock(0)> but define for a finer action
    token fg-xblock {
        <EXPR> <.ws> <pblock(0)>
    }
}

role Forgiven::Actions {
    method fg-xblock(Mu \match) {
        # Get a hold on the matched components
        my $mh  := match.hash;                 # entire match
        my $pbl := nqp::atkey($mh, "pblock");  # parametrized block

        # Will store the parameter names to bind to here
        my $param-names := nqp::create(IterationBuffer);

        # Dive into the signature and collect parameter names
        put-param-names(nqp::atkey($pbl, "signature"), $param-names, $pbl);

        # Insert `$_ := ...` at the beginning of the statement list of the block
        nqp::atkey(nqp::atkey($pbl, "blockoid"), "statementlist").ast.unshift(
            QAST::Op.new(:op("bind"),
                         QAST::Var.new(:name("\$_"), :scope("lexical")),
                         nqp::elems($param-names) == 1
                             # If only one parameter, bind to it directly
                             ?? QAST::Var.new(:name(nqp::atpos($param-names,0)), :scope("lexical"))
                             # If many parameters, form a list and bind to that
                             !! QAST::Op.new(:op<call>, :name<&infix:<,>>,
                                             |(QAST::Var.new(:name($_), :scope("lexical"))
                                               for $param-names))));

        # Roll the usual loop after the insertion
        match.make: QAST::Op.new:
                         :op("p6for"), :node(match),
                         nqp::atkey($mh, "EXPR").ast,
                         $pbl.ast
    }

    method statement_control:sym<forgiven>(Mu \match) {
        match.make: nqp::atkey(match.hash, "fg-xblock").ast
    }
}

sub put-param-names(Mu \sig, $param-names is raw, Mu $pbl?) {
    # Get the parameter submatch of the signature token, if any
    my $parsed-params := nqp::atkey(sig.?hash, "parameter");
    error("Parameterless block is not forgiven; please use \"for\" instead", nqp::atkey($pbl.hash, "blockoid"))
        unless $parsed-params;

    # Iterate over the parsed parameters NQPArray
    my int $i          = -1;
    my int $num-params = nqp::elems($parsed-params);
    nqp::while(
        nqp::islt_i(++$i, $num-params),
        nqp::stmts(
            # Get a hold on the i'th parameter object
            (my %_h := nqp::atpos($parsed-params, $i).hash),
            (my $p),
            nqp::if(
                # Is it a named or a positional parameter?
                # Descend accordingly to get the parameter's name
                nqp::existskey(%_h, "named_param"),
                ($p := nqp::atkey(nqp::atkey(%_h, "named_param").hash, "param_var")),
                ($p := nqp::atkey(%_h, "param_var")),
            ),
            (my %h := $p.hash),
            nqp::if(
                # Is the parameter yet another signature, i.e., destructuring?
                nqp::existskey(%h, "signature"),
                # Then go grab the parameter names in that subsignature
                (put-param-names(nqp::atkey(%h, "signature"), $param-names)),
                # Otherwise, "normal" parameter...
                nqp::if(
                    # ...except is it an "unnamed" parameter to destructure into? e.g., `@ [$a, $b]`
                    nqp::iseq_s((my $_ps = $p.Str),"\@") || nqp::iseq_s($_ps, "\%") || nqp::iseq_s($_ps, "\$"),
                    # If so, binding to, e.g., `@` won't work; get a hold on that `[$a, $b]` part and grab the names therein
                    put-param-names(nqp::atkey(nqp::atkey(%_h, "post_constraint")[0], "signature"), $param-names),
                    # Otherwise, it really is a normal parameter, push its name
                    nqp::push($param-names, $p)
                ),
            )
        )
    )
}

#| Provides a (hopefully) good error message when things go wrong
sub error(Str $message, Mu \mobj) {
    # Get the row-col information where the compilation failed
    my $col = mobj.from;
    my $row = mobj.target.substr(0, $col).indices(NL).elems;

    # Error out with an arrow pointing to that position
    nqp::die(qq:to/EOS/.trim);
    $message
    at $*PROGRAM.absolute():$row
    {ARROW}{mobj.target.lines[$row]}
    {" " x $col.pred - mobj.target.lines(:!chomp)[^$row]>>.chars.sum + ARROW.chars}↑
    EOS
}

sub EXPORT {
    # When `use`d, the LANG in effect will be the MAIN one but `forgiven` mixed in
    $*LANG.define_slang:
        "MAIN",
        $*LANG.slangs<MAIN>         but Forgiven::Grammar,
        $*LANG.slangs<MAIN-actions> but Forgiven::Actions;
    Map.new
}
