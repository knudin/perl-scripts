#!/usr/bin/perl

# Author: Daniel "Trizen" Șuteu
# License: GPLv3
# Date: 14 June 2015
# http://github.com/trizen

# A generic image auto-cropper which adapt itself to any background color.

use 5.010;
use strict;
use warnings;

use GD qw();

use Getopt::Long qw(GetOptions);
use File::Basename qw(basename);
use File::Spec::Functions qw(catfile);

# Set true color
GD::Image->trueColor(1);

# Autoflush mode
local $| = 1;

my $tolerance = 5;

my $jpeg_quality    = 95;
my $png_compression = 7;

my $directory = 'Cropped images';

sub help {
    my ($code) = @_;
    print <<"EOT";
usage: $0 [options] [images]

options:
    -t --tolerance=i    : tolerance value for the background color
                          default: $tolerance

    -p --png-compress=i : the compression level for PNG images
                          default: $png_compression

    -j --jpeg-quality=i : the quality value for JPEG images
                          default: $jpeg_quality

    -d --directory=s    : directory where to create the cropped images
                          default: "$directory"

example:
    perl $0 -t 10 *.png
EOT
    exit($code // 0);
}

GetOptions(
           'd|directory=s'       => \$directory,
           't|tolerance=i'       => \$tolerance,
           'p|png-compression=i' => \$png_compression,
           'j|jpeg-quality=i'    => \$jpeg_quality,
           'h|help'              => sub { help(0) },
          )
  or die("$0: error in command line arguments!\n");

if (not -d $directory) {
    mkdir($directory) || die "Can't mkdir `$directory': $!";
}

{
    my %cache;

    sub is_background {
        my ($img, $index, $bg_rgb) = @_;
        my $rgb = ($cache{$index} //= [$img->rgb($index)]);
        abs($rgb->[0] - $bg_rgb->[0]) <= $tolerance
          and abs($rgb->[1] - $bg_rgb->[1]) <= $tolerance
          and abs($rgb->[2] - $bg_rgb->[2]) <= $tolerance;
    }
}

sub check {
    my ($img, $bg_rgb, $width, $height) = @_;

    my $check = sub {
        foreach my $sub (@_) {
            is_background($img, $sub->(), $bg_rgb) || return;
        }
        1;
    };

    my $w_lt_h = $width < $height;
    my $min = $w_lt_h ? $width : $height;

    my $ok = 1;
    my %seen;

    # Spiral-in to smaller gaps
    # -- this algorithm needs to be improved --
    for (my $i = int(sqrt($min)) ; $i >= 1 ; $i--) {
        foreach my $j (1 .. $min) {

            next if $j % $i;
            next if $seen{$j}++;

            if (
                not $check->(
                             sub { $img->getPixel($j,     0) },
                             sub { $img->getPixel(0,      $j) },
                             sub { $img->getPixel($j,     $height) },
                             sub { $img->getPixel($width, $j) },
                            )
              ) {
                $ok = 0;
                last;
            }
        }
    }

    if ($w_lt_h) {
        foreach my $y ($width + 1 .. $height) {
            if (not $check->(sub { $img->getPixel(0, $y) }, sub { $img->getPixel($width, $y) })) {
                $ok = 0;
                last;
            }
        }
    }
    else {
        foreach my $x ($height + 1 .. $width) {
            if (not $check->(sub { $img->getPixel($x, 0) }, sub { $img->getPixel($x, $height) })) {
                $ok = 0;
                last;
            }
        }
    }

    return $ok;
}

sub autocrop {
    my @images = @_;

    foreach my $file (@images) {
        my $img = GD::Image->new($file);

        if (not defined $img) {
            warn "[!] Can't process image `$file': $!\n";
            next;
        }

        my ($width, $height) = $img->getBounds();

        $width  -= 1;
        $height -= 1;

        my $bg_rgb = [$img->rgb($img->getPixel(0, 0))];

        print "Checking: $file";
        check($img, $bg_rgb, $width, $height) || do {
            say " - fail!";
            next;
        };

        say " - ok!";
        print "Cropping: $file";

        my $top;
        my $bottom;
      TB: foreach my $y (1 .. int($height / 2)) {
            foreach my $x (1 .. $width) {

                if (not defined $top) {
                    if (not is_background($img, $img->getPixel($x, $y), $bg_rgb)) {
                        $top = $y - 1;
                    }
                }

                if (not defined $bottom) {
                    if (not is_background($img, $img->getPixel($x, $height - $y), $bg_rgb)) {
                        $bottom = $height - $y + 1;
                    }
                }

                if (defined $top and defined $bottom) {
                    last TB;
                }
            }
        }

        if (not defined $top or not defined $top) {
            say " - fail!";
            next;
        }

        my $left;
        my $right;
      LR: foreach my $x (1 .. int($width / 2)) {
            foreach my $y (1 .. $height) {
                if (not defined $left) {
                    if (not is_background($img, $img->getPixel($x, $y), $bg_rgb)) {
                        $left = $x - 1;
                    }
                }

                if (not defined $right) {
                    if (not is_background($img, $img->getPixel($width - $x, $y), $bg_rgb)) {
                        $right = $width - $x + 1;
                    }
                }

                if (defined $left and defined $right) {
                    last LR;
                }
            }
        }

        if (not defined $left or not defined $right) {
            say " - fail!";
            next;
        }

        my $cropped = GD::Image->new($right - $left + 1, $bottom - $top + 1);
        $cropped->copyResized(
                              $img,
                              0,          # destX
                              0,          # destY
                              $left,      # srcX
                              $top,       # srcY
                              $right,     # destW
                              $bottom,    # destH
                              $right,     # srcW
                              $bottom,    # srcH
                             );

        my $name = catfile($directory, basename($file));

        open my $fh, '>:raw', $name or die "Can't create file `$name': $!";
        print $fh (
                     $name =~ /\.png\z/i ? $cropped->png($png_compression)
                   : $name =~ /\.gif\z/i ? $cropped->gif
                   :                       $cropped->jpeg($jpeg_quality)
                  );
        close $fh;

        say " - ok!";
    }
}

@ARGV || help(1);
autocrop(@ARGV);
