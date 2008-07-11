package Business::Shipping::USPS_Online::Package;

=head1 NAME

Business::Shipping::USPS_Online::Package

=head1 VERSION

$Rev$

=head1 METHODS

=cut

$VERSION = do { my $r = q$Rev$; $r =~ /\d+/; $&; };

use strict;
use warnings;
use vars qw( $VERSION );
use base ( 'Business::Shipping::Package' );
use Business::Shipping::Logging;
use Business::Shipping::Util;

=head2 container

Default 'None'. 

=head2 size

Default 'Regular'.

=head2 machinable

Default 'False'.

=head2 mail_type

Default 'Package'.

=head2 pounds

=head2 ounces

=cut

use Class::MethodMaker 2.0
    [
      new    => [ { -hash => 1 }, 'new' ],
      new    => 'default_new',
      scalar => [ { -default => undef     }, 'container'  ],
      scalar => [ { -default => 'Regular' }, 'size'       ],
      scalar => [ { -default => undef     }, 'machinable' ],
      scalar => [ { -default => 'Package' }, 'mail_type'  ],
      scalar => [ { -default => '0.00'    }, 'ounces'     ],
      scalar => [ { -default => '0.00'    }, 'pounds'     ],
      scalar => [ { -default => ''        }, 'width'      ],
      scalar => [ { -default => ''        }, 'height'     ],
      scalar => [ { -default => ''        }, 'length'     ],
      scalar => [ { -default => ''        }, 'girth'      ],      
    ];
    

=head2 weight

Overrides the standard weight definition so that it can correctly set pounds &
ounces.

=cut

sub weight
{
    my ( $self, $in_weight ) = @_;
    trace( '(' . uneval( \@_ ) . ')' );
    
    if ( $in_weight ) {
        $self->set_lbs_oz( $in_weight );
    }
    # Convert back to 'weight' (i.e. one number) when returning.
    my $out_weight = $self->lbs_oz_to_weight;
    
    return $out_weight;
}

=head2 set_lbs_oz

Set pounds and ounces.  Converts from fractional pounds.

=cut

sub set_lbs_oz
{
    my ( $self, $in_weight ) = @_;
    
    my $pounds = 0;
    my $ounces = 0;
    
    $pounds = int $in_weight ;
    my $remainder = $in_weight - $pounds;
    # For some weights (e.g. 2.4), this is necessary.
    $remainder = 0 if $remainder < 0;
    if ( $remainder ) {
        $ounces = $remainder * 16;
        $ounces = sprintf( "%1.0f", $ounces );
    }
    $self->pounds( $pounds );
    $self->ounces( $ounces );
    
    return;
}

=head2 lbs_oz_to_weight

Converts pounds + ounces to fractional weight.  Returns weight.

=cut

sub lbs_oz_to_weight
{
    my ( $self ) = @_;
    
    trace '()';
    
    my $pounds = $self->pounds || 0;
    my $ounces = $self->ounces || 0;
    my $fractional_pounds = $ounces ? ($ounces / 16 ) : 0;
    my $weight = ( $pounds + $fractional_pounds );
    
    return $weight;
}

1;

__END__

=head1 AUTHOR

Dan Browning E<lt>F<db@kavod.com>E<gt>, Kavod Technologies, L<http://www.kavod.com>.

=head1 COPYRIGHT AND LICENCE

Copyright (c) 2003-2004 Kavod Technologies, Dan Browning. All rights reserved.
This program is free software; you may redistribute it and/or modify it under
the same terms as Perl itself. See LICENSE for more info.

=cut