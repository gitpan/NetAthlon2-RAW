package NetAthlon2::RAW;

use 5.006;
use strict;
use warnings;

use Carp;
use POSIX qw(mktime);

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use NetAthlon2::RAW qw(:all);
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} });
our @EXPORT = qw();

our $VERSION = '0.10';

our $timeDelta = 1;
our $maxWatts = 2000;

local *FP;
local *DIR;

sub new {
	my ($class, %opts) = @_;
	my ($self);

	$self = \%opts;
	bless ($self, $class);

	return $self;
}

sub open {
	my ($self, $file) = @_;

	if ( -f $file ) {
		$self->{'file'} = $file;
	} else {
		carp "$file not a file";
	}

	open (*FP, $file) || croak "Could not open $file";
}

sub _parse_preamble {
	my ($self) = @_;

	carp "First line not 251"
		if ( $self->{'RAW'}[0] != 251 );

	$self->{'data'}->{'Sample Rate'} = int(${$self->{'RAW'}}[1]);

	carp "Line 3 not 1"
		if ( $self->{'RAW'}[2] != 1 );

	# Hear Rate info
	( $self->{'data'}->{'Heart Rate'}->{'Zone 1'}->{'Max'},
		$self->{'data'}->{'Heart Rate'}->{'Zone 3'}->{'Max'} ) =
		split (/\s/, ${$self->{'RAW'}}[3]);
	( $self->{'data'}->{'Heart Rate'}->{'Zone 1'}->{'Min'},
		$self->{'data'}->{'Heart Rate'}->{'Zone 3'}->{'Min'} ) =
		split (/\s/, ${$self->{'RAW'}}[4]);
	( $self->{'data'}->{'Heart Rate'}->{'Zone 2'}->{'Max'},
		$self->{'data'}->{'Heart Rate'}->{'Anaerobic Threshold'} ) =
		split (/\s/, ${$self->{'RAW'}}[5]);
	( $self->{'data'}->{'Heart Rate'}->{'Zone 2'}->{'Min'},
		$self->{'data'}->{'Heart Rate'}->{'Aerobic Threshold'} ) =
		split (/\s/, ${$self->{'RAW'}}[6]);

	# Store the start time (converting to UNIX timestamp)
	my ($mon, $day, $year, $hour, $h, $min, $m, $sec, $ampm);
	if ( $self->{'file'} =~ /Bike(\d{4})-(\d{2})-(\d{2}) (\d{1,2})-(\d{2})([ap]m)\.RAW$/ ) {
		$year = $1;
		$mon = $2;
		$day = $3;
		$h = $4;
		$m = $5;
		$ampm = $6;

		if ( ${$self->{'RAW'}}[8] =~ m/^(\d{2})\.(\d{2})\.(\d{2}).$/ ) {
			$hour = $1;
			$min = $2;
			$sec = $3;

			# FIXME: There is a bug in some of the RAW data files as
			# the time encoded in the filename is 1 minute after the
			# time encoded in the file contents, hence the different
			# comparison for the minute field.
			carp "Start time mismatch between file name ("
				. $self->{'file'}
				. ") and file contents"
				if ( $h != $hour || (abs($m-$min) > $timeDelta) || ${$self->{'RAW'}}[9] != ($ampm eq 'am' ? 0: 1));

			$hour += 12 if ( $ampm eq 'pm' );

		} else {
			croak "Can't verify performance start time";
		}
		$self->{'data'}->{'Start Time'} = mktime($sec, $min, $hour, $day, ($mon-1), ($year-1900));
	} else {
		croak "Can't determine what day this performance data is from";
	}
}

sub _parse_summary {
	my ($self) = @_;

	carp "Start of summary section line not 254"
		if ( $self->{'RAW'}[-5] != 254 );

	my ($h, $m, $s, $f) = split (/[\.\r]/, $self->{'RAW'}[-3] );
	chomp($f);
	$self->{'data'}->{'Elapsed Time'} = ($h * 3600 + $m * 60 + $s + $f / 100) + 0.0;

	# Reset the last Elapsed Time in the Check Points to match
	# the total Elapsed Time.
	$self->{'data'}->{'Check Points'}->[scalar @{$self->{'data'}->{'Check Points'}} - 1]->{'Elapsed Time'} 
		= $self->{'data'}->{'Elapsed Time'};

	carp "Second to last line not 256"
		if ( $self->{'RAW'}[-2] != 256 );

	my ($u);
	( $u, $self->{'data'}->{'Distance'}, $self->{'data'}->{'Cadence'} ) =
		split (/\s+/, ${$self->{'RAW'}}[-1]);
}

