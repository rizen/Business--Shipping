# Copyright (c) 2003 Kavod Technologies, Dan Browning, and Kevin Old.
# All rights reserved. This program is free software; you can redistribute it
# and/or modify it under the same terms as Perl itself.

package Business::Ship::USPS;
use strict;
use warnings;

=head1 NAME

Business::Ship::USPS - A USPS module 

Documentation forthcoming.

 * Register for the API here:
 
http://www.uspsprioritymail.com/et_regcert.html

 * You will need to call or e-mail to active the account for "Production" usage
 * Otherwise, it will only work with special test queries.

=cut

use vars qw(@ISA $VERSION);
$VERSION = sprintf("%d.%03d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

use Business::Ship;
use Business::Ship::USPS::Package;


use LWP::UserAgent;
use HTTP::Request;
use HTTP::Response;
use XML::Simple 2.05;
use XML::DOM;


use Data::Dumper;

@ISA = qw( Business::Ship );

sub new
{
	my( $class, %arg ) = @_;

	my $self = $class->SUPER::new();
	
	my %internal = (
		ua			=> new LWP::UserAgent,
		xs			=> new XML::Simple,
		packages	=> [ new Business::Ship::USPS::Package ],
		intl		=> undef,
		domestic	=> undef,
	);
	
	# These should be in USPS::Package now... called through build_subs_packages()
	my %optional = (
		
	);

	my %parent_defaults = (qw|
		test_url	http://testing.shippingapis.com/ShippingAPItest.dll
		prod_url	http://production.shippingapis.com/ShippingAPI.dll
	|);
	
	bless( $self, $class );
	
	my %package_subs = (
		id			=> undef,
		service		=> undef,
		pounds		=> undef,
		ounces		=> 0,
		container	=> 'None',
		size		=> 'Regular',
		machinable	=> 'False',
		
		mail_type	=> 'package',
	);
	
	# We need our internals for the rest of it...
	$self->build_subs( keys %internal );
	$self->set( %internal );
	$self->build_subs_packages( keys %package_subs );
	$self->set( %optional, %parent_defaults, %arg );
	
	return $self;
}

# This is to redirect calls to the package level (so that
# people who wont ever ship multiple packages don't have to
# deal with the complexity of it.
sub build_subs_packages
{
	my $self = shift;
    foreach( @_ ) {
		unless ( $self->can( $_ ) ) {
			eval "sub $_ { my \$self = shift; if(\@_) { \$self->{'packages'}->[0]->$_( shift ); } return \$self->{'packages'}->[0]->$_(); }";
		}
    }
	return;
}

sub _gen_url
{
	my ( $self ) = shift;
	
	return( $self->test_mode() ? $self->test_url() : $self->prod_url() );
}

# _gen_request_xml()
# Generate the XML document.
sub _gen_request_xml
{
	my $self = shift;
	
	# Note: The XML::Simple hash-tree-based generation method wont work with USPS,
	# because they enforce the order of their parameters (unlike UPS).
	
	my $rateReqDoc = new XML::DOM::Document; 
	my $rateReqEl = $rateReqDoc->createElement( 
		$self->domestic() ? 'RateRequest' : 'IntlRateRequest' 
	);
	
	$rateReqEl->setAttribute('USERID', $self->user_id() ); 
	$rateReqEl->setAttribute('PASSWORD', $self->password() ); 
	$rateReqDoc->appendChild($rateReqEl);
	
	my $package_count = 0;
	
	die "No packages defined internally." unless ref $self->packages();
	foreach my $package ( @{$self->packages()} ) {

		my $id;
		$id = $package->id();
		$id = $package_count++ unless $id;
		my $packageEl = $rateReqDoc->createElement('Package'); 
		$packageEl->setAttribute('ID', $id); 
		$rateReqEl->appendChild($packageEl); 
		
		if ( $self->domestic() ) {
			my $serviceEl = $rateReqDoc->createElement('Service'); 
			my $serviceText = $rateReqDoc->createTextNode( $package->service() ); 
			$serviceEl->appendChild($serviceText); 
			$packageEl->appendChild($serviceEl);
		
			my $zipOrigEl = $rateReqDoc->createElement('ZipOrigination'); 
			my $zipOrigText = $rateReqDoc->createTextNode( $package->from_zip()); 
			$zipOrigEl->appendChild($zipOrigText); 
			$packageEl->appendChild($zipOrigEl); 
			
			my $zipDestEl = $rateReqDoc->createElement('ZipDestination'); 
			my $zipDestText = $rateReqDoc->createTextNode( $package->to_zip()); 
			$zipDestEl->appendChild($zipDestText); 
			$packageEl->appendChild($zipDestEl); 
		}
		
		my $poundsEl = $rateReqDoc->createElement('Pounds'); 
		my $poundsText = $rateReqDoc->createTextNode( $package->pounds() );
		$poundsEl->appendChild($poundsText); 
		$packageEl->appendChild($poundsEl); 
		
		my $ouncesEl = $rateReqDoc->createElement('Ounces'); 
		my $ouncesText = $rateReqDoc->createTextNode( $package->ounces() ); 
		$ouncesEl->appendChild($ouncesText); 
		$packageEl->appendChild($ouncesEl);
		
		if ( $self->domestic() ) {
			my $containerEl = $rateReqDoc->createElement('Container'); 
			my $containerText = $rateReqDoc->createTextNode( $package->container() ); 
			$containerEl->appendChild($containerText); 
			$packageEl->appendChild($containerEl); 
			
			my $oversizeEl = $rateReqDoc->createElement('Size'); 
			my $oversizeText = $rateReqDoc->createTextNode( $package->size() ); 
			$oversizeEl->appendChild($oversizeText); 
			$packageEl->appendChild($oversizeEl); 
			
			my $machineEl = $rateReqDoc->createElement('Machinable'); 
			my $machineText = $rateReqDoc->createTextNode( $package->machinable() ); 
			$machineEl->appendChild($machineText); 
			$packageEl->appendChild($machineEl);
		}
		elsif ( $self->intl() ) {
			my $mailTypeEl = $rateReqDoc->createElement('MailType'); 
			my $mailTypeText = $rateReqDoc->createTextNode( $package->mail_type() ); 
			$mailTypeEl->appendChild($mailTypeText); 
			$packageEl->appendChild($mailTypeEl); 
			
			my $countryEl = $rateReqDoc->createElement('Country'); 
			my $countryText = $rateReqDoc->createTextNode( $package->to_country() ); 
			$countryEl->appendChild($countryText); 
			$packageEl->appendChild($countryEl);
		}
	
	} #/foreach package
	my $request_xml = $rateReqDoc->toString();
	
	$self->debug( "request xml = \n" .  $request_xml );
	
	return ( $request_xml );
}

sub _gen_request
{
	my ( $self ) = shift;
	
	# The "API=...&XML=" is the only part that is different from UPS...
	my $request_xml;
	$request_xml .= 'API=';
	$request_xml .= $self->domestic() ? 'Rate' : 'IntlRate';
	$request_xml .= '&XML=';
	$request_xml .= $self->_gen_request_xml();

	my $request = new HTTP::Request 'POST', $self->_gen_url();
	
	$request->header( 'content-type' => 'application/x-www-form-urlencoded' );
	$request->header( 'content-length' => length( $request_xml ) );
	
	$request->content(  $request_xml );
	
	return ( $request );
}

sub _massage_values
{
	my $self = shift;
	$self->_set_pounds_ounces();
	$self->_domestic_or_intl();
	return;
}

sub add_package
{
	my $self = shift;
	$self->trace('called with' . $self->uneval( @_ ) );
	
	my $new = new Business::Ship::USPS::Package( @_ );
	
	# If the passed package has an ID, then use that.
	if ( $new->id() or ( $new->id() and $new->id() == 0 ) ) {
		$self->trace( "Using id in passed package" );
		$self->packages()->[$new->id()] = $new;
		return 1;
	}
		
	# If the "default" package ($self->packages()->[0]) is 
	# still in "default" state (has not yet been updated),
	# then replace it with the passed package.
	
	if ( $self->default_package()->is_empty() ) {
		$self->packages()->[0] = $new;
		return 1;	
	}
	
	# Otherwise, add the package in the second slot.
	push( @{$self->packages()}, $new );
	
	return 1;
}

sub validate
{
	my $self = shift;
	
	#TODO: Check all values before submitting
	
	return 1;
}



sub gen_unique_values
{
	my $self = shift;
	
	# USPS unique keys are:  all package vars joined together.
	
	# Nothing unique at this level either, try the USPS::Package level...
	my @unique_values;
	foreach my $package ( @{$self->packages()} ) {
		push @unique_values, $package->get_unique_values()
	}
	
	# We prefer 0 in the key to represent 'undef'
	# clean it all up...
	my @new_unique_values;
	foreach my $value ( @unique_values ) {
		if ( not defined $value ) {
			$value = 0;
		}
		push @new_unique_values, $value;
	}

	return( @new_unique_values );
}

# Caches responses for speed.  Not all API users will be able to extract all
# of the pakage rates for each service at once, they will have to do it twice. 
# This helps a lot.
sub get_response
{
	my $self = shift;
	my $request = shift;
	
	my @unique_values = $self->gen_unique_values();
	my $key = join( "|", @unique_values );
	my $response = $self->cache()->get( $key );
	if ( not defined $response ) {
		#$self->trace( "unique_values = " . $self->uneval( @unique_values ) );
		$self->trace( "running request manually, then add to cache." );
		$response = $self->{'ua'}->request( $request );
		#TODO: Allow setting of cache properties (time limit, enable/disable, etc.)
		$self->cache()->set( $key, $response, "2 days" ); 
	}
	else {
		$self->trace( "using cached response." );
	}
	return $response;	
}
=item $shipment->submit( [%args] )

This method sets some values (optional), generates the request, then parses and
the results and assigns the total_charges amount.

=cut

sub submit
{
	my ( $self, %args ) = @_;
	
	$self->trace( "calling with ( " . $self->uneval( %args ) . " )" );
	
	$self->set( %args ) if %args;
	
	$self->_massage_values();
	$self->validate() or return ( undef );
	
	#my $cached_results = $self->try_cache();
	#if ( defined $cached_results ) {
	#	#TODO: use the cached ones instead of continuing
	#}
	
	my $request = $self->_gen_request();
	
	$self->response( $self->get_response( $request ) );
	
	$self->debug( "response content = " . $self->response()->content() );
	
	my $content;
	
	if ( $self->response()->is_success() ) { 
		 $content = $self->response->content; 
	}
	else { 
		$self->error( "HTTP Error.  Content = " . $content ); 
		return( undef ); 
	}	
	
	my $response_tree = $self->{xs}->XMLin( $self->response()->content(), ForceArray => 0, KeepRoot => 0 );
	
	# TODO: Handle multiple packages errors.
	if ( $response_tree->{Package}->{Error} ) {
		my $error_number 		= $response_tree->{Package}->{Error}->{Number};
		my $error_source 		= $response_tree->{Package}->{Error}->{Source};
		my $error_description	= $response_tree->{Package}->{Error}->{Description};
		$self->error( "$error_source: $error_description ($error_number)" );
		return( undef );
	}
	
	$self->response_tree( $response_tree );
	
	if ( $self->domestic() ) {
		$self->total_charges( $response_tree->{Package}->{Postage} );
	}
	elsif ( $self->intl() ) {
		
		# For now, total_charges will just be the first service returned.
		$self->total_charges( $response_tree->{Package}->{Service}->[0]->{Postage} );
		
		foreach my $service ( @{ $response_tree->{Package}->{Service} } ) {
			$self->debug( " Postage = " . $service->{Postage} );
			$self->packages()->[0]->set_price( $service->{SvcDescription}, $service->{Postage} );
		}
	}
	
	return $self->success( 1 );
}



sub _set_pounds_ounces
{
	my $self = shift;
	unless( $self->pounds() ) {
		$self->pounds( $self->weight() );
	}
	
	# Can pounds be a fraction?  Or do we need to calc the ounces?
	return;
}


# Decide if we are domestic or international for this run...
sub _domestic_or_intl
{
	my $self = shift;
	
	if ( $self->to_country() ) {
		$self->intl( 1 );
		$self->domestic( 0 );
	}
	else {
		$self->intl( 0 );
		$self->domestic( 1 );
	}
	
	return;
}

=pod

 * International Service types:
 
	'Global Express Guaranteed Document Service',
	'Global Express Guaranteed Non-Document Service',
	'Global Express Mail (EMS)',
	'Global Priority Mail - Flat-rate Envelope (large)',
	'Global Priority Mail - Flat-rate Envelope (small)',
	'Global Priority Mail - Variable Weight Envelope (single)',
	'Airmail Letter Post',
	'Airmail Parcel Post',
	'Economy (Surface) Letter Post',
	'Economy (Surface) Parcel Post',


=cut

=head1 SEE ALSO

	http://www.uspswebtools.com/

=head1 AUTHOR

	Initially developed by Kevin Old, later rewritten by Dan Browning.
	
	Dan Browning <db@kavod.com>
	Kavod Technologies
	http://www.kavod.com
	
	Kevin Old <kold@carolina.rr.com>

=head1 COPYRIGHT

	Copyright (c) 2003 Kavod Technologies, Dan Browning, and Kevin Old.
	All rights reserved. This program is free software; you can redistribute it
	and/or modify it under the same terms as Perl itself.

=cut

1;
