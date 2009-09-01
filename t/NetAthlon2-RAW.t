#!/usr/bin/env perl

use strict;
use warnings;

use Test;
BEGIN { plan test => 2 * 7 };

use NetAthlon2::RAW;

my ($d, $f);
my $t = NetAthlon2::RAW->new ();

# Hack to unpack the .RAW files (can't have a filename with
# a space in the MANIFEST file).
`tar -x -C t -f t/test.tar`;

$d = $t->parse('t/Bike2009-07-02 5-54pm.RAW');
ok(ref $d, 'HASH' );
ok($d->{'Distance'}, 0.03);
ok($d->{'Elapsed Time'}, 12.76);
ok($d->{'Average Cadence'}, 28);
ok($d->{'Average Watts'}, 47);
ok($d->{'Start Time'}, 1246575240);
ok(scalar @{$d->{'Check Points'}}, 2);

$d = $t->parse('t/Bike2009-08-20 4-53pm.RAW');
ok(ref $d, 'HASH' );
ok($d->{'Distance'}, '32.90');
ok($d->{'Elapsed Time'}, 6951.49);
ok($d->{'Average Cadence'}, 87.6522678185745);
ok($d->{'Average Watts'}, 187.621505376344);
ok($d->{'Start Time'}, 1250805180);
ok(scalar @{$d->{'Check Points'}}, 465);

exit 0;
