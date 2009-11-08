#!/usr/bin/env perl

use strict;
use warnings;
use Archive::Tar;

use Test;
BEGIN { plan test => 4 * 7 };

use NetAthlon2::RAW;

my ($d, $f);
my $t = NetAthlon2::RAW->new ();

# Set the timezone, so our ./Build test works with machines
# not in the same timezone as the author is in.
$ENV{'TZ'} = 'EDT';

# Hack to unpack the .RAW files
# (can't have a filename with a space in the MANIFEST file).
my $tar = Archive::Tar->new;
chdir('t');
$tar->read('test.tar');
$tar->extract();

$d = $t->parse('Bike2009-07-02 5-54pm.RAW');
ok(ref $d, 'HASH' );
ok($d->{'Distance'}, 0.03);
ok($d->{'Elapsed Time'}, 12.76);
ok($d->{'Average Cadence'}, 28);
ok($d->{'Average Watts'}, 47);
ok($d->{'Start Time'}, 1246557240);
ok(scalar @{$d->{'Check Points'}}, 2);

$d = $t->parse('Bike2009-08-20 4-53pm.RAW');
ok(ref $d, 'HASH' );
ok($d->{'Distance'}, '32.90');
ok($d->{'Elapsed Time'}, 6951.49);
ok($d->{'Average Cadence'}, 87.6522678185745);
ok($d->{'Average Watts'}, 187.621505376344);
ok($d->{'Start Time'}, 1250787180);
ok(scalar @{$d->{'Check Points'}}, 465);

$NetAthlon2::RAW::timeDelta = 5;
$d = $t->parse('Bike2009-09-21 4-30pm.RAW');
ok(ref $d, 'HASH' );
ok($d->{'Distance'}, '0.60');
ok($d->{'Elapsed Time'}, 160.43);
ok($d->{'Average Cadence'}, 71.7142857142857);
ok($d->{'Average Watts'}, 109);
ok($d->{'Start Time'}, 1253550420);
ok(scalar @{$d->{'Check Points'}}, 12);

$NetAthlon2::RAW::timeDelta = 1;
$d = $t->parse('Bike2009-10-25 5-05pm.RAW');
ok(ref $d, 'HASH' );
ok($d->{'Distance'}, 16.87);
ok($d->{'Elapsed Time'}, 2700);
ok($d->{'Average Cadence'}, 95.5222222222222);
ok($d->{'Average Watts'}, 179.538888888889);
ok($d->{'Start Time'}, 1256490300);
ok(scalar @{$d->{'Check Points'}}, 181);

exit 0;