sub _parse_line {
	my ($self, $line) = @_;
	my ($time, $dist);
	chomp $line;
	chop $line;
	my ($hr, $u, $speed, $power, $cadence, $grade, $alt) = split /\s/, $line;

	$time = $self->{'data'}->{'Sample Rate'} * 
		( exists $self->{'data'}->{'Check Points'}
			? scalar @{$self->{'data'}->{'Check Points'}}
			: 0);

	# Insert a calculated distance for this Sample Rate,
	# which will be used in calculating the Average Speed.
	$dist = ( $speed / 10 ) *
		( exists $self->{'data'}->{'Check Points'}
			? ($self->{'data'}->{'Sample Rate'} / 3600)
			: 0);

	push @{$self->{'data'}->{'Check Points'}}, 
		{
			'Elapsed Time' => $time,
			'Calculated Distance' => $dist,
			'Heart Rate' => $hr,
			'Grade' => $grade / 10,
			'Speed' => $speed / 10,
			'Watts' => $power,
			'Cadence' => $cadence,
			'Altitude' => $alt,
		};
}

sub _add_averages {
	my ($self) = @_;

	# Calculate some useful averages
	my ( $c, $cc, $w, $wc, $hr, $hrc, $dist ) = ( 0, 0, 0, 0, 0, 0, 0 );
	map {
		if ( $_->{'Cadence'} > 0 ) {
			$c += $_->{'Cadence'}; $cc++;
		}

		# There is a bug when you have a warm up time, the first
		# checkpoint will have an unrealistic large value for Watts.
		if ( $_->{'Watts'} > 0 && $_->{'Watts'} < $maxWatts ) {
			$w += $_->{'Watts'}; $wc++;
		}
		if ( $_->{'Heart Rate'} > 0 ) {
			$hr += $_->{'Heart Rate'}; $hrc++;
		}
		$dist += $_->{'Calculated Distance'}
			if ( $_->{'Calculated Distance'} > 0 );
	} @{$self->{'data'}->{'Check Points'}};
	$self->{'data'}->{'Average Cadence'} = $c / $cc if ( $cc > 0 ); 
	$self->{'data'}->{'Average Watts'} = $w / $wc if ( $wc > 0 ); 
	$self->{'data'}->{'Average Heart Rate'} = $hr / $hrc if ( $hrc > 0 ); 

	# BUG:  The Distance listed in the file is the total distance 
	# ridden, vs the Elapsed Time is not including any warmup time
	# For example, in the Bike2009-10-25 5-05.RAW test file, the 
	# elapsed time is 2700 seconds (45 minutes), yet the distance traveled
	# is 16.87, which was covered in 60 minutes.  Therefor, need to recaclute
	# the average speed based on the checkpoint's average speed.
	#$self->{'data'}->{'Average Speed'} = 
	#	$self->{'data'}->{'Distance'} / ($self->{'data'}->{'Elapsed Time'} / 3600);
	$self->{'data'}->{'Calculated Distance'} = $dist;
	$self->{'data'}->{'Average Speed'} = $dist / ($self->{'data'}->{'Elapsed Time'} / 3600);
}

sub _verify_parse {
	my ($self) = @_;

	# Verify we got good data.  The number of sample lines should be close
	# to Elapsed Time / Sample Rate.  The 1.99 instead of 2 was determined
	# emperically, and probably due to samping error or clock flux.
	carp "Check Point Data does not match Sample Rate"
		if ( scalar @{$self->{'data'}->{'Check Points'}} !=
			int($self->{'data'}->{'Elapsed Time'} / $self->{'data'}->{'Sample Rate'} + 1.99));
}

