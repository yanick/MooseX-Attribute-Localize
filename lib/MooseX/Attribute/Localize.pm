#!/usr/bin/perl 

use strict;
use warnings;

=head1 SYNOPSIS

    package Foo; 

    use Moose;
    use MooseX::Attribute::Localize;

    has 'bar' => (
        traits => [ 'Localize' ],
        is => 'rw',
        handles => {
            set_local_bar => 'localize'
        },
    );

    my $foo = Foo->new( bar => 'a' );

    print $foo->bar;  # 'a'

    { 
        my $sentinel = $foo->set_local_bar( 'b' );
        print $foo->bar;  # 'b'

        $foo->bar('c');
        print $foo->bar;  # 'c'
    }

    print $foo->bar;  # 'a'

    {
        my $sentinel = $foo->set_local_bar;
        print $foo->bar;  # 'a'

        $foo->bar('c');
        print $foo->bar;  # 'c'
    }

    print $foo->bar;  # 'a'


=head1 DESCRIPTION

Attributes that are given the trait C<Localize> can
handle a C<localize> delegation, which stashes away
the current value of the attribute and replaces it 
with a local value, mimicking the behavior of 
Perl's own C<local>.

The delegated method returns a sentinel variable.
Once this variable gets out of scope, the attribute
returns to its previous value. 

If the delegated method
is called in a void context, a warning will be issued as 
the sentinel will immediately get out of scope, which 
turns the whole thing into a glorious no-op.

=head1 PROVIDED METHODS

=head2 localize( $new_value )

Localizes the attribute. If a C<$new_value> is provided, initializes the newly localized 
value to it. If not, the new value will be a copy of the previous one. Beware, though: the copy is a shallow one, so 
references will end up pointing to the same structure.

The method returns a sentinel object that will return the attribute to its previous value once it gets
out of scope. The method will warn if it is called in a void context (as the sentinel will immediately
falls out of scope). 

=cut


package MooseX::Attribute::Localize {
    use Moose::Role;

    has _value_stack => (
        traits => [ qw/ Array / ],
        is => 'ro',
        default => sub { [] },
        handles => {
            _push_value => 'push',
            _pop_value => 'pop',
        },
    );

    before '_canonicalize_handles' => sub {
        my( $self ) = @_;

        my $handles = $self->handles;

        $_ = sub { 
                my $object = shift;

                my $attr = $object->meta->get_attribute( $self->name );

                my ( $old ) = $attr->_push_value( $attr->get_value($object) );

                my $new_value = @_ ? shift : $old;

                $attr->set_value( $object, $new_value );

                warn "localize called in void context is a no-op\n"
                    unless defined wantarray;

                return MooseX::Attribute::Localize::Sentinel->new(
                    attribute => $attr,
                    object => $object,
                );
        } for grep { $_ eq 'localize' } values %$handles;

    };

}

{
package MooseX::Attribute::Localize::Sentinel; 

    use Moose;

    has [qw/ attribute object /] => ( is => 'ro' );

    sub DEMOLISH {
        my $self = shift;
        $self->attribute->set_value( $self->object, $self->attribute->_pop_value );
    }
}

{
    package Moose::Meta::Attribute::Custom::Trait::Localize;

    sub register_implementation { 'MooseX::Attribute::Localize' }

}

1;

