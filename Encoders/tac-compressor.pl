#!/usr/bin/perl

# Author: Daniel "Trizen" Șuteu
# License: GPLv3
# Date: 01 May 2015
# Website: http://github.com/trizen

#
## The arithmetic coding algorithm.
#

# See: http://en.wikipedia.org/wiki/Arithmetic_coding#Arithmetic_coding_as_a_generalized_change_of_radix

use 5.010;
use strict;
use autodie;
use warnings;

use List::Util qw(min);
use Getopt::Std qw(getopts);
use File::Basename qw(basename);
use Math::BigInt (try => 'GMP');

use constant {
              PKGNAME => 'TAC Compressor',
              VERSION => '0.01',
              FORMAT  => 'tac',
             };

use constant {SIGNATURE => uc(FORMAT) . chr(1),};

sub usage {
    my ($code) = @_;
    print <<"EOH";
usage: $0 [options] [input file] [output file]

options:
        -e            : extract
        -i <filename> : input filename
        -o <filename> : output filename
        -r            : rewrite output

        -v            : version number
        -h            : this message

examples:
         $0 document.txt
         $0 document.txt archive.${\FORMAT}
         $0 archive.${\FORMAT} document.txt
         $0 -e -i archive.${\FORMAT} -o document.txt

EOH

    exit($code // 0);
}

sub version {
    printf("%s %s\n", PKGNAME, VERSION);
    exit;
}

sub main {
    my %opt;
    getopts('ei:o:vhr', \%opt);

    $opt{h} && usage(0);
    $opt{v} && version();

    my ($input, $output) = @ARGV;
    $input //= $opt{i} // usage(2);
    $output //= $opt{o};

    my $ext = qr{\.${\FORMAT}\z}io;
    if ($opt{e} || $input =~ $ext) {

        if (not defined $output) {
            ($output = basename($input)) =~ s{$ext}{}
              || die "$0: no output file specified!\n";
        }

        if (not $opt{r} and -e $output) {
            print "'$output' already exists! -- Replace? [y/N] ";
            <STDIN> =~ /^y/i || exit 17;
        }

        decompress($input, $output)
          || die "$0: error: decompression failed!\n";
    }
    elsif ($input !~ $ext || (defined($output) && $output =~ $ext)) {
        $output //= basename($input) . '.' . FORMAT;
        compress($input, $output)
          || die "$0: error: compression failed!\n";
    }
    else {
        warn "$0: don't know what to do...\n";
        usage(1);
    }
}

sub valid_archive {
    my ($fh) = @_;

    if (read($fh, (my $sig), length(SIGNATURE), 0) == length(SIGNATURE)) {
        $sig eq SIGNATURE || return;
    }

    return 1;
}

sub compress {
    my ($input, $output) = @_;

    use bytes;

    # Open the input file
    open my $fh, '<:raw', $input;

    # Open the output file and write the archive signature
    open my $out_fh, '>:raw', $output;
    print {$out_fh} SIGNATURE;

    my $str = do {
        local $/;
        scalar(<$fh>);
    };

    close $fh;

    my @chars = split(//, $str);

    # The dictionary
    my @range = map { chr } 0 .. 255;

    # The frequency characters
    my %freq;
    $freq{$_}++ for @chars;

    # The cumulative frequency
    my %cf;
    my $total = Math::BigInt->new(0);
    foreach my $c (@range) {
        if (exists $freq{$c}) {
            $cf{$c} = $total;
            $total += $freq{$c};
        }
    }

    # Limit and base
    my $lim  = Math::BigInt->new($#chars);
    my $base = $lim + 1;

    # Lower bound
    my $L = Math::BigInt->new(0);

    # Product of all frequencies
    my $pf = Math::BigInt->new(1);

    # Each term is multiplied by the product of the
    # frequencies of all previously occurring symbols
    for (my $i = 0 ; $i < $base ; $i++) {
        my $x = $cf{$chars[$i]} * $base**($lim - $i);
        $L->badd($x * $pf);
        $pf->bmul($freq{$chars[$i]});
    }

    # Upper bound
    my $U = $L + $pf;

    my $pow = Math::BigInt->new($U - $L)->blog(10);
    my $enc = ($U - 1)->bdiv(Math::BigInt->new(10)->bpow($pow));

    # Remove any other trailing zeros
    while ($enc > 0 and $enc % 10 == 0) {
        $pow->binc;
        $enc->bdiv(10);
    }

    my $bin = substr($enc->as_bin, 2);
    my $encoded = pack('S', $pow);    # the power value
    $encoded .= chr(scalar(keys %freq) - 1);    # number of unique chars
    $encoded .= chr(length($bin) % 8);          # padding

    while (my ($k, $v) = each %freq) {
        $encoded .= $k . pack('S', $v);         # char => freq
    }

    print {$out_fh} $encoded, pack('B*', $bin);
    close $out_fh;
}

sub decompress {
    my ($input, $output) = @_;

    use bytes;

    # Open and validate the input file
    open my $fh, '<:raw', $input;
    valid_archive($fh) || die "$0: file `$input' is not a \U${\FORMAT}\E archive!\n";
    my $content = do { local $/; <$fh> };
    close $fh;

    my ($pow, $uniq, $padd) = unpack('SCC', $content);
    substr($content, 0, 4, '');

    # Create the frequency table (char => freq)
    my %freq;
    foreach my $i (0 .. $uniq) {
        my ($char, $f) = unpack('aS', $content);
        $freq{$char} = $f;
        substr($content, 0, 3, '');
    }

    # Decode the bits into an integer
    my $enc = Math::BigInt->new('0b' . unpack('B*', $content));

    # Remove the trailing bits (if any)
    if ($padd != 0) {
        $enc >>= (8 - $padd);
    }

    $pow = Math::BigInt->new($pow);
    $enc *= Math::BigInt->new(10)->bpow($pow);

    my $base = Math::BigInt->new(0);
    $base += $_ for values %freq;

    my $lim = $base - 1;
    my @range = map { chr } 0 .. 255;

    # Create the cumulative frequency table
    my %cf;
    my $total = Math::BigInt->new(0);
    foreach my $c (@range) {
        if (exists $freq{$c}) {
            $cf{$c} = $total;
            $total += $freq{$c};
        }
    }

    ## Calculate the probabilities
    # my %prob;
    # while (my ($c, $f) = each %freq) {
    #     $prob{$c} = (($f - 1) / ($uniq + 1)) * $lim;
    # }

    # Create the dictionary
    my %dict;
    my $j = 0;
    for my $i (0 .. $#range) {
        my $char = $range[$i];
        if (exists $freq{$char}) {
            $dict{$j} = $char;
            $j += $freq{$char};
        }
    }

    # Fill the gaps in the dictionary
    my $lchar;
    foreach my $i (0 .. $base) {
        if (exists $dict{$i}) {
            $lchar = $dict{$i};
        }
        elsif (defined $lchar) {
            $dict{$i} = $lchar;
        }
    }

    # Open the output file
    open my $out_fh, '>:raw', $output;

    # Decode the input number
    for (my $i = $lim ; $i >= 0 ; $i--) {
        my $div = ($enc / $base**$i);

        my $c  = $dict{$div};
        my $fv = $freq{$c};
        my $cv = $cf{$c};

        $enc = ($enc - $base**$i * $cv) / $fv;
        print {$out_fh} $c;
    }

    close $out_fh;
}

main();
exit(0);