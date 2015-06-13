#!/usr/bin/perl

use 5.014;
use strict;
use warnings;

use GD::Simple;

my $pi = do {
    local $/;
    <DATA> =~ tr/0-9//dcr;
};

my $img = 'GD::Simple'->new(10000, 6000);
$img->fgcolor('blue');
$img->moveTo(5000, 3000);

sub pi {
    my $x = substr($pi, 0, 2, '');
    $x =~ s/^0+//;
    pi() if !length($x) and length($pi);
    $x;
}

while (length($pi)) {
    $img->fgcolor('white');

    my $p_i = pi() || 0;
    $img->line($p_i * ($p_i / sqrt($p_i + 1)) + $p_i);

    foreach $_ (0 .. $p_i + $p_i) {
        $img->fgcolor('green');
        $img->turn($p_i);
        $img->line(-$p_i);
        $img->line(-$p_i);
        $img->line(-$p_i);
        $img->line(-$p_i);
        $img->fgcolor('gray');
        $img->turn(-$p_i);
        $img->line($p_i);
        $img->line($p_i);
        $img->line($p_i);
        $img->line($p_i);
        $img->fgcolor('blue');
        $img->turn(-$p_i);
        $img->line($p_i);
        $img->fgcolor('purple');
        $img->turn($p_i);
        $img->line(-$p_i);
        $img->fgcolor('red');
        $img->turn($p_i);
        $img->line(-$p_i);
    }
}

my $i = 'pi_art_turtle.png';
open my $p, '>:raw', $i;
print $p $img->png;
close $p;

__DATA__
3.14159265358979323846264338327950288419716939937510582097494459230
7816406286208998628034825342117067982148086513282306647093844609550
5822317253594081284811174502841027019385211055596446229489549303819
6442881097566593344612847564823378678316527120190914564856692346034
8610454326648213393607260249141273724587006606315588174881520920962
8292540917153643678925903600113305305488204665213841469519415116094
3305727036575959195309218611738193261179310511854807446237996274956
7351885752724891227938183011949129833673362440656643086021394946395
2247371907021798609437027705392171762931767523846748184676694051320
0056812714526356082778577134275778960917363717872146844090122495343
0146549585371050792279689258923542019956112129021960864034418159813
6297747713099605187072113499999983729780499510597317328160963185950
2445945534690830264252230825334468503526193118817101000313783875288
6587533208381420617177669147303598253490428755468731159562863882353
7875937519577818577805321712268066130019278766111959092164201989380
