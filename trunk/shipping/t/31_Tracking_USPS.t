use strict;
use warnings;

use Test::More 'no_plan';
use Carp;
use Business::Shipping;

sub test
{
	my ( %args ) = @_;
	my $shipment = Business::Shipping->rate_request( 
		'shipper' => 'UPS',
		'user_id'		=> $ENV{ UPS_USER_ID },
		'password'		=> $ENV{ UPS_PASSWORD },
		'access_key'	=> $ENV{ UPS_ACCESS_KEY }, 
		'cache'	=> 0,
		event_handlers => {
			#trace => 'STDERR', 
		}
	);
	$shipment->submit( %args ) or die $shipment->error();
	return $shipment;
}

sub simple_test
{
	my ( %args ) = @_;
	my $shipment = test( %args );
	$shipment->submit() or die $shipment->error();
	my $total_charges = $shipment->total_charges(); 
	my $msg = 
			"UPS Simple Test: " 
		.	( $args{ weight } ? $args{ weight } . " pounds" : ( $args{ pounds } . "lbs and " . $args{ ounces } . "ounces" ) )
		.	" to " . ( $args{ to_city } ? $args{ to_city } . " " : '' )
		.	$args{ to_zip } . " via " . $args{ service }
		.	" = " . ( $total_charges ? '$' . $total_charges : "undef" );
	ok( $total_charges,	$msg );
}
	
ok( 1, "No tests yet" );

1;
