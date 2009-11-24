#!/usr/bin/env perl

use strict;
use warnings;
use Archive::Tar;

use Test;
use POSIX qw(tzset);

BEGIN { plan test => 54 }

use NetAthlon2::RAW;

my $testfiles = {
	'Bike2009-07-02 5-54pm.RAW' => {
		'TimeZone' => 'EDT',
		'Distance' => 0.03,
		'Elapsed Time' => 12.76,
		'Average Cadence' => 28,
		'Average Watts' => 47,
		'Start Time' => 1246557240,
		'Check Points' => 2,
		'Max Cadence' => 28,
		'Max Speed' => 7.2,
		'Max Watts' => 47,
	},

	'Bike2009-08-20 4-53pm.RAW' => {
		'TimeZone' => 'EDT',
		'Distance' => 32.90,
		'Elapsed Time' => 6951.49,
		'Average Cadence' => 87.6522,
		'Average Watts' => 187.8943,
		'Start Time' => 1250787180,
		'Check Points' => 465,
		'Max Watts' => 419,
		'Max Speed' => 24.6,
		'Max Cadence' => 97,
		'Max Heart Rate' => 165,
	},

	# Test a larger time delta between filename and contents
	'Bike2009-09-21 4-30pm.RAW' => {
		'TimeZone' => 'EDT',
		'timeDelta' => 5,
		'Distance' => 0.60,
		'Elapsed Time' => 160.43,
		'Average Cadence' => 71.7142,
		'Average Watts' => 114,
		'Start Time' => 1253550420,
		'Check Points' => 12,
		'Max Watts' => 152,
		'Max Speed' => '15.3',
		'Max Cadence' => 80,
		'Max Heart Rate' => 106,
	},

	# Test with a extremely unrealistic power value in the first checkpoint
	# and a distance that does not match the elapsed time because of warmup
	# time
	'Bike2009-10-25 5-05pm.RAW' => {
		'TimeZone' => 'EDT',
		'Distance' => 16.87,
		'Elapsed Time' => 2700,
		'Average Cadence' => 95.5222,
		'Average Watts' => 179.5388,
		'Start Time' => 1256490300,
		'Check Points' => 181,
		'Max Watts' => 323,
		'Max Speed' => '21.9',
		'Max Cadence' => 127,
		'Max Heart Rate' => 164,
	},

	# Test the am/pm conversion
	'Bike2009-11-08 12-13pm.RAW' => {
		'TimeZone' => 'EST',
		'Distance' => 19.78,
		'Elapsed Time' => 3600,
		'Average Cadence' => 83.2833,
		'Average Watts' => 259.2833,
		'Start Time' => 1257700380,
		'Check Points' => 241,
		'Max Watts' => 805,
		'Max Speed' => '32.6',
		'Max Cadence' => 107,
		'Max Heart Rate' => 208,
	},
};

my $t = NetAthlon2::RAW->new ();

# Hack to unpack the .RAW files
# (cant have a filename with a space in the MANIFEST file).
my $tar = Archive::Tar->new;
chdir('t');
$tar->read('test.tar');
$tar->extract();

sub round_off {
	my ($value) = @_;

	return ((int ($value * 10000)) / 10000);
}

for my $file ( keys %$testfiles ) {
	$NetAthlon2::RAW::timeDelta = ( exists $testfiles->{$file}->{'timeDelta'} )
		? $testfiles->{$file}->{'timeDelta'}
		: 1;

	# Set the timezone, so our ./Build test works with machines
	# not in the same timezone as the author is in.
	if ( exists $testfiles->{$file}->{'TimeZone'} ) {
		$ENV{'TZ'} = $testfiles->{$file}->{'TimeZone'};
		tzset()
			if ( $^O ne 'MSWin32' );
	} elsif ( defined $ENV{'TZ'} ) {
		delete $ENV{'TZ'};
	}

	my $d = $t->parse($file);
	ok(ref $d, 'HASH');
	for my $test ( keys %{$testfiles->{$file}} ) {
		if ( $test eq 'Check Points' ) {
			ok(scalar @{$d->{$test}}, $testfiles->{$file}->{$test}, "Failed test ($test) for file ($file)");

		# Skip the Start Time validation on M$ systems because of
		# the complications with timezones.
		} elsif ( $test eq 'Start Time' ) {
			if ( $^O ne 'MSWin32' ) {
				ok($d->{$test}, $testfiles->{$file}->{$test}, "Failed test ($test), in file ($file)")
			} else {
				ok (0, 0, "# Not testing Start Time on Windows");
			}
		} elsif ( $test ne 'timeDelta' && $test ne 'TimeZone' ) {
			ok(&round_off($d->{$test}), $testfiles->{$file}->{$test}, "Failed test ($test), in file ($file)");
		}
	}
}

exit 0;
