package Net::Nylas::Calendar::Participant;

use Moose;
with 'Net::Nylas::Calendar::ToJson';
use Types::Standard qw( Enum );

has [ qw( email name comment phone_number ) ], is => 'ro';
has status => is => 'ro', isa => Enum[qw( yes no maybe noreply )];

__PACKAGE__->meta->make_immutable;

1;
