#!/usr/bin/perl

# Author: Daniel "Trizen" Șuteu
# License: GPLv3
# Date: 15 April 2016
# Website: https://github.com/trizen

# Analyze a sequence of numbers and find a closed-form expression.

# WARNING: This program is under heavy development.

use 5.010;
use strict;
use warnings;

package Sequence::ClosedForm {

    use Math::BigNum qw(:constant);

    sub new {
        my ($class, %opt) = @_;
        bless \%opt, $class;
    }

    sub sub_n {
        my $n = 0;
        sub {
            $_[0] - ++$n;
        };
    }

    sub add_n {
        my $n = 0;
        sub {
            $_[0] + ++$n;
        };
    }

    sub mul_n {
        my $n = 1;
        sub {
            $_[0] * ++$n;
        };
    }

    sub div_n {
        my $n = 1;
        sub {
            $_[0] / ++$n;
        };
    }

    sub sub_constant {
        my (undef, $c) = @_;
        sub {
            $_[0] - $c;
        };
    }

    sub div_constant {
        my (undef, $c) = @_;
        sub {
            $_[0] / $c;
        };
    }

    sub add_constant {
        my (undef, $c) = @_;
        sub {
            $_[0] + $c;
        };
    }

    sub add_all {
        my $sum = 0;
        sub {
            $sum += $_[0];
            $sum;
        };
    }

    sub mul_all {
        my $prod = 1;
        sub {
            $prod *= $_[0];
            $prod;
        };
    }

    sub sub_consecutive {
        my $prev;
        sub {
            my ($term) = @_;
            if (defined($prev)) {
                $term = $term - $prev;
            }
            $prev = $_[0];
            $term;
        };
    }

    sub add_consecutive {
        my $prev;
        sub {
            my ($term) = @_;
            if (defined($prev)) {
                $term = $term + $prev;
            }
            $prev = $_[0];
            $term;
        };
    }

    sub div_consecutive {
        my $prev;
        sub {
            my ($term) = @_;
            if (defined($prev)) {
                $term = $term / $prev;
            }
            $prev = $_[0];
            $term;
        };
    }

    sub find_closed_form {
        my ($self, $seq) = @_;

        my %data = (
            diff_min => Inf,
            diff_max => -Inf,
            diff_avg => 0,

            ratio_min => Inf,
            ratio_max => -Inf,
            ratio_avg => 1,

            min => Inf,
            max => -Inf,
                   );

        my $count = @$seq - 1;
        return if $count <= 0;

        my $prev;
        foreach my $term (@{$seq}) {

            if ($term < $data{min}) {
                $data{min} = $term;
            }

            if ($term > $data{max}) {
                $data{max} = $term;
            }

            if (defined $prev) {
                my $diff = $term - $prev;

                if ($diff < $data{diff_min}) {
                    $data{diff_min} = $diff;
                }

                if ($diff > $data{diff_max}) {
                    $data{diff_max} = $diff;
                }

                $data{diff_avg} += $diff / $count;

                my $ratio = $term / $prev;

                if ($ratio < $data{ratio_min}) {
                    $data{ratio_min} = $ratio;
                }

                if ($ratio > $data{ratio_max}) {
                    $data{ratio_max} = $ratio;
                }

                $data{ratio_avg} += $ratio;

            }

            $prev = $term;
        }

        $data{ratio_avg} /= $count;

        if ($data{diff_avg} == $data{diff_max} and $data{diff_max} == $data{diff_min}) {
            my $min = ($data{min} - $data{diff_min})->round(-20);

            return {
                    factor => $data{diff_min},
                    offset => $min,
                    type   => 'arithmetic',
                   },
              ;
        }

        foreach my $key (sort keys %data) {
            printf("%9s => %s\n", $key, $data{$key});
        }
        print "\n";

        return ();
    }
}

use Math::BigNum qw(:constant);

my @rules = (
    ['sub_consecutive', 'add_n'],

    #['add_constant', 'div_consecutive'],
    #['sub_constant', 'add_n', 'add_n'],
    #['sub_constant'],
    #['sub_constant', 'div_consecutive',],
    #['sub_constant', 'div_consecutive' ],
    ['sub_constant'],

    #['sub_constant'],
    #['add_n', 'div_consecutive',],
    #['div_consecutive',],
            );

my @constants = (1 .. 5);    #, #exp(1), atan2(0, -'inf'));

my $seq = Sequence::ClosedForm->new();
my @seq = (map { $_ * ($_ + 1) / 2 } 1 .. 10);

#my @seq = (map {(0+$_)->fac + 1} 0..9);
#my @seq = (map{$_+0}1..10);

sub make_constant_obj {
    my ($method) = @_;

    my %cache;

    my %state = (
        i    => 0,
        done => 0,

        code => sub {
            my ($self, $n) = @_;
            my $i = $self->{i} - 1;
            my $sub = ($cache{$i} //= $seq->$method($constants[$i]));
            $sub->($n);
        }
    );

    bless \%state, 'Sequence::Constant';
}

sub generate_actions {
    map { /_constant\z/ ? [$_, make_constant_obj($_)] : [$_, $seq->$_] } @_;
}

my %closed_forms = (
    'sub_consecutive' => sub {
        my ($n, $data) = @_;
        "($data->{factor}*$n + $data->{offset})*($data->{factor}*$n + $data->{offset} + 1)/2";
    },
);

sub fill_closed_form {
    my ($cf, $transforms, $constant) = @_;

    my $result = 'n';
    foreach my $rule (@{$transforms}) {
        $result = $closed_forms{$rule}($result, $cf);
    }

    $result;
}

use List::Util qw(first);

RULE: foreach my $rule (@rules) {
    my @actions   = generate_actions(@$rule);
    my @const_pos = grep { $rule->[$_] =~ /_constant\z/ } 0 .. $#{$rule};
    my $has_const = !!@const_pos;

    while (1) {
        my @new;

        my $stop = $has_const;
        foreach my $pos (@const_pos) {
            my $constant = $actions[$pos][1];

            if (not $constant->{done}) {

                if ($constant->{i} >= $#constants) {
                    $constant->{i}    = 0;
                    $constant->{done} = 1;
                }
                else {
                    $constant->{i}++;
                }

                $stop = 0;
                last;
            }
        }

        last if $stop;

        foreach my $term (@seq) {
            my $result = $term;

            foreach my $group (@actions) {
                my $action = $group->[1];
                if (ref($action) eq 'Sequence::Constant') {
                    $result = $action->{code}($action, $result);
                }
                else {
                    $result = $action->($result);
                }
            }

            next if ($result <= 0 or not $result->is_real);
            push @new, $result;
        }

        say "@new";

        $has_const || last;
        foreach my $group (grep { $_->[0] !~ /_constant\z/ } @actions) {
            my $method = $group->[0];
            $group->[1] = $seq->$method;
        }
    }

    #~ foreach my $i(0..$#sequences) {
    #~ my $sequence = $sequences[$i];
    #~ my @closed_forms = $seq->find_closed_form($sequence);
    #~ if (@closed_forms) {
    #~ my $constant = $constants[$i];
    #~ foreach my $cf(@closed_forms) {
    #~ my $filled = fill_closed_form($cf, $rule, $constant);
    #~ say "Possible closed-form: $filled";
    #~ }
    #~ }
    #~ }
}