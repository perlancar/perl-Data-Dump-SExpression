package Data::Dump::SExpression;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;

use Scalar::Util qw(looks_like_number blessed reftype refaddr);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(dd_sexp dump_sexp);

our %_seen_refaddrs;

# BEGIN COPY PASTE FROM Data::Dump
my %esc = (
    "\a" => "\\a",
    "\b" => "\\b",
    "\t" => "\\t",
    "\n" => "\\n",
    "\013" => "\\v", # chr(11)
    "\f" => "\\f",
    "\r" => "\\r",
    "\e" => "\\e",
    #"\040" => "\\e", # chr(32)
    "\177" => "\\d", # chr(127)
    "\\" => "\\\\",
    '"' => "\\\"",
);

sub _double_quote {
    my $str = shift;

    $str =~ s/([\a\b\t\n\013\f\r\e\177\\"])/$esc{$1}/g;
    return qq("$str");
}

sub _dump {
    my $val = shift;

    my $ref = ref($val);
    if ($ref eq '') {
        if (!defined($val)) {
            return "nil";
        } elsif (looks_like_number($val)) {
            if ($val == "Inf") {
                return "1.0e+INF";
            } elsif ($val == "-Inf") {
                return "-1.0e+INF";
            } elsif ($val =~ /nan/i) {
                return "1.0e+NaN";
            } else {
                return $val;
            }
        } else {
            return _double_quote($val);
        }
    }
    my $refaddr = refaddr($val);
    if ($_seen_refaddrs{$refaddr}++) {
        die "Cannot handle circular references";
    }

    if ($ref eq 'Regexp' || $ref eq 'REGEXP') {
        die "Cannot dump regexp objects";
    }

    if ($ref eq 'JSON::PP::Boolean') {
        return $val ? 't' : 0; # XXX should we dump false as nil or 0?
    }

    if (blessed $val) {
        die "Cannot dump blessed references";
    }

    my $res;
    if ($ref eq 'ARRAY') {
        $res = "(";
        my $i = 0;
        for (@$val) {
            $res .= " " if $i;
            $res .= _dump($_);
            $i++;
        }
        $res .= ")";
    } elsif ($ref eq 'HASH') {
        $res = "(";
        my $i = 0;
        for (sort keys %$val) {
            $res .= " " if $i++;
            my $k = _double_quote($_);
            my $v = _dump($val->{$_});
            $res .= "($k . $v)";
        }
        $res .= ")";
    } elsif ($ref eq 'SCALAR') {
        die "Cannot dump scalarrefs";
    } elsif ($ref eq 'REF') {
        die "Cannot dump refrefs";
    } elsif ($ref eq 'CODE') {
        die "Cannot dump coderefs";
    } else {
        die "Cannot dump $val (ref=$ref)";
    }

    $res;
}

our $_is_dd;
sub _dd_or_dump {
    local %_seen_refaddrs;

    my $res;
    if (@_ > 1) {
        $res = "(" . join(" ", map {_dump($_)} @_) . ")";
    } else {
        $res = _dump($_[0]);
    }

    if ($_is_dd) {
        say $res;
        return wantarray() || @_ > 1 ? @_ : $_[0];
    } else {
        return $res;
    }
}

sub dd_sexp   { local $_is_dd=1; _dd_or_dump(@_) } # goto &sub doesn't work with local
sub dump_sexp { goto &_dd_or_dump }

1;
# ABSTRACT: Dump Perl data structures as S-expression

=head1 SYNOPSIS

 use Data::Dump::SExpression qw(dd_sexp dump_sexp);
 dd [1, 2, 3]; # prints "(1 2 3)"
 my $dmp = dump_sexp({a=>1, b=>1}); # -> '(("a" . 1) ("b" . 1))'


=head1 DESCRIPTION

B<EARLY RELEASE.>


=head1 FUNCTIONS

=head2 dd_sexp

Usage:

 dd_sexp($data, ...);

Print dump to STDOUT. Return the original C<$data>.

=head2 dump_sexp

Usage:

 my $dump = dump_sexp($data, ...);

Return dump result as string. it I<never> prints and only return the dump
result.


=head1 VARIABLES


=head1 FAQ


=head1 SEE ALSO

To parse S-expression: L<SExpression::Decode::Marpa>,
L<SExpression::Decode::Regexp>, L<Data::SExpression>.

=cut