sub parse {
	my ($self, $file) = @_;
	my ($cnt);

	$self->open($file);

	@{$self->{'RAW'}} = <FP>;

	$self->close();

	croak "Could not read data file"
		if ( ! scalar @{$self->{'RAW'}} );

	delete $self->{'data'};

	$self->_parse_preamble();

	$self->_parse_line($self->{'RAW'}[7]);
	for ($cnt = 10; $cnt < scalar (@{$self->{'RAW'}}) - 5; $cnt++) {
		$self->_parse_line($self->{'RAW'}[$cnt]);
	}
	$self->_parse_line($self->{'RAW'}[-4]);

	$self->_parse_summary();

	$self->_add_averages();

	$self->_verify_parse();

	return ($self->{'data'});
}

sub close {
	my ($self) = @_;

	close (FP);
}

1;
__END__

=head1 NAME

NetAthlon2::RAW - Perl extension to parse NetAthlon2 RAW performance data files

=head1 SYNOPSIS

 use NetAthlon2::RAW;

 my $t = NetAthlon2::RAW->new ();
 my $d = $t->parse('Bike2009-07-02 5-54pm.RAW');

=head1 DESCRIPTION

A perl module to parse the NetAthlon RAW file format.  parse() will return
a hash reference to the resultant data structure

=head1 METHODS

=over 4

=item new()

Creates a new NetAthlon2::RAW object.  new() does not accept any options
at this time.

=item parse($file)

Returns a hash reference with the contents of C<$file>.   Keys included are:

=over 4

=item Average Cadence

Calculation of the averages of the non-zero Cadence values from
the Check Points array.

=item Average Heart Rate

Calculation of the averages of the non-zero Heart Rate values from
the Check Points array.

=item Average Speed

Calculation of the averages of the non-zero Speed values from
the Check Points array.  Used to be just the division of the
Distance by the Elapsed Time, but the Elapsed Time is the time
of the race, where as the Distance is the whole distance,
including any warmup time.  This lead to incorrect Average
Speed calculations in version 0.01.

=item Average Watts

Calculation of the averages of the non-zero Watts values from
the Check Points array.

=item Cadence

The overall Cadence of the training session, in miles.

=item Check Points

This is an array of each sample taken during the training session.  Each
array element is an anonymous hash with the following keys:

=over 4

=item Altitude

The instantaneous Altitude at the Elapsed Time.

=item Cadence

The instantaneous Cadence at the Elapsed Time.

=item Elapsed Time

A calculation of when the sample was taken, based on the
number of samples collected multiplied by the Sample Rate.
Number is in seconds.

=item Grade

The instantaneous Grade at the Elapsed Time.

=item Heart Rate

The instantaneous Heart Rate at the Elapsed Time.

=item Speed

The instantaneous Speed at the Elapsed Time. Number is in miles
per hour.

=item Watts

The instantaneous Watts at the Elapsed Time.

=back

=item Distance

The overall Distance of the training session, in miles.

=item Elapsed Time

The time of the training session, in seconds.

=item Heart Rate

Values taken from the training session.

=over 4

=item Aerobic Threshold

=item Anaerobic Threshold

=item Zone 1

The highest training zone.

=over 4

=item Max

=item Min

=back

=item Zone 2

The second training zone.

=over 4

=item Max

=item Min

=back

=item Zone 3

The bottom training zone.

=over 4

=item Max

=item Min

=back

=back

=item Sample Rate

Number of seconds between each Check Point sample.

=item Start Time

The start time of the training session, in a UNIX time_t format.

=back

=back

=head1 VARIABLES

=over 4

=item $timeDelta

Number of minutes the time listed in the file name and the time listed inside
the file can vary before throwing an error.  The default is 1 minute.

=item $maxWatts

The maximum watts can be, to be used in calculating the Average Watts.
The default is 2000 watts.

=back

=head1 SEE ALSO

http://www.whitepeak.org/Raw.aspx

=head1 NOTES

I believe that the field that Martin lists on his web site
(www.whitepeak.org) as the Grade of the course is not.  In all my testing
the Grade was 0, whereas the field he listed as Unknown had positive and
negative values, and looks to me to be Grade * 10, so I have implemented
the code to show this deviation from Martin's documentation.

Based on some empirical data, I believe the Unknown value listed after the
Distance, is really Cadence for the entire time.  I have added the Cadence
field in addition to Average Cadence.

=head1 AUTHOR

Jim Pirzyk, E<lt>jim+perl@pirzyk.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2009 pirzyk.org
All rights reserved.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
