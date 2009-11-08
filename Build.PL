use strict;
use Module::Build;
use vars qw($build);

my $build = Module::Build->new (
	module_name		=> 'NetAthlon2::RAW',
	license			=> 'perl',
	create_makefile_pl	=> 'passthrough',
	create_readme		=> 1,
	sign				=> 0,
	add_to_cleanup		=> ['t/Bike*.RAW'],

	requires			=> {
		'perl'		=> '5.005_03',
		'Carp'		=> 0,
	},

	recommendes		=> {
		'Test'		=> 0,
		'Archive::Tar'	=> 0,
	},
);

$build->create_build_script;
