package Net::Nylas::Calendar::Organizer;

use Moose;
with 'Net::Nylas::Calendar::ToJson';

has [ qw( email name ) ], is => 'ro';

1;
